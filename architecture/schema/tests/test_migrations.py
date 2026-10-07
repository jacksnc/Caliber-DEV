#!/usr/bin/env python3
"""Executable stdlib-only migration/constraint tests. All databases use TemporaryDirectory."""
from pathlib import Path
import json
import shutil
import sqlite3
import tempfile
import time
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
STAMP=1_700_000_000_000
DAY='2023-11-14'

def uuid7():
    bits=(int(time.time()*1000)<<80) | (7<<76) | ((uuid.uuid4().int & ((1<<76)-1)))
    bits=(bits & ~(3<<62)) | (2<<62)
    return str(uuid.UUID(int=bits))

class SchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=tempfile.TemporaryDirectory(prefix='caliber-schema-base-')
        for name in ('core','stack'):
            conn=sqlite3.connect(str(Path(cls.base.name)/(name+'.sqlite')))
            conn.executescript((ROOT/name/'001_v1.up.sql').read_text())
            conn.execute('PRAGMA wal_checkpoint(TRUNCATE)')
            conn.close()
        cls.manifest=json.loads((ROOT/'TABLES.json').read_text())

    @classmethod
    def tearDownClass(cls): cls.base.cleanup()

    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='caliber-schema-test-')
        self.db={}
        for name in ('core','stack'):
            path=Path(self.tmp.name)/(name+'.sqlite')
            shutil.copy2(Path(self.base.name)/(name+'.sqlite'),path)
            c=sqlite3.connect(str(path),isolation_level=None)
            c.row_factory=sqlite3.Row
            c.execute('PRAGMA foreign_keys=ON')
            c.execute('PRAGMA recursive_triggers=ON')
            self.db[name]=c

    def tearDown(self):
        for c in self.db.values(): c.close()
        self.tmp.cleanup()

    def insert(self,db,table,account=None,**values):
        row=dict(id=uuid7(),created_at=STAMP,updated_at=STAMP,source='manual')
        if table!='accounts': row['account_id']=account
        row.update(values)
        keys=list(row)
        self.db[db].execute(f"INSERT INTO {table}({','.join(keys)}) VALUES({','.join('?' for _ in keys)})",[row[k] for k in keys])
        return row['id']

    def account(self,db='core',**kw): return self.insert(db,'accounts',**kw)
    def device(self,db,account): return self.insert(db,'devices',account,label='Test device',platform='test')
    def timed(self,**kw): return dict(occurred_at=STAMP,tz='America/New_York',local_date=DAY,**kw)

    def train(self):
        a=self.account(); d=self.device('core',a)
        exercise=self.insert('core','exercises',a,name='Synthetic press',normalized_name='synthetic press',movement_pattern='push',mechanics='compound',metric_type='weight_reps')
        typ=self.insert('core','set_types',a,name='Working',glyph='circle',color_token='train',counts_volume=1,counts_hard_sets=1,counts_pr=1)
        workout=self.insert('core','workouts',a,status='active',**self.timed())
        we=self.insert('core','workout_exercises',a,workout_id=workout,exercise_id=exercise,position=0)
        st=self.insert('core','workout_sets',a,workout_exercise_id=we,position=0)
        return a,d,exercise,typ,workout,we,st

    def revision(self,a,d,typ,st,**extra):
        values=dict(set_id=st,writer_device_id=d,action='upsert',set_type_id=typ,load_kg=100,reps=5,entered_load_value='100',entered_load_unit='kg',logical_clock=1,**self.timed())
        values.update(extra)
        return self.insert('core','set_revisions',a,**values)

    def stack_fixture(self):
        a=self.account('stack'); d=self.device('stack',a)
        compound=self.insert('stack','compounds',a,name='Synthetic item',dosage_form='vial',default_dimension='mass')
        vial=self.insert('stack','vials',a,label='Synthetic container',form='vial',lifecycle='sealed')
        log=self.insert('stack','dose_logs',a,compound_id=compound)
        return a,d,compound,vial,log

    def dose_revision(self,a,d,log,**extra):
        values=dict(dose_log_id=log,writer_device_id=d,action='upsert',amount_value=250,amount_unit='ug',amount_scale=0,entered_value='0.25',entered_unit='mg',route='user-entered',user_confirmed_at=STAMP,logical_clock=1,**self.timed())
        values.update(extra)
        return self.insert('stack','dose_revisions',a,**values)

    def ledger(self,a,d,compound,vial,value=1000,**extra):
        values=dict(vial_id=vial,compound_id=compound,transaction_id=uuid7(),movement='opening',amount_value=value,amount_unit='ug',amount_scale=0,entered_value=str(value),entered_unit='ug',writer_device_id=d,**self.timed())
        values.update(extra)
        return self.insert('stack','inventory_ledger',a,**values)

    def target(self,a,**extra):
        values=dict(goal_mode='maintain',calories_kcal=2000,protein_g=100,carbs_g=250,fat_g=60,safety_floor_kcal=1500,method_version='test-v1',valid_from=DAY)
        values.update(extra)
        return self.insert('core','nutrition_targets',a,**values)

    def test_01_up_down_up_empty_stores(self):
        for name,c in self.db.items():
            self.assertEqual(c.execute('PRAGMA user_version').fetchone()[0],1)
            c.executescript((ROOT/name/'001_v1.down.sql').read_text())
            self.assertEqual(c.execute("SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").fetchone()[0],0)
            c.executescript((ROOT/name/'001_v1.up.sql').read_text())
            self.assertEqual(c.execute('PRAGMA integrity_check').fetchone()[0],'ok')
            self.assertEqual(c.execute('PRAGMA foreign_key_check').fetchall(),[])

    def test_02_down_refuses_populated_store(self):
        for name,c in self.db.items():
            account=self.account(name)
            with self.assertRaisesRegex(sqlite3.IntegrityError,'Refusing downgrade'):
                c.executescript((ROOT/name/'001_v1.down.sql').read_text())
            if c.in_transaction: c.rollback()
            self.assertEqual(c.execute('PRAGMA foreign_keys').fetchone()[0],1)
            self.assertEqual(c.execute('SELECT id FROM accounts').fetchone()[0],account)

    def test_03_every_table_has_metadata_ownership_and_strict_types(self):
        for name,c in self.db.items():
            for table in self.manifest[name]:
                cols={r['name'] for r in c.execute(f"PRAGMA table_info({table['name']})")}
                self.assertTrue({'id','created_at','updated_at','deleted_at','source','logical_clock'}.issubset(cols))
                if table['name']!='accounts': self.assertIn('account_id',cols)
                sql=c.execute('SELECT sql FROM sqlite_master WHERE name=?',(table['name'],)).fetchone()[0]
                self.assertTrue(sql.endswith('STRICT'))
                self.assertNotIn('ON DELETE CASCADE',sql)

    def test_04_uuid_format_version_and_variant_are_enforced(self):
        for name in self.db:
            for bad in ('not-an-id',str(uuid.uuid4()),uuid7().upper(),'00000000-0000-7000-0000-000000000000','00000000-0000-7000-8000-00000000000z'):
                with self.subTest(name=name,bad=bad):
                    with self.assertRaises(sqlite3.IntegrityError): self.account(name,id=bad)
            self.account(name,id=uuid7())

    def test_05_cross_account_references_are_rejected(self):
        a=self.account(); b=self.account()
        muscle=self.insert('core','muscles',b,code='synthetic',display_name='Synthetic',svg_region_key='test')
        with self.assertRaises(sqlite3.IntegrityError):
            self.insert('core','muscle_targets',a,muscle_id=muscle,valid_from=DAY,min_sets=1,max_sets=2,method_label='user')
        sa,_,compound,_,_=self.stack_fixture(); sb=self.account('stack')
        with self.assertRaises(sqlite3.IntegrityError): self.insert('stack','dose_logs',sb,compound_id=compound)

    def test_06_identity_and_ownership_cannot_be_reassigned(self):
        a=self.account(); b=self.account()
        w=self.insert('core','weigh_ins',a,weight_kg=60,entered_value='60',entered_unit='kg',**self.timed())
        with self.assertRaises(sqlite3.IntegrityError): self.db['core'].execute('UPDATE weigh_ins SET account_id=?,logical_clock=1 WHERE id=?',(b,w))
        with self.assertRaises(sqlite3.IntegrityError): self.db['core'].execute('UPDATE weigh_ins SET id=?,logical_clock=1 WHERE id=?',(uuid7(),w))

    def test_07_utc_timestamp_retains_logging_timezone_and_local_day(self):
        a=self.account(); occurred=1_700_002_800_000
        w=self.insert('core','weigh_ins',a,weight_kg=61.23496995,entered_value='135',entered_unit='lb',occurred_at=occurred,tz='America/Los_Angeles',local_date=DAY)
        row=self.db['core'].execute('SELECT * FROM weigh_ins WHERE id=?',(w,)).fetchone()
        self.assertEqual(row['entered_value'],'135');self.assertEqual(row['entered_unit'],'lb');self.assertEqual(row['local_date'],DAY);self.assertEqual(row['occurred_at'],occurred)
        for day in ('2023-02-30','2023-13-01','bad'):
            with self.assertRaises(sqlite3.IntegrityError): self.insert('core','weigh_ins',a,weight_kg=60,entered_value='60',entered_unit='kg',occurred_at=occurred,tz='UTC',local_date=day)

    def test_08_mutation_and_outbox_commit_or_rollback_together(self):
        a=self.account();c=self.db['core']; before=c.execute('SELECT count(*) FROM sync_outbox').fetchone()[0]
        c.execute('BEGIN IMMEDIATE')
        self.insert('core','weigh_ins',a,weight_kg=60,entered_value='60',entered_unit='kg',**self.timed())
        self.assertEqual(c.execute('SELECT count(*) FROM sync_outbox').fetchone()[0],before+1)
        c.rollback()
        self.assertEqual(c.execute('SELECT count(*) FROM weigh_ins').fetchone()[0],0)
        self.assertEqual(c.execute('SELECT count(*) FROM sync_outbox').fetchone()[0],before)

    def test_09_outbox_payload_and_tombstone_are_preserved(self):
        a=self.account();c=self.db['core']
        w=self.insert('core','weigh_ins',a,weight_kg=60,entered_value='132.277357',entered_unit='lb',**self.timed())
        c.execute('UPDATE weigh_ins SET deleted_at=?,updated_at=?,logical_clock=1 WHERE id=?',(STAMP+1,STAMP+1,w))
        rows=c.execute("SELECT operation,payload_json FROM sync_outbox WHERE entity_table='weigh_ins' ORDER BY rowid").fetchall()
        self.assertEqual([r[0] for r in rows],['upsert','tombstone'])
        self.assertEqual(json.loads(rows[0][1])['entered_value'],'132.277357')
        self.assertEqual(json.loads(rows[1][1])['deleted_at'],STAMP+1)
        self.assertEqual(c.execute('SELECT count(*) FROM body_daily_raw').fetchone()[0],0)

    def test_10_logical_clock_prevents_stale_replacement(self):
        a=self.account(); c=self.db['core']
        with self.assertRaises(sqlite3.IntegrityError): c.execute('UPDATE accounts SET region=? WHERE id=?',('US',a))
        c.execute('UPDATE accounts SET region=?,logical_clock=1 WHERE id=?',('US',a))
        with self.assertRaises(sqlite3.IntegrityError): c.execute('UPDATE accounts SET region=?,logical_clock=1 WHERE id=?',('EU',a))

    def test_11_conflict_keeps_both_candidates(self):
        a=self.account(); entity=uuid7()
        conflict=self.insert('core','sync_conflicts',a,entity_table='weigh_ins',entity_id=entity,local_payload_json='{"weight_kg":60}',remote_payload_json='{"weight_kg":61}')
        self.db['core'].execute("UPDATE sync_conflicts SET resolution='keep_both',resolved_at=? WHERE id=?",(STAMP+1,conflict))
        row=self.db['core'].execute('SELECT * FROM sync_conflicts WHERE id=?',(conflict,)).fetchone()
        self.assertEqual(json.loads(row['local_payload_json'])['weight_kg'],60)
        self.assertEqual(json.loads(row['remote_payload_json'])['weight_kg'],61)

    def test_12_cursor_rolls_back_with_failed_pull(self):
        a=self.account();c=self.db['core']
        cursor=self.insert('core','sync_cursors',a,stream='main',cursor='old')
        c.execute('BEGIN')
        c.execute("UPDATE sync_cursors SET cursor='new' WHERE id=?",(cursor,))
        try:
            self.insert('core','weigh_ins',a,weight_kg=-1,entered_value='-1',entered_unit='kg',**self.timed())
        except sqlite3.IntegrityError: c.rollback()
        self.assertEqual(c.execute('SELECT cursor FROM sync_cursors WHERE id=?',(cursor,)).fetchone()[0],'old')

    def test_13_sets_are_append_only_including_replace(self):
        a,d,_,typ,_,_,st=self.train(); rev=self.revision(a,d,typ,st);c=self.db['core']
        with self.assertRaises(sqlite3.IntegrityError): c.execute('UPDATE set_revisions SET reps=6 WHERE id=?',(rev,))
        with self.assertRaises(sqlite3.IntegrityError): c.execute('DELETE FROM set_revisions WHERE id=?',(rev,))
        row=dict(c.execute('SELECT * FROM set_revisions WHERE id=?',(rev,)).fetchone()); keys=list(row)
        with self.assertRaises(sqlite3.IntegrityError): c.execute(f"INSERT OR REPLACE INTO set_revisions({','.join(keys)}) VALUES({','.join('?' for _ in keys)})",list(row.values()))

    def test_14_set_branches_preserved_and_head_selected_explicitly(self):
        a,d,_,typ,_,_,st=self.train();c=self.db['core']
        first=self.revision(a,d,typ,st)
        left=self.revision(a,d,typ,st,parent_revision_id=first,logical_clock=2,reps=6)
        right=self.revision(a,d,typ,st,parent_revision_id=first,logical_clock=2,reps=7)
        c.execute('UPDATE workout_sets SET current_revision_id=?,logical_clock=1 WHERE id=?',(left,st))
        self.assertEqual(c.execute('SELECT reps FROM current_workout_sets').fetchone()[0],6)
        self.assertEqual(c.execute('SELECT count(*) FROM set_revisions').fetchone()[0],3)
        c.execute('UPDATE workout_sets SET current_revision_id=?,logical_clock=2 WHERE id=?',(right,st))
        self.assertEqual(c.execute('SELECT reps FROM current_workout_sets').fetchone()[0],7)

    def test_15_revision_parent_and_head_must_match_log(self):
        a,d,_,typ,_,we,st=self.train();c=self.db['core'];first=self.revision(a,d,typ,st)
        other=self.insert('core','workout_sets',a,workout_exercise_id=we,position=1)
        with self.assertRaises(sqlite3.IntegrityError): self.revision(a,d,typ,other,parent_revision_id=first,logical_clock=2)
        with self.assertRaises(sqlite3.IntegrityError): c.execute('UPDATE workout_sets SET current_revision_id=?,logical_clock=1 WHERE id=?',(first,other))
        with self.assertRaises(sqlite3.IntegrityError): self.revision(a,d,typ,st,parent_revision_id=first,logical_clock=1)

    def test_16_set_tombstone_and_undo_keep_original_revision(self):
        a,d,_,typ,_,_,st=self.train();c=self.db['core'];first=self.revision(a,d,typ,st)
        deleted=self.revision(a,d,typ,st,parent_revision_id=first,logical_clock=2,action='tombstone',deleted_at=STAMP)
        c.execute('UPDATE workout_sets SET current_revision_id=?,logical_clock=1 WHERE id=?',(deleted,st))
        self.assertEqual(c.execute('SELECT count(*) FROM current_workout_sets').fetchone()[0],0)
        restored=self.revision(a,d,typ,st,parent_revision_id=deleted,logical_clock=3,action='restore')
        c.execute('UPDATE workout_sets SET current_revision_id=?,logical_clock=2 WHERE id=?',(restored,st))
        self.assertEqual(c.execute('SELECT count(*) FROM current_workout_sets').fetchone()[0],1)
        self.assertEqual(c.execute('SELECT count(*) FROM set_revisions').fetchone()[0],3)

    def test_17_dose_fixed_point_units_and_no_float_storage(self):
        a,d,_,_,log=self.stack_fixture()
        for extra in (dict(amount_value=1.5),dict(amount_unit='mg'),dict(amount_unit='IU',amount_scale=0),dict(amount_unit='uL',amount_scale=6),dict(amount_value=-1)):
            with self.subTest(extra=extra):
                with self.assertRaises(sqlite3.IntegrityError): self.dose_revision(a,d,log,**extra)
        rev=self.dose_revision(a,d,log,amount_value=2_500_000,amount_unit='IU',amount_scale=6,entered_value='2.5',entered_unit='IU')
        row=self.db['stack'].execute('SELECT amount_value,amount_scale,typeof(amount_value) FROM dose_revisions WHERE id=?',(rev,)).fetchone()
        self.assertEqual(tuple(row),(2_500_000,6,'integer'))

    def test_18_dose_audit_immutable_and_separate_from_core(self):
        a,d,_,_,log=self.stack_fixture();rev=self.dose_revision(a,d,log);c=self.db['stack']
        with self.assertRaises(sqlite3.IntegrityError): c.execute('UPDATE dose_revisions SET amount_value=500 WHERE id=?',(rev,))
        with self.assertRaises(sqlite3.IntegrityError): c.execute('DELETE FROM dose_logs WHERE id=?',(log,))
        self.assertEqual(self.db['core'].execute('SELECT count(*) FROM sync_outbox').fetchone()[0],0)
        self.assertEqual(self.db['core'].execute('SELECT count(*) FROM events').fetchone()[0],0)
        self.assertEqual(self.db['core'].execute('SELECT count(*) FROM daily_rollups').fetchone()[0],0)

    def test_19_inventory_reversal_is_exact_immutable_and_idempotent(self):
        a,d,compound,vial,_=self.stack_fixture();c=self.db['stack']
        self.ledger(a,d,compound,vial)
        used=self.ledger(a,d,compound,vial,value=-250,movement='dose')
        self.assertEqual(c.execute('SELECT remaining_coefficient FROM inventory_balances').fetchone()[0],750)
        with self.assertRaises(sqlite3.IntegrityError): self.ledger(a,d,compound,vial,value=249,movement='reversal',reverses_entry_id=used)
        self.ledger(a,d,compound,vial,value=250,movement='reversal',reverses_entry_id=used)
        self.assertEqual(c.execute('SELECT remaining_coefficient FROM inventory_balances').fetchone()[0],1000)
        with self.assertRaises(sqlite3.IntegrityError): self.ledger(a,d,compound,vial,value=250,movement='reversal',reverses_entry_id=used)
        with self.assertRaises(sqlite3.IntegrityError): c.execute('UPDATE inventory_ledger SET amount_value=-100 WHERE id=?',(used,))

    def test_20_inventory_dimensions_never_mix_mass_and_activity(self):
        a,d,compound,vial,_=self.stack_fixture();c=self.db['stack']
        self.ledger(a,d,compound,vial,value=1000)
        self.ledger(a,d,compound,vial,value=2_000_000,amount_unit='IU',amount_scale=6,entered_value='2',entered_unit='IU')
        rows=c.execute('SELECT amount_unit,remaining_coefficient FROM inventory_balances ORDER BY amount_unit').fetchall()
        self.assertEqual([tuple(r) for r in rows],[('IU',2_000_000),('ug',1000)])
        with self.assertRaises(sqlite3.IntegrityError): self.ledger(a,d,compound,vial,value=20,amount_unit='mg')

    def test_21_atomic_dose_inventory_and_outbox(self):
        a,d,compound,vial,log=self.stack_fixture();c=self.db['stack'];before=c.execute('SELECT count(*) FROM sync_outbox').fetchone()[0]
        c.execute('BEGIN IMMEDIATE')
        rev=self.dose_revision(a,d,log)
        c.execute('UPDATE dose_logs SET current_revision_id=?,logical_clock=1 WHERE id=?',(rev,log))
        self.ledger(a,d,compound,vial,value=-250,movement='dose',dose_revision_id=rev)
        c.rollback()
        self.assertEqual(c.execute('SELECT count(*) FROM current_doses').fetchone()[0],0)
        self.assertEqual(c.execute('SELECT count(*) FROM inventory_ledger').fetchone()[0],0)
        self.assertEqual(c.execute('SELECT count(*) FROM sync_outbox').fetchone()[0],before)

    def test_22_no_clinical_seed_rows(self):
        for table in ('compounds','compound_references','protocols','protocol_steps','syringes','calculator_presets','vials','dose_logs'):
            self.assertEqual(self.db['stack'].execute(f'SELECT count(*) FROM {table}').fetchone()[0],0)
        self.assertNotIn('recommended_dose',(ROOT/'stack'/'001_v1.up.sql').read_text())

    def test_23_core_registry_rejects_stack_domain(self):
        a=self.account()
        with self.assertRaises(sqlite3.IntegrityError): self.insert('core','series_registry',a,metric_key='dose',domain='stack',unit='ug',kind='daily',aggregation='sum',value_storage='fixed',color_token='stack',source_query_key='private',method_version='1')
        self.assertFalse(any(r['name']=='dose_logs' for r in self.db['core'].execute("SELECT name FROM sqlite_master WHERE type='table'")))
        for db,c in self.db.items():
            names={t['name'] for t in self.manifest[db]}
            for table in names:
                for fk in c.execute(f'PRAGMA foreign_key_list({table})'): self.assertIn(fk['table'],names)

    def test_24_attachment_owner_must_be_same_store_and_account(self):
        a=self.account();b=self.account();note=self.insert('core','notes',b,text='Synthetic note',**self.timed())
        kw=dict(owner_table='notes',owner_id=note,local_locator='private/synthetic.jpg',media_type='image/jpeg',byte_count=12,sha256='0'*64)
        with self.assertRaises(sqlite3.IntegrityError): self.insert('core','attachments',a,**kw)
        self.insert('core','attachments',b,**kw)
        with self.assertRaises(sqlite3.IntegrityError): self.insert('core','attachments',a,**(kw|dict(owner_table='dose_logs',owner_id=uuid7())))

    def test_25_target_floor_override_requires_explicit_valid_ack(self):
        a=self.account(bmr_sex='male')
        with self.assertRaises(sqlite3.IntegrityError): self.target(a,calories_kcal=900)
        with self.assertRaises(sqlite3.IntegrityError): self.target(a,calories_kcal=1400,safety_floor_kcal=1200)
        ack=self.insert('core','safety_acknowledgements',a,kind='clinician_floor_override',policy_version='test',acknowledgement_text='Synthetic explicit acknowledgement',clinician_override_confirmed=1,**self.timed())
        self.target(a,calories_kcal=900,clinician_ack_id=ack)
        bad_ack=self.insert('core','safety_acknowledgements',a,kind='risk_resources_shown',policy_version='test',acknowledgement_text='Synthetic informational acknowledgement',**self.timed())
        with self.assertRaises(sqlite3.IntegrityError): self.target(a,calories_kcal=900,clinician_ack_id=bad_ack)

    def test_26_bmi_and_rate_safety_constraints(self):
        a=self.account(bmr_sex='female')
        with self.assertRaises(sqlite3.IntegrityError): self.target(a,goal_mode='cut',assessed_bmi=18.4)
        with self.assertRaises(sqlite3.IntegrityError): self.target(a,goal_mode='cut')
        with self.assertRaises(sqlite3.IntegrityError): self.target(a,weekly_loss_fraction=.011)
        self.target(a,goal_mode='cut',assessed_bmi=23,weekly_loss_fraction=.01,calories_kcal=1200,safety_floor_kcal=1200)

    def test_27_nutrition_snapshots_aggregate_by_local_day_and_ignore_plan(self):
        a=self.account();slot=self.insert('core','meal_slots',a,name='Lunch',position=1)
        eaten=self.insert('core','meal_logs',a,meal_slot_id=slot,state='eaten',**self.timed())
        planned=self.insert('core','meal_logs',a,meal_slot_id=slot,state='planned',**self.timed())
        for meal,cal in ((eaten,100),(eaten,200),(planned,900)):
            self.insert('core','food_logs',a,meal_log_id=meal,food_name='Synthetic',grams=100,entered_value='1',entered_unit='serving',calories_kcal=cal,protein_g=10,carbs_g=10,fat_g=2,confirmed_at=STAMP,**self.timed())
        row=self.db['core'].execute('SELECT * FROM nutrition_daily_raw').fetchone()
        self.assertEqual(row['calories_kcal'],300);self.assertEqual(row['sample_count'],2);self.assertEqual(row['local_date'],DAY)

    def test_28_recipe_yield_must_match_raw_and_cooked_mass(self):
        a=self.account();src=self.insert('core','food_sources',a,name='Synthetic',source_kind='user',license_identifier='private',attribution='User')
        food=self.insert('core','foods',a,name='Recipe',normalized_name='recipe',source_id=src,quality_rank=0)
        self.insert('core','recipes',a,food_id=food,name='Synthetic recipe',servings=2,raw_mass_g=200,cooked_mass_g=150,yield_factor=.75)
        with self.assertRaises(sqlite3.IntegrityError): self.insert('core','recipes',a,food_id=food,name='Bad yield',servings=2,raw_mass_g=200,cooked_mass_g=150,yield_factor=1)

    def test_29_measurement_dimension_guard(self):
        a=self.account()
        self.insert('core','measurements',a,kind='circumference',landmark='waist',value=80,canonical_unit='cm',entered_value='80',entered_unit='cm',method='tape',**self.timed())
        with self.assertRaises(sqlite3.IntegrityError): self.insert('core','measurements',a,kind='circumference',landmark='waist',value=80,canonical_unit='kg',entered_value='80',entered_unit='kg',method='tape',**self.timed())

    def test_30_health_identity_deduplicates_without_losing_entered_weight(self):
        a=self.account();kw=dict(provider='health',external_key='sample-1',sample_type='steps',value=5000,unit='count',**self.timed())
        self.insert('core','health_samples',a,**kw)
        with self.assertRaises(sqlite3.IntegrityError): self.insert('core','health_samples',a,**kw)

    def test_31_account_delete_deadline_is_zero_to_thirty_days(self):
        for due in (STAMP-1,STAMP+2592000001):
            with self.assertRaises(sqlite3.IntegrityError): self.account(deletion_requested_at=STAMP,deletion_due_at=due)
        self.account(deletion_requested_at=STAMP,deletion_due_at=STAMP+2592000000)

    def test_32_daily_rollup_upsert_is_idempotent_and_missing_stays_missing(self):
        a=self.account();c=self.db['core']
        series=self.insert('core','series_registry',a,metric_key='body.weight',domain='body',unit='kg',kind='daily',aggregation='mean',value_storage='real',color_token='body',source_query_key='body_daily_raw',method_version='1')
        r=self.insert('core','daily_rollups',a,series_id=series,local_date=DAY,sample_count=0,expected_count=1,coverage=0,input_digest='empty',method_version='1',rebuilt_at=STAMP)
        for value in (60,60):
            c.execute('UPDATE daily_rollups SET real_value=?,sample_count=1,coverage=1,input_digest=? WHERE id=?',(value,'same-input',r))
        self.assertEqual(c.execute('SELECT count(*) FROM daily_rollups').fetchone()[0],1)
        self.assertEqual(c.execute('SELECT real_value FROM daily_rollups').fetchone()[0],60)
        self.insert('core','daily_rollups',a,series_id=series,local_date='2023-11-15',sample_count=0,coverage=0,input_digest='missing',method_version='1',rebuilt_at=STAMP)
        self.assertIsNone(c.execute("SELECT real_value FROM daily_rollups WHERE local_date='2023-11-15'").fetchone()[0])

    def test_33_program_day_foreign_key_is_concrete(self):
        a=self.account();program=self.insert('core','programs',a,name='User programme')
        day=self.insert('core','program_days',a,program_id=program,week_number=1,day_number=1,position=0,name='Day one')
        self.insert('core','workouts',a,status='active',program_day_id=day,start_origin='program',**self.timed())

    def test_34_legacy_identity_mapping_preserves_original_without_uuid4_rewrite(self):
        a=self.account();batch=self.insert('core','import_batches',a,format='swiftdata-shadow',file_digest='synthetic',status='planned')
        original=str(uuid.uuid4());new=uuid7()
        self.insert('core','legacy_id_map',a,batch_id=batch,source_entity='WeightEntry',legacy_identifier=original,destination_table='weigh_ins',destination_id=new)
        row=self.db['core'].execute('SELECT legacy_identifier,destination_id FROM legacy_id_map').fetchone()
        self.assertEqual(tuple(row),(original,new))

    def test_35_every_foreign_key_and_integrity_check_is_clean(self):
        self.train();self.stack_fixture()
        for c in self.db.values():
            self.assertEqual(c.execute('PRAGMA foreign_key_check').fetchall(),[])
            self.assertEqual(c.execute('PRAGMA integrity_check').fetchone()[0],'ok')

    def test_36_low_bmi_cannot_hide_deficit_in_another_mode(self):
        a=self.account(bmr_sex='female')
        for mode in ('maintain','recomp','refeed','diet_break','lean_bulk','bulk'):
            with self.assertRaises(sqlite3.IntegrityError):
                self.target(a,goal_mode=mode,assessed_bmi=17,weekly_loss_fraction=.005)

    def test_37_pen_requires_all_calibration_dimensions(self):
        a=self.account('stack')
        base=dict(name='Synthetic pen',kind='pen',label_confirmation_at=STAMP,citation_or_label='Fixture only',per_click_value=1)
        for kw in ({},dict(per_click_unit='ug'),dict(per_click_scale=0),dict(per_click_unit='IU',per_click_scale=0)):
            with self.assertRaises(sqlite3.IntegrityError):self.insert('stack','syringes',a,**(base|kw))
        self.insert('stack','syringes',a,**(base|dict(per_click_unit='ug',per_click_scale=0)))

    def test_38_initial_head_cannot_duplicate_another_dose_or_set(self):
        a,d,compound,vial,log=self.stack_fixture();rev=self.dose_revision(a,d,log)
        with self.assertRaises(sqlite3.IntegrityError):self.insert('stack','dose_logs',a,compound_id=compound,current_revision_id=rev)
        a,d,_,typ,_,we,st=self.train();rev=self.revision(a,d,typ,st)
        with self.assertRaises(sqlite3.IntegrityError):self.insert('core','workout_sets',a,workout_exercise_id=we,position=1,current_revision_id=rev)

    def test_39_dose_compound_changes_require_audited_replacement(self):
        a,d,compound,vial,log=self.stack_fixture();self.dose_revision(a,d,log)
        other=self.insert('stack','compounds',a,name='Other synthetic',dosage_form='vial',default_dimension='mass')
        with self.assertRaises(sqlite3.IntegrityError):self.db['stack'].execute('UPDATE dose_logs SET compound_id=?,logical_clock=1 WHERE id=?',(other,log))

    def test_40_completeness_is_explicit_and_zero_can_be_complete(self):
        a=self.account()
        with self.assertRaises(sqlite3.IntegrityError):self.insert('core','nutrition_days',a,local_date=DAY,status='complete')
        self.insert('core','nutrition_days',a,local_date=DAY,status='complete',confirmed_at=STAMP)
        self.assertEqual(self.db['core'].execute('SELECT count(*) FROM food_logs').fetchone()[0],0)
        self.assertEqual(self.db['core'].execute('SELECT status FROM nutrition_days').fetchone()[0],'complete')

    def test_41_remote_apply_does_not_echo_and_context_rolls_back(self):
        a=self.account();c=self.db['core'];ctx=self.insert('core','sync_context',a,mode='local')
        before=c.execute('SELECT count(*) FROM sync_outbox').fetchone()[0]
        c.execute('BEGIN IMMEDIATE');c.execute("UPDATE sync_context SET mode='remote_apply' WHERE id=?",(ctx,))
        self.insert('core','weigh_ins',a,weight_kg=60,entered_value='60',entered_unit='kg',**self.timed())
        self.assertEqual(c.execute('SELECT count(*) FROM sync_outbox').fetchone()[0],before)
        c.rollback()
        self.assertEqual(c.execute('SELECT mode FROM sync_context').fetchone()[0],'local')
        self.insert('core','weigh_ins',a,weight_kg=61,entered_value='61',entered_unit='kg',**self.timed())
        self.assertEqual(c.execute('SELECT count(*) FROM sync_outbox').fetchone()[0],before+1)

    def test_42_calculator_requires_explicit_final_volume_evidence(self):
        a,d,compound,vial,log=self.stack_fixture()
        base=dict(amount_value=250,amount_unit='ug',amount_scale=0,entered_value='0.25',entered_unit='mg',vial_id=vial,diluent_ul=2000,method_version='fixture',label_verified_at=STAMP)
        with self.assertRaises(sqlite3.IntegrityError):self.insert('stack','calculator_presets',a,**base)
        self.insert('stack','calculator_presets',a,**(base|dict(final_solution_ul=2000,volume_basis='label_final_volume',volume_label_evidence='Synthetic volume fixture')))

    def test_43_unlogged_rir_uses_logged_rpe_for_hard_set_filter(self):
        a,d,ex,typ,_,_,st=self.train();c=self.db['core']
        m=self.insert('core','muscles',a,code='synthetic',display_name='Synthetic',svg_region_key='fixture')
        self.insert('core','exercise_muscles',a,exercise_id=ex,muscle_id=m,role='primary',contribution=1)
        rev=self.revision(a,d,typ,st,rpe=5)
        c.execute('UPDATE workout_sets SET current_revision_id=?,logical_clock=1 WHERE id=?',(rev,st))
        self.assertEqual(c.execute('SELECT fractional_hard_sets FROM training_muscle_daily_raw').fetchone()[0],0)

if __name__=='__main__':
    print('Scratch-only migration tests; SQLite',sqlite3.sqlite_version)
    unittest.main(verbosity=2)
