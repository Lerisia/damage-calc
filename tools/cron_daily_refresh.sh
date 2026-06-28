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

# Fast-forward main — if local has diverged (manual commits in the
# tree before the cron ran), bail rather than overwriting work. The
# script never auto-resolves; that's a person's job.
git fetch --quiet origin main
if ! git merge-base --is-ancestor HEAD origin/main; then
  echo "ERROR: local main diverged from origin/main. Resolve manually."
  exit 2
fi
git reset --hard origin/main

# Refresh from upstream sources. All three tools mutate asset files
# in place. Network failures bubble up — cron mails the error.
# Singles pulls first so that the doubles run can copy X/Y/Z mega
# entries from the just-refreshed singles file.
python3 tools/fetch_pokedb_usage.py --rule 0 --sleep 2
python3 tools/fetch_pokedb_usage.py --rule 1 --sleep 2
python3 tools/apply_champout_learnsets.py

if git diff --quiet assets/; then
  echo "No upstream changes — done."
  exit 0
fi

# Stage only the files this pipeline owns so a stray edit in the
# tree (somehow snuck in despite the reset above) can't tag along.
git add assets/champions_usage.json assets/champions_usage_doubles.json assets/learnsets.json
git -c user.email="cron@home" -c user.name="home-cron" \
  commit -m "chore(data): daily auto-refresh ($(date -u +%Y-%m-%d))"
git push origin main
echo "Pushed refresh to main. GH Actions deploy-web will pick it up."
