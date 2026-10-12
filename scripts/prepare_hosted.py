#!/usr/bin/env python3
"""Prepare reviewable deployment files; never log in or modify a hosted project."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
project = json.loads((ROOT / 'Caliber (DEV)/Resources/CloudDeployment.json').read_text())
handler = (ROOT / 'backend/supabase/functions/caliber-gateway/handler.ts').read_text()
budget = (ROOT / 'backend/supabase/functions/caliber-gateway/auth_budget.ts').read_text()
entry = (ROOT / 'backend/supabase/functions/caliber-gateway/index.ts').read_text()
lifecycle = (ROOT / 'backend/supabase/functions/caliber-gateway/account_lifecycle.ts').read_text()
def strip_imports(source, expected):
    found = re.findall(r'^import [\s\S]*? from "(\./[^"\n]+)";\n', source, re.MULTILINE)
    assert found == expected, 'Review imports before bundling.'
    return re.sub(r'^import [\s\S]*? from "\./[^"\n]+";\n', '', source, flags=re.MULTILINE)
function = '// Generated from tested sources. No credentials are embedded.\n' + budget + '\n' + strip_imports(lifecycle, ['./auth_budget.ts']) + '\n' + strip_imports(handler, ['./auth_budget.ts', './account_lifecycle.ts']) + '\n' + strip_imports(entry, ['./handler.ts', './auth_budget.ts'])
(output / 'index.ts').write_text(function)
migration = (ROOT / 'backend/supabase/migrations/001_foundation.sql').read_text()
(output / 'foundation.sql').write_text('BEGIN;\n' + migration + '\nCOMMIT;\n')
guard_migration = (ROOT / 'backend/supabase/migrations/002_auth_guard.sql').read_text()
(output / 'auth-guard.sql').write_text('BEGIN;\n' + guard_migration + '\nCOMMIT;\n')
guard_repair = (ROOT / 'backend/supabase/migrations/003_auth_guard_route_cleanup.sql').read_text()
(output / 'auth-guard-cleanup.sql').write_text('BEGIN;\n' + guard_repair + '\nCOMMIT;\n')
lifecycle_migration = (ROOT / 'backend/supabase/migrations/004_account_lifecycle.sql').read_text()
(output / 'account-lifecycle.sql').write_text('BEGIN;\n' + lifecycle_migration + '\nCOMMIT;\n')
manifest = {
    'projectURL': project['projectURL'], 'region': project['region'],
    'functionName': 'caliber-gateway', 'verifyJWTAtRelay': False,
    'authentication': 'Supabase Auth verifies sign-in and logout; JWT/auth.uid()/RLS protect sync RPCs.',
    'serverKeys': 'Built-in SUPABASE_URL/SUPABASE_ANON_KEY and private CALIBER_AUTH_GUARD_SECRET. Built-in SUPABASE_SERVICE_ROLE_KEY is server-only and scoped in code to password-reauthenticated self-deletion.',
    'tables': ['caliber_accounts', 'caliber_revisions', 'caliber_auth_guard', 'caliber_auth_buckets', 'caliber_account_consent'],
    'functions': ['caliber_push', 'caliber_pull', 'caliber_auth_budget', 'caliber_accept_account_access'],
    'existingDeployment': 'Check hosted version before applying. Do not reapply already-applied migrations. A fresh project applies foundation.sql, auth-guard.sql, auth-guard-cleanup.sql and account-lifecycle.sql in order, then configures the private guard digest/secret. The approved DEV project already has migrations 001 through 004.',
    'userDataUpload': False, 'status': 'prepared_not_deployed',
    'sha256': {name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in ['index.ts', 'foundation.sql', 'auth-guard.sql', 'auth-guard-cleanup.sql', 'account-lifecycle.sql']},
}
(output / 'deployment.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Prepared tested-source bundle and atomic SQL for review. Nothing deployed.')
