import { Router, Request, Response, NextFunction } from 'express';
import { prisma } from '../lib/prisma';
import { authenticate } from '../middleware/auth';

const router = Router();

// GET /api/songs?q=&genre=
router.get('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { q, genre } = req.query;

    const songs = await prisma.song.findMany({
      where: {
        is_published: true,
        ...(q && { song_name: { contains: String(q) } }),
        // Filter exact JSON array membership
        ...(genre && {
          genres: {
            array_contains: String(genre),
          },
        }),
      },
      include: {
        artists: {
          include: {
            artist: { select: { name: true, user_id: true } },
          },
          where: { is_primary: true },
        },
      },
      orderBy: { song_id: 'desc' },
      take: 50,
    });

    res.json(songs);
  } catch (err) {
    next(err);
  }
});

// GET /api/songs/genres — dynamically list all unique genres in catalog
router.get('/genres', authenticate, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const songs = await prisma.song.findMany({
      where: { is_published: true },
      select: { genres: true },
    });

    const genreSet = new Set<string>();
    for (const s of songs) {
      if (Array.isArray(s.genres)) {
        s.genres.forEach((g) => {
          if (typeof g === 'string' && g.trim()) {
            genreSet.add(g.trim());
          }
        });
      }
    }

    res.json(Array.from(genreSet).sort());
  } catch (err) {
    next(err);
  }
});

// GET /api/songs/:id
router.get('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const songId = parseInt(req.params.id);
    if (isNaN(songId)) {
      res.status(400).json({ error: 'Invalid song ID' });
      return;
    }

    const song = await prisma.song.findUnique({
      where: { song_id: songId },
      include: {
        artists: {
          include: {
            artist: {
              select: {
                name: true,
                user_id: true,
                country: true,
                production_house: true,
              },
            },
          },
        },
      },
    });

    if (!song) {
      res.status(404).json({ error: 'Song not found' });
      return;
    }

    res.json(song);
  } catch (err) {
    next(err);
  }
});

// POST /api/songs/:id/listen — increment listen count + log activity
router.post('/:id/listen', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const songId = parseInt(req.params.id);
    const userId = req.user!.userId;
    const { listening_time } = req.body; // seconds listened (optional)

    // If listening_time is not provided or <= 0, query the song's duration as default
    let finalListeningTime = listening_time;
    if (!finalListeningTime || typeof finalListeningTime !== 'number' || finalListeningTime <= 0) {
      const song = await prisma.song.findUnique({
        where: { song_id: songId },
        select: { duration: true }
      });
      finalListeningTime = song?.duration || 0;
    }

    // Log listening activity (no artificial listen counter is maintained)
    await prisma.listening_Activity.create({
      data: {
        user_id: userId,
        song_id: songId,
        listening_time: Math.round(finalListeningTime),
      },
    });

    res.json({ message: 'Listened' });
  } catch (err) {
    next(err);
  }
});

export default router;

