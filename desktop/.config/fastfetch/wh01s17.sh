#!/usr/bin/env bash
set -euo pipefail

demo=false
if [[ $# -eq 1 && $1 == --demo ]]; then
	demo=true
	shift
fi

# Options and redirected output use Fastfetch directly. --demo repeats the
# interactive overlay until Ctrl-C, and is consumed before delegating.
if [[ ! -t 1 || $# -gt 0 ]]; then
	exec /usr/bin/fastfetch "$@"
fi

# The report currently occupies 28 rows. Logo padding centres the 20-row logo and
# the two-row wordmark below it against the information panels on the right.
report_rows=$(/usr/bin/fastfetch --logo none --pipe | wc -l)
logo_rows=22
logo_top=$((report_rows > logo_rows ? (report_rows - logo_rows) / 2 : 0))
output_rows=$((report_rows > logo_top + logo_rows ? report_rows : logo_top + logo_rows))
logo_column=3

# config.jsonc draws the dotted W above the wordmark; once the report is out,
# w-spin.py spins twice into Arch, then twice back into W above the wordmark.
/usr/bin/fastfetch --logo-padding-top "$logo_top"
fastfetch_status=$?

if ((fastfetch_status == 0)); then
	animation_options=()
	if [[ $demo == true ]]; then
		animation_options+=(--loop)
	fi
	python3 "$HOME/.config/fastfetch/w-spin.py" \
		--play "$((output_rows - logo_top))" "$logo_column" "${animation_options[@]}" || true
fi

exit "$fastfetch_status"
