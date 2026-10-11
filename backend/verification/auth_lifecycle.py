#!/usr/bin/env python3
"""Interactive DEV verification. Passwords/tokens stay in memory, never in evidence."""
import argparse
import base64
import getpass
import json
import math
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, build_opener
from uuid import UUID

from http_smoke import NoRedirect

EMAILS = ('caliber.qa.a@caliber.invalid', 'caliber.qa.b@caliber.invalid')
OWNERS = ('0199b100-1000-7000-8000-000000000001', '0199b100-1000-7000-8000-000000000002')


class SafeFailure(Exception):
    """Only a fixed check name is allowed in this error, never response contents."""


def valid_session(data):
    if not isinstance(data, dict) or not all(
        isinstance(data.get(key), str) and data[key]
        for key in ('accessToken', 'refreshToken', 'subject')
    ):
        return False
    try:
        UUID(data['subject'])
        expiry = data['expiresAt']
        return (isinstance(expiry, (int, float)) and not isinstance(expiry, bool) and
                math.isfinite(expiry) and expiry + 978307200 > datetime.now(timezone.utc).timestamp())
    except (ValueError, KeyError, TypeError):
        return False


def run(endpoint, region, output):
    results, sessions = [], []
    opener = build_opener(NoRedirect)

    def check(name, condition):
        results.append({'criterion': name, 'passed': bool(condition)})
        print(name, 'PASS' if condition else 'FAIL')
        if not condition:
            raise SafeFailure(name)

    def request(route, body, session=None):
        headers = {'Content-Type': 'application/json', 'x-region': region}
        if session:
            headers['Authorization'] = 'Bearer ' + session['accessToken']
        req = Request(endpoint + route, data=json.dumps(body).encode(), headers=headers, method='POST')
        try:
            response = opener.open(req, timeout=25)
        except HTTPError as error:
            response = error
        with response:
            if response.headers.get('Cache-Control') != 'no-store':
                raise SafeFailure('Responses must prohibit caching')
            data = json.loads(response.read(262144))
            return response.code, data

    def signin(email, password, name):
        status, data = request('/auth/sign-in', {'email': email, 'password': password})
        valid = status == 200 and valid_session(data)
        # Save a successfully issued session for best-effort logout even if its contract is invalid.
        if isinstance(data, dict) and isinstance(data.get('accessToken'), str):
            sessions.append(data)
        check(name, valid)
        return data

    def operation(owner, suffix):
        return {'operationID': '0199b100-1000-7000-8000-00000000000' + suffix,
                'ownerID': owner, 'entityID': '0199b100-1000-7000-8000-000000000003',
                'deviceID': '0199b100-1000-7000-8000-000000000004', 'namespace': 'note',
                'logicalClock': 1, 'tombstone': False, 'resolves': [],
                'payload': base64.b64encode(b'{"text":"fictional signed-token fixture"}').decode()}

    def pull(owner, session):
        return request('/sync/pull', {'ownerID': owner, 'after': 0, 'limit': 100}, session)

    failure = None
    try:
        print('Use only the two confirmed fictional DEV accounts shown below.')
        print('This test writes one fictional note per account. No diary/photo data is read or uploaded.')
        password = getpass.getpass(EMAILS[0] + ' password (hidden): ')
        first = signin(EMAILS[0], password, 'Account A first session')
        other = signin(EMAILS[0], password, 'Account A second session')
        del password
        password = getpass.getpass(EMAILS[1] + ' password (hidden): ')
        second = signin(EMAILS[1], password, 'Account B session')
        del password
        check('Sessions bind to distinct authenticated accounts',
              first['subject'] == other['subject'] and first['subject'] != second['subject'])
        for owner, session, suffix in ((OWNERS[0], first, '5'), (OWNERS[1], second, '6')):
            op = operation(owner, suffix)
            body = {'ownerID': owner, 'operations': [op]}
            status, initial = request('/sync/push', body, session)
            check('Owner ' + suffix + ' authenticated push', status == 200 and isinstance(initial, list) and
                  len(initial) == 1 and initial[0].get('operationID') == op['operationID'])
            status, repeated = request('/sync/push', body, session)
            check('Owner ' + suffix + ' idempotent retry', status == 200 and initial == repeated)
            status, page = pull(owner, other if owner == OWNERS[0] else session)
            check('Owner ' + suffix + ' authenticated pull', status == 200 and isinstance(page, dict) and
                  page.get('ownerID') == owner and any(
                      row.get('operation') == op for row in page.get('changes', [])))
        for owner, session in ((OWNERS[0], second), (OWNERS[1], first)):
            status, data = pull(owner, session)
            check('Cross-owner pull denied for ' + owner[-1],
                  status == 409 and data == {'error': 'request_rejected'})
        status, data = request('/sync/push', {'ownerID': OWNERS[0],
            'operations': [operation(OWNERS[0], '5')]}, second)
        check('Cross-owner push denied', status == 409 and data == {'error': 'request_rejected'})
        status, data = request('/auth/sign-out', {}, first)
        check('Current-session logout', status == 200 and data == {'signedOut': True})
        sessions.remove(first)
        status, data = request('/auth/refresh', {'refreshToken': first['refreshToken']})
        check('Logged-out refresh token rejected', status == 409 and data == {'error': 'request_rejected'})
        status, renewed = request('/auth/refresh', {'refreshToken': other['refreshToken']})
        valid = status == 200 and valid_session(renewed) and renewed['subject'] == other['subject']
        if isinstance(renewed, dict) and isinstance(renewed.get('accessToken'), str):
            sessions[sessions.index(other)] = renewed
        check('Other session refreshes after local-scope logout', valid)
        status, page = pull(OWNERS[0], renewed)
        check('Refreshed session remains authorized', status == 200 and page.get('ownerID') == OWNERS[0])
    except SafeFailure as error:
        failure = str(error)  # Fixed check name only.
    except (Exception, KeyboardInterrupt):
        failure = 'Verification interrupted or transport/response failed'
    finally:
        cleanup_ok = True
        for session in sessions:
            try:
                status, data = request('/auth/sign-out', {}, session)
                cleanup_ok = cleanup_ok and status == 200 and data == {'signedOut': True}
            except (Exception, KeyboardInterrupt):
                cleanup_ok = False
        results.append({'criterion': 'Remaining issued sessions logged out', 'passed': cleanup_ok})
        report = {'checkedAt': datetime.now(timezone.utc).isoformat(), 'endpoint': endpoint,
                  'fictionalFixtureOwners': list(OWNERS), 'results': results,
                  'passed': failure is None and cleanup_ok, 'failure': failure,
                  'scope': 'Fictional DEV accounts only; note rows remain until fixture-account cleanup. Access JWTs may remain valid until expiry.'}
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + '\n')
        print('Verification', 'PASS' if report['passed'] else 'FAIL', '— sanitized report:', output)
    return int(not report['passed'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads((Path(__file__).resolve().parents[2] /
                         'Caliber (DEV)/Resources/CloudDeployment.json').read_text())
    endpoint = config['projectURL'].rstrip('/') + '/functions/v1/caliber-gateway'
    if not endpoint.startswith('https://'):
        raise ValueError('HTTPS is required')
    raise SystemExit(run(endpoint, config['region'], args.output))
