#!/usr/bin/env python3
"""Check the deployed gateway's rejection paths without keys or real accounts."""
import argparse
import base64
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def encoded(value):
    return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads((Path(__file__).resolve().parents[2] /
                         'Caliber (DEV)/Resources/CloudDeployment.json').read_text())
    endpoint = config['projectURL'].rstrip('/') + '/functions/v1/caliber-gateway'
    if not endpoint.startswith('https://'):
        raise ValueError('HTTPS is required')
    owner = '018f0000-0000-7000-8000-000000000011'
    pull = {'ownerID': owner, 'after': 0, 'limit': 100}
    # Deliberately invalid signature. This is not an authentication credential.
    forged = '.'.join([encoded({'alg': 'HS256', 'typ': 'JWT'}), encoded({
        'sub': '00000000-0000-4000-8000-000000000001', 'role': 'authenticated',
        'session_id': '00000000-0000-4000-8000-000000000099', 'exp': 4102444800,
    }), encoded('deliberately-invalid-signature')])
    cases = [
        ('GET denied', '', None, None, 405, 'method_not_allowed'),
        ('unknown route', '/unknown/path', {}, None, 404, 'not_found'),
        ('malformed JSON', '/auth/sign-in', b'{', None, 400, 'request_failed'),
        ('array body', '/auth/sign-in', [], None, 400, 'invalid_request'),
        ('invalid sign-in fields', '/auth/sign-in', {'email': 1}, None, 400, 'invalid_request'),
        ('missing pull token', '/sync/pull', pull, None, 401, 'unauthorized'),
        ('missing push token', '/sync/push', {'ownerID': owner, 'operations': []}, None, 401, 'unauthorized'),
        ('missing logout token', '/auth/sign-out', {}, None, 401, 'unauthorized'),
        ('forged pull token', '/sync/pull', pull, forged, 401, 'unauthorized'),
        ('forged logout token', '/auth/sign-out', {}, forged, 401, 'unauthorized'),
        ('invalid refresh token', '/auth/refresh', {'refreshToken': 'fictional-invalid-refresh'}, None, 409, 'request_rejected'),
    ]
    opener = build_opener(NoRedirect)
    results = []
    for name, path, body, token, expected_status, expected_error in cases:
        headers = {'Content-Type': 'application/json', 'x-region': config['region']}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        data = body if isinstance(body, bytes) else (None if body is None else json.dumps(body).encode())
        request = Request(endpoint + path, data=data, headers=headers, method='GET' if body is None else 'POST')
        try:
            response = opener.open(request, timeout=25)
        except HTTPError as error:
            response = error
        # Never retain arbitrary provider bodies; evidence contains a boolean only.
        with response:
            raw = response.read(4096)
            try:
                matches = json.loads(raw) == {'error': expected_error}
            except (ValueError, UnicodeError):
                matches = False
            status = response.code
            no_store = response.headers.get('Cache-Control') == 'no-store'
            passed = status == expected_status and matches and no_store
        results.append({'criterion': name, 'status': status, 'expectedStatus': expected_status,
                        'sanitizedBodyMatches': matches, 'noStore': no_store, 'passed': passed})
        print(name, 'PASS' if passed else 'FAIL', status)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'checkedAt': datetime.now(timezone.utc).isoformat(),
                                      'endpoint': endpoint, 'regionRequested': config['region'],
                                      'results': results}, indent=2) + '\n')
    return int(any(not row['passed'] for row in results))


if __name__ == '__main__':
    raise SystemExit(main())
