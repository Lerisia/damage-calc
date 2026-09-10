#!/usr/bin/env bash
# Daily doubles usage refresh from champs.pokedb.tokyo — runs on the
# home server because pokedb's Cloudflare front returns 403 to every
# datacenter egress we tried (GitHub Actions, Anthropic). The home IP is
# the only one that works, and it was banned once already (July 2026),
# so this is deliberately slow and self-disabling:
#   * one full pass a day, ~60 s between requests (±25 % jitter)
#   * a 403/429 aborts the run at once and drops a marker file; every
#     later run exits immediately until someone removes the marker
#   * the season number follows whatever pokechamdb reports for
#     singles, so a regulation change needs no edit here
# Scheduled at 13:00 KST — the 03:00 singles refresh is long done by then.
set -euo pipefail

REPO="/home/elyss/damage-calc"
MARKER="/tmp/pokedb_blocked"
cd "$REPO"

# Never overlap with a run already in flight (a manual pull, or a
# previous cron still walking the list) — two runs would double the
# request rate on the one IP that still works.
if pgrep -f "fetch_pokedb_doubles.py" >/dev/null; then
  echo "a pokedb doubles fetch is already running — skipping."
  exit 0
fi

if [[ -f "$MARKER" ]]; then
  echo "pokedb blocked marker present ($(cat "$MARKER")) — not running. Remove $MARKER to re-enable."
  exit 0
fi

# Same sync policy as cron_daily_refresh.sh: fast-forward when at or
# behind origin, keep unpushed local commits, bail on true divergence.
git fetch --quiet origin main
if git merge-base --is-ancestor HEAD origin/main; then
  git reset --hard origin/main
elif ! git merge-base --is-ancestor origin/main HEAD; then
  echo "ERROR: local main diverged from origin/main. Resolve manually."
  exit 2
fi

SEASON=$(python3 -c "import json,re; m=json.load(open('assets/champions_usage.json'))['_meta']['format']; print(re.search(r'M-(\d+)', m).group(1))")
echo "season M-$SEASON (from singles meta)"

set +e
python3 tools/fetch_pokedb_doubles.py --season "$SEASON" --rule 1 --sleep 60 --cache "/tmp/pokedb_cache_m$SEASON"
rc=$?
set -e
if [[ $rc -eq 3 ]]; then
  date -u +"%Y-%m-%dT%H:%MZ blocked (HTTP 403/429)" > "$MARKER"
  echo "pokedb blocked — wrote $MARKER; daily runs disabled until it is removed."
  exit 3
elif [[ $rc -ne 0 ]]; then
  echo "doubles refresh failed (rc=$rc) — keeping existing file"
  exit $rc
fi

# Singles fill-in: pokechamdb (03:00) ranks fewer species early in a
# season than pokedb does; fetch only the ones it hasn't ranked. Same
# abort rules; a few dozen requests once the season settles.
set +e
python3 tools/fetch_pokedb_doubles.py --season "$SEASON" --rule 0 --only-missing \
  --sleep 30 --cache "/tmp/pokedb_cache_m${SEASON}_singles"
rc=$?
set -e
if [[ $rc -eq 3 ]]; then
  date -u +"%Y-%m-%dT%H:%MZ blocked (HTTP 403/429)" > "$MARKER"
  echo "pokedb blocked during singles fill — wrote $MARKER"
  exit 3
elif [[ $rc -ne 0 ]]; then
  echo "singles fill failed (rc=$rc) — keeping existing file"
fi

if git diff --quiet assets/champions_usage_doubles.json assets/champions_usage.json; then
  echo "No change — done."
  exit 0
fi
git add assets/champions_usage_doubles.json assets/champions_usage.json
git -c user.email="cron@home" -c user.name="home-cron" \
  commit -m "chore(data): pokedb refresh — doubles + singles fill-in ($(date -u +%Y-%m-%d))"
git push origin main
echo "Pushed doubles refresh. GH Actions deploy-web will pick it up."
