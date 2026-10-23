-- Row count of every table in music_library.
SELECT 'User' AS table_name, COUNT(*) AS row_count FROM User
UNION ALL SELECT 'Artist', COUNT(*) FROM Artist
UNION ALL SELECT 'Production_House', COUNT(*) FROM Production_House
UNION ALL SELECT 'Song', COUNT(*) FROM Song
UNION ALL SELECT 'Song_Artist_Relationship', COUNT(*) FROM Song_Artist_Relationship
UNION ALL SELECT 'Playlist', COUNT(*) FROM Playlist
UNION ALL SELECT 'Playlist_Song', COUNT(*) FROM Playlist_Song
UNION ALL SELECT 'Playlist_Collaborator', COUNT(*) FROM Playlist_Collaborator
UNION ALL SELECT 'Follow', COUNT(*) FROM Follow
UNION ALL SELECT 'Listening_Activity', COUNT(*) FROM Listening_Activity
UNION ALL SELECT 'Lyrics', COUNT(*) FROM Lyrics;
