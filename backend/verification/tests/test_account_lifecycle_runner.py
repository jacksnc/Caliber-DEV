"""Exercise the destructive QA verifier with fictional HTTP responses only."""
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import account_lifecycle_smoke as runner


class Response:
    def __init__(self, status, data):
        self.status, self.data = status, data

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self, _):
        return json.dumps(self.data).encode()


class FixtureTransport:
    def __init__(self, deletion_fails=False, echoes_password=False):
        self.deletion_fails, self.echoes_password = deletion_fails, echoes_password
        self.deleted = False
        self.sessions = 0
        self.logouts = 0

    def open(self, request, timeout):
        route = request.full_url.removeprefix(runner.BASE)
        body = json.loads(request.data)
        if route == '/auth/sign-in':
            if self.echoes_password:
                return Response(500, {'private': body['password']})
            if self.deleted:
                return Response(401, {'error': 'unauthorized'})
            self.sessions += 1
            return Response(200, {
                'subject': '00000000-0000-4000-8000-000000000001',
                'accessToken': 'fixture-private-token-' + str(self.sessions),
                'refreshToken': 'fixture-private-refresh-' + str(self.sessions),
            })
        if route == '/account/consent':
            return Response(401, {'error': 'unauthorized'}) if self.deleted else Response(
                200, {'accepted': True, 'version': 'account-access-v1'})
        if route == '/sync/push':
            return Response(200, [{'operationID': body['operations'][0]['operationID']}])
        if route == '/account/delete':
            if 'subject' in body:
                return Response(400, {'error': 'invalid_request'})
            if body['password'] != 'fictional-private-password':
                return Response(401, {'error': 'unauthorized'})
            if self.deletion_fails:
                return Response(409, {'private': body['password']})
            self.deleted = True
            return Response(200, {'accountDeleted': True})
        if route == '/auth/refresh':
            return Response(401, {'error': 'unauthorized'})
        if route == '/sync/pull':
            return Response(200, {'changes': []})
        if route == '/auth/sign-out':
            self.logouts += 1
            return Response(200, {'signedOut': True})
        raise AssertionError('Unexpected fixture route')


class LifecycleRunnerTests(unittest.TestCase):
    def execute(self, transport):
        with patch.object(runner.urllib.request, 'build_opener', return_value=transport):
            report = runner.run('fictional-private-password')
        rendered = json.dumps(report)
        for private in ('fictional-private-password', 'fixture-private-token', 'fixture-private-refresh'):
            self.assertNotIn(private, rendered)
        return report

    def test_complete_lifecycle_and_cleanup(self):
        transport = FixtureTransport()
        report = self.execute(transport)
        self.assertTrue(report['passed'])
        self.assertEqual(len(report['criteria']), 12)
        self.assertEqual(transport.logouts, 2)

    def test_failed_deletion_cannot_pass_and_sessions_are_cleaned(self):
        transport = FixtureTransport(deletion_fails=True)
        report = self.execute(transport)
        self.assertFalse(report['passed'])
        self.assertFalse(report['criteria'][-1]['passed'])
        self.assertEqual(report['criteria'][-1]['criterion'], 'self-deletion confirmed')
        self.assertFalse(transport.deleted)
        self.assertEqual(transport.logouts, 2)

    def test_provider_password_echo_never_enters_report(self):
        report = self.execute(FixtureTransport(echoes_password=True))
        self.assertFalse(report['passed'])
        self.assertEqual(len(report['criteria']), 1)


if __name__ == '__main__':
    unittest.main()
