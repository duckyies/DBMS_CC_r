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

-- Songs (inserted only if no song with that name exists yet)
INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Midnight Dreams', 213, '2023-03-15', JSON_ARRAY('Pop', 'Synthwave'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Midnight Dreams');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Electric Horizon', 187, '2023-05-22', JSON_ARRAY('Electronic', 'Dance'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Electric Horizon');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Velvet Sky', 245, '2023-07-10', JSON_ARRAY('Indie', 'Pop'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Velvet Sky');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Neon Lights', 198, '2023-09-01', JSON_ARRAY('Synthpop', 'Electro'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Neon Lights');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Starfall', 221, '2023-11-14', JSON_ARRAY('Pop', 'R&B'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Starfall');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Broken Compass', 264, '2022-06-20', JSON_ARRAY('Rock', 'Alternative'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Broken Compass');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Storm Rider', 302, '2022-09-05', JSON_ARRAY('Rock', 'Blues'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Storm Rider');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Silver Lining', 178, '2023-01-12', JSON_ARRAY('Indie', 'Folk'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Silver Lining');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Ember Glow', 233, '2023-04-30', JSON_ARRAY('Pop', 'Soul'), FLOOR(RAND() * 50000), TRUE
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `Song` WHERE song_name = 'Ember Glow');

INSERT INTO `Song` (`song_name`, `duration`, `publish_date`, `genres`, `listen_count`, `is_published`)
SELECT 'Frozen River', 289, '2023-08-18', JSON_ARRAY('Alternative', 'Ambient'), FLOOR(RAND() * 50000), TRUE
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
