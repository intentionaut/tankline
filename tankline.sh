#!/usr/bin/env bash
# Tankline: one-line Claude Code status line showing context fill and
# 5-hour / weekly usage. Needs only bash and jq. MIT licence.
#
# Reads the statusline session JSON on stdin, prints one line:
#   ctx [######----] 62%  |  5h 23% resets 2h14m  |  7d 41% resets 3d4h
# Anything missing prints n/a. It never prints 0% for data it does not have.
#
# Env vars (all optional):
#   TANKLINE_WARN   percent where colour turns yellow (default 70)
#   TANKLINE_CRIT   percent where colour turns red    (default 90)
#   TANKLINE_WIDTH  bar width in characters           (default 10)
#   NO_COLOR        set to anything to turn colour off
#   TANKLINE_COLORBLIND  set to anything but 0 for blue, yellow and magenta,
#                        with "!" after a warn figure and "!!" after a crit one

command -v jq >/dev/null 2>&1 || { echo "tankline: jq not found"; exit 0; }

# printf '%.0f' rejects "62.4" in locales that write decimals with a comma.
LC_ALL=C

warn=${TANKLINE_WARN:-70}
crit=${TANKLINE_CRIT:-90}
width=${TANKLINE_WIDTH:-10}
case $warn$crit$width in *[!0-9]*) warn=70; crit=90; width=10 ;; esac
cb=${TANKLINE_COLORBLIND:-0} # on for any value except empty or 0

input=$(cat)

# One jq call. Fields are empty when absent or null. A non-whitespace separator
# keeps empty fields in place (read would squash consecutive tabs).
IFS='|' read -r ctx h5 h5r d7 d7r < <(
  printf '%s' "$input" | jq -r '
    [ (.context_window.used_percentage // ""),
      (.rate_limits.five_hour.used_percentage // ""),
      (.rate_limits.five_hour.resets_at // ""),
      (.rate_limits.seven_day.used_percentage // ""),
      (.rate_limits.seven_day.resets_at // "") ] | map(tostring) | join("|")' 2>/dev/null
) || true

if [ -z "${NO_COLOR+x}" ]; then
  G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; D=$'\033[2m'; Z=$'\033[0m'
  # Colourblind mode: blue for green, magenta for red.
  [ "$cb" = 0 ] || { G=$'\033[34m'; R=$'\033[35m'; }
else
  G=; Y=; R=; D=; Z=
fi

# Whole number from a possible decimal; empty if not a number.
whole() {
  case $1 in
    ''|*[!0-9.]*|*.*.*) return 1 ;;
  esac
  printf '%.0f' "$1"
}

colour() {
  if [ "$1" -ge "$crit" ]; then printf '%s' "$R"
  elif [ "$1" -ge "$warn" ]; then printf '%s' "$Y"
  else printf '%s' "$G"; fi
}

# Colourblind mode only: "!" at warn, "!!" at crit, so the state never rests
# on colour alone. Prints nothing otherwise.
mark() {
  [ "$cb" = 0 ] && return 0
  if [ "$1" -ge "$crit" ]; then printf '!!'
  elif [ "$1" -ge "$warn" ]; then printf '!'; fi
}

# Seconds left -> 2h14m, 3d4h, 45m. Empty if the timestamp is missing or past.
countdown() {
  case $1 in ''|*[!0-9.]*) return 1 ;; esac
  local left=$(( ${1%.*} - $(date +%s) ))
  [ "$left" -gt 0 ] || { printf 'now'; return 0; }
  local d=$(( left / 86400 )) h=$(( left % 86400 / 3600 )) m=$(( left % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

part_ctx() {
  local p
  if p=$(whole "$ctx") && [ -n "$p" ]; then
    [ "$p" -gt 100 ] && p=100
    local filled=$(( p * width / 100 )) bar="" i
    for (( i = 0; i < width; i++ )); do
      if [ "$i" -lt "$filled" ]; then bar+="#"; else bar+="-"; fi
    done
    printf 'ctx %s[%s] %s%%%s%s' "$(colour "$p")" "$bar" "$p" "$(mark "$p")" "$Z"
  else
    printf 'ctx %sn/a%s' "$D" "$Z"
  fi
}

part_window() { # label pct resets_at
  local p cd
  if p=$(whole "$2") && [ -n "$p" ]; then
    printf '%s %s%s%%%s%s' "$1" "$(colour "$p")" "$p" "$(mark "$p")" "$Z"
    if cd=$(countdown "$3"); then printf ' resets %s' "$cd"; fi
  else
    printf '%s %sn/a%s' "$1" "$D" "$Z"
  fi
}

printf '%s  |  %s  |  %s\n' "$(part_ctx)" "$(part_window 5h "$h5" "$h5r")" "$(part_window 7d "$d7" "$d7r")"
