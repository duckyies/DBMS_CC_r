import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { formatDuration, formatDate } from '@/lib/utils';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Music2, Search, MapPin, Building2, Clock, Users } from 'lucide-react';
import { getInitials } from '@/lib/utils';

interface ArtistSong {
  role: string;
  is_primary: boolean;
  song: {
    song_id: number;
    song_name: string;
    duration: number;
    publish_date: string;
    genres: string[];
  };
}

interface Artist {
  user_id: number;
  name: string;
  country: string | null;
  is_band: boolean;
  country_of_origin: string | null;
  created_at: string;
  production_house: { name: string; type: string } | null;
  user: { user_id: number; username: string; created_at: string };
  band_members: { user_id: number; username: string }[];
  songs: ArtistSong[];
}

export function ArtistsPage() {
  const [artists, setArtists] = useState<Artist[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<Artist | null>(null);

  const fetchArtists = (q = '') => {
    setLoading(true);
    api.get('/artists', { params: q ? { name: q } : {} })
      .then((r) => setArtists(r.data))
      .finally(() => setLoading(false));
  };

  useEffect(() => { fetchArtists(); }, []);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    fetchArtists(query);
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Artists</h1>
        <p className="text-muted-foreground mt-1">Browse and discover artists</p>
      </div>

      <form onSubmit={handleSearch} className="flex gap-2 max-w-md">
        <Input
          placeholder="Search artists by name…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          id="artist-search-input"
        />
        <Button type="submit" size="icon" variant="outline">
          <Search className="h-4 w-4" />
        </Button>
      </form>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Artist list */}
        <div className="space-y-3">
          {loading ? (
            <div className="flex justify-center h-40 items-center"><div className="animate-spin h-8 w-8 rounded-full border-b-2 border-primary" /></div>
          ) : artists.length === 0 ? (
            <Card><CardContent className="py-12 text-center text-muted-foreground">No artists found.</CardContent></Card>
          ) : (
            artists.map((artist) => (
              <Card
                key={artist.user_id}
                className={`cursor-pointer hover:border-primary/40 hover:shadow-md transition-all ${selected?.user_id === artist.user_id ? 'border-primary' : ''}`}
                onClick={() => setSelected(artist === selected ? null : artist)}
              >
                <CardContent className="flex items-center gap-4 py-4">
                  <Avatar className="h-12 w-12 flex-shrink-0">
                    <AvatarFallback className="bg-primary/20 text-primary font-bold">
                      {getInitials(artist.name)}
                    </AvatarFallback>
                  </Avatar>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <h3 className="font-semibold truncate">{artist.name}</h3>
                      {artist.is_band && <Badge variant="secondary">Band</Badge>}
                    </div>
                    <div className="flex items-center gap-2 text-xs text-muted-foreground mt-0.5">
                      {artist.country && <span className="flex items-center gap-1"><MapPin className="h-3 w-3" />{artist.country}</span>}
                      {artist.production_house && <span className="flex items-center gap-1"><Building2 className="h-3 w-3" />{artist.production_house.name}</span>}
                    </div>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      @{artist.user?.username} · {artist.songs?.length || 0} songs
                    </p>
                  </div>
                </CardContent>
              </Card>
            ))
          )}
        </div>

        {/* Artist detail panel */}
        {selected && (
          <div className="animate-fade-in">
            <Card className="sticky top-0">
              <CardContent className="pt-6 space-y-5">
                <div className="flex items-center gap-4">
                  <Avatar className="h-16 w-16">
                    <AvatarFallback className="bg-primary/20 text-primary text-xl font-bold">
                      {getInitials(selected.name)}
                    </AvatarFallback>
                  </Avatar>
                  <div>
                    <h2 className="text-xl font-bold">{selected.name}</h2>
                    <p className="text-sm text-muted-foreground">@{selected.user?.username}</p>
                    <div className="flex gap-2 mt-1 flex-wrap">
                      {selected.is_band && <Badge variant="secondary">Band</Badge>}
                      {selected.country && <Badge variant="outline">{selected.country}</Badge>}
                    </div>
                  </div>
                </div>

                {selected.production_house && (
                  <div className="flex items-center gap-2 text-sm">
                    <Building2 className="h-4 w-4 text-muted-foreground" />
                    <span className="text-muted-foreground">Label:</span>
                    <span className="font-medium">{selected.production_house.name}</span>
                    <Badge variant="outline" className="text-[10px]">{selected.production_house.type}</Badge>
                  </div>
                )}

                {selected.is_band && selected.band_members?.length > 0 && (
                  <div className="flex items-center gap-2 text-sm flex-wrap">
                    <Users className="h-4 w-4 text-muted-foreground" />
                    <span className="text-muted-foreground">Members:</span>
                    {selected.band_members.map((m) => (
                      <Badge key={m.user_id} variant="outline" className="text-[10px]">@{m.username}</Badge>
                    ))}
                  </div>
                )}

                {selected.country_of_origin && (
                  <div className="flex items-center gap-2 text-sm">
                    <MapPin className="h-4 w-4 text-muted-foreground" />
                    <span className="text-muted-foreground">Origin:</span>
                    <span>{selected.country_of_origin}</span>
                  </div>
                )}

                <div>
                  <h3 className="font-semibold text-sm mb-3 flex items-center gap-2">
                    <Music2 className="h-4 w-4" /> Songs ({selected.songs?.length || 0})
                  </h3>
                  <div className="space-y-2">
                    {!selected.songs || selected.songs.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No songs yet.</p>
                    ) : (
                      selected.songs.map(({ song, role, is_primary }) => (
                        <div key={song?.song_id} className="flex items-center justify-between py-2 border-b border-border last:border-0">
                          <div className="min-w-0">
                            <p className="text-sm font-medium truncate">
                              {song?.song_name}
                              {!is_primary && <Badge variant="outline" className="ml-2 text-[10px]">{role}</Badge>}
                            </p>
                            <p className="text-xs text-muted-foreground">
                              {song?.publish_date ? formatDate(song.publish_date) : 'Unknown date'}
                              {Array.isArray(song?.genres) && song.genres.length > 0 ? ` · ${(song.genres as string[]).join(', ')}` : ''}
                            </p>
                          </div>
                          <span className="text-xs text-muted-foreground flex items-center gap-1 ml-3 flex-shrink-0">
                            <Clock className="h-3 w-3" /> {formatDuration(song?.duration || 0)}
                          </span>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </div>
  );
}
