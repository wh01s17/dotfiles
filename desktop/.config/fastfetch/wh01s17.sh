#!/usr/bin/env bash
set -euo pipefail

# Options and redirected output use Fastfetch directly: the cursor overlay below
# is intentionally limited to the normal interactive report.
if [[ ! -t 1 || $# -gt 0 ]]; then
	exec /usr/bin/fastfetch "$@"
fi

# The report currently occupies 28 rows. Logo padding centres the 20-row W
# against the information panels on the right.
report_rows=$(/usr/bin/fastfetch --logo none --pipe | wc -l)
logo_rows=20
logo_top=$((report_rows > logo_rows ? (report_rows - logo_rows) / 2 : 0))
output_rows=$((report_rows > logo_top + logo_rows ? report_rows : logo_top + logo_rows))
logo_column=3

# config.jsonc draws the W at rest; once the report is out, w-spin.py spins it
# in place and brings it back to that same frame.
/usr/bin/fastfetch --logo-padding-top "$logo_top"
fastfetch_status=$?

if ((fastfetch_status == 0)); then
	python3 "$HOME/.config/fastfetch/w-spin.py" \
		--play "$((output_rows - logo_top))" "$logo_column" || true
fi

exit "$fastfetch_status"
