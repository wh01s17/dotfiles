#!/usr/bin/env bash
set -euo pipefail

# Exact values from themes/wh01s17/colors.toml. Keep redirected output free
# from escape sequences while retaining the pixel-art text itself.
if [[ -t 1 ]]; then
	green=$'\e[38;2;0;255;156m'
	cyan=$'\e[38;2;69;217;234m'
	foreground=$'\e[38;2;203;213;206m'
	reset=$'\e[0m'
else
	green=""
	cyan=""
	foreground=""
	reset=""
fi

printf '%s\n' \
  "  ${green}█   █  █   ${cyan}   ██    █ ${green}   ███${foreground}   █   ████${reset}" \
  "  ${green}█   █  █   ${cyan}  █  █  ██ ${green} █   ${foreground} ██      █${reset}" \
  "  ${green}█ █ █  ███ ${cyan}  █  █   █ ${green}   ██ ${foreground}   █    █ ${reset}" \
  "  ${green}█ █ █  █  █${cyan}  █  █   █ ${green}     █${foreground}   █   █  ${reset}" \
  "  ${green} █ █   █  █${cyan}   ██   ███${green}  ███ ${foreground}  ███  █   ${reset}"
printf '\n'

exec /usr/bin/fastfetch "$@"
