import { createEmptyCard, fsrs, generatorParameters, State, type Card as FSRSCard, type Grade } from "ts-fsrs";
import type { SrsStateRow } from "./repos/srs";

const scheduler = fsrs(generatorParameters());

const STATE_TO_TEXT: Record<State, SrsStateRow["state"]> = {
  [State.New]: "new",
  [State.Learning]: "learning",
  [State.Review]: "review",
  [State.Relearning]: "relearning",
};
const TEXT_TO_STATE: Record<SrsStateRow["state"], State> = {
  new: State.New,
  learning: State.Learning,
  review: State.Review,
  relearning: State.Relearning,
};

/** Builds a fresh ts-fsrs Card for a word entering the deck for the first time. */
export function newCard(now: Date): FSRSCard {
  return createEmptyCard(now);
}

export function rowToFSRSCard(row: SrsStateRow): FSRSCard {
  return {
    due: new Date(row.due_at),
    stability: row.stability ?? 0,
    difficulty: row.difficulty ?? 0,
    elapsed_days: 0,
    scheduled_days: 0,
    reps: row.reps,
    lapses: row.lapses,
    state: TEXT_TO_STATE[row.state],
    last_review: row.last_review_at ? new Date(row.last_review_at) : undefined,
  } as FSRSCard;
}

export interface ScheduleResult {
  due_at: number;
  stability: number;
  difficulty: number;
  reps: number;
  lapses: number;
  state: SrsStateRow["state"];
  last_review_at: number | null;
}

/** rating: 1 again | 2 hard | 3 good | 4 easy (CLAUDE.md §5 reviews.rating). */
export function scheduleReview(card: FSRSCard, rating: 1 | 2 | 3 | 4, now: Date): ScheduleResult {
  const result = scheduler.repeat(card, now)[rating as Grade];
  const scheduled = result.card;
  return {
    due_at: scheduled.due.getTime(),
    stability: scheduled.stability,
    difficulty: scheduled.difficulty,
    reps: scheduled.reps,
    lapses: scheduled.lapses,
    state: STATE_TO_TEXT[scheduled.state],
    last_review_at: now.getTime(),
  };
}

export function newCardRow(now: Date): ScheduleResult {
  const card = newCard(now);
  return {
    due_at: card.due.getTime(),
    stability: card.stability,
    difficulty: card.difficulty,
    reps: card.reps,
    lapses: card.lapses,
    state: STATE_TO_TEXT[card.state],
    last_review_at: null,
  };
}
