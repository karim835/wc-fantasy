# WC Fantasy — FIFA World Cup 2026 Fantasy Football Platform

An all-in-one mobile fantasy football platform and RESTful backend dedicated to the **FIFA World Cup 2026** (co-hosted by Morocco, the United States, and Canada, featuring 48 national teams and 104 matches).

WC Fantasy combines competitive team management, Head-to-Head (H2H) league battles, community match predictions, live synchronized match statistics, an integrated AI assistant, and real-time social interaction.

---

## 📌 Architecture Overview

The system is built upon a decoupled three-tier client-server architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                 Mobile Client (Flutter / Dart)              │
│   • Riverpod (State Management)   • Dio (HTTP + Refresh)    │
│   • Socket.io Client              • FlutterSecureStorage    │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP / REST & WebSockets
┌──────────────────────────────▼──────────────────────────────┐
│                 Backend Server (Node.js / Express)          │
│   • MVC Architecture              • JWT Dual-Token Auth     │
│   • Socket.io Server (Rooms)      • Cron Job (node-cron)    │
│   • Centralized Points Engine     • Rate Limiting & Helmet  │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
┌──────────────▼─────────────┐ ┌──────────────▼───────────────┐
│     PostgreSQL 16          │ │          Redis Cache         │
│  20 Relational Tables      │ │  In-memory query caching     │
│  ACID & SELECT FOR UPDATE  │ │  Sub-5ms response time       │
└────────────────────────────┘ └──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│                     External Services                       │
│  • football-data.org (Live scores & fixtures)               │
│  • Google Gemini API (AI football assistant)                │
│  • Brevo SMTP (Transactional emails & password reset)       │
└─────────────────────────────────────────────────────────────┘
```

---

## ✨ Key Features

### 1. Fantasy Team Building & Transfers (Draft)
- **100.0 M€ Budget Cap**: Strict database-level constraint (`budget >= 0`) enforced via transactional SQL.
- **15-Player Squad**: 11 starters + 4 bench players (1 GK, 4 DEF, 4 MID, 3 FWD, or customizable formations).
- **Club/Nation Quota**: Maximum 3 players from the same national team or club.
- **Captain Selection**: Captain scores **2x** fantasy points.
- **Concurrency Protection**: Team adjustments and transfer operations utilize `SELECT FOR UPDATE` row locks to prevent race conditions.

### 2. Private & Public Leagues
- Create public leagues open to all managers or private leagues secured by a unique 8-character invitation code.
- Dynamic leaderboard rankings updated in real-time.
- Automatic member roster and standings calculation.

### 3. Head-to-Head (H2H) Weekly Battles
- Direct manager-vs-manager match-ups within each league.
- Head-to-head score resolution based on real-world player performances.
- Instant battle status and match results broadcasted live.

### 4. Real-Time Chat & Presence (Socket.io)
- Dedicated WebSocket rooms for every league (`league:{id}`) and match battle (`battle:{id}`).
- In-memory rate limiting (1 message/second per user) with automatic anti-flood protection.
- Live online presence indicators for active league competitors.

### 5. Automated Scoring & Real-Time Sync
- Automated cron task scheduled daily at **03:00 UTC** (`node-cron`).
- Pulls completed match fixtures and individual player statistics from `football-data.org`.
- Single source of truth calculation engine (`utils/pointsCalculator.js`) shared across automated cron jobs and administrative manual entry.
- Real-time event broadcasting (`scores:updated`) pushes score changes directly to connected mobile clients.

### 6. AI Assistant Chatbot (Google Gemini)
- Interactive conversational assistant powered by Google Gemini (`gemini-pro`).
- Enriched with live tournament context: team form, injury updates, captain recommendations, and tactical insights.
- Response streaming via Server-Sent Events (SSE) for fluid mobile chat interaction.

### 7. Community Match Predictions & Gamification
- Predict the top goalscorer, winning nation, and total goals before each Gameweek deadline.
- Experience Point (XP) progression and achievement unlocking.
- XP bonuses isolated from fantasy match scoring (`xp` column separated from `total_points`).

### 8. Administration Dashboard
- Supervise platform statistics, registered managers, and active leagues.
- Manual entry and verification for player scores and gameweek completion.
- News content curation and editorial management.
- Batch photo backfill utilities for tournament players.

---

## 📊 Fantasy Scoring Rules

Points are calculated deterministically by position using the unified rules matrix:

| Action / Event | Goalkeeper (GK) | Defender (DEF) | Midfielder (MID) | Forward (FWD) |
| :--- | :---: | :---: | :---: | :---: |
| Playing 1 to 59 minutes | +1 pt | +1 pt | +1 pt | +1 pt |
| Playing 60+ minutes | +2 pts | +2 pts | +2 pts | +2 pts |
| Goal scored | **+10 pts** | **+6 pts** | **+5 pts** | **+4 pts** |
| Assist | +3 pts | +3 pts | +3 pts | +3 pts |
| Clean sheet (≥60 min played) | +4 pts | +4 pts | +1 pt | — |
| Saves (every 3 saves) | +1 pt | — | — | — |
| Penalty saved | +5 pts | — | — | — |
| Penalty missed | -2 pts | -2 pts | -2 pts | -2 pts |
| Yellow card | -1 pt | -1 pt | -1 pt | -1 pt |
| Red card | -3 pts | -3 pts | -3 pts | -3 pts |
| Own goal | -2 pts | -2 pts | -2 pts | -2 pts |
| Hat-trick bonus (≥3 goals) | +5 pts | +5 pts | +5 pts | +5 pts |
| **Captain bonus** | **×2 total points** | **×2 total points** | **×2 total points** | **×2 total points** |

---

## 🛠️ Technology Stack

### Backend
- **Runtime**: Node.js (v20 LTS) & Express.js
- **Database**: PostgreSQL 16 (pg driver, UUID keys, JSONB storage, ACID transactions)
- **Cache**: Redis v7 (ioredis, automatic TTL)
- **Real-Time**: Socket.io v4.7
- **Security**: JWT (7-day access token, 30-day refresh token rotation), bcryptjs (salt factor 10-12), Helmet, Express Rate Limit
- **Background Jobs**: node-cron (automated daily statistics sync)
- **Email Service**: Brevo SMTP via Nodemailer
- **AI Engine**: Google Gemini API

### Mobile Client
- **Framework**: Flutter SDK v3.x / Dart v3.x
- **State Management**: Flutter Riverpod 2.5
- **Networking**: Dio with custom Interceptors (automatic refresh token retry cycle)
- **Navigation**: GoRouter
- **Secure Storage**: FlutterSecureStorage (hardware-backed Android Keystore / iOS Keychain)
- **Charts & UI**: fl_chart, shimmer, flutter_animate, google_fonts

---

## 🔌 API Endpoints Summary

### Authentication (`/api/auth`)
- `POST /api/auth/register` — Register new user account
- `POST /api/auth/login` — Authenticate and receive access + refresh tokens
- `POST /api/auth/refresh` — Issue new access token from valid refresh token
- `POST /api/auth/forgot-password` — Generate secure SHA-256 reset link (1h TTL)
- `POST /api/auth/reset-password` — Finalize password reset via token

### Players & Fantasy Squad (`/api/players`, `/api/fantasy-team`)
- `GET /api/players` — Filter players by position, nationality, club, or price
- `GET /api/players/:id` — Detailed player profile and historical statistics
- `GET /api/fantasy-team/my-team` — Retrieve authenticated user's current squad
- `POST /api/fantasy-team/my-team/players` — Add player with budget and position checks
- `DELETE /api/fantasy-team/my-team/players/:id` — Release player back to market
- `DELETE /api/transfers/leagues/:id/transfer` — Execute atomic player swap (in/out)

### Leagues & Competitions (`/api/leagues`, `/api/battles`)
- `GET /api/leagues` — Fetch all user's enrolled leagues
- `POST /api/leagues` — Create a new league with an auto-generated invite code
- `POST /api/leagues/join` — Join an existing league using invite code
- `GET /api/leagues/:id/battles` — List gameweek Head-to-Head fixtures
- `GET /api/battles/:id` — Detail view of a specific battle

### Gameweeks & Predictions (`/api/gameweeks`, `/api/predictions`)
- `GET /api/gameweeks` — List tournament gameweeks and deadline statuses
- `POST /api/gameweeks/:id/scores` — Saisie des scores (Admin)
- `POST /api/predictions` — Submit match and tournament predictions
- `GET /api/predictions/gameweek/:id` — Aggregated community prediction statistics

### AI & News (`/api/chatbot`, `/api/news`)
- `POST /api/chatbot/chat` — Context-aware AI queries with Gemini (SSE streaming)
- `GET /api/news` — Tournament news cached in Redis (<5ms response time)

---

## ⚙️ Environment Configuration

Create a `.env` file in the project root:

```env
# Server
PORT=3000
NODE_ENV=development

# JWT Authentication
JWT_SECRET=your_jwt_secret_key_here
JWT_EXPIRES_IN=7d
JWT_REFRESH_SECRET=your_jwt_refresh_secret_here
JWT_REFRESH_EXPIRES_IN=30d

# PostgreSQL Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=fantasy_wc2026
DB_USER=postgres
DB_PASSWORD=your_postgres_password
DB_POOL_MAX=10
DB_POOL_IDLE_TIMEOUT=30000

# Redis Cache
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_TTL=3600

# Football Data API (fixtures & live match data)
FOOTBALL_DATA_API_KEY=your_football_data_api_key
FOOTBALL_DATA_COMPETITION=WC

# Google Gemini API (Chatbot)
GEMINI_API_KEY=your_gemini_api_key

# Brevo SMTP (Password reset and transactional emails)
BREVO_API_KEY=your_brevo_api_key
EMAIL_FROM=noreply@fantasyfc2026.com
CLIENT_URL=http://localhost:3000

# Initial Admin Seed
ADMIN_EMAIL=admin@wc2026.com
ADMIN_PASSWORD=Admin1234!
ADMIN_USERNAME=admin_wc

# CORS & Rate Limiting
CORS_ORIGIN=*
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=1000
```

---

## 🚀 Getting Started

### 1. Prerequisites
- **Node.js**: v20 LTS or higher
- **PostgreSQL**: v16 with client utilities (`psql`)
- **Redis**: v7 server running locally or via Docker
- **Flutter SDK**: v3.3+ (for running the mobile app)

### 2. Backend Setup
```bash
# Install dependencies
npm install

# Run database migrations
# Execute SQL migration files located in ./migrations in sequence:
# 001_initial_schema.sql to 010_add_xp_column.sql

# Seed player database and World Cup teams
npm run seed:wc

# Create default administrative account
node create-admin.js

# Start server in development mode
npm run dev
```

### 3. Mobile Setup (Flutter)
```bash
# Navigate to mobile project folder
cd mobile

# Install Flutter dependencies
flutter pub get

# Configure backend host IP in your environment or run script
# Launch the application on an emulator or connected physical device
flutter run
```

---

## 📁 Repository Directory Structure

```
├── config/                 # Database, Redis, and logger configurations
├── controllers/            # Express REST controllers (auth, draft, battles, news, etc.)
├── jobs/                   # Cron scheduled jobs (score sync from football-data)
├── middlewares/            # JWT authentication, role guards, and error handling
├── migrations/             # SQL database schema migration scripts
├── mobile/                 # Cross-platform Flutter mobile application
│   ├── lib/
│   │   ├── models/         # Data transfer models
│   │   ├── providers/      # Riverpod state providers
│   │   ├── screens/        # UI Views (Draft, Leagues, Chat, Admin, Battles)
│   │   ├── services/       # Network, API, Socket.io, and secure storage services
│   │   └── widgets/        # Reusable UI components
├── models/                 # Database access helpers and query models
├── routes/                 # Express API route declarations
├── scripts/                # Database seeding and simulation scripts
├── socket/                 # Socket.io connection handlers and room routing
├── utils/                  # Points calculator, cache helpers, and email sender
├── app.js                  # Main Express application entrypoint
├── package.json            # Project dependencies and script runner
└── README.md               # Project documentation
```

