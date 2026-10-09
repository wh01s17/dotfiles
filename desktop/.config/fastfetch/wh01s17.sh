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

# Prints a six-digit hex color (no "#") from the theme, or nothing.
theme_hex() {
	[[ -r $theme_colors ]] || return 0
	sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"#([[:xdigit:]]{6})\".*/\1/p" "$theme_colors" | head -n 1
}

accent_hex=$(theme_hex accent)

if [[ $accent_hex =~ ^[[:xdigit:]]{6}$ ]]; then
	printf -v accent '\e[38;2;%d;%d;%dm' \
		"$((16#${accent_hex:0:2}))" \
		"$((16#${accent_hex:2:2}))" \
		"$((16#${accent_hex:4:2}))"
else
	accent=$'\e[32m'
fi

# Recolors the Gengar sprite with the active theme: shading takes the accent,
# the body a dark accent tint over the background, the eyes the theme red and
# the teeth its brightest foreground. Each palette is rendered once and cached,
# so a theme change only costs one ImageMagick run. Prints the logo path.
themed_gengar() {
	local source="$HOME/.config/fastfetch/gengar.png"
	local bg red teeth body cache_dir logo i

	[[ $accent_hex =~ ^[[:xdigit:]]{6}$ ]] && command -v magick >/dev/null || {
		printf '%s' "$source"
		return
	}

	bg=$(theme_hex background)
	red=$(theme_hex red)
	teeth=$(theme_hex bright_foreground)
	[[ -n $bg ]] || bg=000000
	[[ -n $red ]] || red=f2000e
	[[ -n $teeth ]] || teeth=$(theme_hex foreground)
	[[ -n $teeth ]] || teeth=ffffff

	# 30% accent over 70% background keeps the body dark but tied to the accent.
	body=""
	for i in 0 2 4; do
		printf -v body '%s%02x' "$body" \
			$(((3 * 16#${accent_hex:i:2} + 7 * 16#${bg:i:2}) / 10))
	done

	cache_dir="${XDG_CACHE_HOME:-"$HOME/.cache"}/fastfetch"
	logo="$cache_dir/gengar-$accent_hex-$body-$red-$teeth.png"

	if [[ ! -s $logo ]]; then
		mkdir -p "$cache_dir"
		rm -f "$cache_dir"/gengar-*.png
		# Snap the anti-aliased source to its four sprite colors and hard alpha,
		# map those to placeholders so a theme color can never be caught by a
		# later replacement, then to the theme colors.
		magick "$source" \
			\( +clone -alpha extract -threshold 50% -write mpr:mask +delete \) \
			\( -size 1x1 xc:'#000000' xc:'#7f5d7f' xc:'#f2000e' xc:'#ffffff' \
			+append -write mpr:sprite +delete \) \
			-alpha off +dither -remap mpr:sprite \
			-fill '#fe01fe' -opaque '#000000' \
			-fill '#01fe01' -opaque '#7f5d7f' \
			-fill '#fefe01' -opaque '#f2000e' \
			-fill '#01fefe' -opaque '#ffffff' \
			-fill "#$body" -opaque '#fe01fe' \
			-fill "#$accent_hex" -opaque '#01fe01' \
			-fill "#$red" -opaque '#fefe01' \
			-fill "#$teeth" -opaque '#01fefe' \
			mpr:mask -compose CopyOpacity -composite \
			"$logo" 2>/dev/null || {
			printf '%s' "$source"
			return
		}
	fi

	printf '%s' "$logo"
}

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

/usr/bin/fastfetch --logo "$(themed_gengar)" --logo-padding-top 8
fastfetch_status=$?

if ((fastfetch_status == 0)); then
	# Preserve the final prompt position while painting inside Fastfetch's blank
	# logo padding. DEC save/restore keeps the following prompt in place.
	printf '\e7\e[%dA\e[1G' "$((output_rows - wordmark_top))"
	print_wordmark
	printf '\e8'
fi

exit "$fastfetch_status"
