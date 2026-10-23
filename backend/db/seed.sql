-- Demo data. Idempotent: re-running it never duplicates rows or touches existing ones.
-- Demo accounts: alice (artist), bob (regular user), charlie (band) - all with password "password123".

-- Production houses
INSERT IGNORE INTO `Production_House` (`name`, `type`) VALUES
    ('Sony Music Entertainment', 'Major Label'),
    ('Universal Music Group',    'Major Label');

-- Users (bcrypt hash of "password123")
INSERT IGNORE INTO `User` (`username`, `password_hash`, `is_artist`) VALUES
    ('alice',   '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('bob',     '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', FALSE),
    ('charlie', '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE);

-- Artist profiles
INSERT IGNORE INTO `Artist` (`user_id`, `name`, `country`, `is_band`, `band_member_ids`, `country_of_origin`, `production_house_id`)
SELECT u.user_id, 'Alice Wonderland', 'US', FALSE, NULL, 'United States', ph.production_house_id
FROM `User` u
JOIN `Production_House` ph ON ph.name = 'Sony Music Entertainment'
WHERE u.username = 'alice';

INSERT IGNORE INTO `Artist` (`user_id`, `name`, `country`, `is_band`, `band_member_ids`, `country_of_origin`, `production_house_id`)
SELECT u.user_id, 'The Charlie Band', 'UK', TRUE, JSON_ARRAY(1, 2, 3), 'United Kingdom', ph.production_house_id
FROM `User` u
JOIN `Production_House` ph ON ph.name = 'Universal Music Group'
WHERE u.username = 'charlie';

-- Songs (inserted only if no song with that name exists yet; fixed listen counts keep the demo data reproducible)
INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Midnight Dreams', 213, '2023-03-15', JSON_ARRAY('Pop', 'Synthwave'), 38257, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Midnight Dreams');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Electric Horizon', 187, '2023-05-22', JSON_ARRAY('Electronic', 'Dance'), 49307, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Electric Horizon');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Velvet Sky', 245, '2023-07-10', JSON_ARRAY('Indie', 'Pop'), 31765, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Velvet Sky');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Neon Lights', 198, '2023-09-01', JSON_ARRAY('Synthpop', 'Electro'), 10904, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Neon Lights');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Starfall', 221, '2023-11-14', JSON_ARRAY('Pop', 'R&B'), 9226, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Starfall');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Broken Compass', 264, '2022-06-20', JSON_ARRAY('Rock', 'Alternative'), 13420, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Broken Compass');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Storm Rider', 302, '2022-09-05', JSON_ARRAY('Rock', 'Blues'), 39422, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Storm Rider');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Silver Lining', 178, '2023-01-12', JSON_ARRAY('Indie', 'Folk'), 6852, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Silver Lining');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Ember Glow', 233, '2023-04-30', JSON_ARRAY('Pop', 'Soul'), 15991, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Ember Glow');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Frozen River', 289, '2023-08-18', JSON_ARRAY('Alternative', 'Ambient'), 9401, TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Frozen River');

-- Song <-> artist links
INSERT IGNORE INTO `Song_Artist_Relationship` (`song_id`, `artist_id`, `role`, `is_primary`)
SELECT s.song_id, u.user_id, 'Main Artist', TRUE
FROM `Song` s
JOIN `User` u ON u.username = 'alice'
WHERE s.song_name IN ('Midnight Dreams', 'Electric Horizon', 'Velvet Sky', 'Neon Lights', 'Starfall', 'Ember Glow');

INSERT IGNORE INTO `Song_Artist_Relationship` (`song_id`, `artist_id`, `role`, `is_primary`)
SELECT s.song_id, u.user_id, 'Main Artist', TRUE
FROM `Song` s
JOIN `User` u ON u.username = 'charlie'
WHERE s.song_name IN ('Broken Compass', 'Storm Rider', 'Silver Lining', 'Frozen River');

-- Playlists
INSERT INTO `Playlist` (`name`, `created_by_user_id`, `release_type`, `is_shared`, `duration`, `last_updated`)
SELECT 'Alice''s Debut Album', u.user_id, 'Album', TRUE, 0, NOW(3)
FROM `User` u
WHERE u.username = 'alice'
  AND NOT EXISTS (SELECT 1 FROM `Playlist` p WHERE p.name = 'Alice''s Debut Album' AND p.created_by_user_id = u.user_id);

INSERT INTO `Playlist` (`name`, `created_by_user_id`, `release_type`, `is_shared`, `duration`, `last_updated`)
SELECT 'Chill Vibes Mix', u.user_id, NULL, FALSE, 0, NOW(3)
FROM `User` u
WHERE u.username = 'bob'
  AND NOT EXISTS (SELECT 1 FROM `Playlist` p WHERE p.name = 'Chill Vibes Mix' AND p.created_by_user_id = u.user_id);

-- Playlist contents (the `order` column is a reserved word, so it is always quoted)
INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 1 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'alice'
JOIN `Song` s ON s.song_name = 'Midnight Dreams' WHERE p.name = 'Alice''s Debut Album';

INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 2 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'alice'
JOIN `Song` s ON s.song_name = 'Electric Horizon' WHERE p.name = 'Alice''s Debut Album';

INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 3 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'alice'
JOIN `Song` s ON s.song_name = 'Velvet Sky' WHERE p.name = 'Alice''s Debut Album';

INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 4 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'alice'
JOIN `Song` s ON s.song_name = 'Neon Lights' WHERE p.name = 'Alice''s Debut Album';

INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 5 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'alice'
JOIN `Song` s ON s.song_name = 'Starfall' WHERE p.name = 'Alice''s Debut Album';

INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 1 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'bob'
JOIN `Song` s ON s.song_name = 'Broken Compass' WHERE p.name = 'Chill Vibes Mix';

INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 2 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'bob'
JOIN `Song` s ON s.song_name = 'Storm Rider' WHERE p.name = 'Chill Vibes Mix';

INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 3 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'bob'
JOIN `Song` s ON s.song_name = 'Silver Lining' WHERE p.name = 'Chill Vibes Mix';

INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, 4 FROM `Playlist` p
JOIN `User` u ON u.user_id = p.created_by_user_id AND u.username = 'bob'
JOIN `Song` s ON s.song_name = 'Ember Glow' WHERE p.name = 'Chill Vibes Mix';

-- Keep the stored playlist durations in sync with their songs
UPDATE `Playlist` p
SET p.duration = (
    SELECT COALESCE(SUM(s.duration), 0)
    FROM `Playlist_Song` ps
    JOIN `Song` s ON s.song_id = ps.song_id
    WHERE ps.playlist_id = p.playlist_id
)
WHERE (p.name = 'Alice''s Debut Album' OR p.name = 'Chill Vibes Mix');

-- Bob collaborates on Alice's playlist
INSERT IGNORE INTO `Playlist_Collaborator` (`playlist_id`, `user_id`)
SELECT p.playlist_id, b.user_id
FROM `Playlist` p
JOIN `User` a ON a.user_id = p.created_by_user_id AND a.username = 'alice'
JOIN `User` b ON b.username = 'bob'
WHERE p.name = 'Alice''s Debut Album';

-- Follows: alice -> bob, bob -> charlie
INSERT IGNORE INTO `Follow` (`follower_user_id`, `followed_user_id`)
SELECT f.user_id, t.user_id FROM `User` f JOIN `User` t ON t.username = 'bob' WHERE f.username = 'alice';

INSERT IGNORE INTO `Follow` (`follower_user_id`, `followed_user_id`)
SELECT f.user_id, t.user_id FROM `User` f JOIN `User` t ON t.username = 'charlie' WHERE f.username = 'bob';

-- ============================================================================================
-- Extended placeholder data (10+ rows in every table). Idempotent like the section above:
-- re-running never duplicates rows. Every account below also uses the password "password123".
-- ============================================================================================

-- More production houses (10 total)
INSERT IGNORE INTO `Production_House` (`name`, `type`) VALUES
    ('Harbor Lane Records',    'Independent Label'),
    ('Velvet Room Music',      'Independent Label'),
    ('Crescent Sound Group',   'Major Label'),
    ('Blue Orchid Records',    'Boutique Label'),
    ('Static Bloom Collective','Independent Label'),
    ('Golden Hour Entertainment', 'Major Label'),
    ('Paper Lantern Records',  'Independent Label'),
    ('Tidewater Music',        'Subsidiary Label');

-- More users: 8 artists (diana ... jonas) and 4 listeners (hannah ... kevin)
INSERT IGNORE INTO `User` (`username`, `password_hash`, `is_artist`) VALUES
    ('diana',  '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('evan',   '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('fiona',  '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('george', '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('gina',   '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('hugo',   '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('isla',   '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('jonas',  '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', TRUE),
    ('hannah', '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', FALSE),
    ('ian',    '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', FALSE),
    ('julia',  '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', FALSE),
    ('kevin',  '$2b$12$Fzi.matzl1F7KoE9XJfWxuSPN5BDcFiLk7.gb1v9IQMd5ocvZ5nVO', FALSE);

-- Artist profiles (jonas has no label on purpose: production_house_id is nullable)
INSERT IGNORE INTO `Artist` (`user_id`, `name`, `country`, `is_band`, `band_member_ids`, `country_of_origin`, `production_house_id`)
SELECT u.user_id, d.name, d.country, d.is_band, NULL, d.origin, ph.production_house_id
FROM (
    SELECT 'diana'  AS username, 'Diana Voss'         AS name, 'CA' AS country, FALSE AS is_band, 'Canada'    AS origin, 'Harbor Lane Records'     AS house
    UNION ALL SELECT 'evan',   'Evan & The Echoes',  'AU', TRUE,  'Australia', 'Velvet Room Music'
    UNION ALL SELECT 'fiona',  'Fiona Reyes',        'MX', FALSE, 'Mexico',    'Crescent Sound Group'
    UNION ALL SELECT 'george', 'Neon Wolves',        'DE', TRUE,  'Germany',   'Blue Orchid Records'
    UNION ALL SELECT 'gina',   'Gina Okafor',        'NG', FALSE, 'Nigeria',   'Static Bloom Collective'
    UNION ALL SELECT 'hugo',   'Hugo Laurent',       'FR', FALSE, 'France',    'Tidewater Music'
    UNION ALL SELECT 'isla',   'Isla Nakamura',      'JP', FALSE, 'Japan',     'Paper Lantern Records'
    UNION ALL SELECT 'jonas',  'Jonas Berg',         'SE', FALSE, 'Sweden',    NULL
) d
JOIN `User` u ON u.username = d.username
LEFT JOIN `Production_House` ph ON ph.name = d.house;

-- Band members are user ids (JSON array): listeners and fellow artists who play in the band
UPDATE `Artist` a
JOIN `User` bu ON bu.user_id = a.user_id AND bu.username = 'evan'
SET a.band_member_ids = (SELECT JSON_ARRAYAGG(m.user_id) FROM `User` m WHERE m.username IN ('evan', 'hannah', 'ian'))
WHERE a.is_band = TRUE AND a.band_member_ids IS NULL;

UPDATE `Artist` a
JOIN `User` bu ON bu.user_id = a.user_id AND bu.username = 'george'
SET a.band_member_ids = (SELECT JSON_ARRAYAGG(m.user_id) FROM `User` m WHERE m.username IN ('george', 'julia', 'kevin'))
WHERE a.is_band = TRUE AND a.band_member_ids IS NULL;

-- More songs (one unpublished demo to exercise the is_published flag)
INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT d.song_name, d.duration, d.publish_date, d.genres, d.listen_count, d.is_published
FROM (
    SELECT 'Northern Lights' AS song_name, 254 AS duration, DATE '2024-01-19' AS publish_date, JSON_ARRAY('Electronic', 'Ambient') AS genres, 21840 AS listen_count, TRUE AS is_published
    UNION ALL SELECT 'Paper Boats',           201, DATE '2024-03-08', JSON_ARRAY('Folk', 'Indie'),            8712, TRUE
    UNION ALL SELECT 'Highway Hum',           227, DATE '2024-06-14', JSON_ARRAY('Country', 'Folk'),         14305, TRUE
    UNION ALL SELECT 'Demo Tape 01',          188, DATE '2024-09-02', JSON_ARRAY('Lo-Fi', 'Indie'),              0, FALSE
    UNION ALL SELECT 'Echo Chamber',          243, DATE '2023-10-06', JSON_ARRAY('Rock', 'Alternative'),     27118, TRUE
    UNION ALL SELECT 'Burning Bridges',       276, DATE '2024-02-02', JSON_ARRAY('Rock', 'Metal'),           19554, TRUE
    UNION ALL SELECT 'Sol y Sombra',          209, DATE '2024-04-12', JSON_ARRAY('Pop', 'Latin'),            33410, TRUE
    UNION ALL SELECT 'Bailando en la Lluvia', 192, DATE '2024-05-24', JSON_ARRAY('Latin', 'Dance'),          28976, TRUE
    UNION ALL SELECT 'Iron Howl',             318, DATE '2023-12-01', JSON_ARRAY('Metal', 'Hard Rock'),      12043, TRUE
    UNION ALL SELECT 'Midnight Run',          224, DATE '2024-07-19', JSON_ARRAY('Rock', 'Electronic'),       9987, TRUE
    UNION ALL SELECT 'Lagos Nights',          215, DATE '2024-02-23', JSON_ARRAY('Afrobeats', 'Pop'),        41276, TRUE
    UNION ALL SELECT 'Golden Road',           238, DATE '2024-08-30', JSON_ARRAY('R&B', 'Soul'),             17660, TRUE
    UNION ALL SELECT 'Café Brume',            281, DATE '2023-06-09', JSON_ARRAY('Jazz', 'Lounge'),           6421, TRUE
    UNION ALL SELECT 'Minuit à Paris',        305, DATE '2024-01-05', JSON_ARRAY('Jazz', 'Classical'),        5318, TRUE
    UNION ALL SELECT 'Sakura Rain',           334, DATE '2024-03-29', JSON_ARRAY('Classical', 'Ambient'),    11209, TRUE
    UNION ALL SELECT 'City Pop Dreams',       247, DATE '2024-05-10', JSON_ARRAY('Pop', 'City Pop'),         23871, TRUE
    UNION ALL SELECT 'Fjord',                 312, DATE '2023-11-03', JSON_ARRAY('Ambient', 'Classical'),     7764, TRUE
    UNION ALL SELECT 'Concrete Poetry',       198, DATE '2024-06-28', JSON_ARRAY('Hip-Hop', 'Rap'),          36502, TRUE
) d
WHERE NOT EXISTS (SELECT 1 FROM `Song` s WHERE s.song_name = d.song_name);

-- Song <-> artist links: every new song has one primary artist; some also credit helpers
INSERT IGNORE INTO `Song_Artist_Relationship` (`song_id`, `artist_id`, `role`, `is_primary`)
SELECT s.song_id, u.user_id, d.role, d.is_primary
FROM (
    SELECT 'Northern Lights' AS song_name, 'diana' AS username, 'Main Artist' AS role, TRUE AS is_primary
    UNION ALL SELECT 'Paper Boats',           'diana',  'Main Artist',     TRUE
    UNION ALL SELECT 'Highway Hum',           'diana',  'Main Artist',     TRUE
    UNION ALL SELECT 'Demo Tape 01',          'diana',  'Main Artist',     TRUE
    UNION ALL SELECT 'Echo Chamber',          'evan',   'Main Artist',     TRUE
    UNION ALL SELECT 'Burning Bridges',       'evan',   'Main Artist',     TRUE
    UNION ALL SELECT 'Sol y Sombra',          'fiona',  'Main Artist',     TRUE
    UNION ALL SELECT 'Bailando en la Lluvia', 'fiona',  'Main Artist',     TRUE
    UNION ALL SELECT 'Iron Howl',             'george', 'Main Artist',     TRUE
    UNION ALL SELECT 'Midnight Run',          'george', 'Main Artist',     TRUE
    UNION ALL SELECT 'Lagos Nights',          'gina',   'Main Artist',     TRUE
    UNION ALL SELECT 'Golden Road',           'gina',   'Main Artist',     TRUE
    UNION ALL SELECT 'Café Brume',            'hugo',   'Main Artist',     TRUE
    UNION ALL SELECT 'Minuit à Paris',        'hugo',   'Main Artist',     TRUE
    UNION ALL SELECT 'Sakura Rain',           'isla',   'Main Artist',     TRUE
    UNION ALL SELECT 'City Pop Dreams',       'isla',   'Main Artist',     TRUE
    UNION ALL SELECT 'Fjord',                 'jonas',  'Main Artist',     TRUE
    UNION ALL SELECT 'Concrete Poetry',       'jonas',  'Main Artist',     TRUE
    UNION ALL SELECT 'Sol y Sombra',          'gina',   'Featured Artist', FALSE
    UNION ALL SELECT 'Lagos Nights',          'fiona',  'Featured Artist', FALSE
    UNION ALL SELECT 'Echo Chamber',          'diana',  'Producer',        FALSE
    UNION ALL SELECT 'Iron Howl',             'evan',   'Featured Artist', FALSE
    UNION ALL SELECT 'Café Brume',            'isla',   'Songwriter',      FALSE
    UNION ALL SELECT 'Paper Boats',           'alice',  'Featured Artist', FALSE
    UNION ALL SELECT 'Velvet Sky',            'charlie','Featured Artist', FALSE
    UNION ALL SELECT 'Fjord',                 'isla',   'Producer',        FALSE
    UNION ALL SELECT 'Concrete Poetry',       'gina',   'Featured Artist', FALSE
    UNION ALL SELECT 'Midnight Dreams',       'hugo',   'Producer',        FALSE
) d
JOIN `Song` s ON s.song_name = d.song_name
JOIN `User` u ON u.username = d.username;

-- More playlists: listener mixes, a few artist releases (Single / EP / Album), shared and private
INSERT INTO `Playlist` (`name`, `created_by_user_id`, `release_type`, `is_shared`, `duration`, `cover_art_url`, `last_updated`)
SELECT d.name, u.user_id, d.release_type, d.is_shared, 0, d.cover_art_url, NOW(3)
FROM (
    SELECT 'Late Night Drive' AS name, 'hannah' AS username, NULL AS release_type, TRUE AS is_shared, 'https://picsum.photos/seed/latenightdrive/400' AS cover_art_url
    UNION ALL SELECT 'Workout Fuel',                 'ian',    NULL,     TRUE,  'https://picsum.photos/seed/workoutfuel/400'
    UNION ALL SELECT 'Sunday Jazz',                  'julia',  NULL,     FALSE, NULL
    UNION ALL SELECT 'Focus & Study',                'kevin',  NULL,     TRUE,  'https://picsum.photos/seed/focusstudy/400'
    UNION ALL SELECT 'Lagos Nights - Single',        'gina',   'Single', TRUE,  'https://picsum.photos/seed/lagosnights/400'
    UNION ALL SELECT 'Wanderlight EP',               'diana',  'EP',     TRUE,  'https://picsum.photos/seed/wanderlight/400'
    UNION ALL SELECT 'Echoes EP',                    'evan',   'EP',     TRUE,  'https://picsum.photos/seed/echoesep/400'
    UNION ALL SELECT 'Road Trip Mix',                'alice',  NULL,     TRUE,  'https://picsum.photos/seed/roadtrip/400'
    UNION ALL SELECT 'Throwback Favourites',         'bob',    NULL,     FALSE, NULL
) d
JOIN `User` u ON u.username = d.username
WHERE NOT EXISTS (SELECT 1 FROM `Playlist` p WHERE p.name = d.name AND p.created_by_user_id = u.user_id);

-- Playlist contents (`order` is a reserved word, so it is quoted)
INSERT IGNORE INTO `Playlist_Song` (`playlist_id`, `song_id`, `order`)
SELECT p.playlist_id, s.song_id, d.pos
FROM (
    SELECT 'Late Night Drive' AS playlist_name, 'hannah' AS owner, 'Midnight Dreams' AS song_name, 1 AS pos
    UNION ALL SELECT 'Late Night Drive', 'hannah', 'Neon Lights',            2
    UNION ALL SELECT 'Late Night Drive', 'hannah', 'Northern Lights',        3
    UNION ALL SELECT 'Late Night Drive', 'hannah', 'Midnight Run',           4
    UNION ALL SELECT 'Late Night Drive', 'hannah', 'Echo Chamber',           5
    UNION ALL SELECT 'Workout Fuel',     'ian',    'Iron Howl',              1
    UNION ALL SELECT 'Workout Fuel',     'ian',    'Burning Bridges',        2
    UNION ALL SELECT 'Workout Fuel',     'ian',    'Storm Rider',            3
    UNION ALL SELECT 'Workout Fuel',     'ian',    'Concrete Poetry',        4
    UNION ALL SELECT 'Workout Fuel',     'ian',    'Bailando en la Lluvia',  5
    UNION ALL SELECT 'Sunday Jazz',      'julia',  'Café Brume',             1
    UNION ALL SELECT 'Sunday Jazz',      'julia',  'Minuit à Paris',         2
    UNION ALL SELECT 'Sunday Jazz',      'julia',  'Silver Lining',          3
    UNION ALL SELECT 'Focus & Study',    'kevin',  'Sakura Rain',            1
    UNION ALL SELECT 'Focus & Study',    'kevin',  'Fjord',                  2
    UNION ALL SELECT 'Focus & Study',    'kevin',  'Frozen River',           3
    UNION ALL SELECT 'Focus & Study',    'kevin',  'Northern Lights',        4
    UNION ALL SELECT 'Lagos Nights - Single', 'gina', 'Lagos Nights',        1
    UNION ALL SELECT 'Wanderlight EP',   'diana',  'Northern Lights',        1
    UNION ALL SELECT 'Wanderlight EP',   'diana',  'Paper Boats',            2
    UNION ALL SELECT 'Wanderlight EP',   'diana',  'Highway Hum',            3
    UNION ALL SELECT 'Echoes EP',        'evan',   'Echo Chamber',           1
    UNION ALL SELECT 'Echoes EP',        'evan',   'Burning Bridges',        2
    UNION ALL SELECT 'Road Trip Mix',    'alice',  'Highway Hum',            1
    UNION ALL SELECT 'Road Trip Mix',    'alice',  'Storm Rider',            2
    UNION ALL SELECT 'Road Trip Mix',    'alice',  'Midnight Run',           3
    UNION ALL SELECT 'Road Trip Mix',    'alice',  'Starfall',               4
    UNION ALL SELECT 'Road Trip Mix',    'alice',  'Ember Glow',             5
    UNION ALL SELECT 'Road Trip Mix',    'alice',  'Golden Road',            6
    UNION ALL SELECT 'Throwback Favourites', 'bob', 'Velvet Sky',            1
    UNION ALL SELECT 'Throwback Favourites', 'bob', 'Broken Compass',        2
    UNION ALL SELECT 'Throwback Favourites', 'bob', 'Silver Lining',         3
    UNION ALL SELECT 'Throwback Favourites', 'bob', 'Sol y Sombra',          4
) d
JOIN `User` o ON o.username = d.owner
JOIN `Playlist` p ON p.name = d.playlist_name AND p.created_by_user_id = o.user_id
JOIN `Song` s ON s.song_name = d.song_name;

-- Keep every stored playlist duration in sync with its songs (also fixes older rows)
UPDATE `Playlist` p
SET p.duration = (
    SELECT COALESCE(SUM(s.duration), 0)
    FROM `Playlist_Song` ps
    JOIN `Song` s ON s.song_id = ps.song_id
    WHERE ps.playlist_id = p.playlist_id
);

-- Collaborators (never the owner)
INSERT IGNORE INTO `Playlist_Collaborator` (`playlist_id`, `user_id`)
SELECT p.playlist_id, c.user_id
FROM (
    SELECT 'Late Night Drive' AS playlist_name, 'hannah' AS owner, 'ian' AS collaborator
    UNION ALL SELECT 'Late Night Drive',     'hannah', 'julia'
    UNION ALL SELECT 'Workout Fuel',         'ian',    'kevin'
    UNION ALL SELECT 'Workout Fuel',         'ian',    'evan'
    UNION ALL SELECT 'Sunday Jazz',          'julia',  'hugo'
    UNION ALL SELECT 'Sunday Jazz',          'julia',  'hannah'
    UNION ALL SELECT 'Focus & Study',        'kevin',  'isla'
    UNION ALL SELECT 'Focus & Study',        'kevin',  'jonas'
    UNION ALL SELECT 'Wanderlight EP',       'diana',  'alice'
    UNION ALL SELECT 'Wanderlight EP',       'diana',  'evan'
    UNION ALL SELECT 'Echoes EP',            'evan',   'george'
    UNION ALL SELECT 'Road Trip Mix',        'alice',  'bob'
    UNION ALL SELECT 'Road Trip Mix',        'alice',  'diana'
    UNION ALL SELECT 'Road Trip Mix',        'alice',  'fiona'
    UNION ALL SELECT 'Throwback Favourites', 'bob',    'charlie'
) d
JOIN `User` o ON o.username = d.owner
JOIN `Playlist` p ON p.name = d.playlist_name AND p.created_by_user_id = o.user_id
JOIN `User` c ON c.username = d.collaborator;

-- Follows
INSERT IGNORE INTO `Follow` (`follower_user_id`, `followed_user_id`)
SELECT f.user_id, t.user_id
FROM (
    SELECT 'hannah' AS follower, 'alice' AS followed
    UNION ALL SELECT 'hannah', 'diana'
    UNION ALL SELECT 'hannah', 'charlie'
    UNION ALL SELECT 'ian',    'george'
    UNION ALL SELECT 'ian',    'evan'
    UNION ALL SELECT 'ian',    'jonas'
    UNION ALL SELECT 'julia',  'hugo'
    UNION ALL SELECT 'julia',  'isla'
    UNION ALL SELECT 'kevin',  'isla'
    UNION ALL SELECT 'kevin',  'jonas'
    UNION ALL SELECT 'kevin',  'hannah'
    UNION ALL SELECT 'diana',  'alice'
    UNION ALL SELECT 'evan',   'george'
    UNION ALL SELECT 'fiona',  'gina'
    UNION ALL SELECT 'gina',   'fiona'
    UNION ALL SELECT 'hugo',   'isla'
    UNION ALL SELECT 'bob',    'alice'
    UNION ALL SELECT 'bob',    'hugo'
    UNION ALL SELECT 'charlie','alice'
    UNION ALL SELECT 'ducky',  'bob'
) d
JOIN `User` f ON f.username = d.follower
JOIN `User` t ON t.username = d.followed;

-- Listening history: only loaded while the table is empty (it has no natural key to dedupe on)
INSERT INTO `Listening_Activity` (`user_id`, `song_id`, `listening_time`, `timestamp`)
SELECT u.user_id, s.song_id, d.seconds, NOW(3) - INTERVAL d.hours_ago HOUR
FROM (
    SELECT 'bob' AS username, 'Midnight Dreams' AS song_name, 213 AS seconds, 2 AS hours_ago
    UNION ALL SELECT 'bob',     'Electric Horizon',  187, 3
    UNION ALL SELECT 'bob',     'Lagos Nights',      150, 26
    UNION ALL SELECT 'ducky',   'Northern Lights',   254, 5
    UNION ALL SELECT 'ducky',   'Echo Chamber',      243, 6
    UNION ALL SELECT 'alice',   'Sakura Rain',       120, 30
    UNION ALL SELECT 'alice',   'Café Brume',        281, 31
    UNION ALL SELECT 'charlie', 'Midnight Dreams',    90, 50
    UNION ALL SELECT 'hannah',  'Midnight Dreams',   213, 1
    UNION ALL SELECT 'hannah',  'Neon Lights',       198, 2
    UNION ALL SELECT 'hannah',  'Northern Lights',   254, 4
    UNION ALL SELECT 'ian',     'Iron Howl',         318, 8
    UNION ALL SELECT 'ian',     'Burning Bridges',   276, 9
    UNION ALL SELECT 'ian',     'Concrete Poetry',   198, 10
    UNION ALL SELECT 'julia',   'Café Brume',        281, 12
    UNION ALL SELECT 'julia',   'Minuit à Paris',    305, 13
    UNION ALL SELECT 'kevin',   'Sakura Rain',       334, 15
    UNION ALL SELECT 'kevin',   'Fjord',             312, 16
    UNION ALL SELECT 'kevin',   'Frozen River',      150, 17
    UNION ALL SELECT 'diana',   'Golden Road',       238, 20
    UNION ALL SELECT 'fiona',   'Lagos Nights',      215, 22
    UNION ALL SELECT 'george',  'Echo Chamber',      243, 40
) d
JOIN `User` u ON u.username = d.username
JOIN `Song` s ON s.song_name = d.song_name
WHERE NOT EXISTS (SELECT 1 FROM `Listening_Activity`);

-- Lyrics (original placeholder text, one file per song)
INSERT INTO `Lyrics` (`song_id`, `lyrics_text`, `lyrics_filename`)
SELECT s.song_id, d.lyrics_text, d.lyrics_filename
FROM (
    SELECT 'Midnight Dreams' AS song_name, 'midnight_dreams.txt' AS lyrics_filename,
           'City lights are melting into violet skies\nI close my eyes and let the neon rise\nMidnight dreams, carry me home\nThrough the static, never alone' AS lyrics_text
    UNION ALL SELECT 'Electric Horizon', 'electric_horizon.txt',
           'Chasing the line where the circuits glow\nBass in my chest and nowhere to go\nElectric horizon, pull me in\nLet the morning light begin'
    UNION ALL SELECT 'Velvet Sky', 'velvet_sky.txt',
           'Under a velvet sky we trade our sighs\nStars stitched in the seams of your eyes\nHold on to the quiet, hold on to me\nWe are whatever we want to be'
    UNION ALL SELECT 'Neon Lights', 'neon_lights.txt',
           'Neon lights on a rain-slick street\nThe city hums a heartbeat\nPink and blue on the window pane\nDancing through the falling rain'
    UNION ALL SELECT 'Starfall', 'starfall.txt',
           'Make a wish on a burning star\nIt does not matter where you are\nStarfall, starfall, light the night\nEverything will be alright'
    UNION ALL SELECT 'Broken Compass', 'broken_compass.txt',
           'My broken compass spins in the dark\nNo north, no south, just a spark\nI will walk it out until the dawn\nFind a road that I can call my own'
    UNION ALL SELECT 'Storm Rider', 'storm_rider.txt',
           'Thunder in my bones and a road ahead\nLeave the quiet town and the words unsaid\nStorm rider, ride the sound\nNever looking back, never slowing down'
    UNION ALL SELECT 'Silver Lining', 'silver_lining.txt',
           'Grey clouds gather but I know\nThere is a silver lining where the wild things grow\nPour the coffee, open the door\nToday is better than the day before'
    UNION ALL SELECT 'Northern Lights', 'northern_lights.txt',
           'Green and gold across the frozen lake\nEvery breath is a promise we make\nNorthern lights, paint the night\nFill the silence with your light'
    UNION ALL SELECT 'Paper Boats', 'paper_boats.txt',
           'We folded all our worries into paper boats\nSet them on the river, watched them float\nThey sailed away beyond the bend\nAnd we began again'
    UNION ALL SELECT 'Echo Chamber', 'echo_chamber.txt',
           'Every word I say comes back to me\nBouncing off the walls of what could be\nEcho chamber, break the glass\nLet the real voice finally pass'
    UNION ALL SELECT 'Lagos Nights', 'lagos_nights.txt',
           'Warm air, loud drums, the city comes alive\nLagos nights, we dance until sunrise\nHands up high, feel the rhythm start\nThe beat is the beat of my heart'
    UNION ALL SELECT 'Sol y Sombra', 'sol_y_sombra.txt',
           'Entre el sol y la sombra te encontre\nBailando despacio, sin saber por que\nSol y sombra, dos mitades de un cantar\nSolo quiero contigo quedarme a bailar'
) d
JOIN `Song` s ON s.song_name = d.song_name
WHERE NOT EXISTS (SELECT 1 FROM `Lyrics` l WHERE l.lyrics_filename = d.lyrics_filename);
