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
entry = (ROOT / 'backend/supabase/functions/caliber-gateway/index.ts').read_text()
expected_import = 'import { gateway } from "./handler.ts";\n'
assert entry.startswith(expected_import), 'Review the gateway entry point before bundling.'
function = '// Generated from the tested handler and entry point. No credentials are embedded.\n' + handler + '\n' + entry.removeprefix(expected_import)
(output / 'index.ts').write_text(function)
migration = (ROOT / 'backend/supabase/migrations/001_foundation.sql').read_text()
(output / 'foundation.sql').write_text('BEGIN;\n' + migration + '\nCOMMIT;\n')
manifest = {
    'projectURL': project['projectURL'], 'region': project['region'],
    'functionName': 'caliber-gateway', 'verifyJWTAtRelay': False,
    'authentication': 'Supabase Auth verifies sign-in and logout; JWT/auth.uid()/RLS protect sync RPCs.',
    'serverKeys': 'Built-in SUPABASE_URL and SUPABASE_ANON_KEY only. No service-role key used.',
    'tables': ['caliber_accounts', 'caliber_revisions'],
    'functions': ['caliber_push', 'caliber_pull'],
    'userDataUpload': False, 'status': 'prepared_not_deployed',
    'sha256': {name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in ['index.ts', 'foundation.sql']},
}
(output / 'deployment.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Prepared tested-source bundle and atomic SQL for review. Nothing deployed.')
