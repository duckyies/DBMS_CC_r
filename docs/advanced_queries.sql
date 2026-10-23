-- MusicLib: advanced SQL queries (MySQL 8). Run them against the music_library database:
--   docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -t music_library' < docs/advanced_queries.sql
-- Each query is preceded by a comment saying what it answers.

-- Q1: most-played songs with artist and label (four-table join, LEFT JOIN keeps unlabelled artists)
SELECT s.song_name, a.name AS artist, ph.name AS label, s.listen_count
FROM Song s
JOIN Song_Artist_Relationship sar ON sar.song_id = s.song_id AND sar.is_primary = 1
JOIN Artist a ON a.user_id = sar.artist_id
LEFT JOIN Production_House ph ON ph.production_house_id = a.production_house_id
WHERE s.is_published = 1
ORDER BY s.listen_count DESC
LIMIT 5;

-- Q2: label performance (GROUP BY, HAVING, aggregates)
SELECT ph.name AS label, COUNT(DISTINCT a.user_id) AS artists, COUNT(sar.song_id) AS credits, SUM(s.listen_count) AS total_listens
FROM Production_House ph
JOIN Artist a ON a.production_house_id = ph.production_house_id
JOIN Song_Artist_Relationship sar ON sar.artist_id = a.user_id AND sar.is_primary = 1
JOIN Song s ON s.song_id = sar.song_id
GROUP BY ph.production_house_id, ph.name
HAVING COUNT(sar.song_id) >= 2
ORDER BY total_listens DESC;

-- Q3: playlists alice owns or collaborates on (correlated subqueries, EXISTS)
SELECT p.playlist_id, p.name, u.username AS creator,
       (SELECT COUNT(*) FROM Playlist_Song ps WHERE ps.playlist_id = p.playlist_id) AS songs_count,
       (SELECT COUNT(*) FROM Playlist_Collaborator pc WHERE pc.playlist_id = p.playlist_id) AS collaborators_count
FROM Playlist p JOIN User u ON u.user_id = p.created_by_user_id
WHERE p.created_by_user_id = (SELECT user_id FROM User WHERE username = 'alice')
   OR EXISTS (SELECT 1 FROM Playlist_Collaborator c WHERE c.playlist_id = p.playlist_id AND c.user_id = (SELECT user_id FROM User WHERE username = 'alice'))
ORDER BY p.playlist_id;

-- Q4: best song per genre (JSON_TABLE, CTE, RANK)
WITH song_genre AS (
    SELECT s.song_id, s.song_name, s.listen_count, jt.genre
    FROM Song s, JSON_TABLE(s.genres, '$[*]' COLUMNS (genre VARCHAR(50) PATH '$')) jt
    WHERE s.is_published = 1
), ranked AS (
    SELECT genre, song_name, listen_count,
           RANK() OVER (PARTITION BY genre ORDER BY listen_count DESC) AS rnk
    FROM song_genre
)
SELECT genre, song_name, listen_count FROM ranked WHERE rnk = 1 ORDER BY listen_count DESC LIMIT 8;

-- Q5: band members unpacked from the JSON list (JSON_TABLE)
SELECT a.name AS band, u.username AS member
FROM Artist a
JOIN JSON_TABLE(a.band_member_ids, '$[*]' COLUMNS (member_id INT PATH '$')) jt
JOIN User u ON u.user_id = jt.member_id
WHERE a.is_band = 1
ORDER BY a.name, u.user_id;

-- Q6: mutual follows (self join)
SELECT a.username AS user_a, b.username AS user_b
FROM Follow f1
JOIN Follow f2 ON f2.follower_user_id = f1.followed_user_id AND f2.followed_user_id = f1.follower_user_id
JOIN User a ON a.user_id = f1.follower_user_id
JOIN User b ON b.user_id = f1.followed_user_id
WHERE f1.follower_user_id < f1.followed_user_id
ORDER BY a.username;

-- Q7: who hannah reaches within two follows (recursive CTE)
WITH RECURSIVE reach AS (
    SELECT followed_user_id AS user_id, 1 AS depth
    FROM Follow WHERE follower_user_id = (SELECT user_id FROM User WHERE username = 'hannah')
    UNION
    SELECT f.followed_user_id, r.depth + 1
    FROM reach r JOIN Follow f ON f.follower_user_id = r.user_id
    WHERE r.depth < 2
)
SELECT u.username, MIN(r.depth) AS hops
FROM reach r JOIN User u ON u.user_id = r.user_id
WHERE u.username <> 'hannah'
GROUP BY u.user_id, u.username
ORDER BY hops, u.username;

-- Q8: window function, running playlist time for Road Trip Mix
SELECT ps.`order` AS pos, s.song_name, s.duration,
       SUM(s.duration) OVER (PARTITION BY ps.playlist_id ORDER BY ps.`order`) AS running_seconds
FROM Playlist_Song ps JOIN Song s ON s.song_id = ps.song_id
WHERE ps.playlist_id = (SELECT playlist_id FROM Playlist WHERE name = 'Road Trip Mix')
ORDER BY ps.`order`;

-- Q9: published songs never played (anti-join)
SELECT s.song_id, s.song_name
FROM Song s
LEFT JOIN Listening_Activity la ON la.song_id = s.song_id
WHERE s.is_published = 1 AND la.activity_id IS NULL
ORDER BY s.song_id
LIMIT 6;

-- Q10: audit: stored playlist duration vs recomputed (returns no rows when consistent)
SELECT p.playlist_id, p.name, p.duration AS stored_secs,
       (SELECT COALESCE(SUM(s.duration),0) FROM Playlist_Song ps JOIN Song s ON s.song_id = ps.song_id WHERE ps.playlist_id = p.playlist_id) AS computed_secs
FROM Playlist p
HAVING stored_secs <> computed_secs;

-- Q11: audit: listen_count vs logged plays
SELECT s.song_name, s.listen_count, COUNT(la.activity_id) AS logged_plays
FROM Song s JOIN Listening_Activity la ON la.song_id = s.song_id
GROUP BY s.song_id, s.song_name, s.listen_count
ORDER BY logged_plays DESC, s.song_name
LIMIT 4;

-- Q12: per-user summary from pre-aggregated derived tables (no join fan-out)
SELECT u.username,
       COALESCE(p.playlists, 0) AS playlists,
       COALESCE(f.following, 0) AS following,
       COALESCE(l.seconds_listened, 0) AS seconds_listened
FROM User u
LEFT JOIN (SELECT created_by_user_id AS uid, COUNT(*) AS playlists FROM Playlist GROUP BY created_by_user_id) p ON p.uid = u.user_id
LEFT JOIN (SELECT follower_user_id AS uid, COUNT(*) AS following FROM Follow GROUP BY follower_user_id) f ON f.uid = u.user_id
LEFT JOIN (SELECT user_id AS uid, SUM(listening_time) AS seconds_listened FROM Listening_Activity GROUP BY user_id) l ON l.uid = u.user_id
ORDER BY seconds_listened DESC, u.username
LIMIT 6;
