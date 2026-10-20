-- MusicLib schema (MySQL 8).
-- Every statement is idempotent (CREATE TABLE IF NOT EXISTS) so it is safe to run
-- on each backend start, and it also adopts a database previously created by Prisma.

CREATE TABLE IF NOT EXISTS `User` (
    `user_id`       INT          NOT NULL AUTO_INCREMENT,
    `username`      VARCHAR(100) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `is_artist`     BOOLEAN      NOT NULL DEFAULT FALSE,
    `created_at`    DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `last_login`    DATETIME(3)  NULL,

    PRIMARY KEY (`user_id`),
    UNIQUE KEY `User_username_key` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Production_House` (
    `production_house_id` INT          NOT NULL AUTO_INCREMENT,
    `name`                VARCHAR(255) NOT NULL,
    `type`                VARCHAR(100) NOT NULL,

    PRIMARY KEY (`production_house_id`),
    UNIQUE KEY `Production_House_name_key` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Artist` (
    `user_id`             INT          NOT NULL,
    `name`                VARCHAR(255) NOT NULL,
    `country`             VARCHAR(100) NULL,
    `is_band`             BOOLEAN      NOT NULL DEFAULT FALSE,
    `band_member_ids`     JSON         NULL,
    `country_of_origin`   VARCHAR(100) NULL,
    `production_house_id` INT          NULL,
    `created_at`          DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`user_id`),
    KEY `Artist_country_idx` (`country`),
    CONSTRAINT `Artist_user_id_fkey` FOREIGN KEY (`user_id`)
        REFERENCES `User` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `Artist_production_house_id_fkey` FOREIGN KEY (`production_house_id`)
        REFERENCES `Production_House` (`production_house_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Song` (
    `song_id`      INT          NOT NULL AUTO_INCREMENT,
    `song_name`    VARCHAR(255) NOT NULL,
    `duration`     INT          NOT NULL,                -- seconds
    `publish_date` DATE         NOT NULL,
    `genres`       JSON         NOT NULL,                -- e.g. ["Pop", "Synthwave"]
    `listen_count` INT          NOT NULL DEFAULT 0,
    `is_published` BOOLEAN      NOT NULL DEFAULT TRUE,

    PRIMARY KEY (`song_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Song_Artist_Relationship` (
    `song_id`    INT          NOT NULL,
    `artist_id`  INT          NOT NULL,
    `role`       VARCHAR(100) NOT NULL,
    `is_primary` BOOLEAN      NOT NULL DEFAULT FALSE,

    PRIMARY KEY (`song_id`, `artist_id`),
    CONSTRAINT `Song_Artist_Relationship_song_id_fkey` FOREIGN KEY (`song_id`)
        REFERENCES `Song` (`song_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `Song_Artist_Relationship_artist_id_fkey` FOREIGN KEY (`artist_id`)
        REFERENCES `Artist` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Playlist` (
    `playlist_id`        INT          NOT NULL AUTO_INCREMENT,
    `name`               VARCHAR(255) NOT NULL,
    `created_by_user_id` INT          NOT NULL,
    `cover_art_url`      VARCHAR(500) NULL,
    `duration`           INT          NOT NULL DEFAULT 0,   -- total seconds
    `release_type`       ENUM('Single', 'EP', 'Album') NULL,
    `last_updated`       DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `is_shared`          BOOLEAN      NOT NULL DEFAULT FALSE,

    PRIMARY KEY (`playlist_id`),
    CONSTRAINT `Playlist_created_by_user_id_fkey` FOREIGN KEY (`created_by_user_id`)
        REFERENCES `User` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Playlist_Song` (
    `playlist_id` INT NOT NULL,
    `song_id`     INT NOT NULL,
    `order`       INT NOT NULL DEFAULT 0,

    PRIMARY KEY (`playlist_id`, `song_id`),
    CONSTRAINT `Playlist_Song_playlist_id_fkey` FOREIGN KEY (`playlist_id`)
        REFERENCES `Playlist` (`playlist_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `Playlist_Song_song_id_fkey` FOREIGN KEY (`song_id`)
        REFERENCES `Song` (`song_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Playlist_Collaborator` (
    `playlist_id` INT NOT NULL,
    `user_id`     INT NOT NULL,

    PRIMARY KEY (`playlist_id`, `user_id`),
    CONSTRAINT `Playlist_Collaborator_playlist_id_fkey` FOREIGN KEY (`playlist_id`)
        REFERENCES `Playlist` (`playlist_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `Playlist_Collaborator_user_id_fkey` FOREIGN KEY (`user_id`)
        REFERENCES `User` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Follow` (
    `follower_user_id` INT NOT NULL,
    `followed_user_id` INT NOT NULL,

    PRIMARY KEY (`follower_user_id`, `followed_user_id`),
    CONSTRAINT `Follow_follower_user_id_fkey` FOREIGN KEY (`follower_user_id`)
        REFERENCES `User` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `Follow_followed_user_id_fkey` FOREIGN KEY (`followed_user_id`)
        REFERENCES `User` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Listening_Activity` (
    `activity_id`    INT         NOT NULL AUTO_INCREMENT,
    `user_id`        INT         NOT NULL,
    `song_id`        INT         NOT NULL,
    `listening_time` INT         NOT NULL,                  -- seconds
    `timestamp`      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`activity_id`),
    CONSTRAINT `Listening_Activity_user_id_fkey` FOREIGN KEY (`user_id`)
        REFERENCES `User` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `Listening_Activity_song_id_fkey` FOREIGN KEY (`song_id`)
        REFERENCES `Song` (`song_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `Lyrics` (
    `lyrics_id`       INT          NOT NULL AUTO_INCREMENT,
    `song_id`         INT          NOT NULL,
    `lyrics_text`     LONGTEXT     NOT NULL,
    `lyrics_filename` VARCHAR(255) NOT NULL,

    PRIMARY KEY (`lyrics_id`),
    CONSTRAINT `Lyrics_song_id_fkey` FOREIGN KEY (`song_id`)
        REFERENCES `Song` (`song_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
