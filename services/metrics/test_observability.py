#!/usr/bin/env python3
"""Offline config/alert tests and isolated loopback fixtures; no production services."""

import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import urllib.parse
import time
import unittest

SERVICES = Path(__file__).resolve().parents[1]


def yaml_load(path):
    # Use the system Ruby YAML parser rather than adding a Python dependency.
    return json.loads(subprocess.check_output([
        'ruby', '-ryaml', '-rjson', '-e',
        'puts JSON.generate(YAML.load_file(ARGV.fetch(0)))', str(path)], text=True))


def port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def request(number, path='/', headers=None):
    connection = http.client.HTTPConnection('127.0.0.1', number, timeout=2)
    try:
        connection.request('GET', path, headers=headers or {})
        response = connection.getresponse()
        return response.status, response.read().decode()
    finally:
        connection.close()


class ObservabilityTests(unittest.TestCase):
    def test_caddy_filters_before_disk_and_client_ip(self):
        config = json.loads(subprocess.check_output([
            'caddy', 'adapt', '--adapter', 'caddyfile', '--config',
            str(SERVICES / 'caddy/Caddyfile')], text=True))
        server = config['apps']['http']['servers']['srv0']
        self.assertEqual(server['trusted_proxies']['ranges'], ['127.0.0.1/32'])
        self.assertEqual(server['client_ip_headers'], ['Cf-Connecting-Ip'])
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            number = port()
            server['listen'] = [f'127.0.0.1:{number}']
            config['admin'] = {'disabled': True, 'config': {'persist': False}}
            environment = {**os.environ, 'HOME': str(directory),
                           'XDG_CONFIG_HOME': str(directory / 'config'),
                           'XDG_DATA_HOME': str(directory / 'data')}
            logfile = directory / 'access.log'
            config['logging']['logs']['log0']['writer']['filename'] = str(logfile)
            filename = directory / 'caddy.json'
            filename.write_text(json.dumps(config))
            subprocess.run(['caddy', 'validate', '--config', str(filename)],
                                       check=True, env=environment)
            with (directory / 'runtime.log').open('w') as runtime:
                process = subprocess.Popen(['caddy', 'run', '--config', str(filename)],
                                           stdout=runtime, stderr=runtime, env=environment)
                try:
                    for _ in range(100):
                        if process.poll() is not None:
                            self.fail((directory / 'runtime.log').read_text())
                        try:
                            request(number, headers={'Host': 'status.maclong.dev'})
                            break
                        except OSError:
                            time.sleep(.05)
                    else:
                        self.fail('fixture Caddy did not start')
                    headers = {
                        'Host': 'status.maclong.dev',
                        'cf-access-jwt-assertion': 'fake.jwt.secret',
                        'CF-Access-Authenticated-User-Email': 'fake-user@example.invalid',
                        'Cookie': 'CF_Authorization=fake-cookie',
                        'Authorization': 'Bearer fake-bearer',
                        'Cf-Connecting-Ip': '198.51.100.42',
                        'X-Forwarded-For': '203.0.113.99',
                    }
                    self.assertEqual(request(number, '/redaction', headers)[0], 200)
                    request(number, '/no-cloudflare', {
                        'Host': 'status.maclong.dev', 'X-Forwarded-For': '203.0.113.99'})
                    for _ in range(100):
                        lines = logfile.read_text() if logfile.exists() else ''
                        if '/no-cloudflare' in lines:
                            break
                        time.sleep(.05)
                    for secret in ('fake.jwt.secret', 'fake-user@example.invalid',
                                   'fake-cookie', 'fake-bearer'):
                        self.assertNotIn(secret, lines)
                    entries = {entry['request']['uri']: entry
                               for entry in map(json.loads, lines.splitlines())}
                    entry = entries['/redaction']
                    self.assertNotIn('Cf-Access-Jwt-Assertion', entry['request']['headers'])
                    self.assertNotIn('Cf-Access-Authenticated-User-Email', entry['request']['headers'])
                    self.assertEqual(entry['request']['client_ip'], '198.51.100.42')
                    self.assertEqual(entries['/no-cloudflare']['request']['client_ip'], '127.0.0.1')
                finally:
                    process.terminate()
                    process.wait(timeout=10)

    def test_blackbox_health_headers_and_redirect_semantics(self):
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/api/health':
                    status = 200 if self.headers.get('Host') == 'dashboard.maclong.dev' else 302
                elif self.path == '/api/healthz':
                    status = 200
                else:
                    status = 302
                self.send_response(status)
                self.end_headers()
                self.wfile.write(b'fixture only')

            def log_message(self, *args):
                pass

        fixture = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=fixture.serve_forever, daemon=True)
        thread.start()
        number = port()
        with tempfile.TemporaryDirectory() as directory:
            with (Path(directory) / 'blackbox.log').open('w') as log:
                process = subprocess.Popen([
                    'blackbox_exporter', '--config.file=' + str(SERVICES / 'blackbox/config.yml'),
                    f'--web.listen-address=127.0.0.1:{number}'], stdout=log, stderr=log)
                try:
                    for _ in range(100):
                        if process.poll() is not None:
                            self.fail('fixture Blackbox exporter exited')
                        try:
                            request(number)
                            break
                        except OSError:
                            time.sleep(.05)
                    else:
                        self.fail('fixture Blackbox exporter did not start')
                    for module, path, success in (
                        ('http_grafana_health', '/api/health', 1),
                        ('http_forgejo_health', '/api/healthz', 1),
                        ('http_access_redirect', '/access', 1),
                        ('http_access_redirect', '/api/healthz', 0),
                        ('http_forgejo_health', '/access', 0),
                    ):
                        query = urllib.parse.urlencode({
                            'module': module,
                            'target': f'http://127.0.0.1:{fixture.server_port}{path}'})
                        status, body = request(number, '/probe?' + query)
                        self.assertEqual(status, 200)
                        self.assertIn(f'\nprobe_success {success}\n', body)
                finally:
                    process.terminate()
                    process.wait(timeout=10)
                    fixture.shutdown()
                    fixture.server_close()
                    thread.join(timeout=5)

    def test_log_workers_fail_independently(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            for name in ('pitchfork', 'postfix'):
                source = (SERVICES / f'logs/ship-{name}.sh').read_text()
                start = '/usr/local/bin/pitchfork' if name == 'pitchfork' else '/usr/bin/log'
                for status in (0, 7):
                    producer = directory / 'producer'
                    producer.write_text(f'#!/bin/sh\nprintf "fake log line\\n"\nexit {status}\n')
                    producer.chmod(0o700)
                    target = directory / f'{name}.log'
                    script = directory / 'worker.sh'
                    script.write_text(source.replace(start, str(producer)).replace(
                        f'/var/log/services/{name}.log', str(target)))
                    result = subprocess.run(['/bin/sh', str(script)], timeout=5)
                    self.assertNotEqual(result.returncode, 0, 'EOF or failure must trigger restart')
                    self.assertIn('fake log line', target.read_text())

    def test_review_timestamp_writer_uses_explicit_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'updates.prom'
            before = int(time.time())
            subprocess.run(['/bin/sh', str(SERVICES / 'metrics/updates-reviewed.sh')],
                           check=True, env={**os.environ, 'METRICS_FILE': str(output)})
            value = int(output.read_text().splitlines()[-1].split()[1])
            self.assertGreaterEqual(value, before)
            self.assertLessEqual(value, int(time.time()))
            self.assertEqual(list(Path(directory).iterdir()), [output])
            subprocess.run(['promtool', 'check', 'metrics'], input=output.read_text(),
                           text=True, check=True)

    def test_native_configs_and_provisioning(self):
        subprocess.run(['promtool', 'check', 'config', str(SERVICES / 'prometheus/config.yml')], check=True)
        subprocess.run(['blackbox_exporter', '--config.check',
                        '--config.file=' + str(SERVICES / 'blackbox/config.yml')], check=True)
        subprocess.run(['alloy', 'validate', str(SERVICES / 'alloy/config.alloy')],
                       check=True, env={**os.environ, 'SCRUB_SALT': 'fake-test-salt'})
        for path in (SERVICES / 'grafana/provisioning').rglob('*.yaml'):
            self.assertEqual(yaml_load(path)['apiVersion'], 1)
        dashboard = json.loads((SERVICES / 'grafana/provisioning/dashboards/server-overview.json').read_text())
        self.assertNotIn('host_memory_pressure_ratio', json.dumps(dashboard))
        self.assertIn('service = "caddy"', (SERVICES / 'alloy/config.alloy').read_text())
        config = yaml_load(SERVICES / 'prometheus/config.yml')
        self.assertEqual(config['global'], {'scrape_interval': '60s', 'evaluation_interval': '60s'})
        blackbox = yaml_load(SERVICES / 'blackbox/config.yml')['modules']
        self.assertEqual(blackbox['http_grafana_health']['http']['headers']['Host'], 'dashboard.maclong.dev')
        self.assertFalse(blackbox['http_grafana_health']['http']['follow_redirects'])

    def test_alert_expressions_with_synthetic_series(self):
        groups = yaml_load(SERVICES / 'grafana/provisioning/alerting/rules.yaml')['groups']
        rules = {rule['uid']: rule for group in groups for rule in group['rules']}
        self.assertEqual(rules['log_ingestion_failing']['for'], '0m')
        self.assertEqual(rules['infrastructure_update_review']['noDataState'], 'Alerting')
        # Grafana's native provisioning has no offline check command. Validate
        # every PromQL expression with promtool, using the exact provisioned query.
        native = []
        for uid, rule in rules.items():
            self.assertIn(rule['condition'], [item['refId'] for item in rule['data']])
            for item in rule['data']:
                if 'expr' in item['model']:
                    native.append({'record': 'test_' + uid, 'expr': item['model']['expr']})
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            rulefile = directory / 'rules.json'
            rulefile.write_text(json.dumps({'groups': [{'name': 'test', 'rules': native}]}))
            subprocess.run(['promtool', 'check', 'rules', str(rulefile)], check=True)
            tests = []
            def case(uid, series, samples, at='0m'):
                tests.append({'interval': '1m', 'input_series': series,
                              'promql_expr_test': [{'expr': rules[uid]['data'][0]['model']['expr'],
                                                   'eval_time': at, 'exp_samples': samples}]})
            def sample(labels, value):
                return {'labels': labels, 'value': value}
            case('infrastructure_update_review', [
                {'series': 'infrastructure_updates_last_review_seconds{job="node"}', 'values': '-2678400'}],
                [sample('{job="node"}', 2678400)])
            # Missing review timestamp yields NoData, configured as Alerting.
            case('infrastructure_update_review', [], [])
            case('disk_metrics_missing', [], [
                sample('{job="node",mountpoint="/"}', 1),
                sample('{job="node",mountpoint="/System/Volumes/Data"}', 1)])
            disks = [{'series': f'{metric}{{job="node",mountpoint="{mount}"}}', 'values': value}
                     for mount in ('/', '/System/Volumes/Data')
                     for metric, value in (('node_filesystem_avail_bytes', '5'),
                                           ('node_filesystem_size_bytes', '100'))]
            case('disk_metrics_missing', disks, [])
            case('disk_space_low', disks, [sample('{mountpoint="/"}', .05),
                                           sample('{mountpoint="/System/Volumes/Data"}', .05)])
            soc_names = ('host_gpu_utilization_ratio', 'host_gpu_memory_bytes',
                         'host_ane_busy_seconds_total', 'host_power_watts',
                         'host_battery_charge_ratio', 'host_memory_free_ratio')
            soc = [{'series': f'{metric}{{job="node"}}', 'values': '1+0x10'} for metric in soc_names]
            soc.append({'series': 'node_textfile_mtime_seconds{job="node",file="/fixture/soc.prom"}',
                        'values': '0+0x10'})
            case('soc_metrics_stale', soc, [sample('{job="node",file="/fixture/soc.prom"}', 0),
                                          ], '1m')
            case('soc_metrics_stale', soc, [sample('{job="node",file="/fixture/soc.prom"}', 1)], '6m')
            case('soc_metrics_stale', [], [sample('{job="node"}', 1)])
            case('textfile_collectors_stale', [
                {'series': 'node_textfile_mtime_seconds{job="node",file="/fixture/daily.prom"}',
                 'values': '-93660'},
                {'series': 'node_textfile_scrape_error{job="node"}', 'values': '0'}],
                [sample('{job="node",file="/fixture/daily.prom"}', 1), sample('{__name__="node_textfile_scrape_error",job="node"}', 0)])
            case('textfile_collectors_stale', [
                {'series': 'node_textfile_mtime_seconds{job="node",file="/fixture/daily.prom"}',
                 'values': '123 stale _ _ _ _ _'},
                {'series': 'node_textfile_scrape_error{job="node"}', 'values': '0+0x6'}],
                [sample('{job="node",file="/fixture/daily.prom"}', 1),
                 sample('{__name__="node_textfile_scrape_error",job="node"}', 0)], '6m')
            case('soc_metrics_stale', soc[1:], [
                sample('{job="node",file="/fixture/soc.prom"}', 0), sample('{job="node"}', 1)], '1m')
            case('infrastructure_update_review', [
                {'series': 'infrastructure_updates_last_review_seconds{job="node"}', 'values': '-60'}],
                [sample('{job="node"}', 60)])
            case('log_ingestion_failing', [
                {'series': 'loki_write_dropped_entries_total', 'values': '0 0 1 1 1 1 1'}],
                [sample('{}', 1)], '6m')
            testfile = directory / 'tests.json'
            testfile.write_text(json.dumps({'rule_files': [str(rulefile)],
                                            'evaluation_interval': '1m', 'tests': tests}))
            subprocess.run(['promtool', 'test', 'rules', str(testfile)], check=True)


if __name__ == '__main__':
    unittest.main()
