/** "YYYY-MM-DD" in the given IANA tz — daily rollover is per-user local midnight (CLAUDE.md §5). */
export function localDateString(tz: string, now: Date = new Date()): string {
  // en-CA formats as YYYY-MM-DD, conveniently matching our schema's date format.
  return new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
}
