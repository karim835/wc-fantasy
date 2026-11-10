require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { connectDB, pool } = require('../config/db');

const PLAYERS = [
  // GK
  { name: 'Thibaut Courtois',   position: 'GK',  club: 'Real Madrid',      nationality: 'Belgium',   price: 6.0,  points: 142, form: 7.8 },
  { name: 'Alisson Becker',     position: 'GK',  club: 'Liverpool',         nationality: 'Brazil',    price: 5.5,  points: 138, form: 7.5 },
  { name: 'Manuel Neuer',       position: 'GK',  club: 'Bayern Munich',     nationality: 'Germany',   price: 5.0,  points: 120, form: 6.9 },
  { name: 'Marc-André ter Stegen', position: 'GK', club: 'Barcelona',       nationality: 'Germany',   price: 5.0,  points: 115, form: 6.7 },
  { name: 'Ederson',            position: 'GK',  club: 'Man City',          nationality: 'Brazil',    price: 5.5,  points: 131, form: 7.2 },
  { name: 'Jordan Pickford',    position: 'GK',  club: 'Everton',           nationality: 'England',   price: 4.5,  points: 105, form: 6.4 },
  { name: 'Mike Maignan',       position: 'GK',  club: 'AC Milan',          nationality: 'France',    price: 5.0,  points: 118, form: 7.0 },
  { name: 'Yann Sommer',        position: 'GK',  club: 'Inter Milan',       nationality: 'Switzerland', price: 4.5, points: 108, form: 6.5 },

  // DEF
  { name: 'Virgil van Dijk',    position: 'DEF', club: 'Liverpool',         nationality: 'Netherlands', price: 7.0, points: 168, form: 8.1 },
  { name: 'Rúben Dias',         position: 'DEF', club: 'Man City',          nationality: 'Portugal',  price: 7.0,  points: 162, form: 7.9 },
  { name: 'Achraf Hakimi',      position: 'DEF', club: 'PSG',               nationality: 'Morocco',   price: 7.5,  points: 175, form: 8.3 },
  { name: 'Trent Alexander-Arnold', position: 'DEF', club: 'Liverpool',     nationality: 'England',   price: 8.0,  points: 185, form: 8.5 },
  { name: 'Andrew Robertson',   position: 'DEF', club: 'Liverpool',         nationality: 'Scotland',  price: 6.5,  points: 155, form: 7.6 },
  { name: 'Theo Hernández',     position: 'DEF', club: 'AC Milan',          nationality: 'France',    price: 7.0,  points: 160, form: 7.8 },
  { name: 'Benjamin Pavard',    position: 'DEF', club: 'Inter Milan',       nationality: 'France',    price: 6.0,  points: 140, form: 7.2 },
  { name: 'Kyle Walker',        position: 'DEF', club: 'Man City',          nationality: 'England',   price: 6.0,  points: 138, form: 7.1 },
  { name: 'Joshua Kimmich',     position: 'DEF', club: 'Bayern Munich',     nationality: 'Germany',   price: 7.5,  points: 172, form: 8.2 },
  { name: 'Marquinhos',         position: 'DEF', club: 'PSG',               nationality: 'Brazil',    price: 6.5,  points: 148, form: 7.4 },
  { name: 'Dayot Upamecano',    position: 'DEF', club: 'Bayern Munich',     nationality: 'France',    price: 6.0,  points: 132, form: 7.0 },
  { name: 'Reece James',        position: 'DEF', club: 'Chelsea',           nationality: 'England',   price: 6.5,  points: 145, form: 7.3 },
  { name: 'Ferland Mendy',      position: 'DEF', club: 'Real Madrid',       nationality: 'France',    price: 5.5,  points: 122, form: 6.8 },
  { name: 'Raphaël Guerreiro',  position: 'DEF', club: 'Bayern Munich',     nationality: 'Portugal',  price: 5.5,  points: 125, form: 6.9 },
  { name: 'Nayef Aguerd',       position: 'DEF', club: 'West Ham',          nationality: 'Morocco',   price: 4.5,  points: 98,  form: 6.2 },
  { name: 'Milan Škriniar',     position: 'DEF', club: 'PSG',               nationality: 'Slovakia',  price: 5.0,  points: 110, form: 6.5 },

  // MID
  { name: 'Kevin De Bruyne',    position: 'MID', club: 'Man City',          nationality: 'Belgium',   price: 12.0, points: 245, form: 9.5 },
  { name: 'Luka Modrić',        position: 'MID', club: 'Real Madrid',       nationality: 'Croatia',   price: 9.0,  points: 198, form: 8.8 },
  { name: 'Casemiro',           position: 'MID', club: 'Man United',        nationality: 'Brazil',    price: 7.5,  points: 165, form: 7.8 },
  { name: 'Pedri',              position: 'MID', club: 'Barcelona',         nationality: 'Spain',     price: 9.5,  points: 210, form: 9.1 },
  { name: 'Gavi',               position: 'MID', club: 'Barcelona',         nationality: 'Spain',     price: 8.5,  points: 195, form: 8.7 },
  { name: 'Jude Bellingham',    position: 'MID', club: 'Real Madrid',       nationality: 'England',   price: 11.0, points: 232, form: 9.3 },
  { name: 'Fede Valverde',      position: 'MID', club: 'Real Madrid',       nationality: 'Uruguay',   price: 8.5,  points: 188, form: 8.6 },
  { name: 'Martin Ødegaard',    position: 'MID', club: 'Arsenal',           nationality: 'Norway',    price: 9.0,  points: 202, form: 8.9 },
  { name: 'Declan Rice',        position: 'MID', club: 'Arsenal',           nationality: 'England',   price: 8.0,  points: 178, form: 8.3 },
  { name: 'Sofyan Amrabat',     position: 'MID', club: 'Fiorentina',        nationality: 'Morocco',   price: 6.5,  points: 148, form: 7.5 },
  { name: 'Hakim Ziyech',       position: 'MID', club: 'Galatasaray',       nationality: 'Morocco',   price: 6.0,  points: 135, form: 7.2 },
  { name: 'Bruno Fernandes',    position: 'MID', club: 'Man United',        nationality: 'Portugal',  price: 9.5,  points: 215, form: 9.0 },
  { name: 'Bernardo Silva',     position: 'MID', club: 'Man City',          nationality: 'Portugal',  price: 8.5,  points: 190, form: 8.7 },
  { name: 'Ilkay Gündogan',     position: 'MID', club: 'Barcelona',         nationality: 'Germany',   price: 7.5,  points: 168, form: 8.0 },
  { name: 'Sandro Tonali',      position: 'MID', club: 'Newcastle',         nationality: 'Italy',     price: 7.0,  points: 158, form: 7.7 },
  { name: 'Khvicha Kvaratskhelia', position: 'MID', club: 'Napoli',         nationality: 'Georgia',   price: 9.0,  points: 205, form: 9.0 },
  { name: 'Phil Foden',         position: 'MID', club: 'Man City',          nationality: 'England',   price: 9.5,  points: 218, form: 9.2 },
  { name: 'Rodrigo',            position: 'MID', club: 'Man City',          nationality: 'Spain',     price: 8.0,  points: 182, form: 8.4 },
  { name: 'Leon Goretzka',      position: 'MID', club: 'Bayern Munich',     nationality: 'Germany',   price: 7.0,  points: 155, form: 7.6 },
  { name: 'Nicolo Barella',     position: 'MID', club: 'Inter Milan',       nationality: 'Italy',     price: 8.0,  points: 178, form: 8.2 },
  { name: 'Leandro Paredes',    position: 'MID', club: 'Roma',              nationality: 'Argentina', price: 6.0,  points: 128, form: 7.0 },
  { name: 'Enzo Fernández',     position: 'MID', club: 'Chelsea',           nationality: 'Argentina', price: 7.5,  points: 165, form: 7.9 },

  // FWD
  { name: 'Erling Haaland',     position: 'FWD', club: 'Man City',          nationality: 'Norway',    price: 14.0, points: 312, form: 9.9 },
  { name: 'Kylian Mbappé',      position: 'FWD', club: 'Real Madrid',       nationality: 'France',    price: 13.5, points: 298, form: 9.8 },
  { name: 'Vinicius Jr',        position: 'FWD', club: 'Real Madrid',       nationality: 'Brazil',    price: 13.0, points: 285, form: 9.7 },
  { name: 'Lionel Messi',       position: 'FWD', club: 'Inter Miami',       nationality: 'Argentina', price: 12.5, points: 275, form: 9.5 },
  { name: 'Cristiano Ronaldo',  position: 'FWD', club: 'Al Nassr',          nationality: 'Portugal',  price: 11.0, points: 252, form: 9.2 },
  { name: 'Robert Lewandowski', position: 'FWD', club: 'Barcelona',         nationality: 'Poland',    price: 11.5, points: 262, form: 9.4 },
  { name: 'Harry Kane',         position: 'FWD', club: 'Bayern Munich',     nationality: 'England',   price: 12.0, points: 270, form: 9.5 },
  { name: 'Karim Benzema',      position: 'FWD', club: 'Al Ittihad',        nationality: 'France',    price: 10.0, points: 228, form: 8.9 },
  { name: 'Romelu Lukaku',      position: 'FWD', club: 'Roma',              nationality: 'Belgium',   price: 9.0,  points: 198, form: 8.5 },
  { name: 'Antoine Griezmann',  position: 'FWD', club: 'Atletico Madrid',   nationality: 'France',    price: 9.5,  points: 212, form: 8.8 },
  { name: 'Neymar Jr',          position: 'FWD', club: 'Al Hilal',          nationality: 'Brazil',    price: 10.5, points: 240, form: 9.0, injury_status: 'Recovering' },
  { name: 'Lautaro Martínez',   position: 'FWD', club: 'Inter Milan',       nationality: 'Argentina', price: 9.5,  points: 215, form: 8.9 },
  { name: 'Bukayo Saka',        position: 'FWD', club: 'Arsenal',           nationality: 'England',   price: 9.0,  points: 205, form: 8.7 },
  { name: 'Marcus Rashford',    position: 'FWD', club: 'Man United',        nationality: 'England',   price: 8.5,  points: 188, form: 8.4 },
  { name: 'Ousmane Dembélé',    position: 'FWD', club: 'PSG',               nationality: 'France',    price: 8.5,  points: 185, form: 8.3 },
  { name: 'Richarlison',        position: 'FWD', club: 'Tottenham',         nationality: 'Brazil',    price: 7.5,  points: 165, form: 7.9 },
  { name: 'Cody Gakpo',         position: 'FWD', club: 'Liverpool',         nationality: 'Netherlands', price: 7.5, points: 168, form: 8.0 },
  { name: 'Ferran Torres',      position: 'FWD', club: 'Barcelona',         nationality: 'Spain',     price: 7.0,  points: 155, form: 7.7 },
  { name: 'Ivan Toney',         position: 'FWD', club: 'Brentford',         nationality: 'England',   price: 7.0,  points: 152, form: 7.6 },
  { name: 'Rafael Leão',        position: 'FWD', club: 'AC Milan',          nationality: 'Portugal',  price: 8.0,  points: 178, form: 8.2 },
  { name: 'Memphis Depay',      position: 'FWD', club: 'Atletico Madrid',   nationality: 'Netherlands', price: 7.0, points: 148, form: 7.5 },
  { name: 'Youssef En-Nesyri',  position: 'FWD', club: 'Sevilla',           nationality: 'Morocco',   price: 7.0,  points: 152, form: 7.6 },
  { name: 'Achraf Dari',        position: 'DEF', club: 'Brest',             nationality: 'Morocco',   price: 4.5,  points: 95,  form: 6.1 },
  { name: 'Azzedine Ounahi',    position: 'MID', club: 'Marseille',         nationality: 'Morocco',   price: 6.0,  points: 130, form: 7.0 },
  { name: 'Sofiane Boufal',     position: 'MID', club: 'Angers',            nationality: 'Morocco',   price: 5.5,  points: 118, form: 6.7 },
  { name: 'Abdessamad Ezzalzouli', position: 'MID', club: 'Osasuna',        nationality: 'Morocco',   price: 5.5,  points: 112, form: 6.5 },
  { name: 'Yassine Bounou',     position: 'GK',  club: 'Al Hilal',          nationality: 'Morocco',   price: 5.0,  points: 115, form: 6.8 },
  { name: 'Romain Saiss',       position: 'DEF', club: 'Besiktas',          nationality: 'Morocco',   price: 5.0,  points: 108, form: 6.5 },
  { name: 'Noussair Mazraoui',  position: 'DEF', club: 'Man United',        nationality: 'Morocco',   price: 5.5,  points: 120, form: 6.9 },
  { name: 'Jawad El Yamiq',     position: 'DEF', club: 'Real Valladolid',   nationality: 'Morocco',   price: 4.5,  points: 90,  form: 6.0 },
  { name: 'Ayoub El Kaabi',     position: 'FWD', club: 'Olympiakos',        nationality: 'Morocco',   price: 7.0,  points: 148, form: 7.5 },
  { name: 'Abde Ezzalzouli',    position: 'FWD', club: 'Osasuna',           nationality: 'Morocco',   price: 6.0,  points: 128, form: 7.0 },
  { name: 'Selim Amallah',      position: 'MID', club: 'Standard Liège',    nationality: 'Morocco',   price: 5.0,  points: 105, form: 6.3 },
];

async function seed() {
  console.log('🌱 Starting database seed...\n');

  try {
    await connectDB();

    // Check if players already seeded
    const existing = await pool.query('SELECT COUNT(*) FROM players');
    if (parseInt(existing.rows[0].count) > 0) {
      console.log(`⚠️  Players already seeded (${existing.rows[0].count} players). Skipping...`);
      console.log('   Run with --force to re-seed: node scripts/seed.js --force');

      if (!process.argv.includes('--force')) {
        process.exit(0);
      }
      console.log('   Clearing existing players...');
      await pool.query('DELETE FROM players');
    }

    // Insert players
    console.log(`📥 Inserting ${PLAYERS.length} players...`);
    let inserted = 0;

    for (const p of PLAYERS) {
      await pool.query(
        `INSERT INTO players (name, position, club, nationality, price, points, form, injury_status, stats)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [
          p.name,
          p.position,
          p.club,
          p.nationality,
          p.price,
          p.points,
          p.form,
          p.injury_status || null,
          JSON.stringify({
            goals: Math.floor(p.points / 12),
            assists: Math.floor(p.points / 18),
            clean_sheets: p.position === 'GK' || p.position === 'DEF' ? Math.floor(p.points / 20) : 0,
            yellow_cards: Math.floor(Math.random() * 4),
            red_cards: Math.random() > 0.9 ? 1 : 0,
            minutes_played: Math.floor(Math.random() * 500) + 600,
          }),
        ]
      );
      inserted++;
      process.stdout.write(`\r   ${inserted}/${PLAYERS.length} players inserted...`);
    }

    console.log('\n');

    // Summary
    const summary = await pool.query(`
      SELECT position, COUNT(*) as count, ROUND(AVG(price)::numeric, 2) as avg_price, MAX(points) as max_points
      FROM players
      GROUP BY position
      ORDER BY position
    `);

    console.log('📊 Summary by position:');
    console.log('─'.repeat(55));
    console.log(' Position │ Count │ Avg Price │ Top Points');
    console.log('─'.repeat(55));
    summary.rows.forEach(r => {
      const pos = r.position.padEnd(8);
      const count = String(r.count).padEnd(5);
      const price = `$${r.avg_price}M`.padEnd(9);
      console.log(` ${pos} │ ${count} │ ${price} │ ${r.max_points}`);
    });
    console.log('─'.repeat(55));

    const total = await pool.query('SELECT COUNT(*) FROM players');
    console.log(`\n✅ Seed complete! ${total.rows[0].count} players in database.\n`);

    process.exit(0);
  } catch (err) {
    console.error('\n❌ Seed failed:', err.message);
    process.exit(1);
  }
}

seed();
