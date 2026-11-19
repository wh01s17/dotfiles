#!/usr/bin/env bash
# Make Limine boot the first kernel on its own after `timeout`.
#
# Older installs wrote a first-boot entry named like limine-entry-tool's OS
# directory (`/Arch Linux`). The tool then filed its kernels under it, so
# that entry turned into a directory that still carried its own protocol,
# path, cmdline and module_path. Limine cannot boot a directory, so when the
# timeout ran out the menu just waited.
#
# This drops those leftover fields, expands the OS directory (`/+`) so its
# kernels are listed, and points `default_entry` at the first of them (entry
# 1 is the directory itself). It also removes the `/Primer arranque` entry
# that new installs boot once, as soon as generated kernel entries exist.
# Safe to run again: a file already in shape is left untouched.
#
# Usage: limine-autoboot.sh [limine.conf]   (default: /boot/limine.conf)
set -euo pipefail

conf=${1:-/boot/limine.conf}
[[ -f $conf ]] || { echo "No existe $conf." >&2; exit 1; }
os_name=${LIMINE_OS_NAME:-}
if [[ -z $os_name ]]; then
  for file in /etc/limine-entry-tool.d/*.conf /etc/default/limine; do
    [[ -f $file ]] || continue
    value=$(sed -n 's/^TARGET_OS_NAME="\(.*\)"$/\1/p' "$file" | tail -n 1)
    [[ -n $value ]] && os_name=$value
  done
fi
os_name=${os_name:-Arch Linux}

tmp=$(mktemp "$conf.XXXXXX")
trap 'rm -f "$tmp"' EXIT

awk -v os="$os_name" '
  function flush_provisional() { provisional = 0 }
  # Generated kernel entries live one level down ("  //linux").
  { lines[NR] = $0 }
  /^[[:space:]]*\/\/[^\/]/ { generated = 1 }
  END {
    has_default = 0
    for (i = 1; i <= NR; i++) if (lines[i] ~ /^default_entry:/) has_default = 1
    in_os = 0; in_first_boot = 0
    for (i = 1; i <= NR; i++) {
      line = lines[i]
      if (line == "/" os || line == "/+" os) {
        print "/+" os
        in_os = 1; in_first_boot = 0
        continue
      }
      if (line == "/Primer arranque") {
        if (generated) { in_first_boot = 1; in_os = 0; continue }
      }
      if (line ~ /^\/[^\/]/) { in_os = 0; in_first_boot = 0 }
      if (in_first_boot) {
        if (line ~ /^    [a-z_]+:/ || line ~ /^[[:space:]]*$/) continue
        in_first_boot = 0
      }
      # The leftover first-boot fields sit right under the OS directory,
      # indented four spaces; the generated children start with "  //".
      if (in_os && line ~ /^    (protocol|path|cmdline|module_path):/) continue
      if (in_os && line !~ /^    /) in_os = 0
      print line
      if (generated && !has_default && line ~ /^timeout:/) { print "default_entry: 2"; has_default = 1 }
    }
  }
' "$conf" >"$tmp"

if cmp -s "$tmp" "$conf"; then
  echo "$conf ya arranca solo."
  exit 0
fi
cp -p "$conf" "$conf.bak-autoboot"
cat "$tmp" >"$conf"
echo "Corregido $conf (copia en $conf.bak-autoboot)."
