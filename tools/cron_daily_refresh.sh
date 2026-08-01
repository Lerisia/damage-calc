#!/usr/bin/env bash
# Daily Champions usage + learnset refresh, run from a home-server
# crontab. GitHub Actions can't host this — champs.pokedb.tokyo
# 403s any datacenter-IP request (Cloudflare gates on TLS fingerprint
# + IP reputation), so the pull has to come from a residential IP.
#
# Pipeline:
#   1. fast-forward main to remote so we never push a stale base
#   2. run the two refresh scripts
#   3. if any asset changed: stage / commit / push to main
#   4. push triggers the deploy-only GitHub Actions workflow which
#      builds Flutter web + publishes to gh-pages
#
# Idempotent: a no-op day exits cleanly without committing anything.
# Logs to ~/.local/log/champions-refresh.log (rotation: trim to last
# 1000 lines so the file doesn't grow forever).

set -euo pipefail

REPO="/home/elyss/damage-calc"
LOG_DIR="$HOME/.local/log"
LOG="$LOG_DIR/champions-refresh.log"
mkdir -p "$LOG_DIR"

# Trim log to last 1000 lines before appending today's run. Cheap;
# avoids unbounded growth without needing logrotate config.
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt 1000 ]; then
  tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# Everything below is captured to the log AND streamed to stderr so
# `cron -L 15` mails an alert if the script exits non-zero.
exec >> "$LOG" 2>&1
echo "──── $(date -u +%Y-%m-%dT%H:%M:%SZ) cron refresh start"

cd "$REPO"

# Sync main with origin. Three states to handle cleanly:
#   * local behind or equal → hard-reset onto origin/main to pick up
#     anything session work missed.
#   * local ahead (session commits made locally but not yet pushed):
#     leave HEAD alone so we don't clobber unpushed work; the cron
#     data commit will layer on top and push everything together.
#   * true divergence (both sides have commits that aren't in the
#     other's ancestry): rare — bail so a human can resolve.
git fetch --quiet origin main
if git merge-base --is-ancestor HEAD origin/main; then
  # Local at or behind origin — fast-forward.
  git reset --hard origin/main
elif git merge-base --is-ancestor origin/main HEAD; then
  # Local strictly ahead — keep the unpushed commits, don't overwrite.
  echo "note: local ahead of origin by " \
       "$(git rev-list --count origin/main..HEAD) commits — keeping them"
else
  echo "ERROR: local main truly diverged from origin/main. Resolve manually."
  exit 2
fi

# Refresh from upstream sources. All three tools mutate asset files
# in place. Network failures bubble up — cron mails the error.
# Singles pulls first so that the doubles run can copy X/Y/Z mega
# entries from the just-refreshed singles file.
#
# Data source: pkmnchamps.com (see fetch_pkmnchamps.py header).
# Previously used champs.pokedb.tokyo but that origin nginx-banned our
# home IP in July 2026; fetch_pokedb_usage.py is kept as .bak in case
# access is later restored via the operator contact still in flight.
python3 tools/fetch_pkmnchamps.py --rule 0
python3 tools/fetch_pkmnchamps.py --rule 1
python3 tools/apply_champout_learnsets.py
# Champions-legal move allowlist (yakkun scrape). Low-churn — the move
# roster only shifts on a Champions patch — but re-running daily keeps
# it current for free. Self-aborts (non-zero, no write) if the scrape
# yields an implausibly small set, so a yakkun markup change can't ship
# a truncated allowlist that would hide legal moves.
python3 tools/fetch_champions_moves.py || \
  echo "champions moves refresh failed (non-fatal) — keeping existing allowlist"

if git diff --quiet assets/; then
  echo "No upstream changes — done."
  exit 0
fi

# Stage only the files this pipeline owns so a stray edit in the
# tree (somehow snuck in despite the reset above) can't tag along.
git add assets/champions_usage.json assets/champions_usage_doubles.json \
        assets/champions_moves.json assets/learnsets.json
git -c user.email="cron@home" -c user.name="home-cron" \
  commit -m "chore(data): daily auto-refresh ($(date -u +%Y-%m-%d))"
git push origin main
echo "Pushed refresh to main. GH Actions deploy-web will pick it up."
