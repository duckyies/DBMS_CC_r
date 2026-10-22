# 🎵 MusicLib — Music Library Management System

A full-stack containerized web application for managing music playlists, following artists and users, and collaborating on playlists.

## Tech Stack
- **Frontend:** React 18 + TypeScript + Vite + Tailwind CSS + shadcn/ui
- **Backend:** Python 3.12 + FastAPI (served by Uvicorn)
- **Database:** MySQL 8, accessed directly with SQL through PyMySQL (no ORM)
- **Deployment:** Docker Compose

## Quick Start

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

### Run the application

```bash
# Clone / navigate to project root
docker-compose up --build
```

Services will start at:
- **Frontend:** http://localhost:5273
- **Backend API:** http://localhost:3101
- **MySQL:** 127.0.0.1:3407 (host-only)

These host ports differ from the original Node/Prisma version (5173 / 3001 / 3307) on purpose, so both stacks can run on the same machine. Change them with `FRONTEND_PORT`, `BACKEND_PORT` and `DB_PORT` in `.env`.

> [!NOTE]  
> If you encounter a `ports are not available` error (e.g. `bind: Only one usage of each socket address is normally permitted`), it means a local service is already using that port. You can change the port mapping in `docker-compose.yml` (or just set `FRONTEND_PORT`, `BACKEND_PORT` or `DB_PORT` in `.env`).

### 📖 Deployment Guides
For detailed instructions on how to deploy this project from scratch on Windows or a fresh Linux VM, please see [DEPLOYMENT.md](./DEPLOYMENT.md).

### Demo Accounts

| Username | Password | Type |
|----------|----------|------|
| `alice` | `password123` | Artist (Sony Music) |
| `bob` | `password123` | Regular User |
| `charlie` | `password123` | Band Artist (Universal Music) |

## Features

### ✅ Authentication
- Signup with optional "Register as Artist" option
- JWT-based login stored in localStorage

### ✅ Playlists
- Create, edit, delete playlists
- Add/remove songs from playlists
- Artists can set release type (Single, EP, Album) — hidden from regular users
- Share playlists and manage collaborators

### ✅ Collaboration
- Add users as collaborators by username
- Collaborators can add/remove songs

### ✅ Social
- Follow/unfollow any user (including artists)
- View following list on Dashboard and Profile

### ✅ Browse
- Search songs by name
- Browse and search artists with profile detail panel

## Project Structure

```
DBMS_CC_retry/
├── docker-compose.yml
├── .env
├── .env.example
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── db/
│   │   ├── schema.sql      # CREATE TABLE statements (run on every start, idempotent)
│   │   └── seed.sql        # demo users, songs, playlists (idempotent)
│   └── app/
│       ├── main.py         # FastAPI app, error handlers
│       ├── config.py       # environment settings
│       ├── db.py           # MySQL connections, transactions, schema/seed bootstrap
│       ├── deps.py         # JWT + bcrypt helpers, auth dependency
│       ├── queries.py      # shared SQL fragments and row -> JSON shaping
│       └── routes/         # auth, users, artists, songs, playlists, collaborators, follow
└── frontend/
    ├── Dockerfile
    ├── vite.config.ts
    └── src/
        ├── App.tsx
        ├── contexts/
        ├── components/ui/
        └── pages/
```

## Environment Variables

Copy `.env.example` to `.env` and adjust:

| Variable | Description |
|----------|-------------|
| `MYSQL_ROOT_PASSWORD` | MySQL root password |
| `MYSQL_DATABASE` | Database name |
| `JWT_SECRET` | Secret for JWT signing (the backend refuses to start without it) |
| `FRONTEND_PORT` | Host port for the website (default: 5273) |
| `BACKEND_PORT` | Host port for the API (default: 3101) |
| `DB_PORT` | Host port for MySQL, bound to 127.0.0.1 (default: 3407) |
| `APP_ENV` | `production` (default) or `development` (adds error details to 500 responses) |
| `SEED_DEMO_DATA` | `true` (default) loads the demo accounts on startup; `false` for an empty database |

## Database

There is no ORM and no migration tool. On startup the backend waits for MySQL, runs
[`backend/db/schema.sql`](backend/db/schema.sql) (`CREATE TABLE IF NOT EXISTS`) and then
[`backend/db/seed.sql`](backend/db/seed.sql). To change the schema, edit `schema.sql` (for an existing
database, also run the matching `ALTER TABLE` by hand, since `IF NOT EXISTS` skips tables that exist).
To poke around directly: `docker compose exec db mysql -uroot -p music_library`.

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login |
| GET | `/api/auth/me` | Current user |
| GET | `/api/users?username=` | Search users |
| GET | `/api/users/me/following` | Get following list |
| GET | `/api/users/me/listening` | My 20 most recent plays (Listening_Activity) |
| POST | `/api/users/:id/follow` | Follow user |
| DELETE | `/api/users/:id/follow` | Unfollow user |
| GET | `/api/artists?name=` | Search artists |
| GET | `/api/artists/:userId` | Artist profile |
| GET | `/api/songs?q=&genre=` | Search songs (genre matches one whole genre) |
| GET | `/api/songs/:id/lyrics` | Lyrics of a song |
| POST | `/api/songs/:id/listen` | Count a listen and log it in Listening_Activity |
| GET | `/api/playlists` | My playlists |
| POST | `/api/playlists` | Create playlist |
| GET | `/api/playlists/:id` | Playlist detail |
| PUT | `/api/playlists/:id` | Update playlist |
| DELETE | `/api/playlists/:id` | Delete playlist |
| POST | `/api/playlists/:id/songs` | Add song |
| DELETE | `/api/playlists/:id/songs/:songId` | Remove song |
| GET | `/api/playlists/:id/collaborators` | List collaborators |
| POST | `/api/playlists/:id/collaborators` | Add collaborator |
| DELETE | `/api/playlists/:id/collaborators/:userId` | Remove collaborator |
