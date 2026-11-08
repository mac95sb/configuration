#!/usr/bin/python3
"""Root-only capture, restic verification and staged recovery. See README.md."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
import pwd
import grp
from pathlib import Path
import re
import secrets
import shutil
import signal
import sqlite3
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid

REPOSITORY = "rclone:R2:home-backups/restic-v1"
REMOTE = "R2:home-backups/recovery-v1"
EXCLUDES = {"node_modules", ".build", "__pycache__", ".cache", "Caches"}
TOOLS = {n: "/usr/local/bin/" + n for n in ("restic", "rclone", "age", "fnox", "pitchfork")}
RUNTIME = Path("/usr/local/libexec/mac-server/backup")
METRICS = Path("/Users/svc_observability/textfile")
SERVICE_ENV = {"PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
               "HOME": "/var/root", "USER": "root", "LOGNAME": "root",
               "PITCHFORK_SUPERVISOR_AUTO_START": "false", "PITCHFORK_USER": "root",
               "XDG_CONFIG_HOME": "/etc"}
# -I intentionally excludes the script directory. Add only this root-controlled runtime.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from courier import write_metric


def run(args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def output(args, **kwargs):
    return run(args, stdout=subprocess.PIPE, **kwargs).stdout


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def private(path, directory=False):
    path = Path(path)
    s = path.lstat()
    require(not path.is_symlink() and s.st_uid == 0 and not s.st_mode & 0o077,
            "must be root-owned and private: " + str(path))
    require(stat.S_ISDIR(s.st_mode) if directory else stat.S_ISREG(s.st_mode),
            "unexpected file type: " + str(path))


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic_json(path, value):
    path = Path(path)
    tmp = path.with_name(path.name + "." + uuid.uuid4().hex)
    with tmp.open("x") as f:
        json.dump(value, f, sort_keys=True, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)
    sync_directory(path.parent)


def rename_exclusive(source, destination):
    # Never let an atomic directory rename replace even an empty unrelated target.
    import ctypes
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == "darwin":
        result = libc.renamex_np(os.fsencode(source), os.fsencode(destination), 4)  # RENAME_EXCL
    else:
        result = libc.renameat2(-100, os.fsencode(source), -100, os.fsencode(destination), 1)
    if result:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(destination))
    sync_directory(Path(source).parent)
    sync_directory(Path(destination).parent)


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def inventory(root, manifest=False):
    result = {}
    for p in sorted(root.rglob("*")):
        rel = str(p.relative_to(root))
        if manifest and rel == "manifest.json":
            continue
        s = p.lstat()
        item = {"mode": stat.S_IMODE(s.st_mode), "uid": s.st_uid, "gid": s.st_gid}
        if p.is_symlink():
            # Restic/macOS recreate symlinks with the restore umask; link mode is not access control.
            item.pop("mode")
            item.update(type="symlink", target=os.readlink(p))
        elif p.is_file():
            item.update(type="file", sha256=digest(p), size=s.st_size)
        elif p.is_dir():
            item.update(type="directory")
        else:
            raise RuntimeError("unsupported special file: " + str(p))
        result[rel] = item
    return result


def copy_file(src, dst):
    shutil.copy2(src, dst, follow_symlinks=False)
    s = os.lstat(src)
    os.chown(dst, s.st_uid, s.st_gid, follow_symlinks=False)
    return dst


def copy_tree(src, dst, excluded=False):
    def ignore(directory, names):
        return EXCLUDES.intersection(names) if excluded else set()
    shutil.copytree(src, dst, symlinks=True, copy_function=copy_file, ignore=ignore)
    # copytree preserves directory modes/timestamps but not owners.
    for p in [Path(src)] + list(Path(src).rglob("*")):
        relative = p.relative_to(src)
        if excluded and any(part in EXCLUDES for part in relative.parts):
            continue
        q = Path(dst) / relative
        if q.exists() or q.is_symlink():
            s = p.lstat()
            os.chown(q, s.st_uid, s.st_gid, follow_symlinks=False)


class Coordinator:
    def __init__(self, fixture=None):
        self.fixture = fixture is not None
        self.tools = dict(TOOLS)
        self.base = Path("/var/db/home-backup")
        self.etc = Path("/etc/fnox")
        self.developer = Path("/Users/mac/Developer")
        self.forgejo = Path("/Users/svc_forgejo/forgejo-data")
        self.grafana = Path("/Users/svc_observability/grafana-data")
        self.export = Path("/var/db/home-backup-export/recovery-v1")
        self.repository = REPOSITORY
        self.service_adapter = None
        self.metrics = METRICS
        self.metric_gid = None
        if fixture:
            # The fixture flag is permitted only unprivileged, never by the root launcher.
            require(os.geteuid() != 0, "fixture mode must not run as root")
            cfg = json.loads(Path(fixture).read_text())
            for name in ("base", "etc", "developer", "forgejo", "grafana", "export"):
                setattr(self, name, Path(cfg[name]).resolve())
            self.repository = cfg["repository"]
            require(":" not in self.repository, "fixtures require a local repository")
            self.tools.update(cfg["tools"])
            self.service_adapter = cfg["service_adapter"]
            self.base.mkdir(mode=0o700, parents=True, exist_ok=True)
            self.metrics = self.base / "metrics"
            self.metrics.mkdir()
            self.metric_gid = os.getgid()
        else:
            require(os.geteuid() == 0, "run through the installed root fnox launcher")
            private(self.etc / "operational.key")
            private(self.etc / "config.toml")
            private(self.etc, directory=True)
        self.base.mkdir(mode=0o700, parents=True, exist_ok=True)
        if not self.fixture:
            private(self.base, directory=True)
        self.password = self.etc / "restic-password.age"
        if not self.fixture and os.path.lexists(self.password):
            private(self.password)
        self.env = dict(os.environ)
        if self.fixture:
            self.env["RCLONE_CONFIG"] = os.devnull
        # Never let inherited restic password/repository overrides bypass the coordinator.
        for key in list(self.env):
            if key.startswith("RESTIC_"):
                del self.env[key]
        self.env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        self.env["RESTIC_CACHE_DIR"] = str(self.base / "cache")
        self.env["RESTIC_PASSWORD_COMMAND"] = " ".join(
            __import__("shlex").quote(str(x)) for x in
            [self.tools["age"], "--decrypt", "--identity", self.etc / "operational.key", self.password])

    @contextlib.contextmanager
    def lock(self):
        path = self.base / "mutation.lock"
        fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w") as f:
            try:
                fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError("another backup/recovery operation holds the lock")
            yield

    def restic(self, *args, **kwargs):
        return output([self.tools["restic"], "--repo", self.repository, *args], env=self.env, **kwargs)

    def recipients(self):
        # Read only the root-controlled copy, not a writable checkout.
        recipients = sorted(set(re.findall(r"\bage1[a-z0-9]+\b", (self.etc / "config.toml").read_text())))
        require(recipients, "no age recipients in copied fnox configuration")
        return recipients

    def encrypt(self, src, dst):
        args = [self.tools["age"]]
        for recipient in self.recipients():
            args += ["-r", recipient]
        run(args + ["-o", dst, src])

    def repository_empty(self):
        if self.repository.startswith("rclone:"):
            remote = self.repository[len("rclone:"):]
            parent, leaf = remote.rsplit("/", 1)
            # List the existing bucket, not a possibly nonexistent object prefix. Listing errors
            # (including auth/network failures) are fatal, never interpreted as an empty repo.
            entries = json.loads(output([self.tools["rclone"], "lsjson", parent,
                                         "--recursive", "--files-only", "--include", "/" + leaf + "/**"],
                                        env=self.env))
            return not entries
        p = Path(self.repository)
        return not p.exists() or not any(p.iterdir())

    def init(self):
        if not self.password.exists():
            # Probe storage without a password. Only an explicitly empty prefix can get a new key.
            # Network/auth/list errors fail closed; do not infer absence from restic failure.
            require(self.repository_empty(), "repository is not empty; recover the original password")
            with tempfile.TemporaryDirectory(dir=self.base) as tmp:
                clear = Path(tmp) / "password"
                clear.write_text(secrets.token_urlsafe(48) + "\n")
                encrypted = Path(tmp) / "password.age"
                self.encrypt(clear, encrypted)
                # Atomic, no-replace publication, including under concurrent external writers.
                os.link(encrypted, self.password)
        if not self.fixture:
            private(self.password)
        # With an existing key, failed repository access is never treated as permission to init.
        empty = self.repository_empty()
        if empty:
            self.restic("init", "--repository-version", "2")
        else:
            self.restic("cat", "config")
        print("Repository initialized/opened; password was not replaced.")

    def git(self, path, *args, isolated_index=False):
        base = ["/usr/bin/git", "--no-optional-locks", "-c", "core.fsmonitor=false",
                "-c", "core.hooksPath=/var/empty", "-c", "safe.directory=" + str(path), "-C", path]
        index_context = tempfile.TemporaryDirectory(prefix="backup-git-index-") if isolated_index else contextlib.nullcontext()
        with index_context as temp:
            env = None
            if isolated_index:
                index = Path(path) / ".git/index"
                isolated = Path(temp) / "index"
                if index.is_file() and not index.is_symlink():
                    shutil.copyfile(index, isolated)
                env = {**os.environ, "GIT_INDEX_FILE": str(isolated)}
            # Even status can execute a checkout's clean/process filters. Never run user code as root.
            filters = subprocess.run([str(a) for a in base] +
                                     ["config", "--null", "--name-only", "--get-regexp", r"^filter\."],
                                     stdout=subprocess.PIPE, check=False, env=env)
            require(filters.returncode in (0, 1), "cannot inspect Git filter configuration")
            overrides = []
            drivers = set()
            for key in filters.stdout.decode().split("\0"):
                if key:
                    drivers.add(key.rsplit(".", 1)[0])
            for driver in sorted(drivers):
                for setting in ("clean", "smudge", "process", "required"):
                    overrides += ["-c", driver + "." + setting + "=" + ("false" if setting == "required" else "")]
            return output(base + overrides + list(args), env=env).decode().strip()

    def sources(self, clean=False):
        for p in (self.developer, self.developer / "configuration" / ".git",
                  self.developer / "robin" / ".git", self.forgejo,
                  self.forgejo / "data/forgejo.db", self.forgejo / "data/repositories",
                  self.grafana / "grafana.db"):
            require(p.exists(), "mandatory source missing: " + str(p))
        heads = {}
        for name in ("configuration", "robin"):
            path = self.developer / name
            gitdir = path / ".git"
            require(gitdir.is_dir() and not gitdir.is_symlink(),
                    "mandatory checkout must have an internal .git directory: " + str(path))
            require(not (gitdir / "objects/info/alternates").exists() and
                    self.git(path, "rev-parse", "--is-shallow-repository") == "false",
                    "mandatory checkout must be self-contained and non-shallow: " + str(path))
            if clean:
                require(not self.git(path, "status", "--porcelain", "--untracked-files=all"),
                        "checkpoint requires a clean checkout: " + str(path))
                require(not self.git(path, "submodule", "status"),
                        "checkpoint does not support submodules; provide a separate recovery plan")
            heads[name] = self.git(path, "rev-parse", "HEAD")
        return heads

    def service(self, name, action):
        require(name in ("forgejo", "grafana") and action in ("status", "stop", "start"),
                "unsupported service operation")
        if self.fixture:
            return output([*self.service_adapter, action, name]).decode().strip()
        args = ["/usr/local/bin/pitchfork", action, "global/" + name]
        if action == "status":
            args.append("--json")
        return output(args, cwd="/var/empty", env=SERVICE_ENV).decode().strip()

    def running(self, name):
        data = json.loads(self.service(name, "status"))
        require(isinstance(data, dict) and isinstance(data.get("status"), str),
                "unrecognized pitchfork status; refusing service mutation")
        require(data.get("id") == "global/" + name and data.get("namespace") == "global" and
                data.get("name") == name, "pitchfork returned a different daemon")
        status = data["status"].lower()
        require(status in ("running", "stopped", "available"),
                "service state is not safe for backup/recovery: " + status)
        return status == "running"

    @contextlib.contextmanager
    def quiesced(self):
        resume = []
        try:
            # Inspect both first. Record intent before stopping so interruption still resumes.
            states = {name: self.running(name) for name in ("forgejo", "grafana")}
            for name, running in states.items():
                if running:
                    resume.append(name)
                    self.service(name, "stop")
                require(not self.running(name), "service did not stop: " + name)
            yield
        finally:
            errors = []
            # Ignore repeat termination signals while attempting every required restart.
            previous = {s: signal.signal(s, signal.SIG_IGN) for s in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)}
            try:
                for name in reversed(resume):
                    try:
                        self.service(name, "start")
                        require(self.running(name), "service did not restart: " + name)
                    except Exception as e:
                        errors.append(str(e))
            finally:
                for s, handler in previous.items():
                    signal.signal(s, handler)
            require(not errors, "SERVICE RESUME FAILED: " + "; ".join(errors))

    def database(self, path, snapshot=False):
        require(path.is_file() and not path.is_symlink(), "missing/linked database: " + str(path))
        # A stopped database may still have WAL. Fold it into a standalone database before excluding sidecars.
        with contextlib.closing(sqlite3.connect("file:" + str(path) +
                                                       ("?mode=ro" if snapshot else "?mode=ro&immutable=1"), uri=True)) as db:
            require(db.execute("PRAGMA integrity_check").fetchall() == [("ok",)],
                    "SQLite integrity check failed: " + str(path))
            if snapshot:
                target = path.with_name(".sqlite-snapshot-" + uuid.uuid4().hex)
                with contextlib.closing(sqlite3.connect(str(target))) as dest:
                    db.backup(dest)
                    dest.execute("PRAGMA journal_mode=DELETE")
        if snapshot:
            shutil.copystat(path, target)
            s = path.stat()
            os.chown(target, s.st_uid, s.st_gid)
            os.replace(target, path)
            for suffix in ("-wal", "-shm"):
                path.with_name(path.name + suffix).unlink(missing_ok=True)

    def capture(self, payload, clean):
        heads = self.sources(clean)
        payload.mkdir()
        # Developer copies can be long; service downtime covers service capture only.
        copy_tree(self.developer, payload / "developer", excluded=True)
        (payload / "bundles").mkdir()
        for name in heads:
            path = payload / "developer" / name
            self.git(path, "bundle", "create", str(payload / "bundles" / (name + ".bundle")), "--all", "HEAD")
            require(self.git(path, "rev-parse", "HEAD") == heads[name], "checkout changed during capture")
            if clean:
                require(not self.git(path, "status", "--porcelain", "--untracked-files=all"),
                        "checkpoint captured a dirty checkout: " + name)
        with self.quiesced():
            copy_tree(self.forgejo, payload / "forgejo")
            copy_tree(self.grafana, payload / "grafana")
        self.database(payload / "forgejo/data/forgejo.db", snapshot=True)
        self.database(payload / "grafana/grafana.db", snapshot=True)
        require(self.sources(clean) == heads, "checkout revision changed during capture")
        files = inventory(payload, manifest=True)
        manifest = {"schema": 2, "created": time.time(), "heads": heads, "clean_checkouts": clean,
                    "excluded_names": sorted(EXCLUDES), "files": files,
                    "accounts": self.accounts(files)}
        atomic_json(payload / "manifest.json", manifest)
        return manifest

    def validate(self, payload, expected_heads=None):
        manifest = json.loads((payload / "manifest.json").read_text())
        require(manifest["schema"] in (1, 2), "unsupported manifest")
        actual = inventory(payload, manifest=True)
        differences = [k for k in sorted(set(actual) | set(manifest["files"]))
                       if actual.get(k) != manifest["files"].get(k)]
        require(not differences, "restored content/metadata differs from manifest: " +
                repr([(k, actual.get(k), manifest["files"].get(k)) for k in differences[:5]]))
        if expected_heads is not None:
            require(manifest["heads"] == expected_heads, "snapshot does not contain requested revisions")
        for name, head in manifest["heads"].items():
            checkout = payload / "developer" / name
            require(self.git(checkout, "rev-parse", "HEAD", isolated_index=True) == head,
                                "working checkout HEAD mismatch")
            if manifest["clean_checkouts"]:
                require(not self.git(checkout, "status", "--porcelain", "--untracked-files=all",
                                      isolated_index=True),
                        "checkpoint restored a dirty checkout: " + name)
            bundle = payload / "bundles" / (name + ".bundle")
            self.git(checkout, "bundle", "verify", str(bundle), isolated_index=True)
            refs = self.git(checkout, "bundle", "list-heads", str(bundle), isolated_index=True).splitlines()
            require(head + " HEAD" in refs, "bundle HEAD mismatch")
            self.git(checkout, "fsck", "--full", isolated_index=True)
        self.database(payload / "forgejo/data/forgejo.db")
        self.database(payload / "grafana/grafana.db")
        repos = payload / "forgejo/data/repositories"
        require(repos.is_dir(), "Forgejo repositories missing")
        for head in repos.rglob("HEAD"):
            if head.parent.name.endswith(".git"):
                self.git(head.parent, "fsck", "--full")
        return manifest

    def exact_snapshot(self, snapshot):
        require(re.fullmatch(r"[0-9a-f]{64}", snapshot), "an explicit full 64-character snapshot ID is required")
        snapshots = json.loads(self.restic("snapshots", "--json", snapshot))
        require(len(snapshots) == 1 and snapshots[0]["id"] == snapshot,
                "snapshot did not resolve to the exact requested ID")

    def restore_data(self, snapshot, stage, heads=None):
        self.exact_snapshot(snapshot)
        self.restic("restore", snapshot, "--target", str(stage), "--verify")
        return self.validate(stage / "payload", heads)

    def prepare_export(self):
        self.export.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
        self.export.mkdir(exist_ok=True, mode=0o755)
        if not self.fixture:
            for path in (self.export.parent, self.export):
                s = path.lstat()
                require(stat.S_ISDIR(s.st_mode) and not path.is_symlink() and
                        s.st_uid == 0 and not s.st_mode & 0o022,
                        "export must be root-controlled: " + str(path))
        self.export.parent.chmod(0o755)
        self.export.chmod(0o755)

    def mirror(self, snapshot, work):
        self.prepare_export()
        mirror = self.export / "restic-v1"
        mirror.mkdir(exist_ok=True, mode=0o755)
        if self.fixture:
            # Use the same immutable merge policy as rclone without network access.
            for src in Path(self.repository).rglob("*"):
                rel = src.relative_to(self.repository)
                if src.is_file() and rel.parts[0] != "locks":
                    dst = mirror / rel
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    if dst.exists():
                        require(digest(src) == digest(dst), "immutable repository object changed")
                    else:
                        shutil.copyfile(src, dst)
        else:
            run([self.tools["rclone"], "copy", "--immutable", "--exclude", "/locks/**",
                 self.repository[len("rclone:"):], mirror])
        original = self.repository
        try:
            self.repository = str(mirror)
            verify = work / "verify-mirror"
            verify.mkdir()
            self.restore_data(snapshot, verify)
        finally:
            self.repository = original
        mirror.chmod(0o755)
        files = {}
        for path in mirror.rglob("*"):
            require(not path.is_symlink(), "repository mirror contains symlink")
            if path.is_dir():
                path.chmod(0o755)
            elif path.is_file() and path.relative_to(mirror).parts[0] != "locks":
                path.chmod(0o644)
                files[str(path.relative_to(self.export))] = digest(path)
        return files

    def publish(self, src, name):
        self.prepare_export()
        # Readers see only complete artifacts; unique names are never overwritten.
        tmp = self.export / (".partial-" + uuid.uuid4().hex)
        try:
            shutil.copyfile(src, tmp)
            tmp.chmod(0o644)  # Only ciphertext or configuration Git bundle may reach here.
            with tmp.open("rb") as f:
                os.fsync(f.fileno())
            os.link(tmp, self.export / name)
        finally:
            tmp.unlink(missing_ok=True)
        return self.export / name

    def capsule(self, work, identity, accounts):
        capsule = work / "capsule"
        capsule.mkdir()
        self.encrypt(self.etc / "config.toml", capsule / "config.toml.age")
        shutil.copyfile(self.password, capsule / "restic-password.age")
        tools = capsule / "tools"
        tools.mkdir()
        metadata = {"repository": self.repository, "snapshot": identity, "platform": sys.platform,
                    "machine": os.uname().machine, "python": sys.version, "tools": {}, "accounts": accounts}
        for name, path in self.tools.items():
            copy = tools / name
            shutil.copy2(path, copy)
            version = output([path, "version"] if name in ("restic", "rclone") else [path, "--version"]).decode().strip()
            metadata["tools"][name] = {"version": version, "sha256": digest(copy)}
        scripts = capsule / "scripts"
        shutil.copytree(Path(__file__).resolve().parent, scripts,
                        ignore=shutil.ignore_patterns(".*", "__pycache__", "*_test*", "test_*"))
        atomic_json(capsule / "metadata.json", metadata)
        archive = work / "capsule.tar"
        with tarfile.open(archive, "w") as tar:
            tar.add(capsule, arcname="capsule")
        encrypted = work / "capsule.age"
        self.encrypt(archive, encrypted)
        return encrypted

    def backup(self, checkpoint=False):
        require(self.password.is_file(), "run explicit init or recover restic-password.age first")
        if not self.fixture:
            private(self.password)
        self.restic("cat", "config")  # Fail before stopping any service.
        with tempfile.TemporaryDirectory(dir=self.base, prefix="capture-") as tmp:
            work = Path(tmp)
            manifest = self.capture(work / "payload", checkpoint)
            lines = self.restic("backup", "--json", "--host", "home-mac", "--tag", "home-v1",
                                "--tag", "checkpoint" if checkpoint else "scheduled", "payload", cwd=work).splitlines()
            summaries = [json.loads(line) for line in lines if json.loads(line).get("message_type") == "summary"]
            require(len(summaries) == 1, "restic returned no unique summary")
            snapshot = summaries[0]["snapshot_id"]
            self.exact_snapshot(snapshot)
            # Read the exact newly created snapshot from the repository, not the capture directory.
            verify = work / "verify"
            verify.mkdir()
            self.restore_data(snapshot, verify, manifest["heads"])
            name = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + "-" + snapshot
            bundle = self.publish(work / "payload/bundles/configuration.bundle", "configuration-" + name + ".bundle")
            capsule = self.publish(self.capsule(work, snapshot, manifest["accounts"]), "capsule-" + name + ".tar.age")
            repository_files = self.mirror(snapshot, work)
            receipt = work / "receipt.json"
            atomic_json(receipt, {"snapshot": snapshot, "heads": manifest["heads"],
                                  "created": manifest["created"],
                                  "repository_files": repository_files,
                                  "artifacts": {p.name: digest(p) for p in (bundle, capsule)}})
            published = self.publish(receipt, "receipt-" + name + ".json")
            if not self.fixture:
                for path in (bundle, capsule, published):
                    # copyto --immutable refuses to replace different bytes; never sync or delete.
                    run([self.tools["rclone"], "copyto", "--immutable", path, REMOTE + "/" + path.name])
                    run([self.tools["rclone"], "check", "--download", "--one-way", "--include", path.name,
                         self.export, REMOTE])
            if checkpoint and not self.fixture:
                run(["/usr/bin/sudo", "-H", "-u", "mac",
                     RUNTIME / "courier.sh", "--snapshot", snapshot], stdout=sys.stderr,
                    env={"PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"})
            completed = json.loads(receipt.read_text())
            recovery_record = {
                "schema": 1, "snapshot": snapshot,
                "capsule": {"filename": capsule.name, "sha256": completed["artifacts"][capsule.name]},
                "bootstrap_bundle": {"filename": bundle.name, "sha256": completed["artifacts"][bundle.name]},
                "receipt": {"filename": published.name, "sha256": digest(published)},
            }
            write_metric(self.metrics, "backup_last_success_seconds", self.metric_gid)
            atomic_json(self.base / "last-success.json", dict(completed, recovery_record=recovery_record))
            print("Keep this recovery record independently with your offline age identity; "
                  "downloaded receipts are not a trusted source of recovery hashes.", file=sys.stderr)
            print("OFFLINE_RECOVERY_RECORD " + json.dumps(recovery_record, sort_keys=True, separators=(",", ":")),
                  file=sys.stderr, flush=True)
            print(snapshot)
            return snapshot

    def accounts(self, files):
        uids = {item["uid"] for item in files.values()}
        gids = {item["gid"] for item in files.values()}
        if not self.fixture:
            uids.update(pwd.getpwnam(name).pw_uid for name in ("mac", "svc_forgejo", "svc_observability"))
        users = []
        for uid in sorted(uids):
            user = pwd.getpwuid(uid)  # Unnamed owners are not silently assigned to another account.
            users.append({"name": user.pw_name, "uid": uid, "gid": user.pw_gid})
            gids.add(user.pw_gid)
        groups = [{"name": grp.getgrgid(gid).gr_name, "gid": gid} for gid in sorted(gids)]
        return {"users": users, "groups": groups}

    def ownership_map(self, manifest):
        require("accounts" in manifest, "snapshot lacks named accounts; create a schema-2 checkpoint before reinstall")
        mapping = {"uid": {}, "gid": {}}
        for kind, records, lookup in (("uid", manifest["accounts"]["users"], pwd.getpwnam),
                                      ("gid", manifest["accounts"]["groups"], grp.getgrnam)):
            for record in records:
                old = record[kind]
                try:
                    entry = lookup(record["name"])
                except KeyError:
                    raise RuntimeError("create recovery account/group before restoring: " + record["name"])
                new = entry.pw_uid if kind == "uid" else entry.gr_gid
                require((old == 0) == (new == 0), "refusing account mapping across root identity")
                require(str(old) not in mapping[kind], "duplicate account identity in manifest")
                mapping[kind][str(old)] = new
        for values in mapping.values():
            require(len(set(values.values())) == len(values), "distinct saved accounts/groups now share an ID")
        for item in manifest["files"].values():
            require(all(str(item[k]) in mapping[k] for k in ("uid", "gid")), "unmapped owner in manifest")
        return mapping

    @staticmethod
    def mapped_files(manifest, mapping):
        return {path: dict(item, uid=mapping["uid"][str(item["uid"])],
                           gid=mapping["gid"][str(item["gid"])])
                for path, item in manifest["files"].items()}

    @staticmethod
    def validate_target(target, name, files):
        expected = {k[len(name) + 1:]: v for k, v in files.items() if k.startswith(name + "/")}
        require(target.is_dir() and not target.is_symlink(), "invalid recovery target: " + str(target))
        actual = inventory(target)
        differences = []
        for path in sorted(set(actual) | set(expected)):
            found, wanted = actual.get(path), expected.get(path)
            if found == wanted:
                continue
            fields = {key: {"actual": (found or {}).get(key), "expected": (wanted or {}).get(key)}
                      for key in sorted(set(found or {}) | set(wanted or {}))
                      if (found or {}).get(key) != (wanted or {}).get(key)}
            differences.append({"path": path, "fields": fields})
            if len(differences) == 5:
                break
        require(not differences, "installed target differs from recovery manifest: " + str(target) +
                "; first differences: " + json.dumps(differences, sort_keys=True))
        s = target.stat()
        root = files[name]
        require((s.st_uid, s.st_gid, stat.S_IMODE(s.st_mode)) ==
                (root["uid"], root["gid"], root["mode"]), "target root metadata differs: " + str(target))

    @staticmethod
    def remap_target(target, name, files):
        for path in [target] + list(target.rglob("*")):
            relative = path.relative_to(target)
            key = name if relative == Path(".") else name + "/" + str(relative)
            item = files[key]
            os.chown(path, item["uid"], item["gid"], follow_symlinks=False)
            if not path.is_symlink():
                # chown clears set-ID mode bits. Restore the recorded mode only after ownership.
                os.chmod(path, item["mode"], follow_symlinks=False)

    def assert_restore_stopped(self, offline):
        if not offline:
            require(not any(self.running(n) for n in ("forgejo", "grafana")),
                    "restore refuses live services; stop them explicitly first")
            return
        # Offline means no launchd job capable of starting the server, not just a quiet supervisor.
        # Enumerate job descriptions so this does not depend on the installer's choice of label.
        listing = output(["/bin/launchctl", "list"]).decode().splitlines()
        require(listing and listing[0].split() == ["PID", "Status", "Label"],
                "cannot establish system launchd job state")
        for row in listing[1:]:
            fields = row.split()
            require(len(fields) == 3 and "/" not in fields[2], "unexpected launchd job listing")
            description = output(["/bin/launchctl", "print", "system/" + fields[2]]).decode()
            require(not re.search(r"pitchfork|forgejo|grafana|mac-server", description, re.I),
                    "offline restore requires server launchd jobs absent: " + fields[2])
        processes = output(["/bin/ps", "-axo", "comm=,args="]).decode()
        require(not re.search(r"(?:^|[ /])(?:pitchfork|forgejo|grafana)(?:[- /]|$)", processes, re.I | re.M),
                "offline restore refuses running supervisor/application processes")

    def restore(self, snapshot, verify_only=False, session=None, offline=False):
        self.exact_snapshot(snapshot)
        if verify_only:
            with tempfile.TemporaryDirectory(dir=self.base, prefix="verify-") as tmp:
                self.restore_data(snapshot, Path(tmp))
            print("Verified exact snapshot " + snapshot)
            return
        self.assert_restore_stopped(offline)
        require(session is not None and re.fullmatch(r"[a-zA-Z0-9_-]+", session),
                "restore requires a simple --session name for safe resume")
        stage = self.base / ("restore-" + session)
        targets = {"developer": self.developer, "forgejo": self.forgejo, "grafana": self.grafana}
        if not stage.exists():
            # Refuse all collisions before downloading anything; never overwrite even empty targets.
            for target in targets.values():
                require(not os.path.lexists(target), "target already exists: " + str(target))
            stage.mkdir(mode=0o700)
            atomic_json(stage / "state.json", {"snapshot": snapshot, "phase": "download", "targets": {}})
        if not self.fixture:
            private(stage, directory=True)
        if not (stage / "state.json").exists():
            require(not any(stage.iterdir()) and not any(os.path.lexists(p) for p in targets.values()),
                    "session has no state marker and is not empty")
            atomic_json(stage / "state.json", {"snapshot": snapshot, "phase": "download", "targets": {}})
        state = json.loads((stage / "state.json").read_text())
        require(state["snapshot"] == snapshot, "session belongs to another snapshot")
        if state["phase"] == "download":
            download = stage / "download"
            if download.exists():
                shutil.rmtree(download)
            download.mkdir()
            self.restore_data(snapshot, download)
            state["phase"] = "install"
            state["manifest"] = json.loads((download / "payload/manifest.json").read_text())
            atomic_json(stage / "state.json", state)
        mapping = self.ownership_map(state["manifest"])
        if "ownership" in state:
            require(mapping == state["ownership"], "account IDs changed during recovery; refusing mixed ownership")
        else:
            state["ownership"] = mapping
            atomic_json(stage / "state.json", state)
        files = self.mapped_files(state["manifest"], mapping)
        for name, target in targets.items():
            record = state["targets"].get(name)
            if record and record["phase"] == "done":
                self.validate_target(target, name, files)
                continue
            self.assert_restore_stopped(offline)
            target.parent.mkdir(parents=True, exist_ok=True)
            container = target.parent / (".home-recovery-" + session + "-" + name)
            if not record:
                require(not os.path.lexists(container), "unrelated staging container exists")
                state["targets"][name] = {"phase": "copying"}
                atomic_json(stage / "state.json", state)
            if not container.exists():
                require(state["targets"][name]["phase"] == "copying", "recovery container disappeared")
                container.mkdir(mode=0o700)
            if not self.fixture:
                private(container, directory=True)
            candidate = container / "tree"
            source = stage / "download/payload" / name
            if record and record["phase"] == "ready" and not candidate.exists() and target.exists():
                require(not target.is_symlink(), "renamed target is a symlink")
                # Crash between rename and durable state write. Verify before accepting completion.
                self.validate_target(target, name, files)
            else:
                require(not os.path.lexists(target), "refusing existing unrelated target: " + str(target))
                if not record:
                    require(not os.path.lexists(candidate), "unrelated staging candidate exists")
                    state["targets"][name] = {"phase": "copying"}
                    atomic_json(stage / "state.json", state)
                if not record or record["phase"] == "copying":
                    if candidate.exists():
                        shutil.rmtree(candidate)
                    copy_tree(source, candidate)
                    require(inventory(candidate) == inventory(source), "target staging copy differs")
                    self.remap_target(candidate, name, files)
                    state["targets"][name] = {"phase": "ready"}
                    atomic_json(stage / "state.json", state)
                self.validate_target(candidate, name, files)
                self.assert_restore_stopped(offline)
                # Parent is required not to be concurrently managed; rename never merges trees.
                require(not os.path.lexists(target), "target appeared during restore")
                rename_exclusive(candidate, target)
            state["targets"][name] = {"phase": "done"}
            atomic_json(stage / "state.json", state)
        state["phase"] = "complete"
        atomic_json(stage / "state.json", state)
        print("Recovery complete; services remain stopped. Private session retained at " + str(stage))

    def prune(self, apply):
        # Keep rules are ORed. Always preserve the newest snapshot, and never touch other hosts/tags.
        args = ["forget", "--host", "home-mac", "--tag", "home-v1", "--group-by", "host",
                "--keep-last", "1", "--keep-daily", "7", "--keep-weekly", "5", "--keep-monthly", "12"]
        if apply:
            self.restic("check")
            args.append("--prune")
        else:
            args.append("--dry-run")
        print(self.restic(*args).decode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", help=argparse.SUPPRESS)

    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("init", "backup", "checkpoint"):
        sub.add_parser(name)
    for name in ("restore", "verify"):
        p = sub.add_parser(name)
        p.add_argument("snapshot")
        p.add_argument("--repository", help="explicit recovery repository; local paths supported")
        if name == "restore":
            p.add_argument("--session", required=True)
            p.add_argument("--offline", action="store_true",
                           help="fresh host only: refuse loaded server jobs/processes without contacting Pitchfork")
    sub.add_parser("prune").add_argument("--apply", action="store_true")
    args = parser.parse_args()
    os.umask(0o077)
    def interrupted(signum, frame):
        raise RuntimeError("interrupted by signal " + str(signum))
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, interrupted)
    c = Coordinator(args.fixture)
    if getattr(args, "repository", None):
        c.repository = args.repository
    with c.lock():
        if args.command == "init":
            c.init()
        elif args.command in ("backup", "checkpoint"):
            c.backup(args.command == "checkpoint")
        elif args.command in ("restore", "verify"):
            c.restore(args.snapshot, args.command == "verify", getattr(args, "session", None),
                      getattr(args, "offline", False))
        elif args.command == "prune":
            c.prune(args.apply)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError, KeyError, sqlite3.Error) as exc:
        print("backup: " + str(exc), file=sys.stderr)
        sys.exit(1)
