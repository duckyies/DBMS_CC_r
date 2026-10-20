import { useEffect, useState, useRef } from 'react';
import api from '@/lib/api';
import { useAuth } from '@/contexts/AuthContext';
import { formatDuration } from '@/lib/utils';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Music2, Search, Clock, Plus, ListMusic } from 'lucide-react';
import { useToast } from '@/components/ui/toaster';

interface Song {
  song_id: number;
  song_name: string;
  duration: number;
  publish_date: string;
  genres: string[];
  is_published: boolean;
  file_path?: string | null;
  downloaded_at?: string | null;
  artists: { artist: { name: string; user_id: number } }[];
}

interface Playlist {
  playlist_id: number;
  name: string;
  creator: { user_id: number };
}

export function SongsPage() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [songs, setSongs] = useState<Song[]>([]);
  const [availableGenres, setAvailableGenres] = useState<string[]>([]);
  const [query, setQuery] = useState('');
  const [genre, setGenre] = useState('');
  const [loading, setLoading] = useState(true);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Add to playlist dialog
  const [playlists, setPlaylists] = useState<Playlist[]>([]);
  const [addDialogSong, setAddDialogSong] = useState<Song | null>(null);
  const [addingToPlaylist, setAddingToPlaylist] = useState<number | null>(null);

  const fetchSongs = (q = '', g = '') => {
    setLoading(true);
    const params: Record<string, string> = {};
    if (q) params.q = q;
    if (g) params.genre = g;
    api.get('/songs', { params })
      .then((r) => setSongs(r.data))
      .finally(() => setLoading(false));
  };

  // Debounced search — triggers 350ms after user stops typing
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => fetchSongs(query, genre), 350);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [query, genre]);

  // Fetch playlists the user owns (for add-to-playlist)
  useEffect(() => {
    api.get('/playlists').then((r) =>
      setPlaylists(r.data.filter((p: Playlist) => p.creator.user_id === user?.user_id))
    );
  }, [user]);

  // Fetch dynamic genres
  useEffect(() => {
    api.get('/songs/genres')
      .then((res) => setAvailableGenres(res.data))
      .catch(() => setAvailableGenres(['Pop', 'Rock', 'Electronic', 'Jazz']));
  }, []);

  const handleGenreClick = (g: string) => setGenre(genre === g ? '' : g);

  const addToPlaylist = async (playlistId: number) => {
    if (!addDialogSong) return;
    setAddingToPlaylist(playlistId);
    try {
      await api.post(`/playlists/${playlistId}/songs`, { song_id: addDialogSong.song_id });
      toast({ title: 'Added to playlist!', description: addDialogSong.song_name });
      setAddDialogSong(null);
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { error?: string } } }).response?.data?.error;
      toast({ title: 'Error', description: msg || 'Could not add song', variant: 'destructive' });
    } finally {
      setAddingToPlaylist(null);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Songs</h1>
        <p className="text-muted-foreground mt-1">Browse all songs in the library</p>
      </div>

      {/* Search + genre filter */}
      <div className="space-y-3">
        <div className="flex gap-2 max-w-md">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              id="song-search-input"
              placeholder="Search songs by name…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              className="pl-9"
            />
          </div>
          {query && (
            <Button variant="ghost" size="sm" onClick={() => setQuery('')} className="text-muted-foreground">
              Clear
            </Button>
          )}
        </div>
        <div className="flex flex-wrap gap-2">
          {availableGenres.map((g) => (
            <Badge
              key={g}
              variant={genre === g ? 'default' : 'outline'}
              className="cursor-pointer hover:bg-primary/20 transition-colors select-none"
              onClick={() => handleGenreClick(g)}
            >
              {g}
            </Badge>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center h-40 items-center">
          <div className="animate-spin h-8 w-8 rounded-full border-b-2 border-primary" />
        </div>
      ) : songs.length === 0 ? (
        <Card>
          <CardContent className="py-16 text-center">
            <Music2 className="h-12 w-12 mx-auto mb-3 text-muted-foreground/30" />
            <p className="text-muted-foreground">No songs found.</p>
          </CardContent>
        </Card>
      ) : (
        <div className="rounded-lg border border-border overflow-hidden">
          <div className="grid grid-cols-[auto_1fr_auto_auto] gap-0 text-xs font-medium text-muted-foreground uppercase tracking-wide px-4 py-3 border-b border-border bg-muted/30">
            <span className="w-8">#</span>
            <span>Title</span>
            <span className="text-right w-16 ml-4">Duration</span>
            <span className="w-10" />
          </div>
          {songs.map((song, idx) => (
            <div
              key={song.song_id}
              className="grid grid-cols-[auto_1fr_auto_auto] gap-0 items-center px-4 py-3 hover:bg-accent/40 transition-colors border-b border-border last:border-0 group"
            >
              <span className="w-8 text-sm text-muted-foreground">{idx + 1}</span>
              <div className="min-w-0">
                <p className="font-medium text-sm truncate">{song.song_name}</p>
                <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                  <p className="text-xs text-muted-foreground truncate">
                    {song.artists[0]?.artist.name || 'Unknown'}
                  </p>
                  {(song.genres as string[]).slice(0, 2).map((g) => (
                    <Badge
                      key={g}
                      variant="secondary"
                      className="text-[10px] px-1.5 py-0 cursor-pointer"
                      onClick={(e) => { e.stopPropagation(); handleGenreClick(g); }}
                    >
                      {g}
                    </Badge>
                  ))}
                </div>
              </div>
              <div className="flex items-center gap-1 text-xs text-muted-foreground w-16 justify-end ml-4">
                <Clock className="h-3 w-3" />
                {formatDuration(song.duration)}
              </div>
              <div className="w-10 flex justify-end">
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-7 w-7 opacity-0 group-hover:opacity-100 transition-opacity"
                  title="Add to playlist"
                  onClick={(e) => { e.stopPropagation(); setAddDialogSong(song); }}
                >
                  <Plus className="h-3.5 w-3.5" />
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add to Playlist dialog (F7) */}
      <Dialog open={!!addDialogSong} onOpenChange={(open) => !open && setAddDialogSong(null)}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>Add to Playlist</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground truncate">"{addDialogSong?.song_name}"</p>
          {playlists.length === 0 ? (
            <p className="text-sm text-muted-foreground py-4 text-center">
              You have no playlists yet.
            </p>
          ) : (
            <div className="space-y-2 max-h-60 overflow-y-auto mt-2">
              {playlists.map((pl) => (
                <button
                  key={pl.playlist_id}
                  className="w-full flex items-center gap-3 p-3 rounded-md hover:bg-accent transition-colors text-left"
                  onClick={() => addToPlaylist(pl.playlist_id)}
                  disabled={addingToPlaylist === pl.playlist_id}
                >
                  <ListMusic className="h-4 w-4 text-primary flex-shrink-0" />
                  <span className="text-sm font-medium truncate">{pl.name}</span>
                  {addingToPlaylist === pl.playlist_id && (
                    <span className="text-xs text-muted-foreground ml-auto">Adding…</span>
                  )}
                </button>
              ))}
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
