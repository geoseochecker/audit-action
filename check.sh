#!/usr/bin/env bash
# geoseo checker audit gate: reads the latest public audit of a site and fails the job when it is below the bar.
# Inputs come as INPUT_* environment variables (see action.yml). Needs only bash, curl and python3 (all on GitHub's runners).
set -euo pipefail

domain="${INPUT_DOMAIN:-}"
domain="$(printf '%s' "$domain" | tr 'A-Z' 'a-z' | sed -E 's#^https?://##; s#/.*$##; s#^www\.##')"
if [ -z "$domain" ]; then echo "::error::The input 'domain' is required, e.g. example.com"; exit 2; fi
base="${INPUT_API_URL:-https://geoseochecker.com}"
min_score="${INPUT_MIN_SCORE:-0}"
max_serious="${INPUT_MAX_SERIOUS:-}"
max_age_days="${INPUT_MAX_AGE_DAYS:-0}"
require_audit="${INPUT_REQUIRE_AUDIT:-false}"
report="$base/audit/$domain"

out() { if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; else echo "output $1=$2"; fi; }
summary() { if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"; else printf '%s\n' "$1"; fi; }

if ! body="$(curl -fsS --max-time 60 -A "geoseochecker-audit-action/1" "$base/api/domain-summary?domain=$domain")"; then
  echo "::error::Could not reach $base. Try again later."; exit 2
fi

# one line per value: found, score, seo, speed, ai, serious, warnings, audited-at, age in days (the values are numbers or an ISO time, never free text)
parsed="$(printf '%s' "$body" | python3 -c '
import json, sys, datetime
d = json.load(sys.stdin)
def n(k):
    v = d.get(k)
    return str(int(v)) if isinstance(v, (int, float)) and not isinstance(v, bool) else ""
audited = d.get("completedAt") if isinstance(d.get("completedAt"), str) else ""
age = ""
if audited:
    try:
        t = datetime.datetime.fromisoformat(audited.replace("Z", "+00:00"))
        age = str(int((datetime.datetime.now(datetime.timezone.utc) - t).total_seconds() // 86400))
    except ValueError:
        pass
print("true" if d.get("found") is True else "false")
print(n("score")); print(n("seoScore")); print(n("perfScore")); print(n("aiScore"))
print(n("criticalCount") or "0"); print(n("warningCount") or "0")
print(audited); print(age)
')" || { echo "::error::Unexpected answer from $base."; exit 2; }
{ read -r found; read -r score; read -r seo; read -r speed; read -r ai; read -r serious; read -r warnings; read -r audited; read -r age_days; } <<<"$parsed" || true # the last lines can be empty and the shell then reports "end of input"

if [ "$found" != "true" ]; then
  out found false; out report-url "$report"
  summary "### geoseo checker: $domain"
  summary "No finished public audit of **$domain** yet. [Run a free audit]($report), then run this job again."
  if [ "$require_audit" = "true" ]; then echo "::error::No audit of $domain yet ($report)"; exit 1; fi
  echo "::notice::No audit of $domain yet: $report"; exit 0
fi

out found true; out score "$score"; out seo-score "$seo"; out speed-score "$speed"; out ai-readiness "$ai"
out serious-issues "$serious"; out warnings "$warnings"; out audited-at "$audited"; out report-url "$report"

fail=0; reasons=""
if [ -n "$score" ] && [ "$score" -lt "$min_score" ]; then fail=1; reasons="$reasons- score $score is below the minimum $min_score"$'\n'; fi
if [ -n "$max_serious" ] && [ "$serious" -gt "$max_serious" ]; then fail=1; reasons="$reasons- $serious serious issues, the maximum is $max_serious"$'\n'; fi
if [ "$max_age_days" -gt 0 ] && [ -n "$age_days" ] && [ "$age_days" -gt "$max_age_days" ]; then fail=1; reasons="$reasons- the audit is $age_days days old, the maximum is $max_age_days"$'\n'; fi

summary "### geoseo checker: $domain"
summary "| Score | SEO | Speed | AI readiness | Serious issues | Warnings |"
summary "|---|---|---|---|---|---|"
summary "| **${score:-n/a}** | ${seo:-n/a} | ${speed:-n/a} | ${ai:-n/a} | $serious | $warnings |"
summary ""
summary "Audited ${audited:-at an unknown time}. [Full report with the fixes]($report)"
if [ "$fail" = 1 ]; then
  summary ""; summary "**Below the bar:**"; summary "$reasons"
  echo "::error::geoseo checker: $domain is below the bar:"$'\n'"$reasons"
  exit 1
fi
echo "geoseo checker: $domain scores ${score:-n/a} ($serious serious issues). Report: $report"
