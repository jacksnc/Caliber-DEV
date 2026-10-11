#!/usr/bin/env python3
"""Bounded DEV check: six parallel attempts for a nonexistent fictional account."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, build_opener

from http_smoke import NoRedirect


def run(endpoint, region, output):
    email = 'caliber.qa.limit@caliber.invalid'
    results = []

    def request(path, body, forwarded_ip=None):
        headers = {'Content-Type': 'application/json', 'x-region': region}
        if forwarded_ip:
            headers['x-forwarded-for'] = forwarded_ip
        raw = body if isinstance(body, bytes) else json.dumps(body).encode()
        req = Request(endpoint + path, data=raw, headers=headers, method='POST')
        opener = build_opener(NoRedirect)
        try:
            response = opener.open(req, timeout=25)
        except HTTPError as error:
            response = error
        with response:
            payload = json.loads(response.read(4096))
            return response.code, payload, response.headers.get('Cache-Control'), response.headers.get('Retry-After')

    def record(name, condition):
        results.append({'criterion': name, 'passed': bool(condition)})
        print(name, 'PASS' if condition else 'FAIL', flush=True)

    failure = None
    try:
        for name, path, body, expected, error in (
            ('Auth byte limit', '/auth/sign-in', b'x' * 8193, 413, 'request_too_large'),
            ('Empty credentials denied', '/auth/sign-in', {'email': '', 'password': ''}, 400, 'invalid_request'),
            ('No gateway signup route', '/auth/sign-up', {}, 404, 'not_found'),
        ):
            status, data, cache, _ = request(path, body)
            record(name, status == expected and data == {'error': error} and cache == 'no-store')
        with ThreadPoolExecutor(max_workers=6) as pool:
            responses = list(pool.map(lambda _: request('/auth/sign-in', {
                'email': email, 'password': 'fictional-wrong-password'}), range(6)))
        accepted = sum(status == 409 and data == {'error': 'request_rejected'} and cache == 'no-store'
                       for status, data, cache, _ in responses)
        throttled = sum(status == 429 and data == {'error': 'rate_limited'} and cache == 'no-store' and
                        retry is not None and retry.isdigit() and 1 <= int(retry) <= 300
                        for status, data, cache, retry in responses)
        record('Six simultaneous attempts forward at most five and throttle the sixth', accepted == 5 and throttled == 1)
        status, data, cache, _ = request('/auth/sign-in', {
            'email': '  ' + email.upper() + '  ', 'password': 'fictional-wrong-password'}, '203.0.113.99')
        record('Case, whitespace and spoofed forwarding cannot reset the bucket',
               status == 429 and data == {'error': 'rate_limited'} and cache == 'no-store')
        status, data, cache, _ = request('/auth/sign-in', {
            'email': 'caliber.qa.limit.other@caliber.invalid', 'password': 'fictional-wrong-password'})
        record('Another identifier retains its own budget', status == 409 and data == {'error': 'request_rejected'} and cache == 'no-store')
    except Exception:
        failure = 'Transport or response contract failed'
    report = {'checkedAt': datetime.now(timezone.utc).isoformat(), 'endpoint': endpoint,
              'results': results, 'passed': failure is None and all(row['passed'] for row in results),
              'failure': failure, 'scope': 'Fictional nonexistent accounts only; no account creation, email or health upload. Do not immediately rerun an exhausted identifier.'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    return int(not report['passed'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    config = json.loads((Path(__file__).resolve().parents[2] /
                         'Caliber (DEV)/Resources/CloudDeployment.json').read_text())
    endpoint = config['projectURL'].rstrip('/') + '/functions/v1/caliber-gateway'
    if not endpoint.startswith('https://'):
        raise ValueError('HTTPS is required')
    raise SystemExit(run(endpoint, config['region'], args.output))
