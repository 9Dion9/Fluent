-- Caches the 3-sentence summary the Worker requests once a conversation
-- exceeds 40 turns, so {SUMMARY} doesn't need re-generating every request
-- (CLAUDE.md §7 "Context window strategy").
ALTER TABLE conversations ADD COLUMN summary TEXT;
ALTER TABLE conversations ADD COLUMN summarized_through_message_count INTEGER NOT NULL DEFAULT 0;
