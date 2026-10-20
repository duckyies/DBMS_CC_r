import { PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

const prisma = new PrismaClient();

const BACKEND_ROOT = path.resolve(__dirname, '..');
const MEDIA_ROOT = path.resolve(BACKEND_ROOT, 'media');
const MUSIC_ROOT = path.join(MEDIA_ROOT, 'music');
const MANIFEST_PATH = path.join(MEDIA_ROOT, 'manifest.json');

interface ManifestEntry {
  song_name: string;
  artist_name: string;
  duration?: number;
  album?: string;
  genre?: string;
  genres?: string[];
  cover_art_url?: string;
  file_path: string;
  downloaded_at?: string;
}

function readManifest(): ManifestEntry[] {
  try {
    if (fs.existsSync(MANIFEST_PATH)) {
      const parsed = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf-8'));
      if (Array.isArray(parsed)) return parsed as ManifestEntry[];
    }
  } catch (err) {
    console.warn('Could not read manifest:', err);
  }
  return [];
}

function collectSidecars(dir: string, acc: ManifestEntry[]): void {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) collectSidecars(full, acc);
    else if (entry.isFile() && entry.name.endsWith('.json') && entry.name !== 'manifest.json') {
      try {
        const data = JSON.parse(fs.readFileSync(full, 'utf-8')) as ManifestEntry;
        if (data && data.file_path && data.song_name) acc.push(data);
      } catch {
        // ignore
      }
    }
  }
}

function collectEntries(): ManifestEntry[] {
  const fromManifest = readManifest();
  if (fromManifest.length > 0) return fromManifest;
  const acc: ManifestEntry[] = [];
  collectSidecars(MUSIC_ROOT, acc);
  return acc;
}

async function getOrCreateArtist(artistName: string): Promise<number> {
  const existing = await prisma.artist.findFirst({
    where: { name: artistName },
    select: { user_id: true },
  });
  if (existing) return existing.user_id;

  // Create a backing user + artist profile for imported content.
  const safeUsername = artistName
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 90) || 'imported_artist';

  let username = safeUsername;
  let suffix = 1;
  while (await prisma.user.findUnique({ where: { username } })) {
    username = `${safeUsername}_${suffix++}`;
  }

  const user = await prisma.user.create({
    data: {
      username,
      password_hash: 'imported',
      is_artist: true,
    },
  });

  await prisma.artist.create({
    data: {
      user_id: user.user_id,
      name: artistName,
    },
  });

  return user.user_id;
}

async function main(): Promise<void> {
  const entries = collectEntries();
  if (entries.length === 0) {
    console.error('No media entries found. Run fetch-youtube first.');
    process.exit(1);
  }

  let created = 0;
  let updated = 0;
  let skipped = 0;

  for (const entry of entries) {
    try {
      const artistId = await getOrCreateArtist(entry.artist_name);
      const genres = entry.genres && entry.genres.length
        ? entry.genres
        : entry.genre
        ? [entry.genre]
        : [];

      const downloadedAt = entry.downloaded_at ? new Date(entry.downloaded_at) : new Date();

      const existing = await prisma.song.findFirst({
        where: { file_path: entry.file_path },
      });

      const data = {
        song_name: entry.song_name,
        duration: entry.duration || 0,
        publish_date: downloadedAt,
        genres,
        is_published: true,
        file_path: entry.file_path,
        downloaded_at: downloadedAt,
        album: entry.album,
        cover_art_url: entry.cover_art_url,
      };

      if (existing) {
        await prisma.song.update({
          where: { song_id: existing.song_id },
          data,
        });
        // Ensure artist relation exists.
        await prisma.song_Artist_Relationship.upsert({
          where: {
            song_id_artist_id: { song_id: existing.song_id, artist_id: artistId },
          },
          update: {},
          create: {
            song_id: existing.song_id,
            artist_id: artistId,
            role: 'Main Artist',
            is_primary: true,
          },
        });
        updated++;
      } else {
        const song = await prisma.song.create({
          data: {
            ...data,
            artists: {
              create: {
                artist_id: artistId,
                role: 'Main Artist',
                is_primary: true,
              },
            },
          },
        });
        created++;
        console.log(`  ✔ Created song ${song.song_id}: ${entry.song_name}`);
      }
    } catch (err) {
      skipped++;
      console.error(`  ✖ Failed to ingest "${entry.song_name}": ${(err as Error).message}`);
    }
  }

  console.log(`\nIngest complete: ${created} created, ${updated} updated, ${skipped} skipped.`);
}

main()
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });