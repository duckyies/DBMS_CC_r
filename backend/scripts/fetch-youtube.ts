import { execFileSync, spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';

// Resolve the media directory relative to this script (backend/media).
const BACKEND_ROOT = path.resolve(__dirname, '..');
const MEDIA_ROOT = path.resolve(BACKEND_ROOT, 'media');
const MUSIC_ROOT = path.join(MEDIA_ROOT, 'music');
const MANIFEST_PATH = path.join(MEDIA_ROOT, 'manifest.json');

interface YouTubeMetadata {
  id: string;
  title: string;
  uploader?: string;
  artist?: string;
  album?: string;
  genre?: string;
  duration?: number;
  upload_date?: string;
  thumbnail?: string;
  webpage_url?: string;
}

interface ManifestEntry {
  song_name: string;
  artist_name: string;
  duration: number;
  album?: string;
  genre?: string;
  cover_art_url?: string;
  file_path: string;
  downloaded_at: string;
  source_url?: string;
  youtube_id?: string;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function sanitizeFileName(name: string): string {
  return name
    .replace(/[<>:"/\\|?*\x00-\x1f]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 120);
}

function ensureDir(dir: string): void {
  fs.mkdirSync(dir, { recursive: true });
}

function readManifest(): ManifestEntry[] {
  try {
    if (fs.existsSync(MANIFEST_PATH)) {
      const raw = fs.readFileSync(MANIFEST_PATH, 'utf-8');
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return parsed as ManifestEntry[];
    }
  } catch (err) {
    console.warn('Could not read manifest, starting fresh:', err);
  }
  return [];
}

function writeManifest(entries: ManifestEntry[]): void {
  ensureDir(MEDIA_ROOT);
  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(entries, null, 2), 'utf-8');
}

function checkYtDlp(): boolean {
  try {
    execFileSync('yt-dlp', ['--version'], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function fetchMetadata(url: string): YouTubeMetadata {
  const stdout = execFileSync(
    'yt-dlp',
    ['--dump-json', '--no-playlist', '--no-warnings', url],
    { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 }
  );
  // yt-dlp may emit multiple JSON lines for playlists; take the first.
  const firstLine = stdout
    .split('\n')
    .map((l) => l.trim())
    .find((l) => l.startsWith('{'));
  if (!firstLine) throw new Error('No metadata returned by yt-dlp');
  return JSON.parse(firstLine) as YouTubeMetadata;
}

function dateFromUploadDate(uploadDate?: string): string {
  if (uploadDate && /^\d{8}$/.test(uploadDate)) {
    return `${uploadDate.slice(0, 4)}/${uploadDate.slice(4, 6)}/${uploadDate.slice(6, 8)}`;
  }
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}/${m}/${d}`;
}

function downloadAudio(url: string, outputTemplate: string): void {
  const result = spawnSync(
    'yt-dlp',
    [
      '-x',
      '--audio-format',
      'mp3',
      '--audio-quality',
      '0',
      '--no-playlist',
      '--no-warnings',
      '-o',
      outputTemplate,
      url,
    ],
    { stdio: 'inherit' }
  );
  if (result.status !== 0) {
    throw new Error(`yt-dlp download failed with exit code ${result.status}`);
  }
}

async function processUrl(url: string, manifest: ManifestEntry[]): Promise<void> {
  console.log(`\n▶ Processing: ${url}`);
  let metadata: YouTubeMetadata;
  try {
    metadata = fetchMetadata(url);
  } catch (err) {
    console.error(`  ✖ Failed to fetch metadata: ${(err as Error).message}`);
    return;
  }

  const title = metadata.title || 'Unknown Title';
  const artist = metadata.artist || metadata.uploader || 'Unknown Artist';
  const duration = typeof metadata.duration === 'number' ? Math.round(metadata.duration) : 0;
  const dateDir = dateFromUploadDate(metadata.upload_date);
  const targetDir = path.join(MUSIC_ROOT, dateDir);
  ensureDir(targetDir);

  const safeTitle = sanitizeFileName(title);
  const outputTemplate = path.join(targetDir, `${safeTitle}.%(ext)s`);
  const expectedFile = path.join(targetDir, `${safeTitle}.mp3`);
  const relativePath = path
    .relative(BACKEND_ROOT, expectedFile)
    .replace(/\\/g, '/');

  try {
    if (fs.existsSync(expectedFile)) {
      console.log(`  ℹ File already exists, skipping download: ${relativePath}`);
    } else {
      downloadAudio(url, outputTemplate);
    }
  } catch (err) {
    console.error(`  ✖ Download failed: ${(err as Error).message}`);
    return;
  }

  if (!fs.existsSync(expectedFile)) {
    console.error(`  ✖ Expected output file not found: ${expectedFile}`);
    return;
  }

  const entry: ManifestEntry = {
    song_name: title,
    artist_name: artist,
    duration,
    album: metadata.album,
    genre: metadata.genre,
    cover_art_url: metadata.thumbnail,
    file_path: relativePath,
    downloaded_at: new Date().toISOString(),
    source_url: metadata.webpage_url || url,
    youtube_id: metadata.id,
  };

  // Write a sidecar JSON next to the mp3 for generate-m3u / ingest-media.
  const sidecarPath = expectedFile.replace(/\.mp3$/i, '.json');
  fs.writeFileSync(sidecarPath, JSON.stringify(entry, null, 2), 'utf-8');

  // De-duplicate manifest entries by file_path.
  const idx = manifest.findIndex((e) => e.file_path === entry.file_path);
  if (idx >= 0) manifest[idx] = entry;
  else manifest.push(entry);

  console.log(`  ✔ Saved: ${relativePath} (${duration}s)`);
}

function parseArgs(argv: string[]): { urls: string[]; urlsFile?: string } {
  const urls: string[] = [];
  let urlsFile: string | undefined;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--file' || arg === '--urls-file') {
      urlsFile = argv[++i];
    } else if (arg.startsWith('http')) {
      urls.push(arg);
    }
  }
  return { urls, urlsFile };
}

async function main(): Promise<void> {
  const { urls, urlsFile } = parseArgs(process.argv.slice(2));

  let allUrls = [...urls];
  if (urlsFile) {
    const content = fs.readFileSync(urlsFile, 'utf-8');
    allUrls = allUrls.concat(
      content
        .split(/\r?\n/)
        .map((l) => l.trim())
        .filter((l) => l && !l.startsWith('#'))
    );
  }

  if (allUrls.length === 0) {
    console.error('Usage: tsx scripts/fetch-youtube.ts <url> [url...] [--file urls.txt]');
    process.exit(1);
  }

  if (!checkYtDlp()) {
    console.error(
      'yt-dlp is not installed or not on PATH. Install it first (https://github.com/yt-dlp/yt-dlp).'
    );
    process.exit(1);
  }

  ensureDir(MUSIC_ROOT);
  const manifest = readManifest();

  // Optional API key (not required for yt-dlp, but supported for future use).
  const apiKey = process.env.YOUTUBE_API_KEY;
  if (apiKey) {
    console.log('YOUTUBE_API_KEY detected (optional).');
  }

  for (let i = 0; i < allUrls.length; i++) {
    await processUrl(allUrls[i], manifest);
    writeManifest(manifest);
    if (i < allUrls.length - 1) {
      // Rate-limit to avoid YouTube throttling.
      await sleep(2000);
    }
  }

  console.log(`\n✔ Done. Manifest written to ${MANIFEST_PATH}`);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});