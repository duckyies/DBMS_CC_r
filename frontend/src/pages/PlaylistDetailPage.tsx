import { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '@/lib/api';
import { useAuth } from '@/contexts/AuthContext';
import { formatDuration, formatDate } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Switch } from '@/components/ui/switch';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { AlertDialog } from '@/components/ui/alert-dialog';
import { useToast } from '@/components/ui/toaster';
import { getInitials } from '@/lib/utils';
import {
  ArrowLeft, Music2, Plus, Trash2, UserPlus, UserMinus,
  Clock, ListMusic, Share2, Pencil, Users, Search
} from 'lucide-react';

interface Song {
  song_id: number;
  song_name: string;
  duration: number;
  genres: string[];
  artists: { artist: { name: string; user_id: number } }[];
}

interface PlaylistSong {
  song_id: number;
  order: number;
  song: Song;
}

interface Collaborator {
  user_id: number;
  username: string;
  is_artist: boolean;
}

interface PlaylistDetail {
  playlist_id: number;
  name: string;
  duration: number;
  release_type: string | null;
  is_shared: boolean;
  cover_art_url: string | null;
  last_updated: string;
  creator: { user_id: number; username: string };
  songs: PlaylistSong[];
  collaborators: { user: Collaborator }[];
}

interface SearchedSong {
  song_id: number;
  song_name: string;
  duration: number;
  artists: { artist: { name: string } }[];
}

export function PlaylistDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();

  const [playlist, setPlaylist] = useState<PlaylistDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [isOwner, setIsOwner] = useState(false);

  // Edit state
  const [editMode, setEditMode] = useState(false);
  const [editName, setEditName] = useState('');
  const [editCover, setEditCover] = useState('');
  const [editReleaseType, setEditReleaseType] = useState<string>('');
  const [saving, setSaving] = useState(false);

  // Add song
  const [songSearch, setSongSearch] = useState('');
  const [songResults, setSongResults] = useState<SearchedSong[]>([]);
  const [songDialogOpen, setSongDialogOpen] = useState(false);
  const [searching, setSearching] = useState(false);

  // Add collaborator
  const [collabUsername, setCollabUsername] = useState('');
  const [collabDialogOpen, setCollabDialogOpen] = useState(false);
  const [addingCollab, setAddingCollab] = useState(false);

  const fetchPlaylist = useCallback(() => {
    api.get(`/playlists/${id}`)
      .then((r) => {
        setPlaylist(r.data);
        setIsOwner(r.data.creator.user_id === user?.user_id);
        setEditName(r.data.name);
        setEditCover(r.data.cover_art_url || '');
        setEditReleaseType(r.data.release_type || '');
      })
      .catch(() => navigate('/playlists'))
      .finally(() => setLoading(false));
  }, [id, user, navigate]);

  useEffect(() => { fetchPlaylist(); }, [fetchPlaylist]);

  const searchSongs = async () => {
    setSearching(true);
    try {
      const r = await api.get('/songs', { params: { q: songSearch } });
      setSongResults(r.data);
    } finally {
      setSearching(false);
    }
  };

  const addSong = async (songId: number, songName: string) => {
    try {
      await api.post(`/playlists/${id}/songs`, { song_id: songId });
      toast({ title: 'Song added', description: songName });
      setSongDialogOpen(false);
      setSongSearch(''); setSongResults([]);
      fetchPlaylist();
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { error?: string } } }).response?.data?.error;
      toast({ title: 'Error', description: msg || 'Could not add song', variant: 'destructive' });
    }
  };

  // Dialog confirmation states
  const [songToRemove, setSongToRemove] = useState<{ id: number; name: string } | null>(null);
  const [collabToRemove, setCollabToRemove] = useState<{ id: number; name: string } | null>(null);
  const [removingAction, setRemovingAction] = useState(false);

  const removeSong = async () => {
    if (!songToRemove) return;
    setRemovingAction(true);
    try {
      await api.delete(`/playlists/${id}/songs/${songToRemove.id}`);
      toast({ title: 'Song removed' });
      setSongToRemove(null);
      fetchPlaylist();
    } catch {
      toast({ title: 'Error', description: 'Could not remove song', variant: 'destructive' });
    } finally {
      setRemovingAction(false);
    }
  };

  const saveEdit = async () => {
    setSaving(true);
    try {
      await api.put(`/playlists/${id}`, {
        name: editName,
        cover_art_url: editCover || null,
        release_type: editReleaseType || null,
        is_shared: playlist?.is_shared,
      });
      toast({ title: 'Saved!' });
      setEditMode(false);
      fetchPlaylist();
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { error?: string } } }).response?.data?.error;
      toast({ title: 'Error', description: msg || 'Could not save', variant: 'destructive' });
    } finally {
      setSaving(false);
    }
  };

  const toggleShare = async () => {
    if (!playlist || !isOwner) return;
    try {
      await api.put(`/playlists/${id}`, { is_shared: !playlist.is_shared });
      fetchPlaylist();
    } catch {
      toast({ title: 'Error', description: 'Could not update sharing', variant: 'destructive' });
    }
  };

  const addCollaborator = async (e: React.FormEvent) => {
    e.preventDefault();
    setAddingCollab(true);
    try {
      await api.post(`/playlists/${id}/collaborators`, { username: collabUsername });
      toast({ title: 'Collaborator added', description: collabUsername });
      setCollabUsername('');
      setCollabDialogOpen(false);
      fetchPlaylist();
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { error?: string } } }).response?.data?.error;
      toast({ title: 'Error', description: msg || 'Could not add collaborator', variant: 'destructive' });
    } finally {
      setAddingCollab(false);
    }
  };

  const removeCollaborator = async () => {
    if (!collabToRemove) return;
    setRemovingAction(true);
    try {
      await api.delete(`/playlists/${id}/collaborators/${collabToRemove.id}`);
      toast({ title: `${collabToRemove.name} removed` });
      setCollabToRemove(null);
      fetchPlaylist();
    } catch {
      toast({ title: 'Error', description: 'Could not remove collaborator', variant: 'destructive' });
    } finally {
      setRemovingAction(false);
    }
  };

  if (loading) {
    return <div className="flex justify-center h-64 items-center"><div className="animate-spin h-8 w-8 rounded-full border-b-2 border-primary" /></div>;
  }

  if (!playlist) return null;

  // Owner and collaborators may change the songs; everyone else with access (shared playlist) can only look
  const canEdit = isOwner || playlist.collaborators.some((c) => c.user.user_id === user?.user_id);

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Back button */}
      <Button variant="ghost" size="sm" onClick={() => navigate('/playlists')} className="gap-2 -ml-2 text-muted-foreground">
        <ArrowLeft className="h-4 w-4" /> Back to Playlists
      </Button>

      {/* Header */}
      <div className="flex gap-6 items-start">
        <div className="h-28 w-28 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0 overflow-hidden">
          {playlist.cover_art_url ? (
            <img src={playlist.cover_art_url} alt={playlist.name} className="h-full w-full object-cover" />
          ) : (
            <ListMusic className="h-12 w-12 text-primary" />
          )}
        </div>

        <div className="flex-1">
          {editMode ? (
            <div className="space-y-3">
              <Input value={editName} onChange={(e) => setEditName(e.target.value)} className="text-lg font-bold h-auto py-1" />
              <Input value={editCover} onChange={(e) => setEditCover(e.target.value)} placeholder="Cover art URL" />
              {user?.is_artist && (
                <Select value={editReleaseType} onValueChange={setEditReleaseType}>
                  <SelectTrigger><SelectValue placeholder="No release type" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Single">Single</SelectItem>
                    <SelectItem value="EP">EP</SelectItem>
                    <SelectItem value="Album">Album</SelectItem>
                  </SelectContent>
                </Select>
              )}
              <div className="flex gap-2">
                <Button size="sm" onClick={saveEdit} disabled={saving}>{saving ? 'Saving…' : 'Save'}</Button>
                <Button size="sm" variant="outline" onClick={() => setEditMode(false)}>Cancel</Button>
              </div>
            </div>
          ) : (
            <>
              <div className="flex items-center gap-3 flex-wrap">
                <h1 className="text-3xl font-bold">{playlist.name}</h1>
                {playlist.release_type && <Badge variant="secondary">{playlist.release_type}</Badge>}
                {playlist.is_shared && (
                  <Badge variant="outline" className="gap-1">
                    <Share2 className="h-3 w-3" /> Shared
                  </Badge>
                )}
              </div>
              <p className="text-muted-foreground mt-1">
                by {playlist.creator.username} · {playlist.songs.length} songs · {formatDuration(playlist.duration)} · updated {formatDate(playlist.last_updated)}
              </p>
              {isOwner && (
                <div className="flex items-center gap-3 mt-3">
                  <Button size="sm" variant="outline" className="gap-1" onClick={() => setEditMode(true)}>
                    <Pencil className="h-3 w-3" /> Edit
                  </Button>
                  <div className="flex items-center gap-2">
                    <Switch id="share-toggle" checked={playlist.is_shared} onCheckedChange={toggleShare} />
                    <Label htmlFor="share-toggle" className="text-sm cursor-pointer">Share playlist</Label>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {/* Songs section */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="text-lg flex items-center gap-2">
              <Music2 className="h-5 w-5" /> Songs
            </CardTitle>
            {canEdit && (
              <Dialog open={songDialogOpen} onOpenChange={setSongDialogOpen}>
                <DialogTrigger asChild>
                  <Button size="sm" variant="outline" className="gap-1">
                    <Plus className="h-3 w-3" /> Add Song
                  </Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle>Add a Song</DialogTitle>
                  </DialogHeader>
                  <div className="space-y-3 mt-2">
                    <div className="flex gap-2">
                      <Input
                        placeholder="Search songs…"
                        value={songSearch}
                        onChange={(e) => setSongSearch(e.target.value)}
                        onKeyDown={(e) => e.key === 'Enter' && searchSongs()}
                      />
                      <Button size="icon" variant="outline" onClick={searchSongs} disabled={searching}>
                        <Search className="h-4 w-4" />
                      </Button>
                    </div>
                    <div className="space-y-2 max-h-64 overflow-y-auto">
                      {songResults.map((s) => (
                        <div key={s.song_id} className="flex items-center justify-between p-2 rounded-md hover:bg-accent">
                          <div>
                            <p className="text-sm font-medium">{s.song_name}</p>
                            <p className="text-xs text-muted-foreground">
                              {s.artists[0]?.artist.name} · {formatDuration(s.duration)}
                            </p>
                          </div>
                          <Button size="sm" variant="outline" onClick={() => addSong(s.song_id, s.song_name)}>
                            Add
                          </Button>
                        </div>
                      ))}
                      {songResults.length === 0 && songSearch && !searching && (
                        <p className="text-sm text-muted-foreground text-center py-4">No songs found. Try a different search.</p>
                      )}
                      {!songSearch && (
                        <p className="text-sm text-muted-foreground text-center py-4">Search for a song by name and press Enter.</p>
                      )}
                    </div>
                  </div>
                </DialogContent>
              </Dialog>
            )}
          </div>
        </CardHeader>
        <CardContent className="p-0">
          {playlist.songs.length === 0 ? (
            <div className="py-12 text-center text-muted-foreground">
              <Music2 className="h-10 w-10 mx-auto mb-3 opacity-30" />
              <p>No songs yet. Add some!</p>
            </div>
          ) : (
            <div className="divide-y divide-border">
              {playlist.songs.map((ps, idx) => (
                <div key={ps.song_id} className="flex items-center gap-4 px-6 py-3 hover:bg-accent/30 transition-colors">
                  <span className="text-sm text-muted-foreground w-5 text-right flex-shrink-0">{idx + 1}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{ps.song.song_name}</p>
                    <p className="text-xs text-muted-foreground truncate">
                      {ps.song.artists[0]?.artist.name || 'Unknown'}
                    </p>
                  </div>
                  <div className="flex items-center gap-3 text-muted-foreground text-xs flex-shrink-0">
                    <span className="flex items-center gap-1"><Clock className="h-3 w-3" /> {formatDuration(ps.song.duration)}</span>
                    {canEdit && (
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-7 w-7 hover:text-destructive"
                        onClick={() => setSongToRemove({ id: ps.song_id, name: ps.song.song_name })}
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </Button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Collaborators section */}
      {(canEdit || playlist.is_shared) && (
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg flex items-center gap-2">
                <Users className="h-5 w-5" /> Collaborators
              </CardTitle>
              {isOwner && (
                <Dialog open={collabDialogOpen} onOpenChange={setCollabDialogOpen}>
                  <DialogTrigger asChild>
                    <Button size="sm" variant="outline" className="gap-1">
                      <UserPlus className="h-3 w-3" /> Add
                    </Button>
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>Add Collaborator</DialogTitle>
                    </DialogHeader>
                    <form onSubmit={addCollaborator} className="space-y-4 mt-2">
                      <div className="space-y-2">
                        <Label>Username</Label>
                        <Input
                          placeholder="Enter username…"
                          value={collabUsername}
                          onChange={(e) => setCollabUsername(e.target.value)}
                          required
                        />
                      </div>
                      <div className="flex justify-end gap-2">
                        <Button type="button" variant="outline" onClick={() => setCollabDialogOpen(false)}>Cancel</Button>
                        <Button type="submit" disabled={addingCollab}>{addingCollab ? 'Adding…' : 'Add'}</Button>
                      </div>
                    </form>
                  </DialogContent>
                </Dialog>
              )}
            </div>
          </CardHeader>
          <CardContent>
            {playlist.collaborators.length === 0 ? (
              <p className="text-sm text-muted-foreground">No collaborators yet.</p>
            ) : (
              <div className="space-y-2">
                {playlist.collaborators.map(({ user: collab }) => (
                  <div key={collab.user_id} className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Avatar className="h-8 w-8">
                        <AvatarFallback className="bg-primary/20 text-primary text-xs">
                          {getInitials(collab.username)}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <p className="text-sm font-medium">{collab.username}</p>
                        {collab.is_artist && <Badge variant="secondary" className="text-[10px]">Artist</Badge>}
                      </div>
                    </div>
                    {isOwner && (
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 text-muted-foreground hover:text-destructive"
                        onClick={() => setCollabToRemove({ id: collab.user_id, name: collab.username })}
                      >
                        <UserMinus className="h-4 w-4" />
                      </Button>
                    )}
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      )}

      {/* Remove Song confirmation dialog */}
      <AlertDialog
        open={!!songToRemove}
        onOpenChange={(open) => !open && setSongToRemove(null)}
        title="Remove Song"
        description={`Remove "${songToRemove?.name}" from this playlist?`}
        confirmLabel="Remove"
        confirmVariant="destructive"
        loading={removingAction}
        onConfirm={removeSong}
      />

      {/* Remove Collaborator confirmation dialog */}
      <AlertDialog
        open={!!collabToRemove}
        onOpenChange={(open) => !open && setCollabToRemove(null)}
        title="Remove Collaborator"
        description={`Remove ${collabToRemove?.name} as a collaborator? They will no longer be able to edit this playlist.`}
        confirmLabel="Remove"
        confirmVariant="destructive"
        loading={removingAction}
        onConfirm={removeCollaborator}
      />
    </div>
  );
}
