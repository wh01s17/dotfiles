#!/usr/bin/env bash
set -euo pipefail

# Options and redirected output use Fastfetch directly: the cursor overlay below
# is intentionally limited to the normal interactive report.
if [[ ! -t 1 || $# -gt 0 ]]; then
	exec /usr/bin/fastfetch "$@"
fi

# Letters inherit the terminal's bright white. All numbers use the single
# predominant accent declared by the active Omarchy theme.
letter=$'\e[97m'
reset=$'\e[0m'
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
theme_colors="$state_home/omarchy/current/theme/colors.toml"
accent_hex=""

if [[ -r $theme_colors ]]; then
	accent_hex=$(sed -nE 's/^[[:space:]]*accent[[:space:]]*=[[:space:]]*"#([[:xdigit:]]{6})".*/\1/p' "$theme_colors")
fi

if [[ $accent_hex =~ ^[[:xdigit:]]{6}$ ]]; then
	printf -v accent '\e[38;2;%d;%d;%dm' \
		"$((16#${accent_hex:0:2}))" \
		"$((16#${accent_hex:2:2}))" \
		"$((16#${accent_hex:4:2}))"
else
	accent=$'\e[32m'
fi

print_wordmark() {
	printf '%s\n' \
		"  ${letter}█╗ ╔█${reset} ${letter}█╗ ╔█${reset} ${accent}╔███╗${reset} ${accent} ██╗ ${reset} ${letter}████╗${reset} ${accent} ██╗ ${reset} ${accent}████╗${reset}" \
		"  ${letter}█║ ║█${reset} ${letter}█║ ║█${reset} ${accent}█╔═╗█${reset} ${accent}███║ ${reset} ${letter}█╔══╝${reset} ${accent}███║ ${reset} ${accent}╚══██${reset}" \
		"  ${letter}█║ ║█${reset} ${letter}█████${reset} ${accent}█║█║█${reset} ${accent}╚██║ ${reset} ${letter}████╗${reset} ${accent}╚██║ ${reset} ${accent}  ██╔${reset}" \
		"  ${letter}█║█║█${reset} ${letter}█╔═╗█${reset} ${accent}██╔╝█${reset} ${accent} ██║ ${reset} ${letter}╚══██${reset} ${accent} ██║ ${reset} ${accent} ██╔╝${reset}" \
		"  ${letter}╚███╝${reset} ${letter}█║ ║█${reset} ${accent}╚███╝${reset} ${accent} ██║ ${reset} ${letter}████║${reset} ${accent} ██║ ${reset} ${accent} ██║ ${reset}" \
		"  ${letter} ╚═╝ ${reset} ${letter}╚╝ ╚╝${reset} ${accent} ╚═╝ ${reset} ${accent} ╚═╝ ${reset} ${letter}╚═══╝${reset} ${accent} ╚═╝ ${reset} ${accent} ╚╝  ${reset}"
}

# The report currently occupies 28 rows. Eight rows of image padding place the
# six-row wordmark and one-row gap above the 20-row logo. Together they span
# the same visible rows as the information panels on the right.
report_rows=$(/usr/bin/fastfetch --logo none --pipe | wc -l)
logo_rows=28
output_rows=$((report_rows > logo_rows ? report_rows : logo_rows))
wordmark_top=1

/usr/bin/fastfetch --logo-padding-top 8
fastfetch_status=$?

if ((fastfetch_status == 0)); then
	# Preserve the final prompt position while painting inside Fastfetch's blank
	# logo padding. DEC save/restore keeps the following prompt in place.
	printf '\e7\e[%dA\e[1G' "$((output_rows - wordmark_top))"
	print_wordmark
	printf '\e8'
fi

exit "$fastfetch_status"
