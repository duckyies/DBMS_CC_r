import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seed...');

  // ── Production House ──────────────────────────────────────────────────
  const sonyMusic = await prisma.production_House.upsert({
    where: { name: 'Sony Music Entertainment' },
    update: {},
    create: {
      name: 'Sony Music Entertainment',
      type: 'Major Label',
    },
  });

  const universalMusic = await prisma.production_House.upsert({
    where: { name: 'Universal Music Group' },
    update: {},
    create: {
      name: 'Universal Music Group',
      type: 'Major Label',
    },
  });

  console.log('✅ Production houses created');

  // ── Users ─────────────────────────────────────────────────────────────
  const aliceHash = await bcrypt.hash('password123', 10);
  const bobHash = await bcrypt.hash('password123', 10);
  const charlieHash = await bcrypt.hash('password123', 10);

  const alice = await prisma.user.upsert({
    where: { username: 'alice' },
    update: {},
    create: {
      username: 'alice',
      password_hash: aliceHash,
      is_artist: true,
    },
  });

  const bob = await prisma.user.upsert({
    where: { username: 'bob' },
    update: {},
    create: {
      username: 'bob',
      password_hash: bobHash,
      is_artist: false,
    },
  });

  const charlie = await prisma.user.upsert({
    where: { username: 'charlie' },
    update: {},
    create: {
      username: 'charlie',
      password_hash: charlieHash,
      is_artist: true,
    },
  });

  console.log('✅ Users created');

  // ── Artist Profiles ───────────────────────────────────────────────────
  const aliceArtist = await prisma.artist.upsert({
    where: { user_id: alice.user_id },
    update: {},
    create: {
      user_id: alice.user_id,
      name: 'Alice Wonderland',
      country: 'US',
      is_band: false,
      country_of_origin: 'United States',
      production_house_id: sonyMusic.production_house_id,
    },
  });

  const charlieArtist = await prisma.artist.upsert({
    where: { user_id: charlie.user_id },
    update: {},
    create: {
      user_id: charlie.user_id,
      name: 'The Charlie Band',
      country: 'UK',
      is_band: true,
      band_member_ids: [1, 2, 3],
      country_of_origin: 'United Kingdom',
      production_house_id: universalMusic.production_house_id,
    },
  });

  console.log('✅ Artist profiles created');

  // ── Songs ─────────────────────────────────────────────────────────────
  const songsData = [
    { song_name: 'Midnight Dreams', duration: 213, publish_date: new Date('2023-03-15'), genres: ['Pop', 'Synthwave'], artist_id: alice.user_id },
    { song_name: 'Electric Horizon', duration: 187, publish_date: new Date('2023-05-22'), genres: ['Electronic', 'Dance'], artist_id: alice.user_id },
    { song_name: 'Velvet Sky', duration: 245, publish_date: new Date('2023-07-10'), genres: ['Indie', 'Pop'], artist_id: alice.user_id },
    { song_name: 'Neon Lights', duration: 198, publish_date: new Date('2023-09-01'), genres: ['Synthpop', 'Electro'], artist_id: alice.user_id },
    { song_name: 'Starfall', duration: 221, publish_date: new Date('2023-11-14'), genres: ['Pop', 'R&B'], artist_id: alice.user_id },
    { song_name: 'Broken Compass', duration: 264, publish_date: new Date('2022-06-20'), genres: ['Rock', 'Alternative'], artist_id: charlie.user_id },
    { song_name: 'Storm Rider', duration: 302, publish_date: new Date('2022-09-05'), genres: ['Rock', 'Blues'], artist_id: charlie.user_id },
    { song_name: 'Silver Lining', duration: 178, publish_date: new Date('2023-01-12'), genres: ['Indie', 'Folk'], artist_id: charlie.user_id },
    { song_name: 'Ember Glow', duration: 233, publish_date: new Date('2023-04-30'), genres: ['Pop', 'Soul'], artist_id: alice.user_id },
    { song_name: 'Frozen River', duration: 289, publish_date: new Date('2023-08-18'), genres: ['Alternative', 'Ambient'], artist_id: charlie.user_id },
  ];

  const songs = [];
  for (const s of songsData) {
    const existing = await prisma.song.findFirst({ where: { song_name: s.song_name } });
    if (!existing) {
      const song = await prisma.song.create({
        data: {
          song_name: s.song_name,
          duration: s.duration,
          publish_date: s.publish_date,
          genres: s.genres,
          is_published: true,
          artists: {
            create: {
              artist_id: s.artist_id,
              role: 'Main Artist',
              is_primary: true,
            },
          },
        },
      });
      songs.push(song);
    } else {
      songs.push(existing);
    }
  }

  console.log('✅ Songs created');

  // ── Playlists ─────────────────────────────────────────────────────────
  const playlist1 = await prisma.playlist.findFirst({ where: { name: 'Alice\'s Debut Album', created_by_user_id: alice.user_id } });
  const alicePlaylist = playlist1 ?? await prisma.playlist.create({
    data: {
      name: "Alice's Debut Album",
      created_by_user_id: alice.user_id,
      release_type: 'Album',
      is_shared: true,
      duration: songs.slice(0, 5).reduce((acc, s) => acc + s.duration, 0),
    },
  });

  const playlist2 = await prisma.playlist.findFirst({ where: { name: 'Chill Vibes Mix', created_by_user_id: bob.user_id } });
  const bobPlaylist = playlist2 ?? await prisma.playlist.create({
    data: {
      name: 'Chill Vibes Mix',
      created_by_user_id: bob.user_id,
      release_type: null,
      is_shared: false,
      duration: songs.slice(5, 9).reduce((acc, s) => acc + s.duration, 0),
    },
  });

  // Add songs to Alice's playlist
  for (let i = 0; i < 5; i++) {
    await prisma.playlist_Song.upsert({
      where: { playlist_id_song_id: { playlist_id: alicePlaylist.playlist_id, song_id: songs[i].song_id } },
      update: {},
      create: { playlist_id: alicePlaylist.playlist_id, song_id: songs[i].song_id, order: i + 1 },
    });
  }

  // Add songs to Bob's playlist
  for (let i = 5; i < 9; i++) {
    await prisma.playlist_Song.upsert({
      where: { playlist_id_song_id: { playlist_id: bobPlaylist.playlist_id, song_id: songs[i].song_id } },
      update: {},
      create: { playlist_id: bobPlaylist.playlist_id, song_id: songs[i].song_id, order: i - 4 },
    });
  }

  console.log('✅ Playlists created');

  // ── Collaborator: Bob collaborates on Alice's playlist ─────────────────
  await prisma.playlist_Collaborator.upsert({
    where: { playlist_id_user_id: { playlist_id: alicePlaylist.playlist_id, user_id: bob.user_id } },
    update: {},
    create: { playlist_id: alicePlaylist.playlist_id, user_id: bob.user_id },
  });

  console.log('✅ Collaborator added');

  // ── Follow: alice follows bob, bob follows charlie ─────────────────────
  await prisma.follow.upsert({
    where: { follower_user_id_followed_user_id: { follower_user_id: alice.user_id, followed_user_id: bob.user_id } },
    update: {},
    create: { follower_user_id: alice.user_id, followed_user_id: bob.user_id },
  });

  await prisma.follow.upsert({
    where: { follower_user_id_followed_user_id: { follower_user_id: bob.user_id, followed_user_id: charlie.user_id } },
    update: {},
    create: { follower_user_id: bob.user_id, followed_user_id: charlie.user_id },
  });

  console.log('✅ Follow relationships created');

  console.log('');
  console.log('🎵 Seed complete! Demo accounts:');
  console.log('   alice   / password123  (artist)');
  console.log('   bob     / password123  (regular user)');
  console.log('   charlie / password123  (artist/band)');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
