// CLAUDE.md §10/§6: content_words.cefr is A1..C1; quizzes.difficulty is the
// integer 1..5 equivalent. Shared by daily-word selection and quiz selection.
export const CEFR_ORDER = ["A1", "A2", "B1", "B2", "C1"];

export const LEVEL_CEFR_CEILING: Record<string, string> = {
  beginner: "A2",
  elementary: "B1",
  intermediate: "B2",
  advanced: "C1",
};

export function cefrsUpTo(ceiling: string): string[] {
  const idx = CEFR_ORDER.indexOf(ceiling);
  return CEFR_ORDER.slice(0, idx === -1 ? CEFR_ORDER.length : idx + 1);
}

export function difficultyForLevel(level: string): number {
  const ceiling = LEVEL_CEFR_CEILING[level] ?? "A2";
  const idx = CEFR_ORDER.indexOf(ceiling);
  return idx === -1 ? 5 : idx + 1;
}
