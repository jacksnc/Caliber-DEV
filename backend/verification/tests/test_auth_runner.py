"""No network or real credentials: verify the verifier fails on global logout and never logs secrets."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import auth_lifecycle as runner


class Response:
    def __init__(self, status, data):
        self.code, self.data = status, data
        self.headers = {'Cache-Control': 'no-store'}

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self, _):
        return json.dumps(self.data).encode()


class FixtureTransport:
    def __init__(self, global_logout=False, echo_secret=False):
        self.global_logout, self.echo_secret = global_logout, echo_secret
        self.sessions, self.records = {}, {}

    def session(self, subject):
        token = 'fixture-token-' + str(len(self.sessions))
        data = {'accessToken': token, 'refreshToken': 'refresh-' + token, 'subject': subject,
                'expiresAt': datetime.now(timezone.utc).timestamp() + 3600 - 978307200}
        self.sessions[token] = (data, True)
        return data

    def open(self, request, timeout):
        route = request.full_url.split('/gateway')[-1]
        body = json.loads(request.data)
        if route == '/auth/sign-in':
            if self.echo_secret:
                return Response(409, {'providerDetail': body['password'], 'token': 'fixture-token-private'})
            subject = ('c71dfb62-e139-4fca-afb6-8d29cda70261' if body['email'] == runner.EMAILS[0]
                       else 'fdc711c7-089d-4807-af2b-9b99ff72ef4a')
            return Response(200, self.session(subject))
        if route == '/auth/refresh':
            prior = next((value for value in self.sessions.values()
                          if value[0]['refreshToken'] == body['refreshToken']), None)
            if not prior or not prior[1]:
                return Response(409, {'error': 'request_rejected'})
            return Response(200, self.session(prior[0]['subject']))
        token = request.get_header('Authorization').removeprefix('Bearer ')
        data, active = self.sessions[token]
        if route == '/auth/sign-out':
            for key, (other, valid) in list(self.sessions.items()):
                if key == token or (self.global_logout and other['subject'] == data['subject']):
                    self.sessions[key] = (other, False)
            return Response(200, {'signedOut': True})
        owner = runner.OWNERS[0] if data['subject'].startswith('c71d') else runner.OWNERS[1]
        if body['ownerID'] != owner:
            return Response(409, {'error': 'request_rejected'})
        if route == '/sync/push':
            self.records[owner] = body['operations'][0]
            return Response(200, [{'operationID': self.records[owner]['operationID'], 'cursor': 1}])
        return Response(200, {'ownerID': owner, 'changes': [{'operation': self.records[owner], 'cursor': 1}]})


class RunnerTests(unittest.TestCase):
    def execute(self, transport):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'results.json'
            stream = io.StringIO()
            with patch.object(runner, 'build_opener', return_value=transport), \
                    patch.object(runner.getpass, 'getpass', return_value='fictional-password-secret'), \
                    contextlib.redirect_stdout(stream):
                status = runner.run('https://fixture.invalid/gateway', 'us-east-1', output)
            text = output.read_text()
            for secret in ('fictional-password-secret', 'fixture-token-', 'refresh-fixture'):
                self.assertNotIn(secret, text + stream.getvalue())
            return status, json.loads(text)

    def test_current_session_logout_passes(self):
        status, report = self.execute(FixtureTransport())
        self.assertEqual(status, 0)
        self.assertTrue(report['passed'])
        self.assertTrue(all(row['passed'] for row in report['results']))

    def test_global_logout_cannot_pass(self):
        status, report = self.execute(FixtureTransport(global_logout=True))
        self.assertEqual(status, 1)
        self.assertEqual(report['failure'], 'Other session refreshes after local-scope logout')

    def test_provider_echo_is_not_saved(self):
        status, report = self.execute(FixtureTransport(echo_secret=True))
        self.assertEqual(status, 1)
        self.assertEqual(report['failure'], 'Account A first session')


if __name__ == '__main__':
    unittest.main()
