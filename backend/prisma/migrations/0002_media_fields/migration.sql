-- AlterTable
ALTER TABLE `Song`
    MODIFY `listen_count` INTEGER NULL,
    ADD COLUMN `file_path` VARCHAR(500) NULL,
    ADD COLUMN `downloaded_at` DATETIME(3) NULL,
    ADD COLUMN `album` VARCHAR(255) NULL,
    ADD COLUMN `cover_art_url` VARCHAR(500) NULL;
