'use strict';
// 版本化 Schema 迁移（docs/02-数据模型设计.md）
// 启动时按 PRAGMA user_version 增量执行。

const migrations = [
  {
    version: 1,
    up(db) {
      db.exec(`
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          email TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          refresh_token_hash TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );

        CREATE TABLE profiles (
          user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
          nickname TEXT,
          gender TEXT,
          birth_date TEXT,
          height_cm REAL,
          weight_kg REAL,
          resting_hr INTEGER,
          max_hr INTEGER,
          pb_5k_sec INTEGER,
          pb_10k_sec INTEGER,
          pb_half_sec INTEGER,
          pb_full_sec INTEGER,
          weekly_km REAL,
          years_running REAL,
          hr_zones_json TEXT
        );

        CREATE TABLE activities (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          provider TEXT NOT NULL DEFAULT 'manual',
          external_id TEXT,
          sport TEXT NOT NULL DEFAULT 'run',
          start_time INTEGER NOT NULL,
          duration_sec INTEGER NOT NULL,
          distance_m REAL NOT NULL,
          elevation_gain_m REAL,
          avg_pace_sec_per_km INTEGER,
          avg_hr INTEGER,
          max_hr INTEGER,
          avg_cadence INTEGER,
          calories INTEGER,
          training_effect REAL,
          source_file TEXT,
          raw_json TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE INDEX idx_activities_user_time ON activities(user_id, start_time DESC);
        CREATE UNIQUE INDEX uq_activities_external
          ON activities(user_id, provider, external_id) WHERE external_id IS NOT NULL;

        CREATE TABLE activity_streams (
          activity_id TEXT PRIMARY KEY REFERENCES activities(id) ON DELETE CASCADE,
          sample_sec INTEGER,
          hr_json TEXT,
          pace_json TEXT,
          cadence_json TEXT,
          alt_json TEXT
        );

        CREATE TABLE activity_laps (
          activity_id TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
          lap_no INTEGER NOT NULL,
          distance_m REAL,
          duration_sec INTEGER,
          avg_hr INTEGER,
          avg_pace INTEGER,
          PRIMARY KEY (activity_id, lap_no)
        );

        CREATE TABLE sync_connections (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          provider TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'connected',
          access_token_enc TEXT,
          refresh_token_enc TEXT,
          token_expires_at INTEGER,
          external_user_id TEXT,
          scopes TEXT,
          cursor TEXT,
          last_sync_at INTEGER,
          last_error TEXT,
          created_at INTEGER NOT NULL,
          UNIQUE (user_id, provider)
        );

        CREATE TABLE sync_jobs (
          id TEXT PRIMARY KEY,
          connection_id TEXT NOT NULL REFERENCES sync_connections(id) ON DELETE CASCADE,
          started_at INTEGER NOT NULL,
          finished_at INTEGER,
          status TEXT NOT NULL DEFAULT 'running',
          added INTEGER NOT NULL DEFAULT 0,
          skipped INTEGER NOT NULL DEFAULT 0,
          error_msg TEXT
        );
        CREATE INDEX idx_sync_jobs_conn ON sync_jobs(connection_id, started_at DESC);

        CREATE TABLE training_plans (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          name TEXT NOT NULL,
          race_type TEXT NOT NULL,
          goal_time_sec INTEGER,
          race_date TEXT,
          start_date TEXT NOT NULL,
          weeks INTEGER NOT NULL,
          sessions_per_week INTEGER NOT NULL,
          vdot REAL,
          status TEXT NOT NULL DEFAULT 'active',
          params_json TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE INDEX idx_plans_user ON training_plans(user_id, created_at DESC);

        CREATE TABLE plan_workouts (
          id TEXT PRIMARY KEY,
          plan_id TEXT NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
          date TEXT NOT NULL,
          week_no INTEGER NOT NULL,
          day_of_week INTEGER NOT NULL,
          order_in_day INTEGER NOT NULL DEFAULT 1,
          workout_type TEXT NOT NULL,
          title TEXT,
          description TEXT,
          target_distance_m REAL,
          target_duration_sec INTEGER,
          pace_min_sec INTEGER,
          pace_max_sec INTEGER,
          hr_zone INTEGER,
          status TEXT NOT NULL DEFAULT 'pending',
          activity_id TEXT REFERENCES activities(id) ON DELETE SET NULL
        );
        CREATE INDEX idx_plan_workouts_plan ON plan_workouts(plan_id, week_no, day_of_week);
      `);
    },
  },
];

module.exports = { migrations };
