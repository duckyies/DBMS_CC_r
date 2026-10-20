import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { errorHandler } from './middleware/errorHandler';

import authRoutes from './routes/auth';
import usersRoutes from './routes/users';
import artistsRoutes from './routes/artists';
import songsRoutes from './routes/songs';
import playlistsRoutes from './routes/playlists';
import collaboratorsRoutes from './routes/collaborators';
import followRoutes from './routes/follow';
import mediaRoutes from './routes/media';

const app = express();
const PORT = process.env.PORT || 3001;

// ── Middleware ──────────────────────────────────────────────────────────
app.use(cors({
  origin: ['http://localhost:5173', 'http://frontend:5173'],
  credentials: true,
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── Health Check ────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Routes ──────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/artists', artistsRoutes);
app.use('/api/songs', songsRoutes);
app.use('/api/playlists', playlistsRoutes);
app.use('/api/playlists', collaboratorsRoutes);
app.use('/api/users', followRoutes);
app.use('/api/media', mediaRoutes);

// ── Error Handler (must be last) ─────────────────────────────────────────
app.use(errorHandler);

// ── Start ────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🎵 Music Library API running on http://localhost:${PORT}`);
});

export default app;
