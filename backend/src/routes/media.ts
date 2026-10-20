import { Router, Request, Response } from 'express';
import path from 'path';
import fs from 'fs';

const router = Router();

// Media files live in <backend>/media. Resolve relative to this file so it works
// regardless of the process working directory.
const MEDIA_ROOT = path.resolve(__dirname, '..', '..', 'media');

// GET /api/media/*  (and /api/media/:path) - serve a local file from media/.
router.get('/*', (req: Request, res: Response) => {
  const requested = (req.params[0] || req.path || '').replace(/^\/+/, '');
  // Allow callers to pass either "music/.../file.mp3" or "media/music/.../file.mp3".
  const relative = requested.startsWith('media/')
    ? requested.slice('media/'.length)
    : requested;

  if (!relative) {
    res.status(400).json({ error: 'Missing file path' });
    return;
  }

  const filePath = path.resolve(MEDIA_ROOT, relative);
  // Prevent path traversal outside of the media root.
  if (filePath !== MEDIA_ROOT && !filePath.startsWith(MEDIA_ROOT + path.sep)) {
    res.status(403).json({ error: 'Access denied' });
    return;
  }

  let stat: fs.Stats;
  try {
    stat = fs.statSync(filePath);
  } catch {
    res.status(404).json({ error: 'File not found' });
    return;
  }

  if (!stat.isFile()) {
    res.status(404).json({ error: 'File not found' });
    return;
  }

  res.sendFile(filePath);
});

export default router;