#!/usr/bin/env python3
"""Generate a private server-only guard and its digest transaction; deploy nothing."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = args.output.resolve()
if output == root or root in output.parents:
    raise SystemExit('Private setup must be outside the repository.')
output.mkdir(parents=True, exist_ok=True, mode=0o700)
credential_path = output / 'private-guard.json'
descriptor = os.open(credential_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
secret = secrets.token_hex(32)
with os.fdopen(descriptor, 'w') as private_file:
    json.dump({'name': 'CALIBER_AUTH_GUARD_SECRET', 'value': secret}, private_file)
    private_file.write('\n')
digest = hashlib.sha256(secret.encode()).hexdigest()
# No reusable secret is in this SQL. Never overwrite an already-enabled configuration.
transaction = f"""BEGIN;
DO $setup$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.caliber_auth_guard WHERE singleton AND NOT enabled) THEN
    RAISE EXCEPTION 'auth_guard_already_configured_or_missing';
  END IF;
  UPDATE public.caliber_auth_guard SET secret_sha256='{digest}',enabled=true WHERE singleton;
END;
$setup$;
COMMIT;
"""
(output / 'configure-digest.sql').write_text(transaction)
del secret
print('Private guard and digest setup prepared outside the repository. No secret printed; nothing deployed.')
