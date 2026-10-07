#!/usr/bin/env python3
"""Generate reviewable SQLite migrations. Never opens or migrates an app database."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parent
SCHEMAS = {'core': [], 'stack': []}

def uuid_check(c):
    return (f"length({c}) = 36 AND substr({c},9,1) = '-' AND substr({c},14,1) = '-' "
            f"AND substr({c},19,1) = '-' AND substr({c},24,1) = '-' "
            f"AND length(replace({c},'-','')) = 32 AND replace({c},'-','') NOT GLOB '*[^0-9a-f]*' "
            f"AND substr({c},15,1) = '7' AND substr({c},20,1) IN ('8','9','a','b')")

def fields(text):
    return [p.strip() for p in text.split(';') if p.strip()]

def table(db, name, description, columns='', refs=(), checks=(), uniques=(), immutable=False, synced=True, timed=False):
    cols = fields(columns)
    if timed:
        cols = ["occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0)", "tz TEXT NOT NULL CHECK(length(tz) BETWEEN 1 AND 128)",
                "local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days') IS NOT NULL AND date(local_date,'+0 days')=local_date)"] + cols
    SCHEMAS[db].append(dict(name=name, description=description, columns=cols, refs=list(refs), checks=list(checks),
                            uniques=list(uniques), immutable=immutable, synced=synced, timed=timed))

def t(name, desc, columns='', **kwargs): table('core', name, desc, columns, **kwargs)
def s(name, desc, columns='', **kwargs): table('stack', name, desc, columns, **kwargs)

META = [
    "created_at INTEGER NOT NULL CHECK(created_at >= 0)",
    "updated_at INTEGER NOT NULL CHECK(updated_at >= created_at)",
    "deleted_at INTEGER CHECK(deleted_at IS NULL OR deleted_at >= created_at)",
    "source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','import','health','ai'))",
    "logical_clock INTEGER NOT NULL DEFAULT 0 CHECK(logical_clock >= 0)",
    "origin_device_id TEXT"
]

for db in SCHEMAS:
    account_extra = '''birth_date TEXT; height_cm REAL CHECK(height_cm>0 AND height_cm<300);
        entered_height_value TEXT; entered_height_unit TEXT;
        bmr_sex TEXT CHECK(bmr_sex IN ('male','female','unspecified'));
        experience TEXT; onboarding_completed_at INTEGER''' if db == 'core' else ''
    table(db,'accounts','Local account root; an offline account works without a remote identity.', '''
        external_subject TEXT; auth_provider TEXT CHECK(auth_provider IN ('apple','google','email'));
        age_verified_at INTEGER; region TEXT; sync_enabled INTEGER NOT NULL DEFAULT 0 CHECK(sync_enabled IN (0,1));
        deletion_requested_at INTEGER; deletion_due_at INTEGER; ''' + account_extra,
        checks=['deletion_due_at IS NULL OR (deletion_requested_at IS NOT NULL AND deletion_due_at >= deletion_requested_at AND deletion_due_at <= deletion_requested_at + 2592000000)'])
    table(db,'devices','Per-account sync writer identity; never a hardware advertising identifier.', '''
        label TEXT NOT NULL; platform TEXT NOT NULL; last_seen_at INTEGER;
        retired_at INTEGER''')
    settings_extra = '''weight_unit TEXT NOT NULL DEFAULT 'kg' CHECK(weight_unit IN ('kg','lb'));
        length_unit TEXT NOT NULL DEFAULT 'cm' CHECK(length_unit IN ('cm','in'));
        energy_unit TEXT NOT NULL DEFAULT 'kcal' CHECK(energy_unit IN ('kcal','kJ'));
        volume_unit TEXT NOT NULL DEFAULT 'mL' CHECK(volume_unit IN ('mL','fl_oz'));
        temperature_unit TEXT NOT NULL DEFAULT 'C' CHECK(temperature_unit IN ('C','F'));
        count_mode TEXT NOT NULL DEFAULT 'fractional' CHECK(count_mode IN ('direct','fractional','hard'));
        e1rm_formula TEXT NOT NULL DEFAULT 'epley'; rest_compound_seconds INTEGER NOT NULL DEFAULT 150 CHECK(rest_compound_seconds>=0);
        rest_isolation_seconds INTEGER NOT NULL DEFAULT 75 CHECK(rest_isolation_seconds>=0);
        count_both_hands INTEGER NOT NULL DEFAULT 0 CHECK(count_both_hands IN (0,1));
        train_enabled INTEGER NOT NULL DEFAULT 1 CHECK(train_enabled IN (0,1));
        fuel_enabled INTEGER NOT NULL DEFAULT 1 CHECK(fuel_enabled IN (0,1));
        ai_enabled INTEGER NOT NULL DEFAULT 0 CHECK(ai_enabled IN (0,1));
        hide_numbers INTEGER NOT NULL DEFAULT 0 CHECK(hide_numbers IN (0,1));
        streaks_opt_in INTEGER NOT NULL DEFAULT 0 CHECK(streaks_opt_in IN (0,1));
        fasting_opt_in INTEGER NOT NULL DEFAULT 0 CHECK(fasting_opt_in IN (0,1));
        ed_risk_flag INTEGER NOT NULL DEFAULT 0 CHECK(ed_risk_flag IN (0,1));
        default_chart_range TEXT NOT NULL DEFAULT '1M' ''' if db=='core' else '''
        module_opt_in_at INTEGER; disclaimer_version TEXT; discreet_mode INTEGER NOT NULL DEFAULT 1 CHECK(discreet_mode IN (0,1));
        biometric_lock INTEGER NOT NULL DEFAULT 1 CHECK(biometric_lock IN (0,1));
        app_switcher_blur INTEGER NOT NULL DEFAULT 1 CHECK(app_switcher_blur IN (0,1));
        region_gate_version TEXT; region_gate_checked_at INTEGER; module_disabled_at INTEGER'''
    table(db,'settings','Typed preferences; key material belongs in Keychain, never this table.', '''
        language TEXT NOT NULL DEFAULT 'en'; locale TEXT NOT NULL DEFAULT 'en_US';
        week_start INTEGER NOT NULL DEFAULT 1 CHECK(week_start BETWEEN 1 AND 7);
        theme TEXT NOT NULL DEFAULT 'system' CHECK(theme IN ('system','light','dark','oled'));
        quiet_start_minute INTEGER CHECK(quiet_start_minute BETWEEN 0 AND 1439);
        quiet_end_minute INTEGER CHECK(quiet_end_minute BETWEEN 0 AND 1439);
        notifications_enabled INTEGER NOT NULL DEFAULT 0 CHECK(notifications_enabled IN (0,1));
        reduce_motion INTEGER NOT NULL DEFAULT 0 CHECK(reduce_motion IN (0,1)); ''' + settings_extra,
        uniques=['account_id'])
    table(db,'consents','Append-only grant/revoke acknowledgements and permission history.', '''
        scope TEXT NOT NULL; policy_version TEXT NOT NULL;
        action TEXT NOT NULL CHECK(action IN ('grant','revoke')); expires_at INTEGER;
        acknowledgement_text TEXT NOT NULL''', immutable=True, timed=True)
    table(db,'sync_outbox','Atomic, idempotent outbound mutation envelopes; health values stay in this store.', '''
        entity_table TEXT NOT NULL; entity_id TEXT NOT NULL; revision_id TEXT;
        operation TEXT NOT NULL CHECK(operation IN ('upsert','tombstone'));
        payload_json TEXT NOT NULL CHECK(json_valid(payload_json));
        status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sending','acknowledged','failed'));
        attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts>=0); next_attempt_at INTEGER;
        acknowledged_at INTEGER; last_error_code TEXT''', synced=False)
    table(db,'sync_cursors','Opaque cursor advances only in the same transaction as all applied pull changes.', '''
        stream TEXT NOT NULL; cursor TEXT NOT NULL DEFAULT ''; server_sequence INTEGER NOT NULL DEFAULT 0 CHECK(server_sequence>=0);
        last_success_at INTEGER; export_checkpoint TEXT''', uniques=['account_id, stream'], synced=False)
    table(db,'sync_conflicts','Keep both remote and local candidates until an explicit deterministic or user resolution.', '''
        entity_table TEXT NOT NULL; entity_id TEXT NOT NULL; local_revision_id TEXT; remote_revision_id TEXT;
        local_payload_json TEXT NOT NULL CHECK(json_valid(local_payload_json));
        remote_payload_json TEXT NOT NULL CHECK(json_valid(remote_payload_json));
        resolution TEXT CHECK(resolution IN ('local','remote','merge','keep_both'));
        resolution_revision_id TEXT; resolved_at INTEGER''', synced=False,
        checks=['(resolution IS NULL AND resolved_at IS NULL) OR (resolution IS NOT NULL AND resolved_at IS NOT NULL)'])
    table(db,'attachments','Encrypted-file manifest with a same-store typed owner; no image bytes in sync logs.', '''
        owner_table TEXT NOT NULL; owner_id TEXT NOT NULL; local_locator TEXT NOT NULL;
        remote_object_key TEXT; media_type TEXT NOT NULL; byte_count INTEGER NOT NULL CHECK(byte_count>=0);
        sha256 TEXT NOT NULL CHECK(length(sha256)=64 AND sha256 NOT GLOB '*[^0-9a-f]*');
        width_px INTEGER CHECK(width_px>0); height_px INTEGER CHECK(height_px>0);
        duration_ms INTEGER CHECK(duration_ms>=0); pose TEXT; sort_order INTEGER NOT NULL DEFAULT 0;
        metadata_stripped INTEGER NOT NULL DEFAULT 1 CHECK(metadata_stripped IN (0,1));
        biometric_required INTEGER NOT NULL DEFAULT 1 CHECK(biometric_required IN (0,1))''')
    allowed_domains = "'train','fuel','body','platform'" if db=='core' else "'stack'"
    table(db,'series_registry','Allowlisted query key and unit contract, never arbitrary executable SQL.', f'''
        metric_key TEXT NOT NULL; domain TEXT NOT NULL CHECK(domain IN ({allowed_domains}));
        unit TEXT NOT NULL; kind TEXT NOT NULL CHECK(kind IN ('daily','event','instant'));
        aggregation TEXT NOT NULL CHECK(aggregation IN ('sum','mean','last','max'));
        value_storage TEXT NOT NULL CHECK(value_storage IN ('real','fixed'));
        color_token TEXT NOT NULL; source_query_key TEXT NOT NULL; method_version TEXT NOT NULL;
        is_estimate INTEGER NOT NULL DEFAULT 0 CHECK(is_estimate IN (0,1)); priority TEXT NOT NULL DEFAULT 'P0' ''',
        uniques=['account_id, metric_key'])
    table(db,'event_registry','Allowlisted event types for charts and the shared in-memory timeline.', f'''
        event_key TEXT NOT NULL; domain TEXT NOT NULL CHECK(domain IN ({allowed_domains}));
        label_key TEXT NOT NULL; shape_token TEXT NOT NULL; color_token TEXT NOT NULL; source_query_key TEXT NOT NULL''',
        uniques=['account_id, event_key'])
    table(db,'events','Typed annotations; Stack events are never copied to the core database.', '''
        event_type_id TEXT NOT NULL; owner_table TEXT; owner_id TEXT;
        title TEXT NOT NULL; notes TEXT; end_at INTEGER''',refs=[('event_type_id','event_registry')],timed=True,
        checks=['end_at IS NULL OR end_at>=occurred_at','(owner_table IS NULL)=(owner_id IS NULL)'])
    table(db,'daily_rollups','Rebuildable per-series, local-day, dimension aggregates; missing values remain missing.', '''
        series_id TEXT NOT NULL; local_date TEXT NOT NULL CHECK(length(local_date)=10 AND date(local_date,'+0 days')=local_date);
        dimension_key TEXT NOT NULL DEFAULT ''; real_value REAL; value_coefficient INTEGER; value_scale INTEGER;
        sample_count INTEGER NOT NULL CHECK(sample_count>=0); expected_count INTEGER CHECK(expected_count>=0);
        coverage REAL CHECK(coverage BETWEEN 0 AND 1); input_digest TEXT NOT NULL; method_version TEXT NOT NULL;
        rebuilt_at INTEGER NOT NULL''',refs=[('series_id','series_registry')],synced=False,
        checks=['(real_value IS NULL AND value_coefficient IS NULL AND value_scale IS NULL) OR (real_value IS NOT NULL AND value_coefficient IS NULL AND value_scale IS NULL) OR (real_value IS NULL AND value_coefficient IS NOT NULL AND value_scale BETWEEN 0 AND 6)'],
        uniques=['account_id, series_id, local_date, dimension_key'])
    table(db,'chart_preferences','Independent per-chart range, transforms, hidden numbers and marker preferences.', '''
        chart_key TEXT NOT NULL; range_key TEXT NOT NULL DEFAULT '1M'; from_date TEXT; to_date TEXT;
        comparison_enabled INTEGER NOT NULL DEFAULT 0 CHECK(comparison_enabled IN (0,1));
        trend TEXT NOT NULL DEFAULT 'raw' CHECK(trend IN ('raw','ewma','moving_average','theil_sen'));
        show_absolute_values INTEGER NOT NULL DEFAULT 1 CHECK(show_absolute_values IN (0,1));
        marker_keys_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(marker_keys_json))''',uniques=['account_id, chart_key'])
    table(db,'notification_jobs','Local schedule state; fixed IDs allow cancel/reschedule without duplicate alerts.', '''
        kind TEXT NOT NULL; owner_table TEXT NOT NULL; owner_id TEXT NOT NULL; due_at INTEGER NOT NULL;
        tz TEXT NOT NULL; request_identifier TEXT NOT NULL; status TEXT NOT NULL CHECK(status IN ('pending','scheduled','delivered','cancelled'));
        repeat_seconds INTEGER CHECK(repeat_seconds>0); snoozed_until INTEGER;
        neutral_text_key TEXT NOT NULL; last_action TEXT''',uniques=['account_id, request_identifier'],synced=False)

# TRAIN: catalogue, prescribed plans, completed history, and immutable corrections.
t('muscles','Body-map region taxonomy and original/license metadata.', '''
    code TEXT NOT NULL; display_name TEXT NOT NULL; parent_id TEXT; body_side TEXT CHECK(body_side IN ('front','back','both'));
    svg_region_key TEXT NOT NULL; citation TEXT; license_key TEXT''',refs=[('parent_id','muscles')],uniques=['account_id, code'])
t('equipment','Searchable equipment and bar definition; masses are canonical kg.', '''
    name TEXT NOT NULL; kind TEXT NOT NULL; bar_mass_kg REAL CHECK(bar_mass_kg>0); entered_value TEXT; entered_unit TEXT;
    is_custom INTEGER NOT NULL DEFAULT 0 CHECK(is_custom IN (0,1))''')
t('gyms','Gym profile and active plate calculator context.', '''name TEXT NOT NULL; notes TEXT; is_active INTEGER NOT NULL DEFAULT 0 CHECK(is_active IN (0,1))''')
t('plate_inventory','Integer plate counts per gym; matched pairs and fractional plates remain exact entered values.', '''
    gym_id TEXT NOT NULL; mass_kg REAL NOT NULL CHECK(mass_kg>0 AND mass_kg<1000); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL CHECK(entered_unit IN ('kg','lb'));
    count INTEGER NOT NULL CHECK(count>=0); color_token TEXT''',refs=[('gym_id','gyms')])
t('exercises','Original/licensed exercise definitions plus private custom records; merge preserves old IDs.', '''
    name TEXT NOT NULL; normalized_name TEXT NOT NULL; movement_pattern TEXT NOT NULL;
    mechanics TEXT NOT NULL CHECK(mechanics IN ('compound','isolation','other'));
    metric_type TEXT NOT NULL CHECK(metric_type IN ('weight_reps','bodyweight_reps','weighted_bodyweight','assisted_bodyweight','reps','duration','weight_duration','distance','distance_duration'));
    unilateral INTEGER NOT NULL DEFAULT 0 CHECK(unilateral IN (0,1)); per_side INTEGER NOT NULL DEFAULT 0 CHECK(per_side IN (0,1));
    is_custom INTEGER NOT NULL DEFAULT 0 CHECK(is_custom IN (0,1)); is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN (0,1));
    cues TEXT; common_mistakes TEXT; pinned_note TEXT; increment_kg REAL NOT NULL DEFAULT 2.5 CHECK(increment_kg>0);
    entered_increment_value TEXT; entered_increment_unit TEXT; default_rest_seconds INTEGER CHECK(default_rest_seconds>=0);
    default_bar_id TEXT; merged_into_id TEXT; license_key TEXT; citation TEXT; external_key TEXT''',
    refs=[('default_bar_id','equipment'),('merged_into_id','exercises')],checks=['merged_into_id IS NULL OR merged_into_id<>id'])
t('exercise_aliases','Indexed aliases include user names without rewriting historical exercise IDs.', '''exercise_id TEXT NOT NULL; alias TEXT NOT NULL; normalized_alias TEXT NOT NULL''',refs=[('exercise_id','exercises')],uniques=['account_id, exercise_id, normalized_alias'])
t('exercise_muscles','Fractional muscle attribution used by set counting and swap ranking.', '''exercise_id TEXT NOT NULL; muscle_id TEXT NOT NULL; role TEXT NOT NULL CHECK(role IN ('primary','secondary')); contribution REAL NOT NULL CHECK(contribution>0 AND contribution<=1)''',refs=[('exercise_id','exercises'),('muscle_id','muscles')],uniques=['account_id, exercise_id, muscle_id'])
t('exercise_equipment','Equipment requirements and optional per-gym setup notes.', '''exercise_id TEXT NOT NULL; equipment_id TEXT NOT NULL; gym_id TEXT; setup_note TEXT; available INTEGER NOT NULL DEFAULT 1 CHECK(available IN (0,1))''',refs=[('exercise_id','exercises'),('equipment_id','equipment'),('gym_id','gyms')])
t('set_types','User-defined set labels and independent volume/hard-set/PR inclusion switches.', '''name TEXT NOT NULL; glyph TEXT NOT NULL; color_token TEXT NOT NULL; counts_volume INTEGER NOT NULL CHECK(counts_volume IN (0,1)); counts_hard_sets INTEGER NOT NULL CHECK(counts_hard_sets IN (0,1)); counts_pr INTEGER NOT NULL CHECK(counts_pr IN (0,1)); default_rest_seconds INTEGER CHECK(default_rest_seconds>=0); is_warmup INTEGER NOT NULL DEFAULT 0 CHECK(is_warmup IN (0,1))''',checks=['is_warmup=0 OR (counts_volume=0 AND counts_hard_sets=0 AND counts_pr=0)'])
t('routine_folders','Routine organization without deleting archived history.', '''name TEXT NOT NULL; position INTEGER NOT NULL DEFAULT 0''')
t('routines','Reusable routine definition; program position can use these routine days before P1 programming.', '''name TEXT NOT NULL; folder_id TEXT; notes TEXT; archived_at INTEGER; share_format_version INTEGER NOT NULL DEFAULT 1''',refs=[('folder_id','routine_folders')])
t('routine_exercises','Ordered routine steps, superset/circuit groups and per-exercise defaults.', '''routine_id TEXT NOT NULL; exercise_id TEXT NOT NULL; position INTEGER NOT NULL; group_key TEXT; group_kind TEXT CHECK(group_kind IN ('superset','giant_set','circuit')); rest_after_round INTEGER NOT NULL DEFAULT 1 CHECK(rest_after_round IN (0,1)); notes TEXT; warmup_template_name TEXT''',refs=[('routine_id','routines'),('exercise_id','exercises')])
t('routine_sets','Editable target sets and warm-up ramps, expressed without programme prose.', '''routine_exercise_id TEXT NOT NULL; set_type_id TEXT NOT NULL; position INTEGER NOT NULL; reps_min INTEGER CHECK(reps_min>=0); reps_max INTEGER CHECK(reps_max>=reps_min); target_load_kg REAL CHECK(target_load_kg>=0); entered_value TEXT; entered_unit TEXT; percent_top_load REAL CHECK(percent_top_load BETWEEN 0 AND 1); target_rpe REAL CHECK(target_rpe BETWEEN 1 AND 10); target_rir REAL CHECK(target_rir BETWEEN 0 AND 10); rest_seconds INTEGER CHECK(rest_seconds>=0); tempo TEXT; duration_seconds REAL CHECK(duration_seconds>=0)''',refs=[('routine_exercise_id','routine_exercises'),('set_type_id','set_types')],checks=['target_rpe IS NULL OR target_rir IS NULL'])
t('training_schedule','Calendar plan, rest days, RRULE, missed handling and automatic programme position.', '''routine_id TEXT; schedule_name TEXT NOT NULL; rrule TEXT; tz TEXT NOT NULL; anchor_date TEXT NOT NULL; local_time TEXT; is_rest_day INTEGER NOT NULL DEFAULT 0 CHECK(is_rest_day IN (0,1)); missed_policy TEXT NOT NULL CHECK(missed_policy IN ('shift','skip')); program_key TEXT; program_position INTEGER NOT NULL DEFAULT 0 CHECK(program_position>=0); next_local_date TEXT; reminder_minutes INTEGER CHECK(reminder_minutes>=0); paused_at INTEGER''',refs=[('routine_id','routines')])
t('workouts','Durable resumable session identity and subjective finish summary.', '''routine_id TEXT; gym_id TEXT; repeated_workout_id TEXT; status TEXT NOT NULL CHECK(status IN ('active','finished','abandoned')); ended_at INTEGER; paused_seconds INTEGER NOT NULL DEFAULT 0 CHECK(paused_seconds>=0); bodyweight_kg REAL CHECK(bodyweight_kg>0); bodyweight_log_id TEXT; notes TEXT; soreness INTEGER CHECK(soreness BETWEEN 1 AND 5); energy INTEGER CHECK(energy BETWEEN 1 AND 5); mood INTEGER CHECK(mood BETWEEN 1 AND 5); current_exercise_position INTEGER NOT NULL DEFAULT 0; current_round INTEGER NOT NULL DEFAULT 0; start_origin TEXT NOT NULL DEFAULT 'empty' CHECK(start_origin IN ('empty','routine','program','history','ai'))''',refs=[('routine_id','routines'),('gym_id','gyms'),('repeated_workout_id','workouts'),('bodyweight_log_id','weigh_ins')],timed=True,checks=['ended_at IS NULL OR ended_at>=occurred_at'])
t('workout_exercises','Session exercise ordering and grouping; swapping records both original and selected exercise.', '''workout_id TEXT NOT NULL; exercise_id TEXT NOT NULL; original_exercise_id TEXT; position INTEGER NOT NULL; group_key TEXT; group_kind TEXT CHECK(group_kind IN ('superset','giant_set','circuit')); skipped INTEGER NOT NULL DEFAULT 0 CHECK(skipped IN (0,1)); notes TEXT; equipment_id TEXT; rest_after_round INTEGER NOT NULL DEFAULT 1 CHECK(rest_after_round IN (0,1))''',refs=[('workout_id','workouts'),('exercise_id','exercises'),('original_exercise_id','exercises'),('equipment_id','equipment')])
t('workout_sets','Stable set identity; the selected immutable revision is the current projection.', '''workout_exercise_id TEXT NOT NULL; current_revision_id TEXT; position INTEGER NOT NULL''',refs=[('workout_exercise_id','workout_exercises'),('current_revision_id','set_revisions')])
t('set_revisions','Append-only complete set snapshots. Branches are preserved rather than silently overwriting.', '''set_id TEXT NOT NULL; parent_revision_id TEXT; writer_device_id TEXT NOT NULL; action TEXT NOT NULL CHECK(action IN ('upsert','tombstone','restore')); set_type_id TEXT NOT NULL; load_kg REAL CHECK(load_kg>=0 AND load_kg<100000); entered_load_value TEXT; entered_load_unit TEXT; reps INTEGER CHECK(reps>=0); rpe REAL CHECK(rpe BETWEEN 0 AND 10); rir REAL CHECK(rir>=0); duration_seconds REAL CHECK(duration_seconds>=0); distance_cm REAL CHECK(distance_cm>=0); entered_distance_value TEXT; entered_distance_unit TEXT; bodyweight_kg REAL CHECK(bodyweight_kg>0); added_kg REAL CHECK(added_kg>=0); assistance_kg REAL CHECK(assistance_kg>=0); side TEXT CHECK(side IN ('both','left','right')); tempo TEXT; rest_actual_seconds REAL CHECK(rest_actual_seconds>=0); planned_rest_seconds INTEGER CHECK(planned_rest_seconds>=0); percent_1rm REAL CHECK(percent_1rm>=0); counts_both_hands INTEGER NOT NULL DEFAULT 0 CHECK(counts_both_hands IN (0,1)); completed INTEGER NOT NULL DEFAULT 1 CHECK(completed IN (0,1)); notes TEXT; edit_reason TEXT''',refs=[('set_id','workout_sets'),('parent_revision_id','set_revisions'),('writer_device_id','devices'),('set_type_id','set_types')],timed=True,immutable=True,checks=['rpe IS NULL OR rir IS NULL','assistance_kg IS NULL OR bodyweight_kg IS NULL OR assistance_kg<=bodyweight_kg','action<>\'tombstone\' OR deleted_at IS NOT NULL'])
t('rest_timers','Persisted timer deadlines survive app termination; notifications schedule from ends_at.', '''workout_id TEXT NOT NULL; set_id TEXT; started_at INTEGER NOT NULL; ends_at INTEGER NOT NULL; finished_at INTEGER; target_seconds INTEGER NOT NULL CHECK(target_seconds>=0); actual_seconds REAL CHECK(actual_seconds>=0); state TEXT NOT NULL CHECK(state IN ('running','completed','skipped','cancelled'))''',refs=[('workout_id','workouts'),('set_id','workout_sets')],checks=['ends_at>=started_at'])
t('pr_records','Rebuildable records linked to the exact set revision and documented calculation method.', '''exercise_id TEXT NOT NULL; workout_id TEXT NOT NULL; set_revision_id TEXT; record_kind TEXT NOT NULL CHECK(record_kind IN ('weight','e1rm','set_volume','session_volume','rep_record','hold','pace')); rep_threshold INTEGER CHECK(rep_threshold BETWEEN 1 AND 12); value REAL NOT NULL CHECK(value>=0); unit TEXT NOT NULL; formula TEXT; confidence TEXT; computed_at INTEGER NOT NULL''',refs=[('exercise_id','exercises'),('workout_id','workouts'),('set_revision_id','set_revisions')],timed=True,synced=False)
t('muscle_targets','User-set weekly neutral target bands, not clinical recommendations.', '''muscle_id TEXT NOT NULL; valid_from TEXT NOT NULL; min_sets REAL NOT NULL CHECK(min_sets>=0); max_sets REAL NOT NULL CHECK(max_sets>=min_sets); mev REAL; mav REAL; mrv REAL; method_label TEXT NOT NULL''',refs=[('muscle_id','muscles')])

# FUEL: provenance, ingredients, snapshots, and safe targets.
t('food_sources','Dataset licensing, attribution, provenance and freshness.', '''name TEXT NOT NULL; source_kind TEXT NOT NULL CHECK(source_kind IN ('usda','off','licensed','restaurant','label','user')); license_identifier TEXT NOT NULL; attribution TEXT NOT NULL; terms_url TEXT; version TEXT; verified_at INTEGER''')
t('restaurants','Preserves the current restaurant library identity during shadow copy.', '''name TEXT NOT NULL; citation TEXT; verified_at INTEGER; is_custom INTEGER NOT NULL DEFAULT 0 CHECK(is_custom IN (0,1))''')
t('foods','Canonical per-100g food definitions; private corrections link to the original food.', '''name TEXT NOT NULL; normalized_name TEXT NOT NULL; brand TEXT; source_id TEXT NOT NULL; source_external_key TEXT; barcode TEXT; quality_rank INTEGER NOT NULL CHECK(quality_rank BETWEEN 0 AND 3); density_g_per_ml REAL CHECK(density_g_per_ml>0); restaurant_id TEXT; menu_category TEXT; corrected_from_id TEXT; correction_reason TEXT; error_report_status TEXT; is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN (0,1)); is_custom INTEGER NOT NULL DEFAULT 0 CHECK(is_custom IN (0,1)); kind TEXT NOT NULL DEFAULT 'food' CHECK(kind IN ('food','recipe','builder','menu_item','supplement')); notes TEXT''',refs=[('source_id','food_sources'),('restaurant_id','restaurants'),('corrected_from_id','foods')])
t('food_servings','Household measures, default serving and exact input display units.', '''food_id TEXT NOT NULL; label TEXT NOT NULL; grams REAL NOT NULL CHECK(grams>0); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; is_default INTEGER NOT NULL DEFAULT 0 CHECK(is_default IN (0,1))''',refs=[('food_id','foods')])
t('nutrients','Versioned nutrient identifiers with their actual canonical dimension and reference source.', '''code TEXT NOT NULL; name TEXT NOT NULL; canonical_unit TEXT NOT NULL CHECK(canonical_unit IN ('g','kcal','mL','IU')); citation TEXT; reference_version TEXT''',uniques=['account_id, code'])
t('food_nutrients','Per-100g values with source units retained; missing is not zero.', '''food_id TEXT NOT NULL; nutrient_id TEXT NOT NULL; value REAL NOT NULL CHECK(value>=0 AND value<1e12); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; precision_digits INTEGER CHECK(precision_digits BETWEEN 0 AND 12)''',refs=[('food_id','foods'),('nutrient_id','nutrients')],uniques=['account_id, food_id, nutrient_id'])
t('food_component_groups','Existing customizable restaurant builder groups; unrelated to dose units.', '''food_id TEXT NOT NULL; name TEXT NOT NULL; selection_mode TEXT NOT NULL CHECK(selection_mode IN ('single','multiple')); required INTEGER NOT NULL CHECK(required IN (0,1)); position INTEGER NOT NULL''',refs=[('food_id','foods')])
t('food_components','Restaurant options/modifier references and explicit portion capabilities.', '''parent_food_id TEXT NOT NULL; child_food_id TEXT NOT NULL; group_id TEXT; name TEXT NOT NULL; grams REAL NOT NULL CHECK(grams>0); is_removal INTEGER NOT NULL DEFAULT 0 CHECK(is_removal IN (0,1)); supports_double INTEGER NOT NULL DEFAULT 0 CHECK(supports_double IN (0,1)); position INTEGER NOT NULL DEFAULT 0''',refs=[('parent_food_id','foods'),('child_food_id','foods'),('group_id','food_component_groups')],checks=['parent_food_id<>child_food_id'])
t('meal_slots','Four initial slots plus unlimited private slots and local times.', '''name TEXT NOT NULL; position INTEGER NOT NULL; default_local_time TEXT''')
t('meal_logs','Meal-level notes, photos, hunger/mood, planned/eaten state and clone provenance.', '''meal_slot_id TEXT NOT NULL; state TEXT NOT NULL CHECK(state IN ('planned','eaten')); notes TEXT; hunger INTEGER CHECK(hunger BETWEEN 1 AND 5); mood INTEGER CHECK(mood BETWEEN 1 AND 5); copied_from_id TEXT''',refs=[('meal_slot_id','meal_slots'),('copied_from_id','meal_logs')],timed=True)
t('food_logs','Immutable-source nutrition snapshot editable only for this log; preserves exact serving entry.', '''meal_log_id TEXT NOT NULL; food_id TEXT; food_name TEXT NOT NULL; serving_id TEXT; grams REAL NOT NULL CHECK(grams>0); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; multiplier REAL NOT NULL DEFAULT 1 CHECK(multiplier>0); calories_kcal REAL NOT NULL CHECK(calories_kcal>=0); protein_g REAL NOT NULL CHECK(protein_g>=0); carbs_g REAL NOT NULL CHECK(carbs_g>=0); fat_g REAL NOT NULL CHECK(fat_g>=0); alcohol_g REAL NOT NULL DEFAULT 0 CHECK(alcohol_g>=0); adjusted INTEGER NOT NULL DEFAULT 0 CHECK(adjusted IN (0,1)); confirmed_at INTEGER NOT NULL; notes TEXT''',refs=[('meal_log_id','meal_logs'),('food_id','foods'),('serving_id','food_servings')],timed=True)
t('food_log_nutrients','Micronutrient and supplement snapshots for diary totals independent of future catalog edits.', '''food_log_id TEXT NOT NULL; nutrient_id TEXT NOT NULL; value REAL NOT NULL CHECK(value>=0); entered_value TEXT; entered_unit TEXT''',refs=[('food_log_id','food_logs'),('nutrient_id','nutrients')],uniques=['account_id, food_log_id, nutrient_id'])
t('recipes','Recipe provenance, portions and explicit raw/cooked mass yield.', '''food_id TEXT NOT NULL; name TEXT NOT NULL; servings REAL NOT NULL CHECK(servings>0); raw_mass_g REAL NOT NULL CHECK(raw_mass_g>0); cooked_mass_g REAL NOT NULL CHECK(cooked_mass_g>0); yield_factor REAL NOT NULL CHECK(yield_factor>0); import_url TEXT; instructions TEXT; parser_version TEXT''',refs=[('food_id','foods')],checks=['abs(yield_factor-cooked_mass_g/raw_mass_g)<0.000001'])
t('recipe_ingredients','Ordered ingredient mass and entered units for deterministic recipe totals.', '''recipe_id TEXT NOT NULL; food_id TEXT NOT NULL; grams REAL NOT NULL CHECK(grams>0); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; position INTEGER NOT NULL; notes TEXT''',refs=[('recipe_id','recipes'),('food_id','foods')])
t('meal_templates','Saved meal identity, independent from logs or originals.', '''name TEXT NOT NULL; notes TEXT; preferred_slot_id TEXT''',refs=[('preferred_slot_id','meal_slots')])
t('meal_template_items','Reusable ordered meal portions.', '''meal_template_id TEXT NOT NULL; food_id TEXT NOT NULL; grams REAL NOT NULL CHECK(grams>0); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; position INTEGER NOT NULL''',refs=[('meal_template_id','meal_templates'),('food_id','foods')])
t('hydration_logs','Water, caffeine and alcohol quick logs with canonical volume/mass and beverage calories.', '''kind TEXT NOT NULL CHECK(kind IN ('water','caffeine','alcohol')); volume_ml REAL CHECK(volume_ml>=0); caffeine_g REAL CHECK(caffeine_g>=0); alcohol_g REAL CHECK(alcohol_g>=0); calories_kcal REAL NOT NULL DEFAULT 0 CHECK(calories_kcal>=0); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; notes TEXT''',timed=True,checks=['volume_ml IS NOT NULL OR caffeine_g IS NOT NULL OR alcohol_g IS NOT NULL'])
t('supplement_logs','Non-peptide supplement log; amounts are food mass and optional nutrients, not injection protocols.', '''food_id TEXT NOT NULL; food_log_id TEXT; grams REAL NOT NULL CHECK(grams>0); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; notes TEXT''',refs=[('food_id','foods'),('food_log_id','food_logs')],timed=True)
t('safety_acknowledgements','Immutable explicit acknowledgements; no silent floor overrides.', '''kind TEXT NOT NULL CHECK(kind IN ('clinician_floor_override','risk_resources_shown','risk_review')); policy_version TEXT NOT NULL; acknowledgement_text TEXT NOT NULL; expires_at INTEGER; clinician_override_confirmed INTEGER NOT NULL DEFAULT 0 CHECK(clinician_override_confirmed IN (0,1))''',timed=True,immutable=True)
TARGET = '''goal_mode TEXT NOT NULL CHECK(goal_mode IN ('cut','maintain','lean_bulk','bulk','recomp','refeed','diet_break'));
    calories_kcal REAL NOT NULL CHECK(calories_kcal>=0); protein_g REAL NOT NULL CHECK(protein_g>=0); carbs_g REAL NOT NULL CHECK(carbs_g>=0); fat_g REAL NOT NULL CHECK(fat_g>=0); fiber_g REAL CHECK(fiber_g>=0);
    assessed_bmi REAL CHECK(assessed_bmi>0); weekly_loss_fraction REAL NOT NULL DEFAULT 0 CHECK(weekly_loss_fraction BETWEEN 0 AND 0.01);
    safety_floor_kcal REAL NOT NULL CHECK(safety_floor_kcal>=1200); clinician_ack_id TEXT; method_version TEXT NOT NULL'''
TARGET_CHECKS = ["calories_kcal>=safety_floor_kcal OR clinician_ack_id IS NOT NULL", "(goal_mode<>'cut' AND weekly_loss_fraction=0) OR (assessed_bmi IS NOT NULL AND assessed_bmi>=18.5)"]
t('nutrition_targets','Calculated/default target snapshots with safety inputs, BMR method and entered goal rate.', TARGET+'''; valid_from TEXT NOT NULL; valid_until TEXT; activity_multiplier REAL CHECK(activity_multiplier>0); bmr_kcal REAL CHECK(bmr_kcal>0); bmr_method TEXT; macro_preset TEXT; entered_rate_value TEXT; entered_rate_unit TEXT; day_type TEXT NOT NULL DEFAULT 'all' CHECK(day_type IN ('all','training','rest')); nutrient_id TEXT; nutrient_target_value REAL CHECK(nutrient_target_value>=0); reference_citation TEXT''',refs=[('clinician_ack_id','safety_acknowledgements'),('nutrient_id','nutrients')],checks=TARGET_CHECKS)
t('target_overrides','Per-day or weekday targets and weekly flex budget with the same safety gates.', TARGET+'''; base_target_id TEXT NOT NULL; local_date TEXT; weekday INTEGER CHECK(weekday BETWEEN 1 AND 7); weekly_budget_kcal REAL CHECK(weekly_budget_kcal>=0)''',refs=[('base_target_id','nutrition_targets'),('clinician_ack_id','safety_acknowledgements')],checks=TARGET_CHECKS+['(local_date IS NOT NULL)+(weekday IS NOT NULL)=1'])
t('diet_phases','Cut/bulk/maintenance, refeed and diet-break schedule; no dose references.', '''name TEXT NOT NULL; kind TEXT NOT NULL CHECK(kind IN ('cut','bulk','maintain','recomp','refeed','diet_break')); starts_on TEXT NOT NULL; ends_on TEXT; target_id TEXT; notes TEXT''',refs=[('target_id','nutrition_targets')])

# BODY, HEALTH and portability.
t('weigh_ins','Canonical kg and original entered representation, including Health source identity.', '''weight_kg REAL NOT NULL CHECK(weight_kg>0 AND weight_kg<1000); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL CHECK(entered_unit IN ('kg','lb')); health_external_key TEXT; tags TEXT; notes TEXT''',timed=True)
t('measurements','Named/custom circumference or composition measurement with method and location.', '''kind TEXT NOT NULL CHECK(kind IN ('circumference','body_fat_percent','lean_mass','fat_mass','height')); landmark TEXT NOT NULL; side TEXT CHECK(side IN ('left','right','both')); value REAL NOT NULL CHECK(value>=0); canonical_unit TEXT NOT NULL CHECK(canonical_unit IN ('cm','kg','percent')); entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; method TEXT NOT NULL; uncertainty REAL CHECK(uncertainty>=0); notes TEXT''',timed=True,checks=["(kind IN ('circumference','height') AND canonical_unit='cm') OR (kind IN ('lean_mass','fat_mass') AND canonical_unit='kg') OR (kind='body_fat_percent' AND canonical_unit='percent' AND value<=100)"])
t('check_ins','Current progress notes/photos and subjective recovery scores; optional weight linkage.', '''weigh_in_id TEXT; notes TEXT NOT NULL DEFAULT ''; sleep_quality INTEGER CHECK(sleep_quality BETWEEN 1 AND 5); soreness INTEGER CHECK(soreness BETWEEN 1 AND 5); stress INTEGER CHECK(stress BETWEEN 1 AND 5); motivation INTEGER CHECK(motivation BETWEEN 1 AND 5)''',refs=[('weigh_in_id','weigh_ins')],timed=True)
t('health_samples','Deduplicated provider observations for weight/steps P0 and recovery P1.', '''provider TEXT NOT NULL; external_key TEXT NOT NULL; sample_type TEXT NOT NULL CHECK(sample_type IN ('weight','steps','sleep','hrv','resting_hr','active_energy','body_fat')); value REAL NOT NULL; unit TEXT NOT NULL; end_at INTEGER; device_label TEXT; provider_modified_at INTEGER''',timed=True,uniques=['account_id, provider, external_key'])
t('health_anchors','Per-type incremental Health cursor; saved atomically with samples/deletions.', '''provider TEXT NOT NULL; sample_type TEXT NOT NULL; anchor_blob BLOB NOT NULL; last_success_at INTEGER''',uniques=['account_id, provider, sample_type'],synced=False)
t('goals','Cross-domain goal lines and dated targets; core accepts no Stack domain data.', '''domain TEXT NOT NULL CHECK(domain IN ('train','fuel','body')); metric_key TEXT NOT NULL; exercise_id TEXT; muscle_id TEXT; target_value REAL NOT NULL; canonical_unit TEXT NOT NULL; entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; target_date TEXT; starts_on TEXT NOT NULL; archived_at INTEGER''',refs=[('exercise_id','exercises'),('muscle_id','muscles')])
t('notes','Dated private annotations with typed references to core entities only.', '''text TEXT NOT NULL; owner_table TEXT; owner_id TEXT; tags TEXT''',timed=True,checks=['(owner_table IS NULL)=(owner_id IS NULL)'])
t('import_batches','Dry-run/reconciliation manifest for external formats and non-destructive SwiftData shadow copies.', '''format TEXT NOT NULL; file_digest TEXT NOT NULL; status TEXT NOT NULL CHECK(status IN ('planned','validated','copied','verified','failed')); total_rows INTEGER NOT NULL DEFAULT 0 CHECK(total_rows>=0); accepted_rows INTEGER NOT NULL DEFAULT 0 CHECK(accepted_rows>=0); rejected_rows INTEGER NOT NULL DEFAULT 0 CHECK(rejected_rows>=0); error_report_locator TEXT; source_schema_version TEXT; validation_digest TEXT; completed_at INTEGER''')
t('legacy_id_map','Stable UUIDv4/SwiftData identity to UUIDv7 translation, without changing the source store.', '''batch_id TEXT NOT NULL; source_entity TEXT NOT NULL; legacy_identifier TEXT NOT NULL; destination_table TEXT NOT NULL; destination_id TEXT NOT NULL''',refs=[('batch_id','import_batches')],uniques=['account_id, source_entity, legacy_identifier'])
t('export_jobs','Private full-fidelity JSON/CSV bundle manifests and deletion-request handoff status.', '''format TEXT NOT NULL CHECK(format IN ('json','csv','bundle')); status TEXT NOT NULL CHECK(status IN ('pending','writing','complete','failed','expired')); output_locator TEXT; sha256 TEXT; row_count INTEGER CHECK(row_count>=0); expires_at INTEGER; include_attachments INTEGER NOT NULL DEFAULT 1 CHECK(include_attachments IN (0,1))''',synced=False)

# STACK: all user-entered amounts, no clinical seed defaults or dose recommendations.
AMOUNT = '''amount_value INTEGER NOT NULL CHECK(amount_value>0); amount_unit TEXT NOT NULL CHECK(amount_unit IN ('ug','uL','IU','click')); amount_scale INTEGER NOT NULL; entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL'''
AMOUNT_CHECK = "(amount_unit IN ('ug','uL') AND amount_scale=0) OR (amount_unit IN ('IU','click') AND amount_scale=6)"
s('compounds','Private user-created compound identity; no benefit, suggested dose or sourcing fields.', '''name TEXT NOT NULL; aliases TEXT; class_label TEXT; permitted_routes TEXT; dosage_form TEXT NOT NULL CHECK(dosage_form IN ('vial','pen','tablet','nasal','topical','other')); default_dimension TEXT NOT NULL CHECK(default_dimension IN ('mass','volume','activity','clicks')); notes TEXT; storage_label_text TEXT''')
s('compound_references','Optional cited neutral reference facts. This migration inserts none.', '''compound_id TEXT NOT NULL; fact_kind TEXT NOT NULL CHECK(fact_kind IN ('half_life','regulatory_status','wada_status','label_storage')); value_text TEXT NOT NULL; unit TEXT; region TEXT; citation_url TEXT NOT NULL; citation_date TEXT NOT NULL; reviewed_at INTEGER''',refs=[('compound_id','compounds')])
s('protocols','Protocol/template identity with an explicit selected immutable revision.', '''name TEXT NOT NULL; is_template INTEGER NOT NULL DEFAULT 0 CHECK(is_template IN (0,1)); reminder_group_key TEXT; color_token TEXT NOT NULL; current_revision_id TEXT''',refs=[('current_revision_id','protocol_revisions')])
s('protocol_revisions','Append-only history of protocol edits, pause/resume and user-authored step plans.', '''protocol_id TEXT NOT NULL; parent_revision_id TEXT; writer_device_id TEXT NOT NULL; status TEXT NOT NULL CHECK(status IN ('draft','active','paused','ended','archived')); starts_on TEXT NOT NULL; ends_on TEXT; notes TEXT; edit_reason TEXT''',refs=[('protocol_id','protocols'),('parent_revision_id','protocol_revisions'),('writer_device_id','devices')],immutable=True,timed=True)
s('protocol_steps','User-entered compound amount and route at a date/position in a protocol revision.', AMOUNT+'''; protocol_revision_id TEXT NOT NULL; compound_id TEXT NOT NULL; position INTEGER NOT NULL; effective_on TEXT NOT NULL; route TEXT NOT NULL; food_note TEXT CHECK(food_note IN ('with_food','fasted','unspecified')); notes TEXT''',refs=[('protocol_revision_id','protocol_revisions'),('compound_id','compounds')],checks=[AMOUNT_CHECK],immutable=True)
s('schedule_rules','User schedules and DST/travel policy; rule generation belongs to the tested schedule engine.', '''protocol_step_id TEXT NOT NULL; kind TEXT NOT NULL CHECK(kind IN ('daily','every_n_days','weekdays','n_per_week','weekly','biweekly','monthly','cycle','prn','rrule')); rrule TEXT; interval_days INTEGER CHECK(interval_days>0); times_per_week INTEGER CHECK(times_per_week BETWEEN 1 AND 7); weekdays_mask INTEGER CHECK(weekdays_mask BETWEEN 1 AND 127); on_days INTEGER CHECK(on_days>0); off_days INTEGER CHECK(off_days>=0); month_day INTEGER CHECK(month_day BETWEEN 1 AND 31); anchor_date TEXT NOT NULL; end_date TEXT; tz TEXT NOT NULL; time_policy TEXT NOT NULL CHECK(time_policy IN ('floating','fixed')); dst_gap_policy TEXT NOT NULL CHECK(dst_gap_policy IN ('next_valid','skip')); dst_fold_policy TEXT NOT NULL CHECK(dst_fold_policy IN ('first','second')); late_window_seconds INTEGER NOT NULL CHECK(late_window_seconds>=0); paused_at INTEGER''',refs=[('protocol_step_id','protocol_steps')],immutable=True,checks=["kind<>'rrule' OR (rrule IS NOT NULL AND length(rrule)>0)", "kind<>'cycle' OR (on_days IS NOT NULL AND off_days IS NOT NULL)"])
s('schedule_times','Multiple chosen local times per schedule, independent of UTC offsets.', '''schedule_rule_id TEXT NOT NULL; hour INTEGER NOT NULL CHECK(hour BETWEEN 0 AND 23); minute INTEGER NOT NULL CHECK(minute BETWEEN 0 AND 59); position INTEGER NOT NULL''',refs=[('schedule_rule_id','schedule_rules')],uniques=['account_id, schedule_rule_id, hour, minute'],immutable=True)
s('dose_occurrences','Materialized expected occurrence and notification state; no inferred recommended amount.', '''protocol_step_id TEXT NOT NULL; schedule_rule_id TEXT NOT NULL; occurrence_key TEXT NOT NULL; due_at INTEGER NOT NULL; late_after_at INTEGER NOT NULL; expires_at INTEGER; tz TEXT NOT NULL; local_date TEXT NOT NULL; state TEXT NOT NULL CHECK(state IN ('due','taken','late','skipped','missed')); snoozed_until INTEGER; state_reason TEXT; resolved_dose_id TEXT''',refs=[('protocol_step_id','protocol_steps'),('schedule_rule_id','schedule_rules'),('resolved_dose_id','dose_logs')],uniques=['account_id, occurrence_key'],checks=['late_after_at>=due_at'])
s('dose_logs','Stable logged-dose identity; all edits/deletions are new immutable revisions.', '''compound_id TEXT NOT NULL; occurrence_id TEXT; current_revision_id TEXT; duplicate_guard_ack_at INTEGER; duplicate_guard_reason TEXT''',refs=[('compound_id','compounds'),('occurrence_id','dose_occurrences'),('current_revision_id','dose_revisions')])
s('dose_revisions','Exact user-confirmed dose snapshots, site/reaction/check-in and audit history.', AMOUNT+'''; dose_log_id TEXT NOT NULL; parent_revision_id TEXT; writer_device_id TEXT NOT NULL; action TEXT NOT NULL CHECK(action IN ('upsert','tombstone','restore')); route TEXT NOT NULL; vial_id TEXT; site_id TEXT; syringe_id TEXT; draw_volume_ul INTEGER CHECK(draw_volume_ul>0); needle_description TEXT; lot_snapshot TEXT; notes TEXT; edit_reason TEXT; energy INTEGER CHECK(energy BETWEEN 1 AND 5); appetite INTEGER CHECK(appetite BETWEEN 1 AND 5); mood INTEGER CHECK(mood BETWEEN 1 AND 5); sleep INTEGER CHECK(sleep BETWEEN 1 AND 5); pain INTEGER CHECK(pain BETWEEN 0 AND 5); redness INTEGER CHECK(redness BETWEEN 0 AND 5); bruise INTEGER CHECK(bruise BETWEEN 0 AND 5); user_confirmed_at INTEGER NOT NULL''',refs=[('dose_log_id','dose_logs'),('parent_revision_id','dose_revisions'),('writer_device_id','devices'),('vial_id','vials'),('site_id','injection_sites'),('syringe_id','syringes')],timed=True,immutable=True,checks=[AMOUNT_CHECK,"action<>'tombstone' OR deleted_at IS NOT NULL"])
s('vials','Vial/pen/container lifecycle and label-entered dates. Remaining inventory is ledger-derived.', '''label TEXT NOT NULL; form TEXT NOT NULL CHECK(form IN ('vial','pen','tablet','nasal','topical','other')); lifecycle TEXT NOT NULL CHECK(lifecycle IN ('sealed','opened','in_use','empty','expired','discarded')); lot TEXT; supplier_note TEXT; price_minor INTEGER CHECK(price_minor>=0); currency TEXT CHECK(length(currency)=3); storage TEXT CHECK(storage IN ('fridge','freezer','room','other')); received_at INTEGER; opened_at INTEGER; reconstituted_at INTEGER; beyond_use_at INTEGER; label_expiry_at INTEGER; diluent_ul INTEGER CHECK(diluent_ul>0); final_solution_ul INTEGER CHECK(final_solution_ul>0); volume_basis TEXT CHECK(volume_basis IN ('label_final_volume','label_confirms_added_equals_final')); volume_label_evidence TEXT; notes TEXT''')
s('vial_components','Per-component initial exact amount supports blends without converting IU into mass.', AMOUNT+'''; vial_id TEXT NOT NULL; compound_id TEXT NOT NULL; ratio_value INTEGER CHECK(ratio_value>0); ratio_scale INTEGER CHECK(ratio_scale BETWEEN 0 AND 6)''',refs=[('vial_id','vials'),('compound_id','compounds')],checks=[AMOUNT_CHECK],uniques=['account_id, vial_id, compound_id'])
s('inventory_ledger','Immutable signed inventory movements; corrections reverse old movements then append replacements.', '''vial_id TEXT NOT NULL; compound_id TEXT; dose_revision_id TEXT; reverses_entry_id TEXT; transaction_id TEXT NOT NULL; movement TEXT NOT NULL CHECK(movement IN ('opening','dose','priming','waste','correction','reversal')); amount_value INTEGER NOT NULL CHECK(amount_value<>0); amount_unit TEXT NOT NULL CHECK(amount_unit IN ('ug','uL','IU','click')); amount_scale INTEGER NOT NULL; entered_value TEXT NOT NULL; entered_unit TEXT NOT NULL; reason TEXT; writer_device_id TEXT NOT NULL''',refs=[('vial_id','vials'),('compound_id','compounds'),('dose_revision_id','dose_revisions'),('reverses_entry_id','inventory_ledger'),('writer_device_id','devices')],checks=[AMOUNT_CHECK,"movement<>'opening' OR amount_value>0","movement NOT IN ('dose','priming','waste') OR amount_value<0","(movement='reversal')=(reverses_entry_id IS NOT NULL)"],uniques=['account_id, reverses_entry_id'],immutable=True,timed=True)
s('injection_sites','User-managed body-map zones, side, route tags and avoid-zone notes.', '''name TEXT NOT NULL; body_region TEXT NOT NULL; side TEXT CHECK(side IN ('left','right','midline')); surface TEXT NOT NULL CHECK(surface IN ('front','back')); route_tag TEXT CHECK(route_tag IN ('SC','IM','other')); avoid INTEGER NOT NULL DEFAULT 0 CHECK(avoid IN (0,1)); notes TEXT; map_x REAL CHECK(map_x BETWEEN 0 AND 1); map_y REAL CHECK(map_y BETWEEN 0 AND 1)''')
s('symptom_logs','Symptom severity/onset and optional dose relationship; descriptive log only.', '''name TEXT NOT NULL; severity INTEGER NOT NULL CHECK(severity BETWEEN 1 AND 5); dose_log_id TEXT; ended_at INTEGER; notes TEXT; user_red_flag_ack_at INTEGER''',refs=[('dose_log_id','dose_logs')],timed=True,checks=['ended_at IS NULL OR ended_at>=occurred_at'])
s('symptom_protocols','Many-to-many symptom/protocol association.', '''symptom_id TEXT NOT NULL; protocol_id TEXT NOT NULL''',refs=[('symptom_id','symptom_logs'),('protocol_id','protocols')],uniques=['account_id, symptom_id, protocol_id'])
s('syringes','User-confirmed syringe/pen calibration; no assumed activity-to-mass equivalence.', '''name TEXT NOT NULL; kind TEXT NOT NULL CHECK(kind IN ('syringe','pen','other')); capacity_ul INTEGER CHECK(capacity_ul>0); units_per_ml_coefficient INTEGER CHECK(units_per_ml_coefficient>0); units_per_ml_scale INTEGER CHECK(units_per_ml_scale BETWEEN 0 AND 6); per_click_value INTEGER CHECK(per_click_value>0); per_click_unit TEXT CHECK(per_click_unit IN ('ug','uL','IU')); per_click_scale INTEGER; label_confirmation_at INTEGER NOT NULL; citation_or_label TEXT NOT NULL''',checks=["kind<>'syringe' OR (capacity_ul IS NOT NULL AND units_per_ml_coefficient IS NOT NULL AND units_per_ml_scale IS NOT NULL)","kind<>'pen' OR (per_click_value IS NOT NULL AND per_click_unit IS NOT NULL AND per_click_scale IS NOT NULL AND ((per_click_unit IN ('ug','uL') AND per_click_scale=0) OR (per_click_unit='IU' AND per_click_scale=6)))"])
s('calculator_presets','User-saved math inputs linked to one vial; calculation is rerun rather than storing authoritative advice.', AMOUNT+'''; vial_id TEXT NOT NULL; syringe_id TEXT; compound_id TEXT; diluent_ul INTEGER CHECK(diluent_ul>0); final_solution_ul INTEGER NOT NULL CHECK(final_solution_ul>0); volume_basis TEXT NOT NULL CHECK(volume_basis IN ('label_final_volume','label_confirms_added_equals_final')); volume_label_evidence TEXT NOT NULL CHECK(length(volume_label_evidence)>0); method_version TEXT NOT NULL; label_verified_at INTEGER NOT NULL; notes TEXT''',refs=[('vial_id','vials'),('syringe_id','syringes'),('compound_id','compounds')],checks=[AMOUNT_CHECK])
s('export_jobs','Separately consented private Stack export; never included implicitly in a core export.', '''format TEXT NOT NULL CHECK(format IN ('json','csv','bundle')); status TEXT NOT NULL CHECK(status IN ('pending','writing','complete','failed','expired')); output_locator TEXT; sha256 TEXT; row_count INTEGER CHECK(row_count>=0); expires_at INTEGER; consent_id TEXT NOT NULL''',refs=[('consent_id','consents')],synced=False)


# Minimal P0 program-day identity; the P1 progression engine is not implemented here.
t('programs','Program identity needed to start/resume a programme day; generic user-authored structure only.',
  "name TEXT NOT NULL; notes TEXT; current_day_position INTEGER NOT NULL DEFAULT 0 CHECK(current_day_position>=0); archived_at INTEGER")
t('program_days','Ordered programme day points to its routine without copying authored programme text.',
  "program_id TEXT NOT NULL; routine_id TEXT; week_number INTEGER NOT NULL CHECK(week_number>0); day_number INTEGER NOT NULL CHECK(day_number>0); position INTEGER NOT NULL; is_rest_day INTEGER NOT NULL DEFAULT 0 CHECK(is_rest_day IN (0,1)); name TEXT NOT NULL",
  refs=[('program_id','programs'),('routine_id','routines')], uniques=['account_id, program_id, position'])
for spec in SCHEMAS['core']:
    if spec['name'] in ('workouts','training_schedule'):
        spec['columns'] += ['program_day_id TEXT']
        spec['refs'] += [('program_day_id','program_days')]
    if spec['name']=='training_schedule':
        spec['columns']=[c for c in spec['columns'] if not c.startswith('program_key ')]
        spec['columns']+=['program_id TEXT']
        spec['refs']+=[('program_id','programs')]
for db in SCHEMAS:
    table(db,'cached_insights','Rebuildable deterministic insight facts with exact input provenance for the Why sheet.',
      "metric_key TEXT NOT NULL; template_key TEXT NOT NULL; method_version TEXT NOT NULL; window_start TEXT NOT NULL; window_end TEXT NOT NULL; sample_count INTEGER NOT NULL CHECK(sample_count>=0); coverage REAL NOT NULL CHECK(coverage BETWEEN 0 AND 1); slope REAL; delta REAL; noise_mad REAL CHECK(noise_mad>=0); gate_passed INTEGER NOT NULL CHECK(gate_passed IN (0,1)); input_digest TEXT NOT NULL; input_refs_json TEXT NOT NULL CHECK(json_valid(input_refs_json)); rendered_text TEXT NOT NULL; computed_at INTEGER NOT NULL; expires_at INTEGER", synced=False)

t('nutrition_days','Explicit day-completeness status; a food entry alone does not establish a complete day.',
  "local_date TEXT NOT NULL; status TEXT NOT NULL CHECK(status IN ('unknown','partial','complete')); confirmed_at INTEGER; notes TEXT",
  checks=["status<>'complete' OR confirmed_at IS NOT NULL"], uniques=['account_id, local_date'])
for db in SCHEMAS:
    table(db,'sync_context','Private transaction-scoped remote-apply suppression; must reset before commit.',
      "mode TEXT NOT NULL DEFAULT 'local' CHECK(mode IN ('local','remote_apply'))",uniques=['account_id'],synced=False)

# Generation keeps repetitive ownership and audit constraints identical across all tables.
UUID_SQL = "(substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),1,8)||'-'||substr(printf('%012x',CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)),9,4)||'-7'||lower(substr(hex(randomblob(2)),2,3))||'-'||substr('89ab',abs(random()%4)+1,1)||lower(substr(hex(randomblob(2)),2,3))||'-'||lower(hex(randomblob(6))))"

def all_columns(spec):
    cols = [f"id TEXT PRIMARY KEY NOT NULL CHECK({uuid_check('id')})"]
    if spec['name']!='accounts': cols += [f"account_id TEXT NOT NULL CHECK({uuid_check('account_id')})"]
    cols += spec['columns']+META
    return cols

def generate(db):
    tables=SCHEMAS[db]; names={t['name'] for t in tables}
    lines=[f'-- Caliber Phase 0: {db}.sqlite v1. No app database is opened by this file.',
           '-- Requires SQLite >= 3.37, JSON1; configure foreign_keys on EVERY connection.',
           'PRAGMA foreign_keys = ON;','PRAGMA recursive_triggers = ON;','PRAGMA journal_mode = WAL;','PRAGMA synchronous = FULL;',
           f'PRAGMA application_id = {0x43414c43 if db=="core" else 0x43414c53};','BEGIN IMMEDIATE;']
    for spec in tables:
        name=spec['name']; cols=all_columns(spec); cons=[]
        if name!='accounts':
            cons+=['UNIQUE(account_id, id)','FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT']
        for col,target in spec['refs']:
            assert target in names,(db,name,target)
            cons+=[f'FOREIGN KEY(account_id, {col}) REFERENCES {target}(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED']
        for col in [c.split()[0] for c in cols if c.split()[0].endswith('_id') and c.split()[0]!='account_id']:
            cons+=[f'CHECK({col} IS NULL OR ({uuid_check(col)}))']
        for col in [c.split()[0] for c in cols if c.split()[0].endswith('_date') or c.split()[0] in ('starts_on','ends_on','effective_on','valid_from','valid_until','next_local_date','anchor_date')]:
            cons += [f"CHECK({col} IS NULL OR (length({col})=10 AND date({col},'+0 days') IS NOT NULL AND date({col},'+0 days')={col}))"]
        if name!='accounts': cons += ['FOREIGN KEY(account_id, origin_device_id) REFERENCES devices(account_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED']
        cons += [f'CHECK({x})' for x in spec['checks']]
        if spec['immutable']: cons+=['CHECK(updated_at=created_at)']
        cons += [f'UNIQUE({x})' for x in spec['uniques']]
        lines += ['',f'-- {spec["description"]}',f'CREATE TABLE {name} (\n    '+',\n    '.join(cols+cons)+'\n) STRICT;']
        if name!='accounts':
            lines += [f'CREATE INDEX {name}_account_live ON {name}(account_id, deleted_at);']
        for col,target in spec['refs']:
            lines += [f'CREATE INDEX {name}_{col}_fk ON {name}(account_id, {col});']
        if spec['timed']: lines += [f'CREATE INDEX {name}_local_day ON {name}(account_id, local_date, occurred_at) WHERE deleted_at IS NULL;']
    # Every ordinary deletion is a tombstone; account erasure uses an explicit store-erasure workflow.
    for spec in tables:
        name=spec['name']
        lines += [f"CREATE TRIGGER {name}_no_hard_delete BEFORE DELETE ON {name} BEGIN SELECT RAISE(ABORT,'Use tombstones or the explicit account-erasure workflow'); END;"]
        if spec['immutable']:
            lines += [f"CREATE TRIGGER {name}_no_replace BEFORE INSERT ON {name} WHEN EXISTS(SELECT 1 FROM {name} WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Immutable revision ID already exists'); END;"]
            lines += [f"CREATE TRIGGER {name}_append_only BEFORE UPDATE ON {name} BEGIN SELECT RAISE(ABORT,'Append a revision instead of editing immutable history'); END;"]
        else:
            owner=' OR NEW.account_id<>OLD.account_id' if name!='accounts' else ''
            lines += [f"CREATE TRIGGER {name}_identity_immutable BEFORE UPDATE ON {name} WHEN NEW.id<>OLD.id{owner} OR NEW.created_at<>OLD.created_at BEGIN SELECT RAISE(ABORT,'Identity, ownership and creation time are immutable'); END;"]
        if spec['synced']:
            keys=[c.split()[0] for c in all_columns(spec)]
            payload='json_object('+','.join(f"'{k}',NEW.{k}" for k in keys)+')'
            # BLOBs only occur in local health_anchors, which never get envelopes.
            owner='NEW.id' if name=='accounts' else 'NEW.account_id'
            rev='NEW.id' if spec['immutable'] else 'NULL'
            for operation in ['INSERT']+([] if spec['immutable'] else ['UPDATE']):
                lines += [f'''CREATE TRIGGER {name}_outbox_{operation.lower()} AFTER {operation} ON {name}
WHEN NOT EXISTS(SELECT 1 FROM sync_context WHERE account_id={owner} AND mode='remote_apply')
BEGIN
 INSERT INTO sync_outbox(id,account_id,entity_table,entity_id,revision_id,operation,payload_json,created_at,updated_at,source,logical_clock,origin_device_id)
 VALUES({UUID_SQL},{owner},'{name}',NEW.id,{rev},CASE WHEN NEW.deleted_at IS NULL THEN 'upsert' ELSE 'tombstone' END,{payload},NEW.updated_at,NEW.updated_at,NEW.source,NEW.logical_clock,NEW.origin_device_id);
END;''']
    lines+=extra_sql(db)
    lines += ['PRAGMA user_version = 1;','COMMIT;']
    (ROOT/db/'001_v1.up.sql').write_text('\n'.join(lines)+'\n')
    # Down removes an EMPTY new schema only. Existing records require backup/restore, not a destructive downgrade.
    down=['-- Empty-schema inverse only. Refuses populated stores; do not point at an app database.','PRAGMA foreign_keys = ON;','BEGIN IMMEDIATE;',
          'CREATE TEMP TABLE rollback_guard(value INTEGER);',
          "CREATE TEMP TRIGGER populated_guard BEFORE INSERT ON rollback_guard WHEN (SELECT count(*) FROM accounts)>0 BEGIN SELECT RAISE(ABORT,'Refusing downgrade of populated store; restore the verified backup instead'); END;",
          'INSERT INTO rollback_guard VALUES(1);','DROP TRIGGER populated_guard;','DROP TABLE rollback_guard;']
    for view in VIEW_NAMES[db]: down+=[f'DROP VIEW {view};']
    down += [f'DROP TABLE {x["name"]};' for x in reversed(tables)]
    down += ['PRAGMA user_version = 0;','PRAGMA application_id = 0;','COMMIT;','PRAGMA foreign_keys = ON;']
    (ROOT/db/'001_v1.down.sql').write_text('\n'.join(down)+'\n')

VIEW_NAMES={'core':['current_workout_sets','nutrition_daily_raw','training_muscle_daily_raw','body_daily_raw'],
            'stack':['current_doses','inventory_balances','stack_dose_daily_raw','stack_adherence_daily_raw','stack_symptom_daily_raw']}

def extra_sql(db):
    out=[]
    revision_links=[('set_revisions','set_id','workout_sets'),] if db=='core' else [('dose_revisions','dose_log_id','dose_logs'),('protocol_revisions','protocol_id','protocols')]
    for rev,fk,identity in revision_links:
        out += [f'''CREATE TRIGGER {rev}_parent_guard BEFORE INSERT ON {rev}
WHEN NEW.parent_revision_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM {rev} p WHERE p.account_id=NEW.account_id AND p.id=NEW.parent_revision_id AND p.{fk}=NEW.{fk} AND p.logical_clock<NEW.logical_clock)
BEGIN SELECT RAISE(ABORT,'Revision parent must belong to the same record and precede its logical clock'); END;''',
        f'''CREATE TRIGGER {identity}_head_guard BEFORE UPDATE OF current_revision_id ON {identity}
WHEN NEW.current_revision_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM {rev} r WHERE r.account_id=NEW.account_id AND r.id=NEW.current_revision_id AND r.{fk}=NEW.id)
BEGIN SELECT RAISE(ABORT,'Revision head belongs to a different record'); END;''']
    for rev,fk,identity in revision_links:
        out += [f"CREATE TRIGGER {identity}_initial_head BEFORE INSERT ON {identity} WHEN NEW.current_revision_id IS NOT NULL BEGIN SELECT RAISE(ABORT,'Insert identity before selecting an owned revision'); END;"]
    if db=='stack':
        out += ["CREATE TRIGGER dose_identity_fields BEFORE UPDATE OF compound_id,occurrence_id ON dose_logs WHEN NEW.compound_id IS NOT OLD.compound_id OR NEW.occurrence_id IS NOT OLD.occurrence_id BEGIN SELECT RAISE(ABORT,'Correct compound or occurrence through a tombstone and replacement log transaction'); END;"]
    for spec in SCHEMAS[db]:
        if spec['immutable']: continue
        # Monotonic clocks prevent accidental old-write replacement; sync conflicts must be captured before resolution.
        if spec['synced']:
            out += [f'''CREATE TRIGGER {spec['name']}_clock_guard BEFORE UPDATE ON {spec['name']}
WHEN NEW.logical_clock<=OLD.logical_clock OR NEW.updated_at<OLD.updated_at
BEGIN SELECT RAISE(ABORT,'Updates require a newer logical clock and nondecreasing updated_at'); END;''']
    domains="'train','fuel','body','platform'" if db=='core' else "'stack'"
    # Generic references are still closed to a compile-time allowlist and checked for same-account existence.
    allowed=[t['name'] for t in SCHEMAS[db] if t['name'] not in ('sync_outbox','sync_cursors','sync_conflicts','attachments','notification_jobs','series_registry','event_registry','daily_rollups')]
    for table_name in ['attachments','events','notification_jobs']+(['notes'] if db=='core' else []):
        existence=' OR '.join(f"(NEW.owner_table='{name}' AND EXISTS(SELECT 1 FROM {name} e WHERE e.id=NEW.owner_id" + (" AND e.account_id=NEW.account_id" if name!='accounts' else ' AND e.id=NEW.account_id') + '))' for name in allowed)
        for action in ['INSERT','UPDATE']:
            out += [f"CREATE TRIGGER {table_name}_owner_{action.lower()} BEFORE {action} ON {table_name} WHEN NEW.owner_id IS NOT NULL AND NOT ({existence}) BEGIN SELECT RAISE(ABORT,'Owner must exist in this privacy store and account'); END;"]
    if db=='core':
        out += ['CREATE INDEX exercises_search_name ON exercises(account_id, normalized_name);', 'CREATE INDEX exercise_aliases_search ON exercise_aliases(account_id, normalized_alias);', 'CREATE INDEX foods_search_name ON foods(account_id, normalized_name);', 'CREATE INDEX foods_barcode ON foods(account_id, barcode);', 'CREATE INDEX workouts_status ON workouts(account_id,status,occurred_at);']
        for target in ['nutrition_targets','target_overrides']:
            for action in ['INSERT','UPDATE']:
                out += [f'''CREATE TRIGGER {target}_safety_{action.lower()} BEFORE {action} ON {target}
WHEN (NEW.calories_kcal<NEW.safety_floor_kcal AND NOT EXISTS(SELECT 1 FROM safety_acknowledgements a WHERE a.id=NEW.clinician_ack_id AND a.account_id=NEW.account_id AND a.kind='clinician_floor_override' AND a.clinician_override_confirmed=1 AND a.deleted_at IS NULL AND (a.expires_at IS NULL OR a.expires_at>NEW.updated_at)))
 OR (NEW.safety_floor_kcal<1500 AND COALESCE((SELECT bmr_sex FROM accounts WHERE id=NEW.account_id),'unspecified')<>'female')
BEGIN SELECT RAISE(ABORT,'Target requires the applicable safety floor or an explicit current clinician acknowledgement'); END;''']
        out += ['''CREATE VIEW current_workout_sets AS
SELECT r.*, s.workout_exercise_id, s.position FROM workout_sets s JOIN set_revisions r ON r.account_id=s.account_id AND r.id=s.current_revision_id AND r.set_id=s.id
WHERE s.deleted_at IS NULL AND r.deleted_at IS NULL AND r.action<>'tombstone';''',
'''CREATE VIEW nutrition_daily_raw AS
SELECT f.account_id,f.local_date,COUNT(*) AS sample_count,SUM(f.calories_kcal) AS calories_kcal,SUM(f.protein_g) AS protein_g,SUM(f.carbs_g) AS carbs_g,SUM(f.fat_g) AS fat_g
FROM food_logs f JOIN meal_logs m ON m.account_id=f.account_id AND m.id=f.meal_log_id
WHERE f.deleted_at IS NULL AND m.deleted_at IS NULL AND m.state='eaten' GROUP BY f.account_id,f.local_date;''',
'''CREATE VIEW training_muscle_daily_raw AS
SELECT r.account_id,r.local_date,em.muscle_id,
 SUM(CASE WHEN st.counts_hard_sets=1 AND (COALESCE(r.rir,10-r.rpe) IS NULL OR COALESCE(r.rir,10-r.rpe)<=4) THEN em.contribution ELSE 0 END) AS fractional_hard_sets,
 SUM(CASE WHEN st.counts_volume=1 THEN COALESCE(r.load_kg,MAX(0,COALESCE(r.bodyweight_kg,0)+COALESCE(r.added_kg,0)-COALESCE(r.assistance_kg,0)),0)*COALESCE(r.reps,0)*em.contribution*(CASE r.counts_both_hands WHEN 1 THEN 2 ELSE 1 END) ELSE 0 END) AS volume_kg,
 COUNT(DISTINCT we.workout_id) AS sessions
FROM current_workout_sets r JOIN workout_exercises we ON we.account_id=r.account_id AND we.id=r.workout_exercise_id
JOIN workouts w ON w.account_id=we.account_id AND w.id=we.workout_id
JOIN set_types st ON st.account_id=r.account_id AND st.id=r.set_type_id
JOIN exercise_muscles em ON em.account_id=we.account_id AND em.exercise_id=we.exercise_id
WHERE r.completed=1 AND we.deleted_at IS NULL AND w.deleted_at IS NULL AND we.skipped=0 AND em.deleted_at IS NULL
GROUP BY r.account_id,r.local_date,em.muscle_id;''',
'''CREATE VIEW body_daily_raw AS
SELECT account_id,local_date,COUNT(*) AS sample_count,AVG(weight_kg) AS mean_weight_kg,MIN(weight_kg) AS min_weight_kg,MAX(weight_kg) AS max_weight_kg
FROM weigh_ins WHERE deleted_at IS NULL GROUP BY account_id,local_date;''']
    else:
        out += ['''CREATE TRIGGER inventory_reversal_guard BEFORE INSERT ON inventory_ledger
WHEN NEW.reverses_entry_id IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM inventory_ledger p WHERE p.account_id=NEW.account_id AND p.id=NEW.reverses_entry_id AND p.vial_id=NEW.vial_id
 AND p.compound_id IS NEW.compound_id AND p.amount_unit=NEW.amount_unit AND p.amount_scale=NEW.amount_scale AND p.amount_value=-NEW.amount_value)
BEGIN SELECT RAISE(ABORT,'A reversal must exactly compensate the same inventory dimension'); END;''',
'''CREATE VIEW current_doses AS
SELECT r.*,d.compound_id,d.occurrence_id FROM dose_logs d JOIN dose_revisions r ON r.account_id=d.account_id AND r.id=d.current_revision_id AND r.dose_log_id=d.id
WHERE d.deleted_at IS NULL AND r.deleted_at IS NULL AND r.action<>'tombstone';''',
'''CREATE VIEW inventory_balances AS
SELECT account_id,vial_id,compound_id,amount_unit,amount_scale,SUM(amount_value) AS remaining_coefficient
FROM inventory_ledger GROUP BY account_id,vial_id,compound_id,amount_unit,amount_scale;''',
'''CREATE VIEW stack_dose_daily_raw AS
SELECT account_id,local_date,compound_id,amount_unit,amount_scale,SUM(amount_value) AS dose_coefficient,COUNT(*) AS sample_count
FROM current_doses GROUP BY account_id,local_date,compound_id,amount_unit,amount_scale;''',
'''CREATE VIEW stack_adherence_daily_raw AS
SELECT account_id,local_date,COUNT(*) AS expected_count,SUM(CASE WHEN state IN ('taken','late') THEN 1 ELSE 0 END) AS taken_count,
 SUM(CASE WHEN state='skipped' THEN 1 ELSE 0 END) AS skipped_count,SUM(CASE WHEN state='missed' THEN 1 ELSE 0 END) AS missed_count
FROM dose_occurrences WHERE deleted_at IS NULL GROUP BY account_id,local_date;''',
'''CREATE VIEW stack_symptom_daily_raw AS
SELECT account_id,local_date,name,COUNT(*) AS sample_count,MAX(severity) AS maximum_severity,AVG(severity) AS mean_severity
FROM symptom_logs WHERE deleted_at IS NULL GROUP BY account_id,local_date,name;''']
    return out

if __name__=='__main__':
    for db in SCHEMAS:
        (ROOT / db).mkdir(parents=True, exist_ok=True)
        generate(db)
    manifest={db:[dict(name=x['name'],description=x['description'],columns=[c.split()[0] for c in all_columns(x)],references=[dict(column=c,table=target) for c,target in x['refs']],immutable=x['immutable'],synced=x['synced'],timed=x['timed']) for x in tables] for db,tables in SCHEMAS.items()}
    (ROOT/'TABLES.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(', '.join(f'{db}: {len(tables)} tables' for db,tables in SCHEMAS.items()))
