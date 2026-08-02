'use strict';
// node:sqlite 连接与迁移执行
const fs = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');
const { migrations } = require('./migrations');

function openDatabase(dbPath) {
  if (dbPath !== ':memory:') {
    fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  }
  const db = new DatabaseSync(dbPath);
  db.exec('PRAGMA journal_mode = WAL;');
  db.exec('PRAGMA foreign_keys = ON;');
  runMigrations(db);
  return db;
}

function runMigrations(db) {
  const row = db.prepare('PRAGMA user_version').get();
  const current = Number(Object.values(row)[0]);
  for (const m of migrations) {
    if (m.version > current) {
      db.exec('BEGIN');
      try {
        m.up(db);
        db.exec(`PRAGMA user_version = ${m.version}`);
        db.exec('COMMIT');
      } catch (err) {
        db.exec('ROLLBACK');
        throw err;
      }
    }
  }
}

module.exports = { openDatabase, runMigrations };
