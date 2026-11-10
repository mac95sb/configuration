#!/usr/bin/env python3
"""Isolated local-repository tests. Never uses live services, cloud or real identities."""
import contextlib
import importlib.util
import io
import json
import os
import pwd
import grp
from types import SimpleNamespace
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import coordinator as m
import metrics
import open_capsule


class Recovery(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Fixture commits must not invoke the operator's signing agent or global hooks.
        git_environment = mock.patch.dict(os.environ, {
            'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_SYSTEM': os.devnull,
            'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_COUNT': '0', 'GIT_EDITOR': 'true',
        })
        git_environment.start()
        cls.addClassCleanup(git_environment.stop)
        cls.restic = os.environ.get('TEST_RESTIC', shutil.which('restic') or str(HERE / '.restic-test'))
        if os.geteuid() == 0:
            raise RuntimeError('fixtures deliberately refuse root')
        if not Path(cls.restic).is_file() or not shutil.which('age') or not shutil.which('age-keygen'):
            raise RuntimeError('set TEST_RESTIC and install age + age-keygen for integration tests')
        subprocess.run([cls.restic, 'version'], check=True, capture_output=True)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='backup-fixture-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.etc = self.root / 'etc'
        self.etc.mkdir()
        key = self.etc / 'operational.key'
        subprocess.run(['age-keygen', '-o', str(key)], check=True, capture_output=True)
        recipient = subprocess.check_output(['age-keygen', '-y', str(key)]).decode().strip()
        (self.etc / 'config.toml').write_text('recipients = ["' + recipient + '"]\n')
        self.developer = self.root / 'developer'
        for name in ('configuration', 'robin'):
            repo = self.developer / name
            repo.mkdir(parents=True)
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            (repo / 'working.txt').write_text('committed ' + name)
            (repo / 'fnox.toml').write_text('ciphertext only fixture')
            subprocess.run(['git', '-C', str(repo), 'add', '.'], check=True)
            subprocess.run(['git', '-C', str(repo), '-c', 'user.name=Fixture', '-c',
                            'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True)
        (self.developer / 'private-work').mkdir(mode=0o700)
        (self.developer / 'private-work/untracked').write_text('private developer state')
        (self.developer / 'manifest.json').write_text('a user file, not our manifest')
        (self.developer / 'private-work/link').symlink_to('untracked')
        (self.developer / 'node_modules').mkdir()
        (self.developer / 'node_modules/ignored').write_text('cache')
        self.forgejo = self.root / 'forgejo'
        self.grafana = self.root / 'grafana'
        (self.forgejo / 'data/repositories').mkdir(parents=True)
        (self.forgejo / 'keys').mkdir()
        (self.forgejo / 'keys/ssh_host_key').write_text('fixture private service key')
        (self.forgejo / 'assets').mkdir()
        (self.forgejo / 'assets/custom').write_text('custom asset')
        self.grafana.mkdir()
        for path in (self.forgejo / 'data/forgejo.db', self.grafana / 'grafana.db'):
            with sqlite3.connect(path) as db:
                db.execute('create table state(value text)')
                db.execute("insert into state values ('durable')")
        self.states = self.root / 'states.json'
        self.states.write_text(json.dumps({'forgejo': 'running', 'grafana': 'stopped'}))
        self.log = self.root / 'service.log'
        adapter = self.root / 'service.py'
        adapter.write_text('''import json, pathlib, sys
states, log = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
action, name = sys.argv[3:]
s = json.loads(states.read_text())
if action == 'status': print(json.dumps({'id': 'global/' + name, 'namespace': 'global', 'name': name, 'status': s[name]}))
else:
    with log.open('a') as f: f.write(action + ' ' + name + '\\n')
    s[name] = 'running' if action == 'start' else 'stopped'
    states.write_text(json.dumps(s))
''')
        tools = {name: shutil.which(name) for name in ('age', 'fnox', 'pitchfork')}
        tools['restic'] = str(Path(self.restic).resolve())
        if not all(tools.values()):
            raise RuntimeError('capsule fixture needs installed fnox/pitchfork for metadata only')
        self.cfg = self.root / 'fixture.json'
        self.cfg.write_text(json.dumps({
            'base': str(self.root / 'private'), 'etc': str(self.etc),
            'developer': str(self.developer), 'forgejo': str(self.forgejo), 'grafana': str(self.grafana),
            'export': str(self.root / 'export'), 'repository': str(self.root / 'export/restic-v1'),
            'tools': tools, 'service_adapter': [sys.executable, str(adapter), str(self.states), str(self.log)]}))
        self.c = m.Coordinator(str(self.cfg))
        self.old_umask = os.umask(0o077)
        self.addCleanup(os.umask, self.old_umask)
        with self.c.lock():
            self.c.init()

    def backup(self, checkpoint=True):
        with self.c.lock():
            return self.c.backup(checkpoint)

    def test_end_to_end_restore_and_resume(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            snapshot = self.backup()
        self.assertRegex(snapshot, r'^[0-9a-f]{64}$')
        self.assertEqual(stdout.getvalue(), snapshot + '\n')
        records = [line.removeprefix('OFFLINE_RECOVERY_RECORD ') for line in stderr.getvalue().splitlines()
                   if line.startswith('OFFLINE_RECOVERY_RECORD ')]
        self.assertEqual(len(records), 1)
        recovery_record = json.loads(records[0])
        self.assertEqual(recovery_record['schema'], 1)
        self.assertEqual(recovery_record['snapshot'], snapshot)
        for kind, pattern in (('capsule', 'capsule-*.tar.age'), ('bootstrap_bundle', 'configuration-*.bundle'),
                              ('receipt', 'receipt-*.json')):
            artifact = next(self.c.export.glob(pattern))
            self.assertEqual(recovery_record[kind], {'filename': artifact.name, 'sha256': m.digest(artifact)})
        last_success = json.loads((self.c.base / 'last-success.json').read_text())
        self.assertEqual(last_success['recovery_record'], recovery_record)
        self.assertEqual(self.log.read_text().splitlines(), ['stop forgejo', 'start forgejo'])
        self.assertEqual(json.loads(self.states.read_text()), {'forgejo': 'running', 'grafana': 'stopped'})
        receipt = json.loads(next(self.c.export.glob('receipt-*.json')).read_text())
        self.assertGreater(receipt['created'], 0)
        metric = self.c.metrics / 'backup_last_success_seconds.prom'
        self.assertRegex(metric.read_text(), r'^backup_last_success_seconds [0-9]+\n$')
        self.assertEqual(metric.stat().st_mode & 0o777, 0o640)
        self.assertEqual(metric.stat().st_gid, os.getgid())
        with self.c.lock():
            self.c.restore(snapshot, verify_only=True)
        # Live service and unrelated target collision both fail closed.
        with self.assertRaisesRegex(RuntimeError, 'live services'):
            self.c.restore(snapshot, session='clean')
        self.states.write_text(json.dumps({'forgejo': 'stopped', 'grafana': 'stopped'}))
        with self.assertRaisesRegex(RuntimeError, 'target already exists'):
            self.c.restore(snapshot, session='clean')
        for target in (self.developer, self.forgejo, self.grafana):
            shutil.rmtree(target)
        original = m.rename_exclusive
        calls = []
        def crash(source, destination):
            original(source, destination)
            calls.append(str(destination))
            if len(calls) == 1:
                raise RuntimeError('simulated crash after rename')
        with mock.patch.object(m, 'rename_exclusive', crash):
            with self.assertRaisesRegex(RuntimeError, 'simulated crash'):
                self.c.restore(snapshot, session='clean')
        self.c.restore(snapshot, session='clean')
        self.c.restore(snapshot, session='clean')
        self.assertEqual((self.developer / 'private-work/untracked').read_text(), 'private developer state')
        self.assertFalse((self.developer / 'node_modules').exists())
        self.assertEqual((self.forgejo / 'keys/ssh_host_key').read_text(), 'fixture private service key')
        self.assertEqual((self.forgejo / 'assets/custom').read_text(), 'custom asset')
        self.assertEqual((self.c.base / 'restore-clean').stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.log.read_text().splitlines(), ['stop forgejo', 'start forgejo'])
        # Capsule, including encrypted config/password, can be recovered with offline key.
        capsule = next(self.c.export.glob('capsule-*.tar.age'))
        unpack = self.root / 'offline'
        open_capsule.open_capsule(capsule, self.etc / 'operational.key', unpack, self.c.tools['age'],
                                  recovery_record['capsule']['sha256'])
        recovered = unpack / 'capsule'
        self.assertEqual((recovered / 'restic-password.age').read_bytes(), self.c.password.read_bytes())
        self.assertFalse((recovered / 'operational.key').exists())
        metadata = json.loads((recovered / 'metadata.json').read_text())
        self.assertEqual(metadata['snapshot'], snapshot)
        self.assertTrue(metadata['accounts']['users'])
        state_path = self.c.base / 'restore-clean/state.json'
        state = json.loads(state_path.read_text())
        original_mapping = dict(state['ownership']['uid'])
        state['ownership']['uid'] = {key: value + 1000 for key, value in original_mapping.items()}
        m.atomic_json(state_path, state)
        with self.assertRaisesRegex(RuntimeError, 'IDs changed during recovery'):
            self.c.restore(snapshot, session='clean')
        state['ownership']['uid'] = original_mapping
        m.atomic_json(state_path, state)
        # The repository and recovery artifacts are written directly to iCloud's local directory.
        self.assertTrue((self.c.export / 'restic-v1/config').is_file())
        self.assertTrue(next(self.c.export.glob('configuration-*.bundle')).is_file())
        self.c.restore(snapshot, verify_only=True)
        self.c.prune(False)
        self.c.prune(True)
        self.c.exact_snapshot(snapshot)

    def test_offline_restore_without_supervisor(self):
        snapshot = self.backup()
        for target in (self.developer, self.forgejo, self.grafana):
            shutil.rmtree(target)
        original = m.output
        def isolated(args, **kwargs):
            if args[0] == '/bin/launchctl':
                self.assertEqual(args, ['/bin/launchctl', 'list'])
                return b'PID\tStatus\tLabel\n'
            if args[0] == '/bin/ps':
                return b'/usr/bin/python3 fixture\n'
            return original(args, **kwargs)
        with mock.patch.object(m, 'output', side_effect=isolated), \
                mock.patch.object(self.c, 'service', side_effect=AssertionError('offline contacted supervisor')):
            self.c.restore(snapshot, session='offline', offline=True)
            self.c.restore(snapshot, session='offline', offline=True)
        self.assertTrue((self.forgejo / 'keys/ssh_host_key').exists())

    def test_capture_failure_resumes_only_previously_running(self):
        original = m.copy_tree
        called = []
        def fail(src, dst, excluded=False):
            called.append(Path(src))
            if Path(src).resolve() == self.forgejo.resolve():
                raise OSError('fixture copy failure')
            return original(src, dst, excluded)
        stderr = io.StringIO()
        with mock.patch.object(m, 'copy_tree', fail), contextlib.redirect_stderr(stderr):
            try:
                self.backup()
            except OSError as error:
                self.assertRegex(str(error), 'fixture copy failure')
            else:
                self.fail('backup did not attempt to copy Forgejo: ' + repr(called))
        self.assertIn(self.forgejo.resolve(), called)
        self.assertNotIn('OFFLINE_RECOVERY_RECORD ', stderr.getvalue())
        self.assertEqual(self.log.read_text().splitlines(), ['stop forgejo', 'start forgejo'])
        self.assertFalse((self.c.base / 'last-success.json').exists())
        self.assertFalse((self.c.metrics / 'backup_last_success_seconds.prom').exists())

    def test_missing_password_never_replaced(self):
        encrypted = self.c.password.read_bytes()
        self.c.password.unlink()
        with self.assertRaisesRegex(RuntimeError, 'not empty'):
            self.c.init()
        self.assertFalse(self.c.password.exists())
        self.c.password.write_bytes(encrypted)
        self.c.init()
        self.assertEqual(self.c.password.read_bytes(), encrypted)

    def test_missing_source_dirty_checkout_lock_and_tamper(self):
        (self.developer / 'configuration/untracked').write_text('dirty')
        with self.assertRaisesRegex(RuntimeError, 'clean checkout'):
            self.backup()
        (self.developer / 'configuration/untracked').unlink()
        (self.forgejo / 'data/forgejo.db').unlink()
        with self.assertRaisesRegex(RuntimeError, 'mandatory source missing'):
            self.backup()
        self.assertFalse(self.log.exists())
        with self.c.lock():
            with self.assertRaisesRegex(RuntimeError, 'holds the lock'):
                with self.c.lock():
                    pass
        with self.assertRaisesRegex(RuntimeError, 'full 64'):
            self.c.exact_snapshot('latest')

    def test_manifest_tamper_and_wal(self):
        payload = self.root / 'payload'
        wal = sqlite3.connect(self.grafana / 'grafana.db')
        self.addCleanup(wal.close)
        wal.execute('pragma journal_mode=wal')
        wal.execute("insert into state values ('from WAL')")
        wal.commit()
        self.c.capture(payload, False)
        self.c.validate(payload)
        self.assertFalse((payload / 'grafana/grafana.db-wal').exists())
        with sqlite3.connect(payload / 'grafana/grafana.db') as db:
            self.assertIn(('from WAL',), db.execute('select value from state').fetchall())
        (payload / 'developer/private-work/untracked').write_text('corrupt')
        with self.assertRaisesRegex(RuntimeError, 'differs from manifest'):
            self.c.validate(payload)

    def test_git_status_never_executes_checkout_filters(self):
        repo = self.developer / 'configuration'
        sentinel = self.root / 'filter-executed'
        subprocess.run(['git', '-C', str(repo), 'config', 'filter.fixture.clean',
                        '/usr/bin/touch ' + str(sentinel)], check=True)
        (repo / '.gitattributes').write_text('working.txt filter=fixture\n')
        self.c.git(repo, 'status', '--porcelain')
        self.assertFalse(sentinel.exists())

    def test_init_refuses_nonempty_local_repository_without_password(self):
        self.c.password.unlink()
        Path(self.c.repository, 'unexpected-object').write_text('preserve')
        with self.assertRaisesRegex(RuntimeError, 'repository is not empty'):
            with self.c.lock():
                self.c.init()
        self.assertFalse(self.c.password.exists())

    def test_interruption_resumes_services_and_preserves_stopped_state(self):
        with self.assertRaisesRegex(RuntimeError, 'interrupted'):
            with self.c.quiesced():
                raise RuntimeError('interrupted by signal 15')
        self.assertEqual(self.log.read_text().splitlines(), ['stop forgejo', 'start forgejo'])

    def test_unknown_service_state_fails_closed(self):
        self.states.write_text(json.dumps({'forgejo': 'failed', 'grafana': 'running'}))
        with self.assertRaisesRegex(RuntimeError, 'not safe'):
            with self.c.quiesced():
                pass
        self.assertFalse(self.log.exists())

    def test_rename_never_replaces_empty_directory(self):
        source, target = self.root / 'source', self.root / 'target'
        source.mkdir()
        target.mkdir()
        with self.assertRaises(FileExistsError):
            m.rename_exclusive(source, target)
        self.assertTrue(source.is_dir())
        self.assertTrue(target.is_dir())


class Contracts(unittest.TestCase):
    def test_capsule_digest_rejection_precedes_staging_and_decryption(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'capsule.age'
            archive.write_bytes(b'untrusted downloaded capsule')
            destination = root / 'not-created'
            for expected in (None, '', 'a' * 63, 'z' * 64, '0' * 64):
                with self.subTest(expected=expected), mock.patch.object(open_capsule.subprocess, 'run') as decrypt:
                    with self.assertRaisesRegex(RuntimeError, 'CAPSULE_SHA256|differs'):
                        open_capsule.open_capsule(archive, root / 'identity', destination, root / 'age', expected)
                    decrypt.assert_not_called()
                    self.assertFalse(destination.exists())
            missing = subprocess.run([sys.executable, '-B', str(HERE / 'open_capsule.py'), str(archive),
                                      '--identity', str(root / 'identity'), '--destination', str(destination)],
                                     capture_output=True, text=True)
            self.assertEqual(missing.returncode, 2)
            self.assertIn('--sha256', missing.stderr)
            self.assertFalse(destination.exists())
            expected = m.digest(archive)
            open_capsule.verify_capsule_digest(archive, expected.upper())
            archive.write_bytes(b'replacement encrypted using public recipients')
            with self.assertRaisesRegex(RuntimeError, 'differs'):
                open_capsule.verify_capsule_digest(archive, expected)

    def test_missing_restic_is_failure_not_skip(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = str(Path(tmp) / 'missing-restic')
            with mock.patch.dict(os.environ, TEST_RESTIC=missing), mock.patch.object(os, 'geteuid', return_value=501):
                with self.assertRaisesRegex(RuntimeError, 'TEST_RESTIC'):
                    Recovery.setUpClass()
            result = subprocess.run(['/bin/sh', str(HERE / 'prune_test.sh')],
                                    env=dict(os.environ, TEST_RESTIC=missing), capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Restic is required', result.stderr)
    def test_cli_recovery_options_follow_allowlisted_command(self):
        snapshot = 'a' * 64
        c = mock.MagicMock()
        argv = ['coordinator.py', 'restore', snapshot, '--repository', '/tmp/local-repository',
                '--session', 'fresh', '--offline']
        with mock.patch.object(sys, 'argv', argv), mock.patch.object(m, 'Coordinator', return_value=c), \
                mock.patch.object(m.os, 'umask'), mock.patch.object(m.signal, 'signal'):
            m.main()
        self.assertEqual(c.repository, '/tmp/local-repository')
        c.restore.assert_called_once_with(snapshot, False, 'fresh', True)
        for name in ('init', 'checkpoint', 'restore', 'verify', 'prune'):
            text = (HERE.parent.parent / '.mise/tasks/recovery' / name).read_text()
            self.assertIn('/usr/local/libexec/mac-server/backup/launch.sh ' + name + ' "$@"', text)
        rejected = subprocess.run(['/bin/sh', str(HERE / 'launch.sh'), 'courier'], capture_output=True)
        self.assertEqual(rejected.returncode, 2)

    def test_root_global_service_commands_and_identity(self):
        c = m.Coordinator.__new__(m.Coordinator)
        c.fixture = False
        c.env = {'HOME': '/var/root'}
        with mock.patch.object(m, 'output', return_value=b'{}') as call:
            c.service('forgejo', 'status')
            call.assert_called_once_with(['/usr/local/bin/pitchfork', 'status', 'global/forgejo', '--json'],
                                         cwd='/var/empty', env=m.SERVICE_ENV)
            env = call.call_args.kwargs['env']
            self.assertEqual(env['PITCHFORK_SUPERVISOR_AUTO_START'], 'false')
            self.assertEqual(env['PITCHFORK_USER'], 'root')
            self.assertEqual(env['XDG_CONFIG_HOME'], '/etc')
        with mock.patch.object(c, 'service', return_value=json.dumps({
                'id': 'global/grafana', 'namespace': 'global', 'name': 'grafana', 'status': 'running'})):
            with self.assertRaisesRegex(RuntimeError, 'different daemon'):
                c.running('forgejo')

    def test_offline_guard_refuses_jobs_processes_and_unknown_state(self):
        c = m.Coordinator.__new__(m.Coordinator)
        cases = [
            ([b'PID Status Label\n- 0 server-job\n', b'program = /usr/local/bin/pitchfork'], 'jobs absent'),
            ([b'PID Status Label\n', b'/usr/local/bin/forgejo web\n'], 'running supervisor'),
            ([b'PID Status Label\n', b'/usr/local/bin/grafana-server\n'], 'running supervisor'),
            ([b'not a launchd listing'], 'cannot establish'),
        ]
        for responses, error in cases:
            with self.subTest(error=error), mock.patch.object(m, 'output', side_effect=responses), \
                    mock.patch.object(c, 'service', side_effect=AssertionError('unexpected supervisor contact')):
                with self.assertRaisesRegex(RuntimeError, error):
                    c.assert_restore_stopped(True)
        with mock.patch.object(m, 'output', side_effect=[b'PID Status Label\n- 0 unrelated\n',
                                                        b'program = /usr/sbin/syslogd', b'/bin/ps ps\n']):
            c.assert_restore_stopped(True)
        with mock.patch.object(m, 'output', side_effect=subprocess.CalledProcessError(1, ['launchctl'])):
            with self.assertRaises(subprocess.CalledProcessError):
                c.assert_restore_stopped(True)

    def test_named_ownership_mapping_remaps_ids_and_preserves_original(self):
        c = m.Coordinator.__new__(m.Coordinator)
        files = {'developer': {'type': 'directory', 'uid': 501, 'gid': 20, 'mode': 0o700}}
        manifest = {'files': files, 'accounts': {
            'users': [{'name': 'mac', 'uid': 501, 'gid': 20}],
            'groups': [{'name': 'staff', 'gid': 20}]}}
        with mock.patch.object(m.pwd, 'getpwnam', return_value=SimpleNamespace(pw_uid=1501)), \
                mock.patch.object(m.grp, 'getgrnam', return_value=SimpleNamespace(gr_gid=120)):
            mapping = c.ownership_map(manifest)
        self.assertEqual(mapping, {'uid': {'501': 1501}, 'gid': {'20': 120}})
        mapped = c.mapped_files(manifest, mapping)
        self.assertEqual((mapped['developer']['uid'], mapped['developer']['gid']), (1501, 120))
        self.assertEqual(files['developer']['uid'], 501)
        with mock.patch.object(m.pwd, 'getpwnam', side_effect=KeyError):
            with self.assertRaisesRegex(RuntimeError, 'create recovery account/group'):
                c.ownership_map(manifest)
        with mock.patch.object(m.pwd, 'getpwnam', return_value=SimpleNamespace(pw_uid=0)):
            with self.assertRaisesRegex(RuntimeError, 'root identity'):
                c.ownership_map(manifest)
        with self.assertRaisesRegex(RuntimeError, 'lacks named accounts'):
            c.ownership_map({'files': files})
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / 'tree'
            target.mkdir()
            (target / 'file').write_text('content')
            (target / 'link').symlink_to('file')
            mapped = {'developer': dict(mapped['developer']),
                      'developer/file': {'uid': 1501, 'gid': 120, 'mode': 0o600},
                      'developer/link': {'uid': 1501, 'gid': 120}}
            with mock.patch.object(m.os, 'chown') as chown:
                c.remap_target(target, 'developer', mapped)
            self.assertEqual(chown.call_count, 3)
            chown.assert_any_call(target / 'link', 1501, 120, follow_symlinks=False)
            self.assertEqual((target / 'file').read_text(), 'content')
            self.assertEqual((target / 'file').stat().st_mode & 0o777, 0o600)

    def test_metric_atomic_permissions_no_follow_and_failure_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            unrelated = directory / 'unrelated'
            unrelated.write_text('do not change')
            metric = directory / 'backup_last_success_seconds.prom'
            metric.symlink_to(unrelated)
            with mock.patch.object(metrics.pwd, 'getpwnam', return_value=SimpleNamespace(pw_gid=os.getgid())) as lookup:
                metrics.write_metric(directory, 'backup_last_success_seconds')
                lookup.assert_called_once_with('svc_observability')
            self.assertFalse(metric.is_symlink())
            self.assertEqual(unrelated.read_text(), 'do not change')
            self.assertEqual(metric.stat().st_mode & 0o777, 0o640)
            self.assertEqual(metric.stat().st_gid, os.getgid())
            old = metric.read_bytes()
            with mock.patch.object(metrics.os, 'replace', side_effect=OSError('fixture failure')):
                with self.assertRaisesRegex(OSError, 'fixture failure'):
                    metrics.write_metric(directory, 'backup_last_success_seconds', os.getgid())
            self.assertEqual(metric.read_bytes(), old)
            self.assertEqual(sorted(p.name for p in directory.iterdir()),
                             ['backup_last_success_seconds.prom', 'unrelated'])


if __name__ == '__main__':
    unittest.main()
