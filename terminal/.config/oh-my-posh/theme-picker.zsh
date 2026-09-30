#!/usr/bin/env zsh

emulate -R zsh
setopt pipefail

config_dir=${OMP_THEME_PICKER_CONFIG_DIR:-$HOME/.config/oh-my-posh}
script_dir=${0:A:h}
composer=$script_dir/compose-theme.py
previewer=$script_dir/preview-themes.py
active_theme=$config_dir/active.omp.json
selection_file=$config_dir/active.theme
catalog_cache=$config_dir/catalog.names
local_theme=$config_dir/pure.omp.json
theme_catalog=https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes?ref=main
theme_source=https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes

theme_error() {
  print -u2 -r -- "omp-theme: $*"
  return 1
}

theme_valid_name() {
  [[ $1 =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]]
}

theme_file() {
  local name=$1 scratch=$2 installed=$config_dir/themes/$1.omp.json
  local download=$scratch/$name.omp.json

  if [[ $name == pure-local ]]; then
    [[ -r $local_theme ]] || { theme_error "No se encuentra $local_theme"; return 1; }
    print -r -- "$local_theme"
    return 0
  fi

  theme_valid_name "$name" || { theme_error 'Nombre de tema inválido'; return 1; }
  if [[ -f $installed && ! -L $installed ]]; then
    print -r -- "$installed"
    return 0
  fi
  if [[ ! -s $download ]]; then
    curl --location --fail --silent --show-error --connect-timeout 5 --max-time 25 \
      --output "$download.part" "$theme_source/$name.omp.json" || return 1
    jq -e 'type == "object" and (.blocks | type == "array")' "$download.part" >/dev/null || {
      theme_error "El tema $name no contiene una configuración válida"
      return 1
    }
    mv -- "$download.part" "$download" || return 1
  fi
  print -r -- "$download"
}

theme_compose() {
  local name=$1 file=$2 inherited=$3 output=$4 mode=$5
  local -a arguments
  arguments=(--base "$file" --extends "$inherited" --output "$output")
  [[ $name == pure-local ]] && arguments+=(--pure-local)
  [[ $mode == omarchy ]] && arguments+=(--omarchy)
  python3 -B "$composer" "${arguments[@]}"
}

theme_preview() {
  local name=$1 scratch=$2 file original=$2/preview-$1-original.omp.json
  local themed=$2/preview-$1-omarchy.omp.json
  file=$(theme_file "$name" "$scratch") || return 1
  theme_compose "$name" "$file" "$file" "$original" original || return 1
  theme_compose "$name" "$file" "$file" "$themed" omarchy || return 1
  print -r -- "$name"
  python3 -B "$previewer" --original "$original" --omarchy "$themed" \
    --pwd "$PWD" --columns "${FZF_PREVIEW_COLUMNS:-120}"
}

theme_choose_colors() {
  local name=$1 preferred=$2 selected
  local -a options
  if [[ $preferred == omarchy ]]; then
    options=('Colores de Omarchy' 'Colores originales')
  else
    options=('Colores originales' 'Colores de Omarchy')
  fi
  selected=$(printf '%s\n' "${options[@]}" | fzf \
    --height=8 --min-height=8 --margin=0,15% --layout=reverse \
    --border=rounded --border-label="Colores para $name" \
    --no-input --no-info --no-sort \
    --header='↑/↓: elegir · Enter: aplicar · Esc: cancelar') || return 1
  case $selected in
    'Colores originales') print -r -- original ;;
    'Colores de Omarchy') print -r -- omarchy ;;
    *) return 1 ;;
  esac
}

theme_list() {
  local scratch=$1 names=$2 force_refresh=${3:-false} file name cache_age refresh=0
  print -r -- pure-local > "$names"
  for file in "$config_dir"/themes/*.omp.json(N); do
    name=${file:t:r:r}
    theme_valid_name "$name" && print -r -- "$name" >> "$names"
  done

  if [[ $force_refresh == true || ! -s $catalog_cache ]]; then
    refresh=1
  else
    cache_age=$(( $(date +%s) - $(stat -c %Y -- "$catalog_cache") ))
    (( cache_age >= 604800 )) && refresh=1
  fi

  if (( refresh )); then
    if curl --location --fail --silent --show-error --connect-timeout 3 --max-time 8 \
      --header 'Accept: application/vnd.github+json' \
      --output "$scratch/catalog.json" "$theme_catalog"; then
      if jq -er 'if type == "array" then .[] | select(.type == "file") | .name | select(test("^[A-Za-z0-9][A-Za-z0-9._-]*\\.omp\\.json$")) | sub("\\.omp\\.json$"; "") else error("Catálogo inesperado") end' \
        "$scratch/catalog.json" > "$scratch/catalog.names" && [[ -s $scratch/catalog.names ]]; then
        cp -- "$scratch/catalog.names" "$config_dir/.catalog.names.$$.tmp" || return 1
        mv -Tf -- "$config_dir/.catalog.names.$$.tmp" "$catalog_cache" || return 1
      else
        print -u2 -r -- 'omp-theme: Catálogo remoto inválido; se usará la caché local.'
      fi
    else
      print -u2 -r -- 'omp-theme: Sin catálogo en línea; se usarán los temas en caché.'
    fi
  fi
  [[ -s $catalog_cache ]] && cat -- "$catalog_cache" >> "$names"
  sort -f -u "$names" -o "$names"
}

theme_activate() {
  local name=$1 scratch=$2 mode=$3 source_file target installed temporary generated link_temporary old_target suffix=''
  source_file=$(theme_file "$name" "$scratch") || return 1
  [[ -L $active_theme ]] && old_target=$(readlink -- "$active_theme")
  [[ $mode == omarchy ]] && suffix='@omarchy'

  if [[ $name == pure-local ]]; then
    target=pure.omp.json
  else
    mkdir -p -- "$config_dir/themes" || return 1
    installed=$config_dir/themes/$name.omp.json
    if [[ ! -e $installed ]]; then
      cp -- "$source_file" "$installed" || return 1
    fi
    target=themes/$name.omp.json
  fi

  generated=$config_dir/.active-$name$suffix.omp.json
  temporary=$config_dir/.active-$name$suffix.$$.tmp.omp.json
  theme_compose "$name" "$source_file" "$target" "$temporary" "$mode" || {
    command rm -f -- "$temporary"
    return 1
  }
  oh-my-posh config export --config "$temporary" >/dev/null || {
    theme_error "Oh My Posh no pudo cargar el tema compuesto $name"
    command rm -f -- "$temporary"
    return 1
  }
  mv -Tf -- "$temporary" "$generated" || return 1
  link_temporary=$config_dir/.active.omp.json.$$.link
  ln -s -- "${generated:t}" "$link_temporary" || return 1
  mv -Tf -- "$link_temporary" "$active_theme" || {
    command rm -f -- "$link_temporary"
    return 1
  }
  [[ $old_target == .active-*.omp.json && $old_target != ${generated:t} ]] &&
    command rm -f -- "$config_dir/$old_target"
  [[ -f $selection_file ]] && command rm -f -- "$selection_file"
  oh-my-posh enable reload --config "$active_theme" >/dev/null || {
    print -u2 -r -- 'omp-theme: Tema guardado; abre una nueva terminal para aplicarlo.'
    return 0
  }
  if [[ $mode == omarchy ]]; then
    print -r -- "Tema activo: $name (colores de Omarchy)"
  else
    print -r -- "Tema activo: $name"
  fi
}

for dependency in oh-my-posh curl jq python3; do
  (( $+commands[$dependency] )) || { theme_error "Falta $dependency"; exit 1; }
done

selection_mode=original
if [[ $1 == --omarchy ]]; then
  selection_mode=omarchy
  shift
fi

if [[ $1 == --preview ]]; then
  theme_preview "$2" "$3"
  exit $?
fi

if [[ $1 == --current ]]; then
  if [[ -L $active_theme ]]; then
    [[ -r $active_theme ]] || { theme_error 'El enlace del tema activo está roto'; exit 1; }
    target=$(readlink -- "$active_theme") || exit 1
    if [[ $target == .active-*.omp.json ]]; then
      name=${target#.active-}
      name=${name%.omp.json}
      print -r -- ${name%@omarchy}
    elif [[ $target == pure.omp.json ]]; then
      print -r -- pure-local
    elif [[ $target == themes/*.omp.json ]]; then
      print -r -- ${target:t:r:r}
    else
      print -r -- "$target"
    fi
  elif [[ -f $selection_file ]]; then
    cat -- "$selection_file"
  elif [[ -f $active_theme ]]; then
    target=$(jq -r '.extends // empty' "$active_theme") || exit 1
    if [[ $target == pure.omp.json ]]; then
      print -r -- pure-local
    elif [[ $target == themes/*.omp.json ]]; then
      print -r -- ${target:t:r:r}
    else
      theme_error 'No hay una selección registrada'
    fi
  else
    theme_error 'No hay un tema activo'
  fi
  exit $?
fi

if [[ $1 == --mode ]]; then
  [[ -r $active_theme ]] || { theme_error 'No hay un tema activo'; exit 1; }
  if [[ -L $active_theme ]]; then
    target=$(readlink -- "$active_theme") || exit 1
  else
    target=''
  fi
  if [[ $target == .active-*@omarchy.omp.json ]]; then
    print -r -- omarchy
  else
    print -r -- original
  fi
  exit 0
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/omp-theme.XXXXXXXX") || exit 1
trap 'command rm -rf -- "$scratch"' EXIT

if [[ $1 == --list || $1 == --refresh ]]; then
  if [[ $1 == --refresh ]]; then
    theme_list "$scratch" "$scratch/names" true || exit 1
  else
    theme_list "$scratch" "$scratch/names" false || exit 1
  fi
  cat -- "$scratch/names"
  exit $?
fi

if (( $# > 1 )); then
  theme_error 'Uso: omp-theme [--list|--refresh|--current|--mode|--omarchy [NOMBRE]|NOMBRE]'
  exit 1
fi

if (( $# == 0 )); then
  (( $+commands[fzf] )) || { theme_error 'Falta fzf'; exit 1; }
  theme_list "$scratch" "$scratch/names" || exit 1
  export OMP_THEME_PICKER_SCRIPT=$0 OMP_THEME_PICKER_SCRATCH=$scratch
  selection=$(fzf --height=80% --layout=reverse --border \
    --prompt='Oh My Posh > ' \
    --header='Entrar: elegir tema · Esc: cancelar' \
    --preview='zsh "$OMP_THEME_PICKER_SCRIPT" --preview {} "$OMP_THEME_PICKER_SCRATCH"' \
    --preview-window=down:60%:wrap < "$scratch/names") || exit 0
  [[ -n $selection ]] || exit 0
  choice=$selection
  if [[ $choice != pure-local ]]; then
    selection_mode=$(theme_choose_colors "$choice" "$selection_mode") || exit 0
  fi
else
  choice=$1
fi

theme_activate "$choice" "$scratch" "$selection_mode"
