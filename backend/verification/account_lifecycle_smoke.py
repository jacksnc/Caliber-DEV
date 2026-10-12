#!/usr/bin/env python3
"""Verify only a disposable DEV fixture; never accept an arbitrary account target."""
import argparse
import base64
from datetime import datetime, timezone
import getpass
import json
from pathlib import Path
import urllib.error
import urllib.request

EMAIL = 'caliber.qa.lifecycle.20261012@caliber.invalid'
BASE = 'https://tuvbdozxtkcxnojxbvlh.supabase.co/functions/v1/caliber-gateway'
OWNER = '0199c300-1000-7000-8000-000000000001'
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None

def run(password):
    checks = []
    sessions = []
    subject = None
    def check(name, condition):
        checks.append({'criterion': name, 'passed': bool(condition)})
        if not condition:
            raise RuntimeError(name)
    def request(path, body, token=None):
        headers = {'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'x-region': 'us-east-1'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(BASE + path, json.dumps(body).encode(), headers, method='POST')
        try:
            response = urllib.request.build_opener(NoRedirect).open(req, timeout=25)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            status = response.status
            raw = response.read(100000)
        data = json.loads(raw)
        # Error bodies must never be retained or surfaced; only booleans are saved.
        return status, data
    try:
        credentials = {'email': EMAIL, 'password': password, 'consentVersion': 'account-access-v1'}
        status, first = request('/auth/sign-in', credentials)
        check('fixture sign-in with consent', status == 200 and isinstance(first.get('subject'), str))
        sessions.append(first); subject = first['subject']
        status, second = request('/auth/sign-in', credentials)
        check('fixture second session', status == 200 and second.get('subject') == subject)
        sessions.append(second)
        token = first['accessToken']
        status, data = request('/account/consent', {'version': 'account-access-v1'}, token)
        check('authenticated consent confirmation', status == 200 and data == {'accepted': True, 'version': 'account-access-v1'})
        operation = {'operationID':'0199c300-1000-7000-8000-000000000002','ownerID':OWNER,'entityID':'0199c300-1000-7000-8000-000000000003','namespace':'note','deviceID':'0199c300-1000-7000-8000-000000000004','logicalClock':1,'tombstone':False,'payload':base64.b64encode(b'{"text":"Disposable lifecycle fixture"}').decode(),'resolves':[]}
        status, data = request('/sync/push', {'ownerID':OWNER,'operations':[operation]}, token)
        check('synthetic journal created', status == 200 and isinstance(data,list) and len(data)==1)
        status, data = request('/account/delete', {'password':'fictional-wrong-password','confirmation':'DELETE'}, token)
        check('wrong password cannot delete', status == 401 and data == {'error':'unauthorized'})
        status, data = request('/account/delete', {'password':password,'confirmation':'DELETE','subject':'00000000-0000-4000-8000-000000000099'}, token)
        check('caller cannot select deletion target', status == 400)
        status, data = request('/account/delete', {'password':password,'confirmation':'DELETE'}, token)
        check('self-deletion confirmed', status == 200 and data == {'accountDeleted':True})
        for index, session in enumerate(sessions):
            status, data = request('/auth/refresh', {'refreshToken':session['refreshToken']})
            check('deleted session %d cannot refresh' % (index+1), status not in (200,201))
        status, data = request('/account/consent', {'version':'account-access-v1'}, token)
        check('deleted subject cannot create consent with old JWT', status == 401)
        status, data = request('/sync/pull', {'ownerID':OWNER,'after':0,'limit':100}, token)
        check('deleted journal not returned to old JWT', status == 401 or (status == 200 and data.get('changes') == []))
        status, data = request('/auth/sign-in', credentials)
        check('deleted fixture cannot sign in', status != 200)
    except Exception:
        return {'verifiedAt':datetime.now(timezone.utc).isoformat(),'passed':False,'criteria':checks,'fixtureSubject':subject,'scope':'Disposable lifecycle fixture only; no email delivery or personal health data.'}
    finally:
        for session in sessions:
            try:
                request('/auth/sign-out', {}, session.get('accessToken'))
            except Exception:
                pass
    return {'verifiedAt':datetime.now(timezone.utc).isoformat(),'passed':True,'criteria':checks,'fixtureSubject':subject,'scope':'Disposable lifecycle fixture only; no email delivery or personal health data.'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--private-password-file', type=Path)
    args = parser.parse_args()
    if args.private_password_file:
        private = args.private_password_file.resolve()
        repo = Path(__file__).resolve().parents[2]
        if private.is_relative_to(repo) or private.stat().st_mode & 0o077:
            raise SystemExit('Use a mode-0600 credential file outside the repository.')
        password = private.read_text().strip()
    else:
        password = getpass.getpass(EMAIL + ' password (hidden): ')
    result = run(password)
    del password
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('%d lifecycle criteria passed.' % sum(row['passed'] for row in result['criteria']))
    raise SystemExit(0 if result['passed'] else 1)
