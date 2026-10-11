#!/usr/bin/env python3
"""Prepare reviewable deployment files; never log in or modify a hosted project."""
import argparse
import hashlib
import json
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
expected_import = 'import { gateway } from "./handler.ts";\nimport { DatabaseAuthBudget, unavailableAuthBudget } from "./auth_budget.ts";\n'
handler_import = 'import { type AuthBudget, unavailableAuthBudget } from "./auth_budget.ts";\n'
assert entry.startswith(expected_import) and handler.startswith(handler_import), 'Review imports before bundling.'
function = '// Generated from tested sources. No credentials are embedded.\n' + budget + '\n' + handler.removeprefix(handler_import) + '\n' + entry.removeprefix(expected_import)
(output / 'index.ts').write_text(function)
migration = (ROOT / 'backend/supabase/migrations/001_foundation.sql').read_text()
(output / 'foundation.sql').write_text('BEGIN;\n' + migration + '\nCOMMIT;\n')
guard_migration = (ROOT / 'backend/supabase/migrations/002_auth_guard.sql').read_text()
(output / 'auth-guard.sql').write_text('BEGIN;\n' + guard_migration + '\nCOMMIT;\n')
guard_repair = (ROOT / 'backend/supabase/migrations/003_auth_guard_route_cleanup.sql').read_text()
(output / 'auth-guard-cleanup.sql').write_text('BEGIN;\n' + guard_repair + '\nCOMMIT;\n')
manifest = {
    'projectURL': project['projectURL'], 'region': project['region'],
    'functionName': 'caliber-gateway', 'verifyJWTAtRelay': False,
    'authentication': 'Supabase Auth verifies sign-in and logout; JWT/auth.uid()/RLS protect sync RPCs.',
    'serverKeys': 'Built-in SUPABASE_URL/SUPABASE_ANON_KEY and private CALIBER_AUTH_GUARD_SECRET. No service-role key.',
    'tables': ['caliber_accounts', 'caliber_revisions', 'caliber_auth_guard', 'caliber_auth_buckets'],
    'functions': ['caliber_push', 'caliber_pull', 'caliber_auth_budget'],
    'existingDeployment': 'Check hosted version before applying. Do not reapply already-applied migrations. Fresh guard setup applies auth-guard.sql then auth-guard-cleanup.sql and configures the private digest/secret.',
    'userDataUpload': False, 'status': 'prepared_not_deployed',
    'sha256': {name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in ['index.ts', 'foundation.sql', 'auth-guard.sql', 'auth-guard-cleanup.sql']},
}
(output / 'deployment.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Prepared tested-source bundle and atomic SQL for review. Nothing deployed.')
