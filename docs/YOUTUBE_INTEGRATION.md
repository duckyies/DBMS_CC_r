# YouTube Integration

Personal-use tooling for downloading audio from YouTube and ingesting it into MusicLib.

## Overview

The workflow has three steps:

1. **Fetch** — `backend/scripts/fetch-youtube.ts` uses `yt-dlp` to scrape metadata and download MP3 files into `backend/media/music/YYYY/MM/DD/`.
2. **Playlist** — `backend/scripts/generate-m3u.ts` builds an `.m3u` playlist from the downloaded files.
3. **Ingest** — `backend/scripts/ingest-media.ts` loads the downloaded files and their metadata into the database.

Downloaded files are served by the backend at `GET /api/media/:path`.

## Prerequisites

- `yt-dlp` installed and on `PATH` (https://github.com/yt-dlp/yt-dlp)
- `ffmpeg` installed (required by `yt-dlp` for MP3 conversion)
- A running MySQL instance and `DATABASE_URL` configured

## Usage

Run from the `backend/` directory:

```bash
# 1. Download one or more videos
npm run media:fetch -- "https://www.youtube.com/watch?v=..." "https://youtu.be/..."

# Or from a file (one URL per line)
npm run media:fetch -- --file urls.txt

# 2. Generate an .m3u playlist
npm run media:m3u
# Optional: custom output path
npm run media:m3u -- --output media/my-playlist.m3u

# 3. Ingest into the database
npm run media:ingest
```

## Storage layout

```
backend/media/
  manifest.json
  playlist.m3u
  music/
    2026/
      10/
        18/
          Song Title.mp3
          Song Title.json   # sidecar metadata
```

## Serving media

`GET /api/media/*` streams a file from the `media/` directory.

Examples:

- `GET /api/media/music/2026/10/18/Song%20Title.mp3`
- `GET /api/media/media/music/2026/10/18/Song%20Title.mp3` (the `media/` prefix is accepted too)

Path traversal outside of the media root is rejected.

## Metadata

Each downloaded track stores: title, artist, duration, album, genre, cover art URL, file path, and download timestamp. These are persisted on the `Song` model (`file_path`, `downloaded_at`, `album`, `cover_art_url`).

## Rate limiting & errors

- Downloads are spaced 2 seconds apart to reduce throttling.
- A missing or broken link is logged and skipped; the run continues.
- `yt-dlp` must be installed; otherwise the fetch script exits with an error.
- Failed downloads do not partially update the manifest.

## Environment variables

| Variable | Description |
|---|---|
| `YOUTUBE_API_KEY` | Optional API key (not required for `yt-dlp`) |
| `YOUTUBE_DOWNLOAD_DIR` | Override download directory (default: `media`) |

## Notes

- For personal use only. Do not scale to production.
- YouTube may throttle unauthenticated requests; re-run later if downloads fail.