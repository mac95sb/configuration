"""Fixture-only tests: no sudo, fnox, key reads, deployment, or live service calls."""
import argparse
import ast
import contextlib
import importlib.util
import io
import json
import os
import shlex
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


installer = load('install', 'install.py')
launcher = load('secret_launcher', 'secret_launcher.py')
child = load('security_child', 'secret_child.py')
backup = load('backup_launcher', 'backup_launcher.py')
backup_child = load('security_backup_child', 'backup_child.py')
shipper = load('security_shipper', 'ship_pitchfork.py')
activation = load('security_activation', 'activate.py')


def fixture_config():
    return {'providers': {'age': {'type': 'age', 'recipients': ['age1fixture']}},
            'default_provider': 'age',
            'profiles': {name: {'secrets': {key: {'value': 'fixture ciphertext'}}}
        for name, key in [('forgejo', 'FORGEJO_SECRET'), ('observability', 'ALLOY_SECRET'),
                          ('grafana', 'GRAFANA_SECRET'), ('notifications', 'NOTIFY_SECRET')]}}


class SecurityTests(unittest.TestCase):
    def test_deploy_shell_uses_bootstrap_checkout_and_explicit_config_without_sudo(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve()
            repo = base / 'bootstrap checkout'
            security = repo / 'services/security'
            security.mkdir(parents=True)
            caller = base / 'caller'
            caller.mkdir()
            capsule = caller / 'capsule config.toml'
            capsule.write_text('fixture recovered config')
            (repo / 'fnox.toml').write_text('fixture Git config')
            tools = base / 'tools/bin'
            tools.mkdir(parents=True)
            (tools / 'python3').write_text('fixture; never executed')
            (tools / 'python3').chmod(0o755)
            runner = base / 'capture.py'
            runner.write_text('import json,os,sys; print(json.dumps({"args":sys.argv[1:],"cwd":os.getcwd()}))\n')
            capture = base / 'capture-exec'
            capture.write_text('#!/bin/sh\nexec ' + shlex.quote(sys.executable) + ' -I -S ' +
                               shlex.quote(str(runner)) + ' "$@"\n')
            capture.chmod(0o755)
            home = base / 'home'
            mise = home / '.local/bin/mise'
            mise.parent.mkdir(parents=True)
            mise.write_text('#!/bin/sh\ncase "$1:$2" in\nwhere:python) printf "%s\\n" ' +
                shlex.quote(str(tools.parent)) + ' ;;\nwhich:*) printf "%s/%s\\n" ' +
                shlex.quote(str(tools)) + ' "$2" ;;\n*) exit 1 ;;\nesac\n')
            mise.chmod(0o755)
            source = (HERE / 'deploy.sh').read_text()
            self.assertEqual(source.count('/usr/bin/sudo'), 1)
            script = security / 'deploy.sh'
            script.write_text(source.replace('/usr/bin/sudo', shlex.quote(str(capture))))
            tasks = repo / '.mise/tasks/daemon'
            tasks.mkdir(parents=True)
            for name in ('install', 'relink', 'reload'):
                task_source = (HERE.parents[1] / '.mise/tasks/daemon' / name).read_text()
                self.assertNotIn('/Users/mac/Developer', task_source)
                self.assertNotIn('sudo', task_source)
                self.assertIn('"$repo/services/security/deploy.sh"', task_source)
                (tasks / name).write_text(task_source)
            env = {**os.environ, 'HOME': str(home), 'PATH': '/usr/bin:/bin',
                   'MISE_BIN': '/fixture/ignored-at-startup'}
            cases = [(script, ['stage', capsule.name], 'stage', capsule),
                                 (script, ['stage', '/etc/fnox/config.toml'], 'stage', Path('/etc/fnox/config.toml')),
                     (script, ['deploy', str(capsule)], 'deploy', capsule),
                     (script, ['deploy'], 'deploy', repo / 'fnox.toml'),
                     (tasks / 'install', [capsule.name], 'deploy', capsule),
                     (tasks / 'relink', [], 'tools', None),
                     (tasks / 'reload', [], 'config', None)]
            for entry, args, action, config in cases:
                with self.subTest(action=action, args=args):
                    result = subprocess.run(['/bin/sh', str(entry), *args], cwd=caller, env=env,
                                            check=True, capture_output=True, text=True, timeout=10)
                    captured = json.loads(result.stdout)
                    command = captured['args']
                    self.assertEqual(captured['cwd'], str(repo))
                    index = command.index(str(security / 'install.py'))
                    self.assertEqual(command[index + 1], action)
                    self.assertIn('/usr/bin/python3', command)
                    if config is not None:
                        self.assertEqual(command[command.index('--config') + 1], str(config))
                    else:
                        self.assertNotIn('--config', command)
                    self.assertEqual('--tool' in command, action != 'config')
            for args in ([], ['stage', ''], ['deploy', capsule.name, 'extra'],
                         ['tools', capsule.name], ['config', capsule.name], ['arbitrary-command']):
                with self.subTest(rejected=args):
                    result = subprocess.run(['/bin/sh', str(script), *args], cwd=caller, env=env,
                                            capture_output=True, text=True, timeout=10)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, '')  # The execution shim was never reached.
            # Prefer the fixed executable even when PATH contains a conflicting mise.
            fallback = tools / 'mise'
            fallback.write_text('#!/bin/sh\nexit 97\n')
            fallback.chmod(0o755)
            fallback_env = {**env, 'PATH': str(tools) + ':/usr/bin:/bin'}
            subprocess.run(['/bin/sh', str(script), 'tools'], cwd=caller, env=fallback_env,
                           check=True, capture_output=True, text=True, timeout=10)
            # Only absence permits PATH fallback; a present but unusable fixed file
            # must fail rather than silently select another executable.
            fallback.write_text(mise.read_text())
            mise.unlink()
            subprocess.run(['/bin/sh', str(script), 'stage', capsule.name], cwd=caller, env=fallback_env,
                           check=True, capture_output=True, text=True, timeout=10)
            mise.write_text('#!/bin/sh\nexit 98\n')
            mise.chmod(0o600)
            result = subprocess.run(['/bin/sh', str(script), 'tools'], cwd=caller, env=fallback_env,
                                    capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')
            mise.unlink()
            mise.symlink_to(home / 'missing-mise')
            result = subprocess.run(['/bin/sh', str(script), 'tools'], cwd=caller, env=fallback_env,
                                    capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')

    def test_stage_installs_runtime_and_selected_config_but_never_boot_configuration(self):
        for action in ('stage', 'deploy'):
            with self.subTest(action=action):
                config = Path('fixture-capsule-config.toml')
                argv = ['install.py', action, '--config', str(config)]
                for name in (*installer.TOOLS, 'python3'):
                    argv += ['--tool', name + '=/fixture/tools/' + name]
                fnox_config = fixture_config()
                with contextlib.ExitStack() as stack:
                    for module, name, kwargs in (
                        (sys, 'argv', {'new': argv}),
                        (installer.os, 'geteuid', {'return_value': 0}),
                        (installer.os, 'umask', {}), (installer.os, 'chdir', {}),
                        (installer, 'directory', {}), (installer, 'trusted_dir', {}),
                                                (Path, 'is_file', {'return_value': True}),
                        (installer, 'reject_acl', {}), (installer, 'install_python', {}),

                        (Path, 'lstat', {'return_value': SimpleNamespace(st_mode=stat.S_IFREG | 0o600, st_uid=0)}),
                        (installer, 'toml', {'return_value': fnox_config}),
                    ):
                        stack.enter_context(patch.object(module, name, **kwargs))
                    policy = stack.enter_context(patch.object(installer, 'validate_fnox_config',
                                                              wraps=installer.validate_fnox_config))
                    read = stack.enter_context(patch.object(Path, 'read_bytes', autospec=True,
                                                            return_value=b'fixture capsule config, not Git config'))
                    write = stack.enter_context(patch.object(installer, 'atomic_bytes'))
                    install = stack.enter_context(patch.object(installer, 'install'))
                    backup_install = stack.enter_context(patch.object(installer, 'deploy_backup'))
                    logging = stack.enter_context(patch.object(installer, 'prepare_logging'))
                    boot = stack.enter_context(patch.object(installer, 'deploy_config'))
                    stack.enter_context(patch('builtins.print'))
                    installer.main()
                    policy.assert_called_once_with(fnox_config)
                    read.assert_called_once_with(config.absolute())
                    write.assert_any_call(b'fixture capsule config, not Git config', Path('/etc/fnox/config.toml'), 0o600)
                    backup_install.assert_called_once_with()
                    destinations = {call.args[1] for call in install.call_args_list}
                    self.assertIn(launcher.BASE / 'backup_launcher.py', destinations)
                    self.assertIn(launcher.BASE / 'secret-service', destinations)
                    self.assertIn(Path('/usr/local/bin/restic'), destinations)
                    if action == 'stage':
                        boot.assert_not_called()
                        logging.assert_not_called()
                        self.assertEqual({call.args[1] for call in write.call_args_list},
                                         {Path('/etc/fnox/config.toml'), launcher.BASE / 'environment.json',
                                                                                   Path('/usr/local/bin/forgejo'), Path('/usr/local/bin/grafana')})
                        self.assertFalse(any(str(p).startswith(('/Library/LaunchDaemons/', '/etc/pitchfork/',
                                                               '/etc/newsyslog.d/')) for p in destinations))
                    else:
                        boot.assert_called_once_with(installer.REPO / 'pitchfork.toml')
                    write.reset_mock()
                    boot.reset_mock()
                    backup_install.reset_mock()
                    fnox_config['providers']['age']['type'] = 'command'
                    with self.assertRaises(ValueError):
                        installer.main()
                    self.assertNotIn(Path('/etc/fnox/config.toml'),
                                     {call.args[1] for call in write.call_args_list})
                    boot.assert_not_called()
                    backup_install.assert_not_called()

    def test_installer_rejects_invalid_stage_options_before_mutation(self):
        for args in (['stage'], ['tools', '--config', 'fixture.toml'],
                     ['config', '--config', 'fixture.toml'], ['stage', '--config', 'fixture.toml', '--no-boot-config']):
            with self.subTest(args=args), patch.object(sys, 'argv', ['install.py', *args]), \
                 patch.object(installer, 'directory') as directory, \
                 contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                installer.main()
            directory.assert_not_called()
        with patch.object(sys, 'argv', ['install.py', 'stage', '--config', '/fixture/missing.toml']), \
             patch.object(installer.os, 'geteuid', return_value=0), \
             patch.object(Path, 'is_file', return_value=False), \
             patch.object(installer, 'directory') as directory, self.assertRaises(ValueError):
            installer.main()
        directory.assert_not_called()

    def test_new_runtime_directories_get_0755_under_real_077_umask(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            paths = [base / part for part in ('usr', 'usr/local', 'usr/local/bin', 'usr/local/libexec',
                'usr/local/libexec/mac-server', 'usr/local/libexec/mac-server/backup',
                'usr/local/libexec/mac-server/python-fixture', 'usr/local/libexec/mac-server/python-fixture/bin')]
            real_fchmod = os.fchmod
            old_umask = os.umask(0o077)
            try:
                # Ownership checks are mocked because fixtures are unprivileged;
                # mkdir, the process umask, descriptor chmod, and mode checks are real.
                with patch.object(installer, 'trusted_dir') as trusted:
                    for path in paths:
                        trusted.reset_mock()
                        def chmod_after_validation(fd, mode):
                            trusted.assert_any_call(path, private=False)
                            real_fchmod(fd, mode)
                        with patch.object(installer.os, 'fchmod', side_effect=chmod_after_validation):
                            installer.directory(path)
                        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o755)
                    private = base / 'fnox'
                    installer.directory(private, 0o700)
                    self.assertEqual(stat.S_IMODE(private.stat().st_mode), 0o700)
            finally:
                os.umask(old_umask)

    def test_existing_directory_permissions_are_never_silently_relaxed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'existing'
            path.mkdir(mode=0o700)
            with patch.object(installer, 'trusted_dir'), patch.object(installer.os, 'fchmod') as chmod:
                with self.assertRaises(ValueError):
                    installer.directory(path)  # A private directory cannot become public implicitly.
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o700)
                installer.directory(path, 0o700)
                chmod.assert_not_called()
            path.chmod(0o755)
            with patch.object(installer, 'trusted_dir'), patch.object(installer.os, 'fchmod') as chmod:
                installer.directory(path)
                chmod.assert_not_called()
            path.chmod(0o777)
            with patch.object(installer, 'trusted_dir', side_effect=ValueError('Unsafe directory')), \
                 patch.object(installer.os, 'fchmod') as chmod, self.assertRaises(ValueError):
                installer.directory(path)
            chmod.assert_not_called()
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o777)

    def test_root_fnox_accepts_only_declared_age_providers_and_references(self):
        config = fixture_config()
        config['profiles']['forgejo']['providers'] = {'operational': {'type': 'age'}}
        config['profiles']['forgejo']['default_provider'] = 'operational'
        config['profiles']['forgejo']['secrets']['FORGEJO_SECRET']['sync'] = {
            'provider': 'operational', 'value': 'fixture ciphertext'}
        installer.validate_fnox_config(config)
        for provider in ('command', 'lua', 'plain', 'keychain', '1password', 'aws-sm', None):
            for profile_override in (False, True):
                changed = fixture_config()
                scope = changed['profiles']['forgejo'] if profile_override else changed
                scope['providers'] = {'future': {'type': provider}}
                with self.subTest(provider=provider, profile=profile_override), self.assertRaises(ValueError):
                    installer.validate_fnox_config(changed)
        for reference in ('undeclared', 'command', 'plain', {'secret': 'dynamic-provider'}):
            changed = fixture_config()
            changed['profiles']['forgejo']['secrets']['FORGEJO_SECRET']['provider'] = reference
            with self.subTest(reference=reference), self.assertRaises(ValueError):
                installer.validate_fnox_config(changed)
        with self.assertRaises(ValueError):
            installer.validate_fnox_config({'profiles': {}})

    def test_root_fnox_rejects_hooks_and_external_configuration_sources(self):
        for key in ('auth_command', 'credential_command', 'command', 'hooks', 'pre_exec', 'post_exec',
                    'import', 'plugins', 'leases', 'targets', 'files'):
            for placement in ('global', 'profile', 'provider', 'secret'):
                config = fixture_config()
                scope = {'global': config, 'profile': config['profiles']['forgejo'],
                         'provider': config['providers']['age'],
                         'secret': config['profiles']['forgejo']['secrets']['FORGEJO_SECRET']}[placement]
                scope[key] = 'fixture-not-executed'
                with self.subTest(key=key, placement=placement), self.assertRaises(ValueError):
                    installer.validate_fnox_config(config)
        config = fixture_config()
        config['providers']['unused'] = {'type': 'command'}
        with self.assertRaises(ValueError):
            installer.validate_fnox_config(config)

    def test_fixed_services_and_no_extra_arguments(self):
        with patch.object(launcher.os, 'geteuid', return_value=0):
            for args in ([], ['backup'], ['forgejo', '/bin/sh'], ['--profile', 'forgejo']):
                with self.subTest(args=args), self.assertRaises(SystemExit):
                    launcher.service_arg(args)
            self.assertEqual(launcher.service_arg(['forgejo']), 'forgejo')
        with patch.object(launcher.os, 'geteuid', return_value=501), self.assertRaises(SystemExit):
            launcher.service_arg(['forgejo'])

    def test_profile_whitelists_are_separate_and_combined_only_for_grafana(self):
        names = installer.environment_names(fixture_config())
        self.assertEqual(names['forgejo'], ['FORGEJO_SECRET'])
        self.assertEqual(names['alloy'], ['ALLOY_SECRET'])
        self.assertEqual(names['grafana'], ['GRAFANA_SECRET', 'NOTIFY_SECRET'])

    def test_control_environment_rejected(self):
        for name in ('PATH', 'DYLD_INSERT_LIBRARIES', 'PYTHONPATH', 'BASH_ENV', 'ENV',
                     'FNOX_AGE_KEY_FILE', 'SUDO_ASKPASS', 'BAD,NAME', 'HOME'):
            config = fixture_config()
            config['profiles']['forgejo']['secrets'][name] = {}
            with self.subTest(name=name), self.assertRaises(ValueError):
                installer.environment_names(config)

    def test_parent_exec_uses_protected_config_and_clean_environment(self):
        with patch.object(sys, 'argv', ['secret-service', 'forgejo']), \
             patch.object(launcher.os, 'geteuid', return_value=0), \
             patch.object(launcher, 'trusted'), patch.object(launcher.os, 'chdir'), \
             patch.object(Path, 'read_text', return_value='fixture-age-identity'), \
             patch.object(launcher.os, 'execve') as execute:
            launcher.main()
        binary, argv, env = execute.call_args.args
        self.assertEqual(binary, '/usr/local/bin/fnox')
        self.assertIn('/etc/fnox/config.toml', argv)
        self.assertIn('--no-daemon', argv)
        self.assertEqual(argv[argv.index('--profile') + 1], 'forgejo')
        self.assertEqual(argv[-2:], [str(launcher.BASE / 'secret_child.py'), 'forgejo'])
        self.assertEqual(env['FNOX_AGE_KEY_FILE'], '/etc/fnox/operational.key')
        self.assertEqual(env['FNOX_CONFIG_DIR'], '/etc/fnox')
        self.assertNotIn('PYTHONPATH', env)
        self.assertEqual(env['FNOX_AGE_KEY'], 'fixture-age-identity')
        self.assertNotIn('fixture-age-identity', ' '.join(argv))

    def test_child_drops_uid_and_never_places_secret_values_in_argv(self):
        for service, (user, command) in launcher.COMMANDS.items():
            with self.subTest(service=service), \
                 patch.object(sys, 'argv', ['secret_child.py', service]), \
                 patch.object(launcher.os, 'geteuid', return_value=0), \
                 patch.object(child, 'trusted'), \
                 patch.object(Path, 'read_text', return_value=json.dumps({service: ['APP_SECRET']})), \
                 patch.dict(os.environ, {'APP_SECRET': 'fixture-sensitive-value',
                     'FNOX_AGE_KEY_FILE': '/never/pass', 'OTHER_SECRET': 'not-for-this-service'}, clear=True), \
                 patch.object(child.os, 'execve') as execute:
                child.main()
                binary, argv, env = execute.call_args.args
                self.assertEqual(binary, '/usr/bin/sudo')
                self.assertIn('--preserve-env=APP_SECRET', argv)
                self.assertEqual(argv[argv.index('-u') + 1], user)
                self.assertEqual(argv[argv.index('--') + 1:], command)
                self.assertNotIn('fixture-sensitive-value', ' '.join(argv))
                self.assertEqual(env['APP_SECRET'], 'fixture-sensitive-value')
                self.assertNotIn('FNOX_AGE_KEY_FILE', env)
                self.assertNotIn('OTHER_SECRET', env)

    def test_backup_is_root_only_fixed_profile_and_default_backup(self):
        with patch.object(sys, 'argv', ['backup_launcher.py']), \
             patch.object(backup.os, 'geteuid', return_value=0), \
             patch.object(backup, 'validate_backup_runtime'), \
             patch.object(backup, 'root_environment', return_value={'FIXTURE': 'root-only'}), \
             patch.object(backup.os, 'chdir'), patch.object(backup.os, 'execve') as execute:
            backup.main()
        binary, argv, env = execute.call_args.args
        self.assertEqual(binary, '/usr/local/bin/fnox')
        self.assertEqual(argv[argv.index('--profile') + 1], 'backup')
        self.assertEqual(argv[-2:], [str(launcher.BASE / 'backup_child.py'), 'backup'])
        self.assertIn('/usr/local/bin/python3', argv)
        self.assertNotIn('/usr/bin/python3', argv)
        with patch.object(backup.os, 'geteuid', return_value=501), self.assertRaises(SystemExit):
            backup.main()

    def test_backup_allowed_commands_match_coordinator_parser(self):
        # Execute only the coordinator's argparse construction, not its operational code.
        source = (HERE.parent / 'backup/coordinator.py').read_text()
        main = next(n for n in ast.parse(source).body if isinstance(n, ast.FunctionDef) and n.name == 'main')
        statements = []
        for node in main.body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'args' for t in node.targets):
                break
            statements.append(node)
        namespace = {'argparse': argparse, '__doc__': 'fixture parser'}
        exec(compile(ast.Module(body=statements, type_ignores=[]), '<coordinator parser>', 'exec'), namespace)
        snapshot = 'a' * 64
        cases = [[], ['init'], ['backup'], ['checkpoint'], ['prune'], ['prune', '--apply'],
                 ['verify', snapshot], ['verify', snapshot, '--repository', '/Volumes/Recovery/repo'],
                 ['restore', snapshot, '--session', 'recovery_1'],
                 ['restore', snapshot, '--session=-resume', '--repository', '/Volumes/iCloud/restic-v1', '--offline']]
        for argv in cases:
            with self.subTest(argv=argv):
                canonical = backup.coordinator_args(argv)
                parsed = namespace['parser'].parse_args(canonical)
                self.assertEqual(parsed.command, argv[0] if argv else 'backup')
                self.assertIsNone(parsed.fixture)
        self.assertEqual(backup.coordinator_args([]), ['backup'])

    def test_backup_rejects_extra_commands_fixture_and_unsafe_recovery(self):
        snapshot = 'b' * 64
        cases = [['/bin/sh'], ['courier'], ['backup', '--fixture', '/tmp/x'],
                 ['--fixture', '/tmp/x', 'backup'], ['backup', '--repository', '/tmp/repo'],
                 ['--repository', '/tmp/repo', 'verify', snapshot], ['init', '--apply'],
                 ['prune', '--repository', '/tmp/repo'], ['verify', 'latest'], ['verify', 'A' * 64],
                 ['verify', snapshot, 'extra'], ['restore', snapshot],
                 ['restore', snapshot, '--session', '../escape'],
                 ['restore', snapshot, '--ses', 'abbreviated'],
                 ['verify', snapshot, '--repository', 'sftp:host:repo'],
                 ['verify', snapshot, '--repository', '/tmp/../escape'],
                 ['verify', snapshot, '--repository', 'rclone:R2:repo;command'],
                 ['verify', snapshot, '--repository', '/tmp/repo\ncommand'],
                 ['verify', snapshot, '--offline']]
        for argv in cases:
            with self.subTest(argv=argv), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                backup.coordinator_args(argv)

    def test_backup_child_drops_identity_and_unrelated_secrets(self):
        name = 'RCLONE_CONFIG_R2_SECRET_ACCESS_KEY'
        with patch.object(sys, 'argv', ['backup_child.py', 'checkpoint']), \
             patch.object(backup_child.os, 'geteuid', return_value=0), \
             patch.object(backup_child, 'validate_backup_runtime'), \
             patch.object(Path, 'read_text', return_value=json.dumps({'backup': [name]})), \
             patch.dict(os.environ, {name: 'fixture-backup-credential', 'FNOX_AGE_KEY': 'fixture-identity',
                 'FNOX_AGE_KEY_FILE': '/never/pass', 'FORGEJO_SECRET': 'unrelated'}, clear=True), \
             patch.object(backup_child.os, 'chdir'), patch.object(backup_child.os, 'execve') as execute:
            backup_child.main()
        binary, argv, env = execute.call_args.args
        self.assertEqual(binary, '/usr/local/bin/python3')
        self.assertEqual(argv[-2:], [str(launcher.BASE / 'backup/coordinator.py'), 'checkpoint'])
        self.assertEqual(env[name], 'fixture-backup-credential')
        self.assertEqual(env['PITCHFORK_USER'], 'root')
        self.assertEqual(env['HOME'], '/var/root')
        self.assertEqual(env['XDG_CONFIG_HOME'], '/etc')
        self.assertEqual(env['PITCHFORK_SUPERVISOR_AUTO_START'], 'false')
        self.assertNotIn('FNOX_AGE_KEY', env)
        self.assertNotIn('FNOX_AGE_KEY_FILE', env)
        self.assertNotIn('FORGEJO_SECRET', env)
        self.assertNotIn('fixture-backup-credential', ' '.join(argv))

    def test_backup_profile_rejects_remote_credentials_and_exports_none(self):
        config = fixture_config()
        config['profiles']['backup'] = {'secrets': {}}
        config['secrets'] = {'INHERITED_UNRELATED': {}}
        config['profiles']['backup']['secrets'].update({'UNRELATED_PROFILE_SECRET': {}})
        self.assertEqual(installer.environment_names(config)['backup'], [])
        for name in ('FNOX_AGE_KEY', 'DYLD_INSERT_LIBRARIES', 'RESTIC_PASSWORD_COMMAND', 'RCLONE_CONFIG'):
            changed = fixture_config()
            changed['profiles']['backup'] = {'secrets': {}}
            changed['profiles']['backup']['secrets'][name] = {}
            with self.subTest(name=name), self.assertRaises(ValueError):
                installer.environment_names(changed)

    def test_backup_deployment_forwards_args_and_has_one_canonical_runtime(self):
        with patch.object(installer, 'directory'), \
             patch.object(Path, 'read_bytes', return_value=b'#!/usr/bin/python3\n'), \
             patch.object(installer, 'atomic_bytes') as write:
            installer.deploy_backup()
        files = {args.args[1]: args.args[0] for args in write.call_args_list}
        canonical = files[launcher.BASE / 'backup/launch.sh']
        legacy = files[Path('/usr/local/libexec/home-backup/launch.sh')]
        self.assertIn(b'backup_launcher.py "$@"', canonical)
        self.assertIn(b'/mac-server/backup/launch.sh "$@"', legacy)
        self.assertNotIn(b'[ "$#" = 0 ]', canonical)
        self.assertIn(launcher.BASE / 'backup/coordinator.py', files)
        self.assertNotIn(Path('/usr/local/libexec/home-backup/coordinator.py'), files)
        self.assertNotIn('install.py', installer.BACKUP_FILES)
        self.assertNotIn(launcher.BASE / 'backup/install.py', files)
        for name in installer.BACKUP_FILES:
            with self.subTest(manifest_entry=name):
                self.assertTrue((HERE.parent / 'backup' / name).is_file())

    def test_boot_plist_uses_foreground_root_binary_and_keepalive(self):
        import plistlib
        import tomllib
        data = (HERE.parents[1] / 'pitchfork.toml').read_bytes()
        config = tomllib.loads(data.decode())
        with patch.object(installer, 'directory'), patch.object(installer, 'trusted_dir'), \
             patch.object(installer, 'prepare_logging'), \
             patch.object(installer, 'toml', return_value=config), \
             patch.object(installer, 'atomic_bytes') as write:
            installer.deploy_config(HERE.parents[1] / 'pitchfork.toml')
        self.assertEqual(write.call_args_list[0].args[0], data)
        plist = plistlib.loads(write.call_args_list[-1].args[0])
        self.assertEqual(plist['ProgramArguments'], ['/usr/local/bin/pitchfork', 'supervisor', 'run', '--boot'])
        self.assertTrue(plist['KeepAlive'])
        self.assertEqual(plist['UserName'], 'root')
        capture = config['daemons']['log_shipper_pitchfork']
        expected = capture['run']
        capture['run'] = '/Users/mac/Developer/configuration/services/logs/ship-pitchfork.sh'
        with patch.object(installer, 'directory'), patch.object(installer, 'toml', return_value=config), \
             self.assertRaises(ValueError):
            installer.deploy_config(HERE.parents[1] / 'pitchfork.toml')
        capture['run'] = expected
        config['daemons']['unexpected'] = {'run': '/bin/sh'}
        with patch.object(installer, 'directory'), patch.object(installer, 'toml', return_value=config), \
             self.assertRaises(ValueError):
            installer.deploy_config(HERE.parents[1] / 'pitchfork.toml')

    def test_root_log_capture_uses_fixed_global_commands_and_no_identity(self):
        process = MagicMock()
        process.__enter__.return_value = process
        process.stdout = [b'{"line":"fixture"}\n']
        process.wait.return_value = 0
        process.poll.return_value = 0
        with patch.object(sys, 'argv', ['ship_pitchfork.py']), \
             patch.object(shipper.os, 'geteuid', return_value=0), patch.object(shipper, 'trusted'), \
             patch.object(shipper.signal, 'signal'), patch.object(shipper, 'append_record') as append, \
             patch.dict(os.environ, {'FNOX_AGE_KEY': 'fixture-identity'}, clear=True), \
             patch.object(shipper.subprocess, 'Popen', return_value=process) as popen:
            shipper.main()
        command = popen.call_args.args[0]
        self.assertEqual(command[0], '/usr/local/bin/pitchfork')
        self.assertEqual(command[1:8], ['logs', '--json', '--follow', '--no-pager', '-n', '0', 'global/caddy'])
        self.assertNotIn('global/log_shipper_pitchfork', command)
        self.assertEqual(popen.call_args.kwargs['cwd'], '/var/empty')
        env = popen.call_args.kwargs['env']
        self.assertEqual(env['HOME'], '/var/root')
        self.assertEqual(env['PITCHFORK_USER'], 'root')
        self.assertNotIn('FNOX_AGE_KEY', env)
        append.assert_called_once_with(b'{"line":"fixture"}\n')

    def test_log_capture_reopens_rotated_sink_and_rejects_links_or_wrong_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'pitchfork.log'
            path.write_bytes(b'old\n')
            path.chmod(0o640)
            actual_fstat = os.fstat
            def root_stat(fd):
                s = actual_fstat(fd)
                return SimpleNamespace(st_mode=s.st_mode, st_uid=0, st_gid=os.getgid(), st_nlink=s.st_nlink)
            with patch.object(shipper.os, 'fstat', side_effect=root_stat):
                shipper.append_record(b'one\n', path, os.getgid())
                rotated = path.with_suffix('.old')
                path.rename(rotated)
                path.write_bytes(b'')
                path.chmod(0o640)
                shipper.append_record(b'two\n', path, os.getgid())
                self.assertEqual(rotated.read_bytes(), b'old\none\n')
                self.assertEqual(path.read_bytes(), b'two\n')
                path.chmod(0o666)
                with self.assertRaises(RuntimeError):
                    shipper.append_record(b'rejected', path, os.getgid())
            link = Path(tmp) / 'linked.log'
            link.symlink_to(path)
            with self.assertRaises(OSError):
                shipper.append_record(b'rejected', link, os.getgid())
            self.assertEqual(path.read_bytes(), b'two\n')

    def test_log_setup_preserves_data_and_sets_group_readable_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'postfix.log'
            path.write_bytes(b'preserve\n')
            with patch.object(installer.os, 'fchown') as chown, patch.object(installer, 'reject_acl'):
                installer.log_file(path, os.getuid(), os.getgid(), os.getuid())
            self.assertEqual(path.read_bytes(), b'preserve\n')
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o640)
            self.assertEqual(chown.call_args.args[1:], (os.getuid(), os.getgid()))

    def test_activation_gracefully_stops_old_supervisors_before_bootstrap(self):
        import plistlib
        env = {key: activation.ROOT_ENV[key] for key in
               ('PATH', 'HOME', 'PITCHFORK_USER', 'PITCHFORK_SUPERVISOR_AUTO_START', 'XDG_CONFIG_HOME')}
        plist = {'Label': 'pitchfork', 'UserName': 'root', 'KeepAlive': True, 'WorkingDirectory': '/var/empty',
                 'ProgramArguments': ['/usr/local/bin/pitchfork', 'supervisor', 'run', '--boot'],
                 'EnvironmentVariables': env}
        with patch.object(sys, 'argv', ['activate.py']), patch.object(activation.os, 'geteuid', return_value=0), \
             patch.object(activation, 'validate_runtime'), patch.object(activation, 'trusted'), \
             patch.object(Path, 'read_bytes', return_value=plistlib.dumps(plist)), \
             patch.object(activation, 'prepare_logging') as logging, \
             patch.object(activation.pwd, 'getpwnam', return_value=SimpleNamespace(pw_uid=501)), \
             patch.object(activation, 'loaded', return_value=True), \
             patch.object(activation, 'status', side_effect=['up', 'down', 'up', 'down', 'up']), \
             patch.object(activation, 'run') as run, patch('builtins.print'):
            activation.main()
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[:2], [['/bin/launchctl', 'disable', 'gui/501/pitchfork'],
                                      ['/bin/launchctl', 'disable', 'system/pitchfork']])
        self.assertEqual(commands[2][-2:], ['stop', '--all'])
        self.assertIn('-u', commands[2])
        self.assertEqual(commands[2][commands[2].index('-u') + 1], 'mac')
        self.assertEqual(commands[3][-2:], ['supervisor', 'stop'])
        self.assertEqual(commands[4][-2:], ['stop', '--all'])
        self.assertEqual(commands[5][-2:], ['supervisor', 'stop'])
        self.assertEqual(commands[6:8], [['/bin/launchctl', 'bootout', 'gui/501/pitchfork'],
                                        ['/bin/launchctl', 'bootout', 'system/pitchfork']])
        self.assertEqual(commands[-1], ['/bin/launchctl', 'bootstrap', 'system', str(activation.PLIST)])
        logging.assert_called_once_with(launcher.BASE / 'newsyslog.conf')

    def test_activation_bootstrap_validates_before_using_installed_python(self):
        task = (HERE.parents[1] / '.mise/tasks/daemon/activate').read_text()
        words = shlex.split(task, comments=True)
        bootstrap = words[words.index('-c') + 1]
        compile(bootstrap, '<activation bootstrap>', 'exec')
        self.assertIn('/usr/bin/python3', words)
        self.assertIn('s.st_uid != 0', bootstrap)
        self.assertIn('s.st_mode & 0o022', bootstrap)
        self.assertIn('stat.S_ISREG', bootstrap)
        self.assertIn('/mac-server/install.py', bootstrap)
        self.assertIn('/mac-server/secret_launcher.py', bootstrap)
        self.assertNotIn('/Users/mac/Developer', task)

    def test_activation_reads_plain_status_json_and_rejects_unknown(self):
        for state in ('up', 'down'):
            with self.subTest(state=state), patch.object(activation, 'run',
                    return_value=json.dumps({'status': state, 'web_ui': None})):
                self.assertEqual(activation.status('root'), state)
        current_shape = {'status': 'unknown',
                         'error': 'supervisor process is running but IPC connection failed'}
        with patch.object(activation, 'run', return_value=json.dumps(current_shape)), self.assertRaises(RuntimeError):
            activation.status('root')

    def test_activation_fresh_host_skips_absent_supervisors_and_fails_on_unknown_state(self):
        with patch.object(activation, 'status', return_value='down'), patch.object(activation, 'run') as run:
            activation.stop_supervisor('mac')
        run.assert_not_called()
        with patch.object(activation, 'run', return_value='{"status":"unknown"}'), self.assertRaises(RuntimeError):
            activation.status('mac')
        with patch.object(activation, 'status', side_effect=['up', 'up']), \
             patch.object(activation.time, 'monotonic', side_effect=[0, 16]), \
             patch.object(activation, 'run') as run, self.assertRaises(RuntimeError):
            activation.stop_supervisor('mac')
        self.assertFalse(any('bootstrap' in call.args[0] for call in run.call_args_list))
        with patch.object(activation, 'status', side_effect=['up', 'up', 'down']), \
             patch.object(activation.time, 'sleep') as sleep, patch.object(activation, 'run'):
            activation.stop_supervisor('mac')
        sleep.assert_called_once_with(0.5)

    def test_atomic_install_replaces_symlink_without_touching_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            parent = Path(tmp)
            target = parent / 'user-file'
            target.write_bytes(b'unchanged')
            destination = parent / 'installed'
            destination.symlink_to(target)
            with patch.object(installer, 'trusted_dir'), patch.object(installer.os, 'fchown') as chown:
                installer.atomic_bytes(b'protected', destination, 0o600)
            self.assertFalse(destination.is_symlink())
            self.assertTrue(stat.S_ISREG(destination.lstat().st_mode))
            self.assertEqual(destination.read_bytes(), b'protected')
            self.assertEqual(target.read_bytes(), b'unchanged')
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)
            self.assertEqual(chown.call_args.args[1:], (0, 0))

    def test_extended_acls_rejected(self):
        with patch.object(installer.os, 'uname') as uname, \
             patch.object(installer.subprocess, 'check_output', return_value='drwxr-xr-x+ root wheel fixture'):
            uname.return_value.sysname = 'Darwin'
            with self.assertRaises(ValueError):
                installer.reject_acl(Path('/fixture'))

    def test_python_external_libraries_and_loader_escapes_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            binary = root / 'python3'
            binary.write_bytes(b'\xcf\xfa\xed\xfe')
            for dependency in ('/opt/homebrew/lib/libpython.dylib',
                               '@loader_path/../../outside/libpython.dylib'):
                with self.subTest(dependency=dependency), \
                     patch.object(installer.subprocess, 'check_output',
                                  return_value=str(binary) + ':\n\t' + dependency + ' (compatibility version 1.0.0)\n'), \
                     self.assertRaises(ValueError):
                    installer.check_macho_tree(root)

    def test_directory_symlinks_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            parent = Path(tmp)
            link = parent / 'link'
            link.symlink_to(parent, target_is_directory=True)
            with self.assertRaises(ValueError):
                installer.check_dir(link)

    def test_pitchfork_root_commands_and_minute_metrics(self):
        import tomllib
        config = tomllib.loads((HERE.parents[1] / 'pitchfork.toml').read_text())
        self.assertEqual(config['settings']['supervisor']['user'], 'root')
        roots = {name: daemon['run'] for name, daemon in config['daemons'].items()
                 if daemon['user'] == 'root'}
        self.assertEqual(roots, {**{name: str(launcher.BASE / 'secret-service') + ' ' + name
            for name in launcher.PROFILES}, 'backup': str(launcher.BASE / 'backup/launch.sh'),
                            'log_shipper_pitchfork': str(launcher.BASE / 'ship-pitchfork.sh')})
        self.assertEqual(config['daemons']['soc_metrics']['cron']['schedule'], '0 * * * * *')
        self.assertNotIn('log_shipper', config['daemons'])


if __name__ == '__main__':
    unittest.main()
