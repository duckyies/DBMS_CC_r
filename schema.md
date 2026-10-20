

| Table | Fields |
| :--- | :--- |
| **User** | `user_id` (PK), `username` (unique), `password_hash`, `is_artist` (bool), `created_at`, `last_login` |
| **Artist** | `user_id` (PK, FK→User), `name` (string, required), `country` (string, indexed), `is_band` (bool), `band_member_ids` (JSON, nullable), `country_of_origin` (string, nullable), `production_house_id` (FK→Production_House), `created_at` |
| **Production_House** | `production_house_id` (PK), `name` (unique), `type` (string) |
| **Song** | `song_id` (PK), `song_name` (required), `duration` (int), `publish_date` (date), `genres` (JSON), `listen_count` (int, default 0), `is_published` (bool) |
| **Song_Artist_Relationship** | `song_id` (FK→Song), `artist_id` (FK→Artist.user_id), `role` (string), `is_primary` (bool) – Composite PK |
| **Playlist** | `playlist_id` (PK), `name` (required), `created_by_user_id` (FK→User), `cover_art_url` (string, nullable), `duration` (int, total seconds), `release_type` (Enum: 'Single','EP','Album' **OR NULL**), `last_updated`, `is_shared` (bool, default false) |
| **Playlist_Song** | `playlist_id` (FK→Playlist), `song_id` (FK→Song), `order` (int) – Composite PK |
| **Playlist_Collaborator** | `playlist_id` (FK→Playlist), `user_id` (FK→User) – Composite PK. (This table stores users who have edit/view access besides the creator. The creator is inferred from `Playlist.created_by_user_id`). |
| **Follow** | `follower_user_id` (FK→User), `followed_user_id` (FK→User) – Composite PK. |
| **Listening_Activity** | **(IGNORE for implementation)** – Keep the tables in `backend/db/schema.sql` but do not seed them or create APIs for them (`Listening_Activity` is only written by `POST /api/songs/:id/listen`). |
| **Lyrics** | **(IGNORE for implementation)** – Keep the tables in `backend/db/schema.sql` but do not seed them or create APIs for them (`Listening_Activity` is only written by `POST /api/songs/:id/listen`). |

---

#### Mermaid ER Diagram (Crow’s Foot Notation)

```mermaid
erDiagram
    User ||--|| Artist : "1-to-1 (extends)"
    User ||--o{ Playlist : "creates"
    User ||--o{ Listening_Activity : "has (ignored)"
    User ||--o{ Playlist_Collaborator : "collaborates_on"
    User ||--o{ Follow : "follows (follower)"
    User ||--o{ Follow : "is_followed_by (followed)"
    Artist }o--|| Production_House : "belongs_to"
    Artist ||--o{ Song_Artist_Relationship : "performs"
    Song ||--o{ Song_Artist_Relationship : "features"
    Song ||--o{ Listening_Activity : "played_in (ignored)"
    Song ||--o{ Playlist_Song : "included_in"
    Playlist ||--o{ Playlist_Song : "contains"
    Playlist ||--o{ Playlist_Collaborator : "has_collaborators"

    User {
        int user_id PK
        string username UK
        string password_hash
        boolean is_artist
        timestamp created_at
        timestamp last_login
    }

    Artist {
        int user_id PK,FK
        string name
        string country
        boolean is_band
        json band_member_ids
        string country_of_origin
        int production_house_id FK
        timestamp created_at
    }

    Production_House {
        int production_house_id PK
        string name UK
        string type
    }

    Song {
        int song_id PK
        string song_name
        int duration
        date publish_date
        json genres
        int listen_count
        boolean is_published
    }

    Song_Artist_Relationship {
        int song_id PK,FK
        int artist_id PK,FK
        string role
        boolean is_primary
    }

    Playlist {
        int playlist_id PK
        string name
        int created_by_user_id FK
        string cover_art_url
        int duration
        enum release_type
        timestamp last_updated
        boolean is_shared
    }

    Playlist_Song {
        int playlist_id PK,FK
        int song_id PK,FK
        int order
    }

    Playlist_Collaborator {
        int playlist_id PK,FK
        int user_id PK,FK
    }

    Follow {
        int follower_user_id PK,FK
        int followed_user_id PK,FK
    }

    Listening_Activity {
        int activity_id PK
        int user_id FK
        int song_id FK
        int listening_time
        timestamp timestamp
    }

    Lyrics {
        int lyrics_id PK
        int song_id FK
        text lyrics_text
        string lyrics_filename
    }
```

---
