SELECT 'deleted Auth subject absent' AS criterion, NOT EXISTS (SELECT 1 FROM auth.users WHERE id='0767b982-9dc8-45e9-875d-3dc70f823c10') AS passed
UNION ALL SELECT 'deleted journal owner absent', NOT EXISTS (SELECT 1 FROM public.caliber_accounts WHERE subject='0767b982-9dc8-45e9-875d-3dc70f823c10')
UNION ALL SELECT 'deleted journal revisions absent', NOT EXISTS (SELECT 1 FROM public.caliber_revisions WHERE subject='0767b982-9dc8-45e9-875d-3dc70f823c10')
UNION ALL SELECT 'deleted consent absent', NOT EXISTS (SELECT 1 FROM public.caliber_account_consent WHERE subject='0767b982-9dc8-45e9-875d-3dc70f823c10')
UNION ALL SELECT 'four earlier QA accounts preserved', (SELECT count(*)=4 FROM auth.users WHERE id IN ('e0b46ff1-8b32-4c17-94b6-8b4af994bb92','bde0e17b-7f40-41b3-9e24-63bb8a6352c4','09b97dc8-89a3-4ab3-bdf0-65374b112f49','4e4df684-8536-48a9-978b-42ad982774fe'));
