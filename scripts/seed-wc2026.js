/**
 * FIFA World Cup 2026 — Seed complet
 * 48 nations qualifiées + joueurs clés par équipe
 * Usage: npm run seed:wc2026
 *        npm run seed:wc2026 -- --force  (re-seed)
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { connectDB, pool } = require('../config/db');

// ─── HELPERS ──────────────────────────────────────────────────────────────────
const p = (name, pos, club, nat, price, pts, form, injury = null) => ({
  name, position: pos, club, nationality: nat,
  price, points: pts, form: parseFloat(form.toFixed(1)), injury_status: injury,
});

// ─── PLAYERS BY NATION ────────────────────────────────────────────────────────

const PLAYERS = [

  // ════════════════════════════════════════════════════════
  // 🌍 AFRICA — CAF (10 teams)
  // ════════════════════════════════════════════════════════

  // 🇲🇦 MOROCCO
  p('Yassine Bounou',          'GK',  'Al Hilal',           'Morocco', 5.5, 128, 7.2),
  p('Munir Mohamedi',          'GK',  'Deportivo La Coruña','Morocco', 4.5,  82, 6.0),
  p('Achraf Hakimi',           'DEF', 'PSG',                'Morocco', 8.0, 188, 8.6),
  p('Romain Saiss',            'DEF', 'Besiktas',           'Morocco', 5.0, 112, 6.6),
  p('Noussair Mazraoui',       'DEF', 'Man United',         'Morocco', 5.5, 122, 6.9),
  p('Achraf Dari',             'DEF', 'Brest',              'Morocco', 4.5,  95, 6.1),
  p('Jawad El Yamiq',          'DEF', 'Real Valladolid',    'Morocco', 4.5,  88, 5.9),
  p('Sofyan Amrabat',          'MID', 'Fiorentina',         'Morocco', 6.5, 152, 7.6),
  p('Azzedine Ounahi',         'MID', 'Marseille',          'Morocco', 6.0, 132, 7.1),
  p('Hakim Ziyech',            'MID', 'Galatasaray',        'Morocco', 6.0, 138, 7.2),
  p('Selim Amallah',           'MID', 'Standard Liège',     'Morocco', 5.0, 108, 6.4),
  p('Abdessamad Ezzalzouli',   'MID', 'Betis',              'Morocco', 6.0, 118, 6.8),
  p('Soufiane Rahimi',         'FWD', 'Al Ain',             'Morocco', 6.5, 148, 7.5),
  p('Youssef En-Nesyri',       'FWD', 'Sevilla',            'Morocco', 7.0, 158, 7.7),
  p('Ayoub El Kaabi',          'FWD', 'Olympiakos',         'Morocco', 6.5, 145, 7.4),

  // 🇸🇳 SENEGAL
  p('Édouard Mendy',           'GK',  'Al-Ahli',            'Senegal', 5.0, 108, 6.5),
  p('Kalidou Koulibaly',       'DEF', 'Al Hilal',           'Senegal', 6.5, 148, 7.4),
  p('Abdou Diallo',            'DEF', 'RB Leipzig',         'Senegal', 5.0, 105, 6.4),
  p('Ismail Jakobs',           'DEF', 'Monaco',             'Senegal', 5.0, 102, 6.3),
  p('Formose Mendy',           'DEF', 'Metz',               'Senegal', 4.5,  88, 5.8),
  p('Idrissa Gueye',           'MID', 'Everton',            'Senegal', 6.0, 132, 7.0),
  p('Cheikhou Kouyaté',        'MID', 'Nottm Forest',       'Senegal', 5.5, 118, 6.7),
  p('Nampalys Mendy',          'MID', 'Leicester',          'Senegal', 5.0, 105, 6.3),
  p('Sadio Mané',              'FWD', 'Al Nassr',           'Senegal', 9.5, 218, 9.0),
  p('Ismaïla Sarr',            'FWD', 'Crystal Palace',     'Senegal', 7.0, 158, 7.8),
  p('Habib Diallo',            'FWD', 'Strasbourg',         'Senegal', 6.5, 142, 7.3),
  p('Nicolas Jackson',         'FWD', 'Chelsea',            'Senegal', 7.5, 168, 8.0),

  // 🇪🇬 EGYPT
  p('Mohamed El-Shenawy',      'GK',  'Al-Ahly',            'Egypt',   5.0, 112, 6.6),
  p('Ahmed Hegazy',            'DEF', 'Al-Ittihad',         'Egypt',   5.0, 108, 6.5),
  p('Omar Kamal',              'DEF', 'Zamalek',            'Egypt',   4.5,  88, 5.8),
  p('Ahmed Elmohamady',        'DEF', 'Aston Villa',        'Egypt',   5.0, 102, 6.2),
  p('Mahmoud Trezeguet',       'MID', 'Trabzonspor',        'Egypt',   6.0, 135, 7.1),
  p('Ahmed Elneny',            'MID', 'Arsenal',            'Egypt',   5.5, 122, 6.8),
  p('Hamdy Fathy',             'MID', 'Al-Ahly',            'Egypt',   5.0, 105, 6.4),
  p('Mohamed Salah',           'FWD', 'Liverpool',          'Egypt',  13.0, 295, 9.8),
  p('Mostafa Mohamed',         'FWD', 'Nantes',             'Egypt',   6.5, 148, 7.5),
  p('Omar Marmoush',           'FWD', 'Man City',           'Egypt',   8.0, 178, 8.3),

  // 🇩🇿 ALGERIA
  p('Rais M\'Bolhi',           'GK',  'Al-Taawoun',         'Algeria', 5.0, 108, 6.4),
  p('Aïssa Mandi',             'DEF', 'Villarreal',         'Algeria', 5.5, 118, 6.7),
  p('Ramy Bensebaini',         'DEF', 'Dortmund',           'Algeria', 6.5, 145, 7.5),
  p('Youcef Atal',             'DEF', 'Nice',               'Algeria', 6.0, 132, 7.1),
  p('Mehdi Zeffane',           'DEF', 'Rennes',             'Algeria', 5.0, 102, 6.2),
  p('Ismaël Bennacer',         'MID', 'AC Milan',           'Algeria', 7.0, 158, 7.8),
  p('Sofiane Feghouli',        'MID', 'Galatasaray',        'Algeria', 6.0, 128, 6.9),
  p('Riyad Mahrez',            'MID', 'Al Ahli',            'Algeria', 9.0, 205, 8.8),
  p('Saïd Benrahma',           'MID', 'Lyon',               'Algeria', 7.0, 158, 7.8),
  p('Islam Slimani',           'FWD', 'Sport Boys',         'Algeria', 6.0, 132, 7.0),
  p('Andy Delort',             'FWD', 'Nice',               'Algeria', 6.5, 142, 7.3),
  p('Youcef Belaïli',          'FWD', 'Esperance',          'Algeria', 6.5, 138, 7.2),

  // 🇹🇳 TUNISIA
  p('Aymen Dahmen',            'GK',  'Montpellier',        'Tunisia', 4.5,  92, 6.0),
  p('Dylan Bronn',             'DEF', 'Salernitana',        'Tunisia', 4.5,  88, 5.8),
  p('Montassar Talbi',         'DEF', 'Lorient',            'Tunisia', 5.0, 102, 6.3),
  p('Ali Maaloul',             'DEF', 'Al-Ahly',            'Tunisia', 5.0, 108, 6.5),
  p('Ellyes Skhiri',           'MID', 'Frankfurt',          'Tunisia', 6.5, 148, 7.5),
  p('Anis Ben Slimane',        'MID', 'Brøndby',            'Tunisia', 5.5, 118, 6.7),
  p('Hannibal Mejbri',         'MID', 'Burnley',            'Tunisia', 6.0, 128, 7.0),
  p('Wahbi Khazri',            'FWD', 'Montpellier',        'Tunisia', 6.5, 142, 7.3),
  p('Youssef Msakni',          'FWD', 'Al Gharafa',         'Tunisia', 6.0, 132, 7.0),
  p('Seifeddine Jaziri',       'FWD', 'Montpellier',        'Tunisia', 5.5, 118, 6.6),
  p('Wissam Ben Yedder',       'FWD', 'Monaco',             'Tunisia', 8.0, 172, 8.1),

  // 🇬🇭 GHANA
  p('Lawrence Ati Zigi',       'GK',  'St. Gallen',         'Ghana',   4.5,  88, 5.8),
  p('Andy Yiadom',             'DEF', 'Reading',            'Ghana',   4.5,  90, 5.9),
  p('Daniel Amartey',          'DEF', 'Leicester',          'Ghana',   5.0, 102, 6.2),
  p('Denis Odoi',              'DEF', 'Club Brugge',        'Ghana',   4.5,  88, 5.8),
  p('Thomas Partey',           'MID', 'Arsenal',            'Ghana',   7.5, 168, 8.0),
  p('Mohammed Kudus',          'MID', 'West Ham',           'Ghana',   8.0, 182, 8.4),
  p('Baba Rahman',             'DEF', 'Reading',            'Ghana',   4.5,  88, 5.7),
  p('Jordan Ayew',             'FWD', 'Leicester',          'Ghana',   6.0, 128, 7.0),
  p('André Ayew',              'FWD', 'Le Havre',           'Ghana',   6.5, 138, 7.2),
  p('Antoine Semenyo',         'FWD', 'Bournemouth',        'Ghana',   7.0, 155, 7.7),
  p('Abdul Fatawu Issahaku',   'FWD', 'Leicester',          'Ghana',   7.0, 155, 7.7),

  // 🇨🇮 IVORY COAST
  p('Badra Ali Sangaré',       'GK',  'Toumodi FC',         'Ivory Coast', 4.5, 85, 5.7),
  p('Serge Aurier',            'DEF', 'Villarreal',         'Ivory Coast', 5.5, 118, 6.7),
  p('Eric Bailly',             'DEF', 'Besiktas',           'Ivory Coast', 5.0, 105, 6.3),
  p('Simon Deli',              'DEF', 'Club Brugge',        'Ivory Coast', 4.5,  92, 6.0),
  p('Seko Fofana',             'MID', 'Al Qadisiyah',       'Ivory Coast', 6.5, 142, 7.3),
  p('Franck Kessié',           'MID', 'Barcelona',          'Ivory Coast', 7.5, 168, 8.0),
  p('Jean Michaël Seri',       'MID', 'Fulham',             'Ivory Coast', 5.5, 115, 6.6),
  p('Nicolas Pépé',            'FWD', 'Trabzonspor',        'Ivory Coast', 7.5, 162, 7.9),
  p('Wilfried Zaha',           'FWD', 'Galatasaray',        'Ivory Coast', 8.0, 175, 8.2),
  p('Sebastien Haller',        'FWD', 'Dortmund',           'Ivory Coast', 8.5, 185, 8.5),
  p('Jonathan Kodjia',         'FWD', 'Al Gharafa',         'Ivory Coast', 6.0, 125, 7.0),

  // 🇿🇦 SOUTH AFRICA
  p('Ronwen Williams',         'GK',  'Mamelodi Sundowns',  'South Africa', 4.5, 88, 5.8),
  p('Sifiso Hlanti',           'DEF', 'Kaizer Chiefs',      'South Africa', 4.5, 85, 5.7),
  p('Rushine de Reuck',        'DEF', 'Mamelodi Sundowns',  'South Africa', 4.5, 82, 5.6),
  p('Bongani Zungu',           'MID', 'Rangers',            'South Africa', 5.0, 105, 6.3),
  p('Ethan Nthle',             'MID', 'Mamelodi Sundowns',  'South Africa', 4.5,  88, 5.8),
  p('Themba Zwane',            'MID', 'Mamelodi Sundowns',  'South Africa', 5.5, 118, 6.7),
  p('Percy Tau',               'FWD', 'Al Ahly',            'South Africa', 6.5, 142, 7.3),
  p('Evidence Makgopa',        'FWD', 'Orlando Pirates',    'South Africa', 6.0, 128, 7.0),
  p('Lyle Foster',             'FWD', 'Burnley',            'South Africa', 6.5, 138, 7.2),

  // 🇨🇻 CAPE VERDE
  p('Vozinha',                 'GK',  'Cova Pia',           'Cape Verde', 4.5, 78, 5.5),
  p('Roberto Lopes',           'DEF', 'Shamrock Rovers',    'Cape Verde', 4.5, 82, 5.6),
  p('Ryan Mendes',             'MID', 'Moreirense',         'Cape Verde', 5.5, 112, 6.5),
  p('Garry Rodrigues',         'MID', 'Galatasaray',        'Cape Verde', 5.5, 118, 6.6),
  p('Júlio Tavares',           'FWD', 'Dijon',              'Cape Verde', 5.5, 115, 6.5),
  p('Kenny Rocha',             'FWD', 'Lausanne',           'Cape Verde', 5.0, 102, 6.2),

  // 🇨🇩 DR CONGO
  p('Joël Kiassumbua',         'GK',  'Beerschot',          'DR Congo', 4.5, 85, 5.7),
  p('Chancel Mbemba',          'DEF', 'Porto',              'DR Congo', 5.0, 108, 6.4),
  p('Silas Wissa',             'FWD', 'Brentford',          'DR Congo', 7.0, 155, 7.7),
  p('Cédric Bakambu',          'FWD', 'Beşiktaş',           'DR Congo', 6.5, 138, 7.2),
  p('Yannick Bolasie',         'MID', 'Middlesbrough',      'DR Congo', 6.0, 125, 6.9),
  p('Gaël Kakuta',             'MID', 'Amiens',             'DR Congo', 5.5, 112, 6.5),
  p('Théo Bongonda',           'MID', 'Genk',               'DR Congo', 5.5, 118, 6.6),

  // ════════════════════════════════════════════════════════
  // 🌏 ASIA — AFC (8 teams)
  // ════════════════════════════════════════════════════════

  // 🇯🇵 JAPAN
  p('Shuichi Gonda',           'GK',  'Shimizu S-Pulse',    'Japan',   5.0, 112, 6.6),
  p('Hiroki Sakai',            'DEF', 'Gamba Osaka',        'Japan',   5.0, 108, 6.5),
  p('Takehiro Tomiyasu',       'DEF', 'Arsenal',            'Japan',   5.5, 122, 6.8),
  p('Ko Itakura',              'DEF', 'Gladbach',           'Japan',   5.0, 112, 6.5),
  p('Wataru Endo',             'MID', 'Liverpool',          'Japan',   7.0, 158, 7.8),
  p('Junya Ito',               'MID', 'Stade de Reims',     'Japan',   6.5, 145, 7.5),
  p('Daichi Kamada',           'MID', 'Crystal Palace',     'Japan',   7.0, 155, 7.7),
  p('Ritsu Doan',              'MID', 'Freiburg',           'Japan',   6.5, 148, 7.5),
  p('Hidemasa Morita',         'MID', 'Sporting CP',        'Japan',   6.0, 132, 7.0),
  p('Kaoru Mitoma',            'FWD', 'Brighton',           'Japan',   8.5, 192, 8.6),
  p('Takumi Minamino',         'FWD', 'Monaco',             'Japan',   6.5, 145, 7.4),
  p('Ayase Ueda',              'FWD', 'Feyenoord',          'Japan',   7.0, 158, 7.8),
  p('Takefusa Kubo',           'MID', 'Real Sociedad',      'Japan',   8.5, 195, 8.7),

  // 🇰🇷 SOUTH KOREA
  p('Kim Seung-gyu',           'GK',  'Al-Shabab',          'South Korea', 4.5, 95, 6.1),
  p('Kim Min-jae',             'DEF', 'Bayern Munich',      'South Korea', 7.0, 162, 7.9),
  p('Kim Young-gwon',          'DEF', 'Gam Seoul',          'South Korea', 5.0, 108, 6.4),
  p('Lee Jae-sung',            'MID', 'Mainz',              'South Korea', 5.5, 118, 6.7),
  p('Jung Woo-young',          'MID', 'Al-Qadsiah',         'South Korea', 5.5, 115, 6.5),
  p('Lee Kang-in',             'MID', 'PSG',                'South Korea', 8.0, 182, 8.4),
  p('Son Heung-min',           'FWD', 'Tottenham',          'South Korea',11.5, 258, 9.4),
  p('Hwang Hee-chan',          'FWD', 'Wolverhampton',      'South Korea', 7.5, 168, 8.0),
  p('Cho Gue-sung',            'FWD', 'Midtjylland',        'South Korea', 6.0, 132, 7.0),
  p('Kwon Chang-hoon',         'MID', 'Jeonbuk',            'South Korea', 5.5, 118, 6.6),

  // 🇮🇷 IRAN
  p('Alireza Beiranvand',      'GK',  'Antwerp',            'Iran',    5.0, 108, 6.4),
  p('Shoja Khalilzadeh',       'DEF', 'Tractor SC',         'Iran',    4.5,  88, 5.8),
  p('Ramin Rezaeian',          'DEF', 'Sepahan',            'Iran',    4.5,  85, 5.7),
  p('Milad Mohammadi',         'DEF', 'AEK Athens',         'Iran',    5.0, 102, 6.2),
  p('Saeid Ezatolahi',         'MID', 'Vejle BK',           'Iran',    5.5, 115, 6.6),
  p('Alireza Jahanbakhsh',     'MID', 'Feyenoord',          'Iran',    6.5, 142, 7.4),
  p('Saman Ghoddos',           'MID', 'Brentford',          'Iran',    6.5, 138, 7.2),
  p('Mehdi Taremi',            'FWD', 'Inter Milan',        'Iran',    9.0, 205, 8.8),
  p('Sardar Azmoun',           'FWD', 'Roma',               'Iran',    8.0, 178, 8.2),
  p('Karim Ansarifard',        'FWD', 'Omonia',             'Iran',    5.5, 115, 6.5),

  // 🇦🇺 AUSTRALIA
  p('Mat Ryan',                'GK',  'Real Sociedad',      'Australia', 5.0, 112, 6.5),
  p('Miloš Degenek',           'DEF', 'Columbus Crew',      'Australia', 4.5,  90, 5.9),
  p('Harry Souttar',           'DEF', 'Leicester',          'Australia', 5.0, 105, 6.3),
  p('Aziz Behich',             'DEF', 'Dundee United',      'Australia', 4.5,  88, 5.8),
  p('Jackson Irvine',          'MID', 'St. Pauli',          'Australia', 5.5, 118, 6.7),
  p('Riley McGree',            'MID', 'Middlesbrough',      'Australia', 6.0, 132, 7.0),
  p('Aaron Mooy',              'MID', 'Celtic',             'Australia', 6.5, 142, 7.3),
  p('Matthew Leckie',          'FWD', 'Melbourne City',     'Australia', 5.5, 118, 6.6),
  p('Mitchell Duke',           'FWD', 'Fagiano Okayama',    'Australia', 5.5, 112, 6.5),
  p('Martin Boyle',            'FWD', 'Panathinaikos',      'Australia', 6.0, 128, 7.0),

  // 🇸🇦 SAUDI ARABIA
  p('Mohammed Al-Owais',       'GK',  'Al-Hilal',           'Saudi Arabia', 4.5, 95, 6.1),
  p('Ali Al-Bulayhi',          'DEF', 'Al-Hilal',           'Saudi Arabia', 4.5, 88, 5.8),
  p('Sultan Al-Ghannam',       'DEF', 'Al-Nassr',           'Saudi Arabia', 4.5, 85, 5.7),
  p('Abdullah Madu',           'DEF', 'Al-Hilal',           'Saudi Arabia', 4.5, 82, 5.6),
  p('Ali Al-Hassan',           'MID', 'Al-Shabab',          'Saudi Arabia', 5.0, 105, 6.3),
  p('Saleh Al-Shehri',         'FWD', 'Al-Hilal',           'Saudi Arabia', 6.5, 142, 7.3),
  p('Salem Al-Dawsari',        'FWD', 'Al-Hilal',           'Saudi Arabia', 7.5, 168, 8.0),
  p('Firas Al-Buraikan',       'FWD', 'Al-Fateh',           'Saudi Arabia', 6.5, 138, 7.2),
  p('Mohammed Al-Qasem',       'MID', 'Al-Ittihad',         'Saudi Arabia', 5.0, 102, 6.2),

  // 🇶🇦 QATAR
  p('Saad Al-Sheeb',           'GK',  'Al-Sadd',            'Qatar',   4.5, 85, 5.7),
  p('Pedro Miguel',            'DEF', 'Al-Sadd',            'Qatar',   4.5, 88, 5.8),
  p('Bassam Al-Rawi',          'DEF', 'Al-Duhail',          'Qatar',   4.5, 82, 5.6),
  p('Abdelkarim Hassan',       'DEF', 'Al-Sadd',            'Qatar',   5.0, 102, 6.2),
  p('Karim Boudiaf',           'MID', 'Al-Duhail',          'Qatar',   5.0, 105, 6.3),
  p('Akram Afif',              'MID', 'Al-Sadd',            'Qatar',   7.0, 155, 7.7),
  p('Almoez Ali',              'FWD', 'Al-Duhail',          'Qatar',   7.0, 158, 7.8),
  p('Hassan Al-Haydos',        'FWD', 'Al-Sadd',            'Qatar',   6.0, 128, 7.0),

  // 🇺🇿 UZBEKISTAN
  p('Eldorbek Suyunov',        'GK',  'Pakhtakor',          'Uzbekistan', 4.5, 78, 5.4),
  p('Shamsiddin Latipov',      'DEF', 'Pakhtakor',          'Uzbekistan', 4.5, 80, 5.5),
  p('Otabek Shukurov',         'DEF', 'Pakhtakor',          'Uzbekistan', 4.5, 78, 5.4),
  p('Jaloliddin Masharipov',   'MID', 'Pakhtakor',          'Uzbekistan', 5.5, 118, 6.6),
  p('Azizbek Turgunboev',      'MID', 'Pakhtakor',          'Uzbekistan', 5.0, 102, 6.2),
  p('Eldor Shomurodov',        'FWD', 'Roma',               'Uzbekistan', 7.0, 155, 7.7),
  p('Dostonbek Khamdamov',     'FWD', 'Pakhtakor',          'Uzbekistan', 5.5, 112, 6.5),

  // 🇯🇴 JORDAN
  p('Yazeed Abulaila',         'GK',  'Al-Wehdat',          'Jordan',  4.5, 78, 5.4),
  p('Ehsan Haddad',            'DEF', 'Al-Wahdat',          'Jordan',  4.5, 80, 5.5),
  p('Ahmad Harman',            'DEF', 'Al-Faisaly',         'Jordan',  4.5, 78, 5.4),
  p('Musa Al-Tamari',          'MID', 'Montpellier',        'Jordan',  6.0, 128, 7.0),
  p('Yazan Al-Naimat',         'MID', 'Al-Hilal',           'Jordan',  5.0, 105, 6.3),
  p('Baha Faisal',             'MID', 'Al-Wahdat',          'Jordan',  4.5,  88, 5.8),
  p('Hamza Al-Dardour',        'FWD', 'Al-Wehdat',          'Jordan',  5.5, 112, 6.5),

  // ════════════════════════════════════════════════════════
  // 🌎 SOUTH AMERICA — CONMEBOL (6 teams)
  // ════════════════════════════════════════════════════════

  // 🇦🇷 ARGENTINA
  p('Emiliano Martínez',       'GK',  'Aston Villa',        'Argentina', 7.5, 172, 8.2),
  p('Nahuel Molina',           'DEF', 'Atletico Madrid',    'Argentina', 6.5, 148, 7.5),
  p('Nicolás Otamendi',        'DEF', 'Benfica',            'Argentina', 6.0, 135, 7.1),
  p('Cristian Romero',         'DEF', 'Tottenham',          'Argentina', 6.5, 148, 7.5),
  p('Marcos Acuña',            'DEF', 'Sevilla',            'Argentina', 5.5, 122, 6.8),
  p('Rodrigo De Paul',         'MID', 'Atletico Madrid',    'Argentina', 8.0, 182, 8.4),
  p('Leandro Paredes',         'MID', 'Roma',               'Argentina', 6.0, 132, 7.0),
  p('Alexis Mac Allister',     'MID', 'Liverpool',          'Argentina', 8.5, 195, 8.7),
  p('Enzo Fernández',          'MID', 'Chelsea',            'Argentina', 7.5, 168, 8.0),
  p('Lionel Messi',            'FWD', 'Inter Miami',        'Argentina',12.5, 278, 9.5),
  p('Julián Álvarez',          'FWD', 'Man City',           'Argentina', 9.5, 215, 9.0),
  p('Ángel Di María',          'FWD', 'Benfica',            'Argentina', 8.5, 192, 8.6),
  p('Lautaro Martínez',        'FWD', 'Inter Milan',        'Argentina', 9.5, 218, 9.0),

  // 🇧🇷 BRAZIL
  p('Alisson Becker',          'GK',  'Liverpool',          'Brazil',   6.0, 142, 7.5),
  p('Danilo',                  'DEF', 'Juventus',           'Brazil',   5.5, 122, 6.8),
  p('Marquinhos',              'DEF', 'PSG',                'Brazil',   7.0, 162, 7.9),
  p('Thiago Silva',            'DEF', 'Chelsea',            'Brazil',   6.5, 148, 7.4),
  p('Renan Lodi',              'DEF', 'Nottm Forest',       'Brazil',   5.5, 118, 6.7),
  p('Casemiro',                'MID', 'Man United',         'Brazil',   7.5, 168, 7.9),
  p('Bruno Guimarães',         'MID', 'Newcastle',          'Brazil',   8.0, 182, 8.4),
  p('Lucas Paquetá',           'MID', 'West Ham',           'Brazil',   8.0, 180, 8.3),
  p('Fred',                    'MID', 'Man United',         'Brazil',   6.5, 142, 7.3),
  p('Vinicius Jr',             'FWD', 'Real Madrid',        'Brazil',  13.0, 288, 9.7),
  p('Rodrygo',                 'FWD', 'Real Madrid',        'Brazil',   9.5, 215, 9.0),
  p('Richarlison',             'FWD', 'Tottenham',          'Brazil',   7.5, 168, 8.0),
  p('Gabriel Martinelli',      'FWD', 'Arsenal',            'Brazil',   8.5, 192, 8.6),
  p('Raphinha',                'FWD', 'Barcelona',          'Brazil',   9.0, 205, 8.8),

  // 🇺🇾 URUGUAY
  p('Sergio Rochet',           'GK',  'Nacional',           'Uruguay',  4.5,  92, 6.0),
  p('José María Giménez',      'DEF', 'Atletico Madrid',    'Uruguay',  6.5, 148, 7.5),
  p('Ronald Araújo',           'DEF', 'Barcelona',          'Uruguay',  7.0, 162, 7.9),
  p('Mathías Olivera',         'DEF', 'Napoli',             'Uruguay',  5.5, 122, 6.8),
  p('Rodrigo Bentancur',       'MID', 'Tottenham',          'Uruguay',  7.5, 168, 8.0),
  p('Federico Valverde',       'MID', 'Real Madrid',        'Uruguay',  9.0, 208, 8.9),
  p('Giorgian De Arrascaeta',  'MID', 'Flamengo',           'Uruguay',  7.5, 168, 8.0),
  p('Darwin Núñez',            'FWD', 'Liverpool',          'Uruguay',  9.5, 215, 9.0),
  p('Luis Suárez',             'FWD', 'Inter Miami',        'Uruguay',  8.0, 178, 8.2),
  p('Facundo Pellistri',       'FWD', 'Man United',         'Uruguay',  6.5, 145, 7.4),

  // 🇪🇨 ECUADOR
  p('Hernán Galíndez',         'GK',  'Aucas',              'Ecuador',  4.5,  88, 5.8),
  p('Piero Hincapié',          'DEF', 'Leverkusen',         'Ecuador',  6.5, 145, 7.5),
  p('Byron Castillo',          'DEF', 'Racing Club',        'Ecuador',  5.0, 108, 6.4),
  p('Pervis Estupiñán',        'DEF', 'Brighton',           'Ecuador',  6.5, 145, 7.4),
  p('Moisés Caicedo',          'MID', 'Chelsea',            'Ecuador',  9.0, 205, 8.8),
  p('Jeremy Sarmiento',        'MID', 'Brighton',           'Ecuador',  6.5, 142, 7.3),
  p('Gonzalo Plata',           'MID', 'Al-Qadsiah',         'Ecuador',  6.5, 138, 7.2),
  p('Ángel Mena',              'MID', 'León',               'Ecuador',  6.0, 128, 7.0),
  p('Enner Valencia',          'FWD', 'Fenerbahce',         'Ecuador',  7.0, 158, 7.8),
  p('Kevin Rodríguez',         'FWD', 'Ipswich',            'Ecuador',  6.5, 142, 7.3),

  // 🇨🇴 COLOMBIA
  p('Camilo Vargas',           'GK',  'Atlas',              'Colombia', 4.5,  90, 5.9),
  p('Dávinson Sánchez',        'DEF', 'Galatasaray',        'Colombia', 6.0, 132, 7.0),
  p('Jhon Lucumí',             'DEF', 'Bologna',            'Colombia', 5.5, 118, 6.7),
  p('Jordi Alba-style Mojica', 'DEF', 'Girona',             'Colombia', 5.5, 115, 6.6),
  p('Wilmar Barrios',          'MID', 'Zenit',              'Colombia', 5.5, 118, 6.7),
  p('James Rodríguez',         'MID', 'Rayo Vallecano',     'Colombia', 9.0, 205, 8.8),
  p('Juan Cuadrado',           'MID', 'Inter Milan',        'Colombia', 7.0, 158, 7.8),
  p('Luis Díaz',               'FWD', 'Liverpool',          'Colombia',10.0, 228, 9.1),
  p('Radamel Falcao',          'FWD', 'Rayo Vallecano',     'Colombia', 7.5, 165, 7.9),
  p('Rafael Santos Borré',     'FWD', 'Frankfurt',          'Colombia', 7.0, 155, 7.7),
  p('Miguel Ángel Borja',      'FWD', 'River Plate',        'Colombia', 6.5, 142, 7.3),

  // 🇵🇾 PARAGUAY
  p('Antony Silva',            'GK',  'Libertad',           'Paraguay', 4.5, 85, 5.7),
  p('Junior Alonso',           'DEF', 'Atletico Mineiro',   'Paraguay', 5.0, 105, 6.3),
  p('Gustavo Gómez',           'DEF', 'Palmeiras',          'Paraguay', 5.5, 118, 6.7),
  p('Omar Alderete',           'DEF', 'Getafe',             'Paraguay', 5.0, 105, 6.3),
  p('Mathías Villasanti',      'MID', 'Guadalajara',        'Paraguay', 5.5, 112, 6.5),
  p('Andrés Cubas',            'MID', 'Nottm Forest',       'Paraguay', 5.5, 112, 6.5),
  p('Miguel Almirón',          'MID', 'Newcastle',          'Paraguay', 8.0, 178, 8.2),
  p('Julio Enciso',            'FWD', 'Brighton',           'Paraguay', 7.5, 165, 8.0),
  p('Antonio Sanabria',        'FWD', 'Torino',             'Paraguay', 7.0, 155, 7.7),
  p('Óscar Romero',            'FWD', 'Al-Hilal',           'Paraguay', 6.5, 138, 7.2),

  // ════════════════════════════════════════════════════════
  // 🌎 CONCACAF (6 teams incl. hosts)
  // ════════════════════════════════════════════════════════

  // 🇺🇸 USA
  p('Matt Turner',             'GK',  'Nottm Forest',       'USA',      5.5, 118, 6.7),
  p('Walker Zimmerman',        'DEF', 'Nashville SC',       'USA',      4.5,  88, 5.8),
  p('Tim Ream',                'DEF', 'Fulham',             'USA',      5.0, 105, 6.3),
  p('Antonee Robinson',        'DEF', 'Fulham',             'USA',      6.0, 132, 7.0),
  p('Sergiño Dest',            'DEF', 'PSV',                'USA',      6.0, 132, 7.0),
  p('Tyler Adams',             'MID', 'Leeds United',       'USA',      6.5, 142, 7.3),
  p('Weston McKennie',         'MID', 'Juventus',           'USA',      6.5, 145, 7.4),
  p('Yunus Musah',             'MID', 'AC Milan',           'USA',      7.0, 158, 7.8),
  p('Giovanni Reyna',          'MID', 'Nottm Forest',       'USA',      7.5, 165, 8.0),
  p('Christian Pulisic',       'FWD', 'AC Milan',           'USA',      9.0, 205, 8.8),
  p('Folarin Balogun',         'FWD', 'Monaco',             'USA',      7.5, 168, 8.0),
  p('Tim Weah',                'FWD', 'Juventus',           'USA',      7.0, 155, 7.7),

  // 🇲🇽 MEXICO
  p('Guillermo Ochoa',         'GK',  'Salernitana',        'Mexico',   5.5, 122, 6.8),
  p('Jorge Sánchez',           'DEF', 'Ajax',               'Mexico',   5.0, 108, 6.4),
  p('César Montes',            'DEF', 'Monterrey',          'Mexico',   5.0, 105, 6.3),
  p('Gerardo Arteaga',         'DEF', 'Genk',               'Mexico',   5.5, 112, 6.5),
  p('Héctor Moreno',           'DEF', 'Rayados',            'Mexico',   5.0, 105, 6.3),
  p('Edson Álvarez',           'MID', 'West Ham',           'Mexico',   7.0, 158, 7.8),
  p('Andrés Guardado',         'MID', 'Betis',              'Mexico',   6.5, 142, 7.3),
  p('Hirving Lozano',          'FWD', 'PSV',                'Mexico',   8.5, 192, 8.6),
  p('Raúl Jiménez',            'FWD', 'Fulham',             'Mexico',   8.0, 178, 8.2),
  p('Alexis Vega',             'FWD', 'Chivas',             'Mexico',   6.5, 142, 7.3),
  p('Henry Martín',            'FWD', 'Club América',       'Mexico',   6.5, 138, 7.2),

  // 🇨🇦 CANADA
  p('Maxime Crépeau',          'GK',  'LA Galaxy',          'Canada',   5.0, 108, 6.4),
  p('Alistair Johnston',       'DEF', 'Celtic',             'Canada',   5.5, 118, 6.7),
  p('Steven Vitória',          'DEF', 'Maritimo',           'Canada',   4.5,  88, 5.8),
  p('Richie Laryea',           'DEF', 'Nottm Forest',       'Canada',   5.5, 115, 6.6),
  p('Stephen Eustáquio',       'MID', 'Porto',              'Canada',   6.5, 142, 7.3),
  p('Atiba Hutchinson',        'MID', 'Besiktas',           'Canada',   6.0, 128, 7.0),
  p('Mark-Anthony Kaye',       'MID', 'Brøndby',            'Canada',   5.5, 115, 6.6),
  p('Alphonso Davies',         'DEF', 'Bayern Munich',      'Canada',   9.0, 208, 8.9),
  p('Jonathan David',          'FWD', 'Lille',              'Canada',   9.5, 218, 9.1),
  p('Cyle Larin',              'FWD', 'Club Brugge',        'Canada',   7.5, 168, 8.0),
  p('Tajon Buchanan',          'FWD', 'Inter Milan',        'Canada',   7.5, 165, 8.0),
  p('Lucas Cavallini',         'FWD', 'Vancouver',          'Canada',   6.0, 128, 7.0),

  // 🇵🇦 PANAMA
  p('Luis Mejía',              'GK',  'Modena',             'Panama',   4.5, 85, 5.7),
  p('Roderick Miller',         'DEF', 'Zulte Waregem',      'Panama',   4.5, 82, 5.6),
  p('Eric Davis',              'DEF', 'New York City FC',   'Panama',   5.0, 102, 6.2),
  p('Édgar Yoel Bárcenas',     'MID', 'UD Almería',         'Panama',   5.5, 112, 6.5),
  p('Adalberto Carrasquilla',  'MID', 'Al-Fateh',           'Panama',   5.5, 115, 6.6),
  p('Anibal Godoy',            'MID', 'Nashville SC',       'Panama',   5.5, 118, 6.7),
  p('Ismael Díaz',             'FWD', 'Porto',              'Panama',   6.5, 138, 7.2),
  p('Abdiel Ayarza',           'FWD', 'Colón',              'Panama',   5.5, 112, 6.5),

  // 🇭🇹 HAITI
  p('Josué Duverger',          'GK',  'Violette AC',        'Haiti',    4.5, 72, 5.3),
  p('Mechack Jérôme',          'DEF', 'Vancouver',          'Haiti',    4.5, 78, 5.4),
  p('Carlens Arcus',           'DEF', 'Haiti NT',           'Haiti',    4.5, 75, 5.4),
  p('Wilde-Donald Guerrier',   'MID', 'Nantes',             'Haiti',    5.5, 112, 6.5),
  p('Duckens Nazon',           'FWD', 'Troyes',             'Haiti',    6.0, 128, 7.0),
  p('Frantzdy Pierrot',        'FWD', 'New England',        'Haiti',    5.5, 112, 6.4),

  // 🇨🇼 CURAÇAO
  p('Eloy Room',               'GK',  'Columbus Crew',      'Curaçao',  4.5, 82, 5.6),
  p('Cuco Martina',            'DEF', 'CS Vise',            'Curaçao',  5.0, 98, 6.1),
  p('Darryl Lachman',          'DEF', 'ADO Den Haag',       'Curaçao',  4.5, 80, 5.5),
  p('Leandro Bacuna',          'MID', 'Cardiff City',       'Curaçao',  6.0, 128, 7.0),
  p('Jarchinio Antonia',       'MID', 'Kasımpaşa',          'Curaçao',  5.5, 112, 6.5),
  p('Chedrick Troper',         'FWD', 'Roda JC',            'Curaçao',  5.5, 108, 6.4),

  // ════════════════════════════════════════════════════════
  // 🌏 OCEANIA — OFC (1 team)
  // ════════════════════════════════════════════════════════

  // 🇳🇿 NEW ZEALAND
  p('Michael Woud',            'GK',  'PEC Zwolle',         'New Zealand', 4.5, 85, 5.7),
  p('Liberato Cacace',         'DEF', 'Empoli',             'New Zealand', 5.5, 115, 6.6),
  p('Tommy Smith',             'DEF', 'Stoke City',         'New Zealand', 4.5,  90, 5.9),
  p('Tim Payne',               'DEF', 'Wellington Phoenix',  'New Zealand', 4.5, 82, 5.5),
  p('Sarpreet Singh',          'MID', 'Jamshedpur FC',      'New Zealand', 5.5, 112, 6.5),
  p('Marco Rojas',             'MID', 'Macarthur FC',       'New Zealand', 5.5, 108, 6.4),
  p('Clayton Lewis',           'MID', 'Macarthur FC',       'New Zealand', 5.0, 102, 6.2),
  p('Chris Wood',              'FWD', 'Nottm Forest',       'New Zealand', 8.0, 175, 8.1),
  p('Callan Elliot',           'FWD', 'Wellington Phoenix',  'New Zealand', 5.5, 112, 6.5),

  // ════════════════════════════════════════════════════════
  // 🇪🇺 EUROPE — UEFA (16 teams)
  // ════════════════════════════════════════════════════════

  // 🏴󠁧󠁢󠁥󠁮󠁧󠁿 ENGLAND
  p('Jordan Pickford',         'GK',  'Everton',            'England',  5.0, 112, 6.6),
  p('Aaron Ramsdale',          'GK',  'Arsenal',            'England',  5.0, 105, 6.4),
  p('Kyle Walker',             'DEF', 'Man City',           'England',  6.0, 138, 7.1),
  p('Trent Alexander-Arnold',  'DEF', 'Liverpool',          'England',  8.5, 195, 8.7),
  p('Luke Shaw',               'DEF', 'Man United',         'England',  6.0, 132, 7.0),
  p('John Stones',             'DEF', 'Man City',           'England',  6.0, 135, 7.1),
  p('Marc Guéhi',              'DEF', 'Crystal Palace',     'England',  6.0, 132, 7.0),
  p('Kieran Trippier',         'DEF', 'Newcastle',          'England',  7.5, 168, 8.0),
  p('Declan Rice',             'MID', 'Arsenal',            'England',  8.0, 182, 8.4),
  p('Jude Bellingham',         'MID', 'Real Madrid',        'England', 11.5, 245, 9.3),
  p('Phil Foden',              'MID', 'Man City',           'England',  9.5, 222, 9.2),
  p('Mason Mount',             'MID', 'Man United',         'England',  7.0, 155, 7.7),
  p('Harry Kane',              'FWD', 'Bayern Munich',      'England', 12.5, 278, 9.5),
  p('Bukayo Saka',             'FWD', 'Arsenal',            'England',  9.5, 218, 9.0),
  p('Raheem Sterling',         'FWD', 'Chelsea',            'England',  8.0, 178, 8.2),
  p('Marcus Rashford',         'FWD', 'Man United',         'England',  8.5, 188, 8.5),

  // 🇫🇷 FRANCE
  p('Mike Maignan',            'GK',  'AC Milan',           'France',   5.5, 125, 7.1),
  p('Hugo Lloris',             'GK',  'Tottenham',          'France',   5.5, 118, 6.8),
  p('Theo Hernández',          'DEF', 'AC Milan',           'France',   7.0, 162, 7.9),
  p('Raphaël Varane',          'DEF', 'Man United',         'France',   6.5, 145, 7.4),
  p('William Saliba',          'DEF', 'Arsenal',            'France',   6.5, 148, 7.5),
  p('Benjamin Pavard',         'DEF', 'Inter Milan',        'France',   6.0, 138, 7.2),
  p('Eduardo Camavinga',       'MID', 'Real Madrid',        'France',   8.0, 182, 8.4),
  p('Aurélien Tchouaméni',     'MID', 'Real Madrid',        'France',   8.0, 178, 8.3),
  p('Adrien Rabiot',           'MID', 'Juventus',           'France',   7.0, 158, 7.8),
  p('Kylian Mbappé',           'FWD', 'Real Madrid',        'France',  13.5, 302, 9.8),
  p('Antoine Griezmann',       'FWD', 'Atletico Madrid',    'France',   9.5, 215, 8.9),
  p('Ousmane Dembélé',         'FWD', 'PSG',                'France',   8.5, 188, 8.4),
  p('Randal Kolo Muani',       'FWD', 'PSG',                'France',   8.0, 175, 8.2),
  p('Marcus Thuram',           'FWD', 'Inter Milan',        'France',   8.5, 190, 8.5),

  // 🇩🇪 GERMANY
  p('Manuel Neuer',            'GK',  'Bayern Munich',      'Germany',  5.5, 125, 6.9),
  p('Marc-André ter Stegen',   'GK',  'Barcelona',          'Germany',  5.5, 122, 6.8),
  p('Niklas Süle',             'DEF', 'Dortmund',           'Germany',  5.5, 118, 6.7),
  p('Antonio Rüdiger',         'DEF', 'Real Madrid',        'Germany',  6.5, 148, 7.5),
  p('David Raum',              'DEF', 'RB Leipzig',         'Germany',  6.0, 132, 7.0),
  p('Joshua Kimmich',          'DEF', 'Bayern Munich',      'Germany',  8.0, 182, 8.5),
  p('Leon Goretzka',           'MID', 'Bayern Munich',      'Germany',  7.0, 158, 7.7),
  p('Ilkay Gündogan',          'MID', 'Barcelona',          'Germany',  7.5, 168, 8.0),
  p('Kai Havertz',             'MID', 'Arsenal',            'Germany',  8.5, 192, 8.6),
  p('Leroy Sané',              'FWD', 'Bayern Munich',      'Germany',  9.0, 205, 8.8),
  p('Serge Gnabry',            'FWD', 'Bayern Munich',      'Germany',  8.5, 188, 8.5),
  p('Florian Wirtz',           'FWD', 'Leverkusen',         'Germany',  9.5, 215, 9.0),
  p('Niclas Füllkrug',         'FWD', 'Dortmund',           'Germany',  8.0, 175, 8.2),

  // 🇪🇸 SPAIN
  p('Unai Simón',              'GK',  'Athletic Bilbao',    'Spain',    5.5, 122, 6.9),
  p('Dani Carvajal',           'DEF', 'Real Madrid',        'Spain',    6.5, 148, 7.5),
  p('Pau Torres',              'DEF', 'Aston Villa',        'Spain',    6.0, 135, 7.1),
  p('Aymeric Laporte',         'DEF', 'Al Nassr',           'Spain',    6.0, 132, 7.0),
  p('Jordi Alba',              'DEF', 'Inter Miami',        'Spain',    5.5, 118, 6.7),
  p('Pedri',                   'MID', 'Barcelona',          'Spain',    9.5, 215, 9.1),
  p('Gavi',                    'MID', 'Barcelona',          'Spain',    9.0, 205, 8.9),
  p('Rodrigo Hernández',       'MID', 'Man City',           'Spain',    8.0, 182, 8.4),
  p('Dani Olmo',               'MID', 'Leipzig',            'Spain',    8.5, 192, 8.6),
  p('Álvaro Morata',           'FWD', 'AC Milan',           'Spain',    8.5, 190, 8.5),
  p('Ferran Torres',           'FWD', 'Barcelona',          'Spain',    7.5, 168, 7.9),
  p('Lamine Yamal',            'FWD', 'Barcelona',          'Spain',   10.0, 228, 9.2),
  p('Nico Williams',           'FWD', 'Athletic Bilbao',    'Spain',    9.0, 205, 8.8),

  // 🇵🇹 PORTUGAL
  p('Diogo Costa',             'GK',  'Porto',              'Portugal', 5.5, 122, 6.9),
  p('Rúben Dias',              'DEF', 'Man City',           'Portugal', 7.5, 172, 8.1),
  p('Pepe',                    'DEF', 'Porto',              'Portugal', 5.5, 118, 6.7),
  p('João Cancelo',            'DEF', 'Barcelona',          'Portugal', 7.5, 172, 8.2),
  p('Nuno Mendes',             'DEF', 'PSG',                'Portugal', 6.5, 148, 7.5),
  p('Bruno Fernandes',         'MID', 'Man United',         'Portugal', 9.5, 218, 9.0),
  p('Bernardo Silva',          'MID', 'Man City',           'Portugal', 9.0, 208, 8.9),
  p('Vitinha',                 'MID', 'PSG',                'Portugal', 7.5, 168, 8.0),
  p('João Neves',              'MID', 'Benfica',            'Portugal', 8.0, 178, 8.3),
  p('Cristiano Ronaldo',       'FWD', 'Al Nassr',           'Portugal',11.0, 255, 9.2),
  p('Rafael Leão',             'FWD', 'AC Milan',           'Portugal', 9.0, 205, 8.8),
  p('João Félix',              'FWD', 'Chelsea',            'Portugal', 8.5, 190, 8.5),
  p('Gonçalo Ramos',           'FWD', 'PSG',                'Portugal', 8.5, 188, 8.5),

  // 🇳🇱 NETHERLANDS
  p('Bart Verbruggen',         'GK',  'Brighton',           'Netherlands', 5.0, 108, 6.5),
  p('Virgil van Dijk',         'DEF', 'Liverpool',          'Netherlands', 7.5, 175, 8.2),
  p('Nathan Aké',              'DEF', 'Man City',           'Netherlands', 6.0, 132, 7.0),
  p('Denzel Dumfries',         'DEF', 'Inter Milan',        'Netherlands', 7.0, 158, 7.8),
  p('Daley Blind',             'DEF', 'Girona',             'Netherlands', 5.5, 118, 6.7),
  p('Frenkie de Jong',         'MID', 'Barcelona',          'Netherlands', 9.0, 205, 8.8),
  p('Tijjani Reijnders',       'MID', 'AC Milan',           'Netherlands', 8.0, 178, 8.3),
  p('Teun Koopmeiners',        'MID', 'Juventus',           'Netherlands', 8.0, 178, 8.3),
  p('Cody Gakpo',              'FWD', 'Liverpool',          'Netherlands', 8.0, 178, 8.2),
  p('Memphis Depay',           'FWD', 'Atletico Madrid',    'Netherlands', 7.5, 165, 7.9),
  p('Donyell Malen',           'FWD', 'Dortmund',           'Netherlands', 7.5, 168, 8.0),
  p('Wout Weghorst',           'FWD', 'Burnley',            'Netherlands', 7.0, 155, 7.7),

  // 🇧🇪 BELGIUM
  p('Thibaut Courtois',        'GK',  'Real Madrid',        'Belgium',  7.0, 155, 7.9),
  p('Toby Alderweireld',       'DEF', 'Antwerp',            'Belgium',  5.5, 118, 6.7),
  p('Jan Vertonghen',          'DEF', 'Anderlecht',         'Belgium',  5.5, 115, 6.6),
  p('Timothy Castagne',        'DEF', 'Fulham',             'Belgium',  5.5, 118, 6.7),
  p('Thomas Meunier',          'DEF', 'Trabzonspor',        'Belgium',  5.5, 115, 6.6),
  p('Kevin De Bruyne',         'MID', 'Man City',           'Belgium', 12.5, 252, 9.5),
  p('Axel Witsel',             'MID', 'Atletico Madrid',    'Belgium',  6.5, 142, 7.3),
  p('Youri Tielemans',         'MID', 'Aston Villa',        'Belgium',  7.5, 165, 8.0),
  p('Leandro Trossard',        'MID', 'Arsenal',            'Belgium',  8.0, 178, 8.2),
  p('Romelu Lukaku',           'FWD', 'Roma',               'Belgium',  9.5, 212, 8.7),
  p('Dries Mertens',           'FWD', 'Galatasaray',        'Belgium',  7.5, 162, 7.9),
  p('Lois Openda',             'FWD', 'RB Leipzig',         'Belgium',  8.5, 190, 8.5),
  p('Yannick Carrasco',        'MID', 'Al Shabab',          'Belgium',  7.5, 162, 7.9),

  // 🇭🇷 CROATIA
  p('Dominik Livaković',       'GK',  'Fenerbahce',         'Croatia',  5.0, 112, 6.6),
  p('Josip Juranović',         'DEF', 'Celtic',             'Croatia',  5.0, 108, 6.4),
  p('Joško Gvardiol',          'DEF', 'Man City',           'Croatia',  8.0, 182, 8.4),
  p('Borna Sosa',              'DEF', 'Stuttgart',          'Croatia',  5.5, 118, 6.7),
  p('Luka Modrić',             'MID', 'Real Madrid',        'Croatia',  9.5, 208, 8.9),
  p('Mateo Kovačić',           'MID', 'Man City',           'Croatia',  7.5, 168, 8.0),
  p('Marcelo Brozović',        'MID', 'Al Nassr',           'Croatia',  7.5, 165, 7.9),
  p('Mario Pašalić',           'MID', 'Atalanta',           'Croatia',  7.0, 155, 7.7),
  p('Ivan Perišić',            'FWD', 'Hajduk Split',       'Croatia',  8.0, 175, 8.2),
  p('Andrej Kramarić',         'FWD', 'Hoffenheim',         'Croatia',  8.0, 172, 8.1),
  p('Bruno Petković',          'FWD', 'Dinamo Zagreb',      'Croatia',  7.0, 152, 7.7),

  // 🇦🇹 AUSTRIA
  p('Patrick Pentz',           'GK',  'Bayer Leverkusen',   'Austria',  4.5,  92, 6.0),
  p('Stefan Posch',            'DEF', 'Bologna',            'Austria',  5.0, 108, 6.4),
  p('Phillipp Mwene',          'DEF', 'Mainz',              'Austria',  5.0, 102, 6.2),
  p('David Alaba',             'DEF', 'Real Madrid',        'Austria',  7.0, 155, 7.8),
  p('Marcel Sabitzer',         'MID', 'Man United',         'Austria',  7.5, 165, 8.0),
  p('Konrad Laimer',           'MID', 'Bayern Munich',      'Austria',  7.5, 168, 8.0),
  p('Christoph Baumgartner',   'MID', 'RB Leipzig',         'Austria',  7.5, 165, 8.0),
  p('Florian Grillitsch',      'MID', 'Ajax',               'Austria',  6.0, 128, 7.0),
  p('Marko Arnautović',        'FWD', 'Inter Milan',        'Austria',  8.0, 175, 8.2),
  p('Michael Gregoritsch',     'FWD', 'Freiburg',           'Austria',  7.0, 155, 7.7),

  // 🇨🇭 SWITZERLAND
  p('Yann Sommer',             'GK',  'Inter Milan',        'Switzerland', 5.0, 115, 6.7),
  p('Manuel Akanji',           'DEF', 'Man City',           'Switzerland', 6.5, 145, 7.4),
  p('Silvan Widmer',           'DEF', 'Mainz',              'Switzerland', 5.0, 108, 6.4),
  p('Ricardo Rodríguez',       'DEF', 'Torino',             'Switzerland', 5.0, 105, 6.3),
  p('Granit Xhaka',            'MID', 'Leverkusen',         'Switzerland', 8.0, 178, 8.3),
  p('Denis Zakaria',           'MID', 'Monaco',             'Switzerland', 6.5, 142, 7.3),
  p('Remo Freuler',            'MID', 'Nottm Forest',       'Switzerland', 6.5, 138, 7.2),
  p('Xherdan Shaqiri',         'MID', 'Chicago Fire',       'Switzerland', 7.0, 152, 7.6),
  p('Breel Embolo',            'FWD', 'Monaco',             'Switzerland', 8.0, 175, 8.2),
  p('Haris Seferović',         'FWD', 'Galatasaray',        'Switzerland', 7.0, 152, 7.6),
  p('Noah Okafor',             'FWD', 'AC Milan',           'Switzerland', 7.5, 162, 7.9),

  // 🏴󠁧󠁢󠁳󠁣󠁴󠁿 SCOTLAND
  p('Craig Gordon',            'GK',  'Hearts',             'Scotland',  4.5,  90, 5.9),
  p('Andrew Robertson',        'DEF', 'Liverpool',          'Scotland',  7.5, 175, 8.2),
  p('Kieran Tierney',          'DEF', 'Arsenal',            'Scotland',  6.5, 142, 7.3),
  p('Jack Hendry',             'DEF', 'Club Brugge',        'Scotland',  5.0, 105, 6.3),
  p('Scott McTominay',         'MID', 'Napoli',             'Scotland',  7.5, 168, 8.0),
  p('Billy Gilmour',           'MID', 'Brighton',           'Scotland',  6.5, 142, 7.3),
  p('John McGinn',             'MID', 'Aston Villa',        'Scotland',  7.5, 168, 8.0),
  p('Ryan Christie',           'MID', 'Bournemouth',        'Scotland',  6.0, 128, 7.0),
  p('Che Adams',               'FWD', 'Southampton',        'Scotland',  7.0, 155, 7.7),
  p('Lawrence Shankland',      'FWD', 'Hearts',             'Scotland',  7.0, 152, 7.7),

  // 🇳🇴 NORWAY
  p('Ørjan Nyland',            'GK',  'Nottm Forest',       'Norway',   4.5,  92, 6.0),
  p('Leo Skiri Østigård',      'DEF', 'Napoli',             'Norway',   5.5, 118, 6.7),
  p('Kristoffer Ajer',         'DEF', 'Brentford',          'Norway',   5.5, 118, 6.7),
  p('Birger Meling',           'DEF', 'Rennes',             'Norway',   5.0, 105, 6.3),
  p('Sander Berge',            'MID', 'Burnley',            'Norway',   7.0, 155, 7.7),
  p('Martin Ødegaard',         'MID', 'Arsenal',            'Norway',   9.5, 215, 9.0),
  p('Morten Thorsby',          'MID', 'Genoa',              'Norway',   6.0, 128, 7.0),
  p('Erling Haaland',          'FWD', 'Man City',           'Norway',  14.5, 322, 9.9),
  p('Alexander Sørloth',       'FWD', 'Atletico Madrid',    'Norway',   8.5, 190, 8.5),

  // 🇸🇪 SWEDEN
  p('Robin Olsen',             'GK',  'Aston Villa',        'Sweden',   4.5,  90, 5.9),
  p('Victor Lindelöf',         'DEF', 'Man United',         'Sweden',   5.5, 118, 6.7),
  p('Ludwig Augustinsson',     'DEF', 'Mallorca',           'Sweden',   5.0, 105, 6.3),
  p('Jesper Karlsson',         'MID', 'Bologna',            'Sweden',   7.0, 155, 7.7),
  p('Emil Forsberg',           'MID', 'RB Leipzig',         'Sweden',   7.5, 162, 7.9),
  p('Mattias Svanberg',        'MID', 'Wolfsburg',          'Sweden',   6.0, 128, 7.0),
  p('Alexander Isak',          'FWD', 'Newcastle',          'Sweden',   9.5, 215, 9.0),
  p('Dejan Kulusevski',        'FWD', 'Tottenham',          'Sweden',   9.0, 205, 8.8),
  p('Robin Quaison',           'FWD', 'Mainz',              'Sweden',   6.5, 138, 7.2),

  // 🇨🇿 CZECH REPUBLIC
  p('Jiří Staněk',             'GK',  'Slavia Prague',      'Czech Republic', 4.5, 90, 5.9),
  p('Vladimír Coufal',         'DEF', 'West Ham',           'Czech Republic', 5.5, 118, 6.7),
  p('Tomáš Souček',            'MID', 'West Ham',           'Czech Republic', 7.5, 165, 8.0),
  p('Lukáš Provod',            'MID', 'Slavia Prague',      'Czech Republic', 6.0, 128, 7.0),
  p('Antonín Barák',           'MID', 'Fiorentina',         'Czech Republic', 7.0, 152, 7.7),
  p('Patrik Schick',           'FWD', 'Leverkusen',         'Czech Republic', 9.5, 215, 9.0),
  p('Adam Hložek',             'FWD', 'Leverkusen',         'Czech Republic', 8.0, 175, 8.2),
  p('Matěj Jurásek',           'FWD', 'Slavia Prague',      'Czech Republic', 6.5, 138, 7.2),

  // 🇹🇷 TURKEY
  p('Uğurcan Çakır',           'GK',  'Trabzonspor',        'Turkey',   5.0, 108, 6.4),
  p('Zeki Çelik',              'DEF', 'Roma',               'Turkey',   5.5, 118, 6.7),
  p('Merih Demiral',           'DEF', 'Al Qadsiyah',        'Turkey',   6.5, 145, 7.4),
  p('Mert Müldür',             'DEF', 'Sassuolo',           'Turkey',   5.5, 115, 6.6),
  p('Hakan Çalhanoğlu',        'MID', 'Inter Milan',        'Turkey',   8.5, 192, 8.6),
  p('Kaan Ayhan',              'MID', 'Galatasaray',        'Turkey',   6.0, 128, 7.0),
  p('Samet Akaydın',           'DEF', 'Fenerbahce',         'Turkey',   5.5, 112, 6.5),
  p('Arda Güler',              'MID', 'Real Madrid',        'Turkey',   9.0, 205, 8.9),
  p('Yusuf Yazıcı',            'MID', 'LOSC Lille',         'Turkey',   7.5, 162, 7.9),
  p('Kerem Aktürkoğlu',        'FWD', 'Galatasaray',        'Turkey',   8.0, 175, 8.2),
  p('Kenan Yıldız',            'FWD', 'Juventus',           'Turkey',   9.0, 205, 8.9),
  p('Baris Alper Yilmaz',      'FWD', 'Galatasaray',        'Turkey',   7.5, 162, 7.9),

  // 🇧🇦 BOSNIA & HERZEGOVINA
  p('Nikola Vasilj',           'GK',  'St. Pauli',          'Bosnia',   4.5,  88, 5.8),
  p('Sead Kolašinac',          'DEF', 'Marseille',          'Bosnia',   6.0, 128, 7.0),
  p('Ermin Bičakčić',          'DEF', 'Leverkusen',         'Bosnia',   5.0, 102, 6.2),
  p('Amer Gojak',              'MID', 'Dinamo Zagreb',      'Bosnia',   6.0, 128, 7.0),
  p('Miralem Pjanić',          'MID', 'Sharjah FC',         'Bosnia',   8.0, 175, 8.1),
  p('Ognjen Todorović',        'MID', 'Kardemir Karabük',   'Bosnia',   5.5, 112, 6.5),
  p('Edin Džeko',              'FWD', 'Fenerbahce',         'Bosnia',   9.0, 202, 8.7),
  p('Ermedin Demirović',       'FWD', 'Augsburg',           'Bosnia',   7.5, 165, 8.0),
  p('Vedat Muriqi',            'FWD', 'Mallorca',           'Bosnia',   7.5, 162, 7.9),
];

// ─── SEED FUNCTION ────────────────────────────────────────────────────────────
async function seed() {
  console.log('\n🌍 FIFA World Cup 2026 — Player Seed\n');
  await connectDB();

  const force = process.argv.includes('--force');

  // Get already seeded nationalities to avoid full duplicates
  const existing = await pool.query(
    'SELECT DISTINCT nationality FROM players'
  );
  const seededNats = new Set(existing.rows.map(r => r.nationality));

  const toInsert = force
    ? PLAYERS
    : PLAYERS.filter(pl => !seededNats.has(pl.nationality));

  if (toInsert.length === 0) {
    console.log('✅ All WC2026 nations already seeded. Use --force to re-seed.\n');
    process.exit(0);
  }

  // Count by nation
  const nationCount = {};
  toInsert.forEach(p => {
    nationCount[p.nationality] = (nationCount[p.nationality] || 0) + 1;
  });

  console.log(`📥 Inserting ${toInsert.length} players from ${Object.keys(nationCount).length} nations...\n`);

  let inserted = 0;
  let skipped = 0;

  for (const pl of toInsert) {
    const alreadyExists = await pool.query(
      'SELECT id FROM players WHERE name = $1',
      [pl.name]
    );

    if (alreadyExists.rows.length > 0 && !force) {
      skipped++;
      continue;
    }

    if (alreadyExists.rows.length > 0 && force) {
      await pool.query(
        `UPDATE players SET
           position=$1, club=$2, nationality=$3,
           price=$4, points=$5, form=$6, injury_status=$7
         WHERE name=$8`,
        [pl.position, pl.club, pl.nationality, pl.price, pl.points, pl.form, pl.injury_status, pl.name]
      );
    } else {
      await pool.query(
        `INSERT INTO players (name, position, club, nationality, price, points, form, injury_status, stats)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [
          pl.name, pl.position, pl.club, pl.nationality,
          pl.price, pl.points, pl.form, pl.injury_status,
          JSON.stringify({
            goals: Math.floor(pl.points / 14),
            assists: Math.floor(pl.points / 20),
            clean_sheets: (pl.position === 'GK' || pl.position === 'DEF') ? Math.floor(pl.points / 22) : 0,
            minutes_played: pl.form > 6 ? 850 : 620,
          }),
        ]
      );
    }
    inserted++;
  }

  // Summary
  console.log('📊 Nations seeded:');
  console.log('─'.repeat(55));
  const grouped = {};
  PLAYERS.forEach(p => { (grouped[p.nationality] = grouped[p.nationality] || []).push(p); });
  Object.entries(grouped)
    .sort(([a],[b]) => a.localeCompare(b))
    .forEach(([nat, pls]) => {
      const flag = { Morocco:'🇲🇦', Senegal:'🇸🇳', Egypt:'🇪🇬', Algeria:'🇩🇿', Tunisia:'🇹🇳',
        Ghana:'🇬🇭', 'Ivory Coast':'🇨🇮', 'South Africa':'🇿🇦', 'Cape Verde':'🇨🇻', 'DR Congo':'🇨🇩',
        Japan:'🇯🇵', 'South Korea':'🇰🇷', Iran:'🇮🇷', Australia:'🇦🇺', 'Saudi Arabia':'🇸🇦',
        Qatar:'🇶🇦', Uzbekistan:'🇺🇿', Jordan:'🇯🇴', Argentina:'🇦🇷', Brazil:'🇧🇷',
        Uruguay:'🇺🇾', Ecuador:'🇪🇨', Colombia:'🇨🇴', Paraguay:'🇵🇾', USA:'🇺🇸',
        Mexico:'🇲🇽', Canada:'🇨🇦', Panama:'🇵🇦', Haiti:'🇭🇹', 'Curaçao':'🇨🇼',
        'New Zealand':'🇳🇿', England:'🏴󠁧󠁢󠁥󠁮󠁧󠁿', France:'🇫🇷', Germany:'🇩🇪', Spain:'🇪🇸',
        Portugal:'🇵🇹', Netherlands:'🇳🇱', Belgium:'🇧🇪', Croatia:'🇭🇷', Austria:'🇦🇹',
        Switzerland:'🇨🇭', Scotland:'🏴󠁧󠁢󠁳󠁣󠁴󠁿', Norway:'🇳🇴', Sweden:'🇸🇪',
        'Czech Republic':'🇨🇿', Turkey:'🇹🇷', 'Bosnia':'🇧🇦',
      }[nat] || '🌍';
      console.log(`  ${flag} ${nat.padEnd(20)} ${pls.length} players`);
    });

  const total = await pool.query('SELECT COUNT(*) FROM players');
  console.log('─'.repeat(55));
  console.log(`\n✅ Done! ${inserted} inserted, ${skipped} skipped.`);
  console.log(`📦 Total players in database: ${total.rows[0].count}\n`);
  process.exit(0);
}

seed().catch(err => {
  console.error('❌ Seed failed:', err.message);
  process.exit(1);
});
