import fs from 'fs';
import path from 'path';

const BACKEND_ROOT = path.resolve(__dirname, '..');
const MEDIA_ROOT = path.resolve(BACKEND_ROOT, 'media');
const MUSIC_ROOT = path.join(MEDIA_ROOT, 'music');
const MANIFEST_PATH = path.join(MEDIA_ROOT, 'manifest.json');

interface ManifestEntry {
  song_name: string;
  artist_name: string;
  duration: number;
  file_path: string;
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
    if (entry.isDirectory()) {
      collectSidecars(full, acc);
    } else if (entry.isFile() && entry.name.endsWith('.json') && entry.name !== 'manifest.json') {
      try {
        const data = JSON.parse(fs.readFileSync(full, 'utf-8')) as ManifestEntry;
        if (data && data.file_path && data.song_name) acc.push(data);
      } catch {
        // ignore malformed sidecar
      }
    }
  }
}

function collectEntries(): ManifestEntry[] {
  const fromManifest = readManifest();
  if (fromManifest.length > 0) return fromManifest;

  const acc: ManifestEntry[] = [];
  collectSidecars(MUSIC_ROOT, acc);

  // Fall back to scanning mp3 files if no metadata is available.
  if (acc.length === 0) {
    const walk = (dir: string) => {
      if (!fs.existsSync(dir)) return;
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (entry.isFile() && entry.name.toLowerCase().endsWith('.mp3')) {
          const rel = path.relative(BACKEND_ROOT, full).replace(/\\/g, '/');
          acc.push({
            song_name: path.basename(entry.name, '.mp3'),
            artist_name: 'Unknown Artist',
            duration: 0,
            file_path: rel,
          });
        }
      }
    };
    walk(MUSIC_ROOT);
  }
  return acc;
}

function parseArgs(argv: string[]): { output: string; baseDir: string } {
  let output = path.join(MEDIA_ROOT, 'playlist.m3u');
  let baseDir = BACKEND_ROOT;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--output' || arg === '-o') output = argv[++i];
    else if (arg === '--base-dir') baseDir = argv[++i];
  }
  return { output, baseDir };
}

function main(): void {
  const { output } = parseArgs(process.argv.slice(2));
  const entries = collectEntries();

  if (entries.length === 0) {
    console.error('No songs found to include in playlist.');
    process.exit(1);
  }

  const lines: string[] = ['#EXTM3U'];
  for (const entry of entries) {
    const duration = Math.max(0, Math.round(entry.duration || 0));
    lines.push(`#EXTINF:${duration},`);
    lines.push(entry.file_path);
  }

  const outPath = path.resolve(output);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, lines.join('\n') + '\n', 'utf-8');
  console.log(`✔ Generated playlist with ${entries.length} track(s): ${outPath}`);
}

main();