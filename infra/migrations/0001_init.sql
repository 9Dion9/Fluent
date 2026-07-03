-- Fluent D1 schema — CLAUDE.md §5. Never edit an applied migration; add a new one.

-- identity (anonymous device accounts; upgradeable to Apple sign-in in v2)
CREATE TABLE users (
  id TEXT PRIMARY KEY,                 -- uuid
  created_at INTEGER NOT NULL,
  native_lang TEXT NOT NULL,
  target_lang TEXT NOT NULL,
  level TEXT NOT NULL,                 -- beginner | elementary | intermediate | advanced
  interests_json TEXT NOT NULL,        -- ["travel","food",...]
  tutor_name TEXT NOT NULL,
  tutor_persona TEXT NOT NULL DEFAULT 'sunny',  -- sunny | dry | professor (see DESIGN.md)
  tz TEXT NOT NULL DEFAULT 'UTC',      -- IANA tz; daily rollover is per-user local midnight
  reminder_time TEXT,                  -- "HH:MM" local, null = no reminder
  daily_goal INTEGER NOT NULL DEFAULT 10,
  streak_current INTEGER NOT NULL DEFAULT 0,
  streak_best INTEGER NOT NULL DEFAULT 0,
  streak_freezes INTEGER NOT NULL DEFAULT 0,
  last_active_date TEXT,               -- YYYY-MM-DD in user's tz
  auth_kind TEXT NOT NULL DEFAULT 'device',
  apple_sub TEXT
);

CREATE TABLE devices (
  id TEXT PRIMARY KEY,                 -- device pubid
  user_id TEXT NOT NULL,
  secret_hash TEXT NOT NULL,           -- SHA-256 of device secret; verified on re-auth
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER,
  FOREIGN KEY(user_id) REFERENCES users(id)
);

-- batch-generated, shared across users
CREATE TABLE content_words (
  id TEXT PRIMARY KEY, lang TEXT NOT NULL, word TEXT NOT NULL,
  translation TEXT NOT NULL, pos TEXT, gender TEXT,          -- der/die/das etc.
  ipa TEXT,                                                  -- from wiktextract
  cefr TEXT,                                                 -- A1..C1, drives placement + daily selection
  topics_json TEXT,                                          -- ["food","travel"] for interest-themed selection
  frequency_rank INTEGER, example TEXT, example_translation TEXT,
  audio_key TEXT,                                            -- R2 key, null until rendered
  source TEXT NOT NULL DEFAULT 'pipeline',                   -- pipeline | camera_vlm
  verified INTEGER NOT NULL DEFAULT 0,                       -- gender/POS matched Wiktionary
  UNIQUE(lang, word)
);

CREATE TABLE quizzes (
  id TEXT PRIMARY KEY, lang TEXT NOT NULL, type TEXT NOT NULL, -- mcq | match | fillblank | order
  prompt_json TEXT NOT NULL, answer_json TEXT NOT NULL,
  difficulty INTEGER NOT NULL,                                 -- 1..5, maps to CEFR
  word_ids_json TEXT,                                          -- words exercised (match quizzes use several)
  content_hash TEXT UNIQUE                                     -- batch idempotency
);

CREATE TABLE scenarios (                -- roleplay catalog, batch-generated
  id TEXT PRIMARY KEY, lang TEXT NOT NULL,
  title TEXT NOT NULL, emoji TEXT, min_level TEXT NOT NULL,
  seed_prompt TEXT NOT NULL,            -- injected as {SCENARIO}
  focus_word_ids_json TEXT
);

CREATE TABLE vision_labels (            -- Vision classifier label -> word mapping
  label TEXT NOT NULL,                  -- lowercase Vision/CoreML label, e.g. "coffee mug"
  lang TEXT NOT NULL,
  word_id TEXT NOT NULL,
  PRIMARY KEY(label, lang),
  FOREIGN KEY(word_id) REFERENCES content_words(id)
);

-- per-user learning state
CREATE TABLE user_cards (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, word_id TEXT NOT NULL,
  source TEXT NOT NULL,                 -- daily | camera | chat | manual
  added_at INTEGER NOT NULL, UNIQUE(user_id, word_id)
);

CREATE TABLE srs_state (                -- FSRS, one row per card
  card_id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
  due_at INTEGER NOT NULL, stability REAL, difficulty REAL,
  reps INTEGER NOT NULL DEFAULT 0, lapses INTEGER NOT NULL DEFAULT 0,
  state TEXT NOT NULL,                  -- new | learning | review | relearning
  last_review_at INTEGER
);

CREATE TABLE reviews (
  id TEXT PRIMARY KEY,                  -- CLIENT-generated uuid -> offline sync is idempotent (upsert)
  card_id TEXT NOT NULL, user_id TEXT NOT NULL,
  rating INTEGER NOT NULL,              -- 1 again | 2 hard | 3 good | 4 easy
  reviewed_at INTEGER NOT NULL, elapsed_ms INTEGER
);

CREATE TABLE daily_sets (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, date TEXT NOT NULL, -- YYYY-MM-DD in user tz
  word_ids_json TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0,
  UNIQUE(user_id, date)
);

CREATE TABLE conversations (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, scenario_id TEXT, created_at INTEGER NOT NULL
);

CREATE TABLE messages (
  id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, role TEXT NOT NULL, -- user | tutor
  text TEXT, audio_key TEXT, corrections_json TEXT, created_at INTEGER NOT NULL
);

CREATE TABLE events (                   -- lightweight product analytics, pruned at 90 days
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
  name TEXT NOT NULL,                   -- onboarding_step, chat_turn, review_done, camera_snap, ...
  props_json TEXT, created_at INTEGER NOT NULL
);

-- indexes (performance is a feature)
CREATE INDEX idx_srs_due       ON srs_state(user_id, due_at);
CREATE INDEX idx_cards_user    ON user_cards(user_id);
CREATE INDEX idx_msgs_convo    ON messages(conversation_id, created_at);
CREATE INDEX idx_words_lang    ON content_words(lang, frequency_rank);
CREATE INDEX idx_reviews_user  ON reviews(user_id, reviewed_at);
CREATE INDEX idx_events_user   ON events(user_id, created_at);
