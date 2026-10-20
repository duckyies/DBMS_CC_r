# 🎵 MusicLib — Music Library Management System

A full-stack containerized web application for managing music playlists, following artists and users, and collaborating on playlists.

## Tech Stack
- **Frontend:** React 18 + TypeScript + Vite + Tailwind CSS + shadcn/ui
- **Backend:** Node.js + TypeScript + Express + Prisma ORM
- **Database:** MySQL 8
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
- **Frontend:** http://localhost:5173
- **Backend API:** http://localhost:3001
- **MySQL:** localhost:3307 (Note: Changed from 3306 to 3307 to avoid local MySQL conflicts)

> [!NOTE]  
> If you encounter a `ports are not available` error (e.g. `bind: Only one usage of each socket address is normally permitted`), it means a local service is already using that port. You can change the port mapping in `docker-compose.yml` (e.g., `"3307:3306"` for MySQL or `"3002:3001"` for backend).

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
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── seed.ts
│   │   └── migrations/
│   └── src/
│       ├── index.ts
│       ├── lib/prisma.ts
│       ├── middleware/
│       └── routes/
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
| `JWT_SECRET` | Secret for JWT signing |
| `PORT` | Backend API port (default: 3001) |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login |
| GET | `/api/auth/me` | Current user |
| GET | `/api/users?username=` | Search users |
| GET | `/api/users/me/following` | Get following list |
| POST | `/api/users/:id/follow` | Follow user |
| DELETE | `/api/users/:id/follow` | Unfollow user |
| GET | `/api/artists?name=` | Search artists |
| GET | `/api/artists/:userId` | Artist profile |
| GET | `/api/songs?q=` | Search songs |
| GET | `/api/media/*` | Serve local media files |
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
