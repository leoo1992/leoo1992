#!/usr/bin/env bash
# Rewrite public Git history to remove leaked secrets and sensitive files.
# Requires: gh (authenticated), git, git-filter-repo, gitleaks, python3, jq.
# Run from Git Bash. Backups are retained; every push is force-updated.
set -Eeuo pipefail

OWNER="leoo1992"
STAMP="$(date +%Y%m%d-%H%M%S)"
ROOT="${PWD}/github-history-cleanup-${STAMP}"
BACKUP="${ROOT}/backups"
WORK="${ROOT}/work"
REPORT="${ROOT}/private-reports"
mkdir -p "$BACKUP" "$WORK" "$REPORT"
chmod 700 "$ROOT" "$BACKUP" "$WORK" "$REPORT" 2>/dev/null || true

for cmd in gh git git-filter-repo gitleaks python3 jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing dependency: $cmd"; exit 2; }
done
gh auth status >/dev/null

echo "Discovering public repositories for $OWNER..."
gh repo list "$OWNER" --limit 300 --json name,isPrivate,url \
  | jq -r '.[] | select(.isPrivate == false) | [.name,.url] | @tsv' > "$ROOT/repos.tsv"
[ -s "$ROOT/repos.tsv" ] || { echo "No public repositories returned."; exit 3; }

echo "Repositories: $(wc -l < "$ROOT/repos.tsv" | tr -d ' ')"
echo "Backup directory: $BACKUP"
echo "A complete mirror backup will be retained for each repository."
read -r -p "Proceed with rewriting and force-pushing every public repository listed? Type REWRITE: " CONFIRM
[ "$CONFIRM" = "REWRITE" ] || { echo "Cancelled."; exit 0; }

while IFS=$'\t' read -r NAME URL; do
  [ -n "$NAME" ] || continue
  echo
  echo "=== $OWNER/$NAME ==="
  MIRROR="$WORK/$NAME.git"
  BACKUP_MIRROR="$BACKUP/$NAME.git"
  REPORT_JSON="$REPORT/$NAME.json"
  REPLACEMENTS="$REPORT/$NAME-replacements.txt"

  git clone --mirror "$URL" "$MIRROR"
  cp -a "$MIRROR" "$BACKUP_MIRROR"

  SCAN_STATUS=0
  gitleaks git --log-opts="--all" --redact=0 --report-format=json \
    --report-path="$REPORT_JSON" "$MIRROR" >/dev/null 2>&1 || SCAN_STATUS=$?
  [ "$SCAN_STATUS" -le 1 ] || { echo "Gitleaks failed on $NAME; stopping before push."; exit 10; }
  [ -f "$REPORT_JSON" ] || printf '[]' > "$REPORT_JSON"

  # Secret values remain in the permission-restricted report/replacement files only.
  python3 - "$REPORT_JSON" "$REPLACEMENTS" <<'PY'
import json, sys
src, dst = sys.argv[1:3]
try:
    findings = json.load(open(src, encoding="utf-8"))
except Exception:
    findings = []
values = set()
for item in findings if isinstance(findings, list) else []:
    value = item.get("Secret")
    if isinstance(value, str) and len(value) >= 6 and not any(c in value for c in "\r\n") and "==>" not in value:
        values.add(value)
with open(dst, "w", encoding="utf-8", newline="\n") as out:
    for value in sorted(values, key=len, reverse=True):
        out.write("literal:" + value + "==>***REMOVED***\n")
print(f"Detected {len(findings) if isinstance(findings, list) else 0} finding(s); prepared {len(values)} literal replacement(s).")
PY

  # Remove dotenv files except the safe template, and private-key/container files.
  git -C "$MIRROR" filter-repo --force \
    --path-regex '(^|/)\.env($|\.(?!example($|\.))[^/]+$)' \
    --path-regex '\.(pem|key|p12|pfx)$' \
    --invert-paths \
    --replace-text "$REPLACEMENTS"

  # Validate the rewritten local mirror before changing GitHub.
  POST_STATUS=0
  gitleaks git --log-opts="--all" --redact=0 --report-format=json \
    --report-path="$REPORT/$NAME-after.json" "$MIRROR" >/dev/null 2>&1 || POST_STATUS=$?
  [ "$POST_STATUS" -eq 0 ] || { echo "Secrets remain or scan failed in $NAME; NOT pushing."; exit 11; }

  if git -C "$MIRROR" log --all --format= --name-only -- ':(glob)**/.env' ':(glob)**/.env.*' \
      | grep -E '(^|/)\.env($|\.)' >/dev/null; then
    echo "A dotenv file remains in history for $NAME; NOT pushing."
    exit 12
  fi

  echo "Pushing rewritten refs for $NAME..."
  git -C "$MIRROR" push --force --mirror

  # Fresh clone confirms the remote refs, not just the local rewritten mirror.
  git clone --mirror "$URL" "$WORK/$NAME-verify.git"
  VERIFY_STATUS=0
  gitleaks git --log-opts="--all" --redact=0 --report-format=json \
    --report-path="$REPORT/$NAME-remote.json" "$WORK/$NAME-verify.git" >/dev/null 2>&1 || VERIFY_STATUS=$?
  [ "$VERIFY_STATUS" -eq 0 ] || { echo "Remote verification failed for $NAME. Investigate immediately."; exit 13; }

  echo "Verified: $NAME"
  rm -f "$REPORT_JSON" "$REPLACEMENTS" "$REPORT/$NAME-after.json" "$REPORT/$NAME-remote.json"
done < "$ROOT/repos.tsv"

echo
echo "Completed. Backups retained at: $BACKUP"
echo "Do not delete backups until deployments, collaborators, and open PRs are checked."
echo "All collaborators must re-clone rewritten repositories; old commit SHAs may require GitHub Support cache cleanup."
