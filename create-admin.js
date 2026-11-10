#!/usr/bin/env node

require('dotenv').config();
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'fantasy_wc2026',
  user: 'postgres',
  password: 'Azerty123'
});

const email = 'admin@wc2026.com';
const password = 'Admin1234!';
const username = 'admin_wc';

const hash = bcrypt.hashSync(password, 10);

pool.query(
  'INSERT INTO users (id, username, email, password_hash, role, created_at) VALUES (gen_random_uuid(), $1, $2, $3, $4, now())',
  [username, email, hash, 'admin']
).then(r => {
  console.log('\n✓ Compte admin créé avec succès!\n');
  console.log('Email:         ' + email);
  console.log('Mot de passe:  ' + password);
  console.log('\nNotez ces identifiants!\n');
  pool.end();
})
.catch(e => {
  if (e.code === '23505') {
    console.log('⚠️ Ce compte existe déjà.');
  } else {
    console.error('Erreur:', e.message);
  }
  pool.end();
});
