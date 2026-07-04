"""Weekly retention/funnel report (CLAUDE.md §14): "prints weekly
retention/funnel from D1." Reads via `wrangler d1 execute --json` (the same
tool every other D1 read/write in this project already uses) rather than
wiring up a separate Cloudflare REST API client for one report script.

Usage:
    python -m batch.report [--local | --remote] [--days 7]
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

from batch.config import BATCH_ROOT

INFRA_DIR = BATCH_ROOT.parent / "infra"

FUNNEL_EVENTS = [
    "onboarding_step",
    "placement_done",
    "first_chat_turn",
    "daily_completed",
    "review_done",
    "camera_snap",
    "streak_day",
    "chat_turn",
]


def run_query(sql: str, target: str) -> list[dict]:
    result = subprocess.run(
        ["npx", "wrangler", "d1", "execute", "fluent-db", "--config", "wrangler.toml", f"--{target}", "--json", "--command", sql],
        cwd=INFRA_DIR,
        capture_output=True,
        text=True,
        check=True,
    )
    data = json.loads(result.stdout)
    return data[0]["results"] if data and data[0].get("success") else []


def funnel_report(days: int, target: str) -> None:
    cutoff_ms = f"(strftime('%s', 'now') - {days} * 86400) * 1000"
    placeholders = ",".join(f"'{e}'" for e in FUNNEL_EVENTS)
    sql = (
        f"SELECT name, COUNT(*) as total, COUNT(DISTINCT user_id) as distinct_users "
        f"FROM events WHERE created_at >= {cutoff_ms} AND name IN ({placeholders}) "
        f"GROUP BY name ORDER BY total DESC;"
    )
    rows = run_query(sql, target)
    print(f"\n=== Funnel (last {days}d) ===")
    if not rows:
        print("  (no events yet)")
        return
    for r in rows:
        print(f"  {r['name']:<20} {r['total']:>6} events  {r['distinct_users']:>5} users")


def retention_report(days: int, target: str) -> None:
    cutoff_ms = f"(strftime('%s', 'now') - {days} * 86400) * 1000"
    new_users_sql = f"SELECT COUNT(*) as n FROM users WHERE created_at >= {cutoff_ms};"
    active_users_sql = f"SELECT COUNT(DISTINCT user_id) as n FROM events WHERE created_at >= {cutoff_ms};"
    retained_sql = (
        f"SELECT COUNT(*) as n FROM ("
        f"  SELECT user_id FROM events WHERE created_at >= {cutoff_ms}"
        f"  GROUP BY user_id"
        f"  HAVING COUNT(DISTINCT date(created_at / 1000, 'unixepoch')) >= 2"
        f");"
    )

    new_users = run_query(new_users_sql, target)[0]["n"]
    active_users = run_query(active_users_sql, target)[0]["n"]
    retained = run_query(retained_sql, target)[0]["n"]

    print(f"\n=== Retention (last {days}d) ===")
    print(f"  new users:                {new_users}")
    print(f"  active users (any event): {active_users}")
    print(f"  active on 2+ distinct days: {retained}" + (f" ({100 * retained / active_users:.0f}%)" if active_users else ""))


def streak_distribution(target: str) -> None:
    sql = "SELECT streak_current, COUNT(*) as n FROM users GROUP BY streak_current ORDER BY streak_current DESC LIMIT 10;"
    rows = run_query(sql, target)
    print("\n=== Streak distribution (top 10) ===")
    if not rows:
        print("  (no users yet)")
        return
    for r in rows:
        print(f"  streak={r['streak_current']:<4} {r['n']} user(s)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--remote", action="store_true", help="query production D1 (default: local)")
    parser.add_argument("--days", type=int, default=7)
    args = parser.parse_args()
    target = "remote" if args.remote else "local"

    print(f"Fluent weekly report — {target} D1, window={args.days}d", file=sys.stderr)
    funnel_report(args.days, target)
    retention_report(args.days, target)
    streak_distribution(target)


if __name__ == "__main__":
    main()
