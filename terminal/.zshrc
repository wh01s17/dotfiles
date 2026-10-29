# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Oh My Zsh loads plugins; Starship provides the prompt.
ZSH_THEME=""

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-sudo
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
# Manual aliases

# Local secrets (API keys, tokens). Lives outside the dotfiles repo on purpose.
[[ -r "$HOME/.config/zsh/secrets.zsh" ]] && source "$HOME/.config/zsh/secrets.zsh"

# --- Helpers ---------------------------------------------------------------

# Copy stdin to the clipboard. Calls wl-copy/xclip directly rather than
# oh-my-zsh's clipcopy, which backgrounds the copy and can lose the race when
# the shell exits right after. Falls back to clipcopy on other platforms.
function _copy_to_clipboard() {
    if [[ -n "$WAYLAND_DISPLAY" ]] && (( $+commands[wl-copy] )); then
        wl-copy
    elif [[ -n "$DISPLAY" ]] && (( $+commands[xclip] )); then
        xclip -selection clipboard -in
    elif (( $+functions[clipcopy] )); then
        clipcopy
    else
        cat >/dev/null
        return 1
    fi
}

# Fail with a clear message when a required binary is missing.
function _require_cmd() {
    local cmd missing=()
    for cmd in "$@"; do
        (( $+commands[$cmd] )) || missing+=("$cmd")
    done
    (( ${#missing} )) || return 0
    print -u2 -- "[!] Missing required command(s): ${missing[*]}"
    return 1
}

# --- CTF / recon -----------------------------------------------------------

# Extract the target IP and open ports from an nmap report (grepable or normal
# output) and copy the port list to the clipboard.
function extractPorts() {
    emulate -L zsh

    local file="$1"
    if [[ -z "$file" || "$file" == (-h|--help) ]]; then
        print -u2 -- "Usage: extractPorts <nmap-output-file>"
        return 1
    fi
    if [[ ! -r "$file" ]]; then
        print -u2 -- "[!] Cannot read file: $file"
        return 1
    fi

    local ports ip_address
    # Grepable output ("22/open/tcp") and normal output ("22/tcp  open").
    ports="$( { grep -oE '[0-9]{1,5}/open' "$file"
                grep -oE '^[0-9]{1,5}/(tcp|udp)[[:space:]]+open' "$file"
              } 2>/dev/null | cut -d/ -f1 | sort -nu | paste -sd, - )"
    ip_address="$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$file" | sort -u | head -n 1)"

    if [[ -z "$ports" ]]; then
        print -u2 -- "[!] No open ports found in $file"
        return 1
    fi

    printf '\n[*] Extracting information...\n\n'
    printf '\t[*] IP Address: %s\n' "${ip_address:-unknown}"
    printf '\t[*] Open ports: %s\n\n' "$ports"

    if printf '%s' "$ports" | _copy_to_clipboard; then
        printf '[*] Ports copied to clipboard\n\n'
    else
        print -u2 -- "[!] No clipboard tool found (wl-copy/xclip); ports not copied"
    fi
}

# Create the standard CTF working tree, optionally inside a new directory.
function mkt() {
    emulate -L zsh

    local base="${1:-.}" name
    mkdir -p -- "$base" || return 1
    for name in nmap content exploits; do
        mkdir -p -- "$base/$name" || return 1
    done
    for name in user_flag.txt root_flag.txt notes.txt; do
        [[ -e "$base/$name" ]] || : > "$base/$name" || return 1
    done
    [[ "$base" != "." ]] && { cd -- "$base" || return 1; }
    print -r -- "[+] Workspace ready at $PWD"
}

# Enumerate subdomains with whatever passive tooling is installed.
function subdomain_enum() {
    emulate -L zsh

    local domain="$1" outfile="$2"
    if [[ -z "$domain" || "$domain" == (-h|--help) ]]; then
        print -u2 -- "Usage: subdomain_enum <domain> [output-file]"
        return 1
    fi

    local -a tools=()
    (( $+commands[subfinder] )) && tools+=(subfinder)
    (( $+commands[amass] ))     && tools+=(amass)
    if (( ! ${#tools} )); then
        print -u2 -- "[!] Neither subfinder nor amass is installed; nothing to run."
        return 1
    fi

    local tmpdir
    tmpdir="$(mktemp -d)" || return 1
    trap "rm -rf -- ${(q)tmpdir}" EXIT INT TERM

    print -r -- "[*] Enumerating subdomains for: $domain"
    local tool
    for tool in $tools; do
        case "$tool" in
            subfinder)
                print -r -- "[+] Running subfinder..."
                subfinder -d "$domain" -silent >> "$tmpdir/raw" ;;
            amass)
                print -r -- "[+] Running amass (passive mode)..."
                amass enum -passive -d "$domain" >> "$tmpdir/raw" ;;
        esac
    done

    grep -E '^[A-Za-z0-9._-]+$' "$tmpdir/raw" 2>/dev/null | sort -u > "$tmpdir/sorted"
    local count
    count="$(wc -l < "$tmpdir/sorted")"

    print
    print -r -- "[*] Unique subdomains found: ${count// /}"
    cat -- "$tmpdir/sorted"

    if [[ -n "$outfile" ]]; then
        cp -- "$tmpdir/sorted" "$outfile" && print -r -- "[+] Saved to $outfile"
    fi
}

# --- IP intelligence -------------------------------------------------------

# Fetch one JSON endpoint and pretty-print it under a labelled header.
function _ipinfo_source() {
    local label="$1" url="$2" body
    printf '\n===== %s =====\n' "$label"
    if ! body="$(curl -fsS --max-time 10 -- "$url" 2>&1)"; then
        print -u2 -- "[!] Request failed: $body"
        return 1
    fi
    print -r -- "$body" | jq . 2>/dev/null || print -r -- "$body"
}

function _ipinfo_whois() {
    local ip="$1"
    printf '\n===== host / whois =====\n'
    (( $+commands[host] )) && host "$ip"
    if (( $+commands[whois] )); then
        whois "$ip" | grep -E 'CIDR|OrgName|NetName|Country|OrgTechEmail'
    else
        print -u2 -- "[!] whois is not installed."
    fi
}

# Query public IP intelligence sources.
# ipgeolocation.io needs $IPGEOLOCATION_API_KEY (see ~/.config/zsh/secrets.zsh).
function ipinfo() {
    emulate -L zsh

    local ip="$1" mode="${2:---all}"
    if [[ -z "$ip" || "$ip" == (-h|--help) ]]; then
        print -u2 -- "Usage: ipinfo <IP|host> [--all|--info|--geo|--whois]"
        return 1
    fi
    _require_cmd curl jq || return 1

    local geo_url="https://api.ipgeolocation.io/v2/ipgeo?apiKey=${IPGEOLOCATION_API_KEY}&ip=${ip}"

    case "$mode" in
        --whois)
            _ipinfo_whois "$ip"
            ;;
        --info)
            _ipinfo_source "ipinfo.io" "https://ipinfo.io/${ip}"
            ;;
        --geo)
            if [[ -z "$IPGEOLOCATION_API_KEY" ]]; then
                print -u2 -- "[!] IPGEOLOCATION_API_KEY is not set. Get a key at https://ipgeolocation.io/"
                return 1
            fi
            _ipinfo_source "ipgeolocation.io" "$geo_url"
            ;;
        --all)
            _ipinfo_source "ipinfo.io"   "https://ipinfo.io/${ip}"
            _ipinfo_source "ip-api.com"  "http://ip-api.com/json/${ip}"
            _ipinfo_source "ipwhois.app" "https://ipwhois.app/json/${ip}"
            _ipinfo_source "ipapi.co"    "https://ipapi.co/${ip}/json/"
            if [[ -n "$IPGEOLOCATION_API_KEY" ]]; then
                _ipinfo_source "ipgeolocation.io" "$geo_url"
            fi
            _ipinfo_whois "$ip"
            ;;
        *)
            print -u2 -- "[!] Unknown option: $mode"
            print -u2 -- "Usage: ipinfo <IP|host> [--all|--info|--geo|--whois]"
            return 1
            ;;
    esac
}

# --- git -------------------------------------------------------------------

# Update Git repositories directly inside a directory (including hidden ones).
# Only clean worktrees on a branch with an upstream are eligible; never stash,
# rebase, reset or create merge commits. Return nonzero if anything is skipped
# or fails, but keep processing the remaining repositories.
function git_update_all() {
    emulate -L zsh

    if [[ "$1" == (-h|--help) ]]; then
        print -r -- 'Uso: git_update_all [carpeta]'
        print -r -- 'Actualiza los repositorios hijos directos (por defecto: carpeta actual).'
        return 0
    fi
    if (( $# > 1 )) || [[ ! -d "${1:-.}" ]]; then
        print -u2 -r -- 'Uso: git_update_all [carpeta existente]'
        return 1
    fi
    _require_cmd git || return 1

    local base="${1:-.}" repo git_dir marker branch upstream changes
    local -i total=0 updated=0 skipped=0 failed=0 busy=0
    base="${base:A}"

    for repo in "$base"/*(ND/); do
        # A .git file also covers linked worktrees and submodules. Checking
        # the marker prevents Git from treating ordinary folders as the parent repo.
        [[ -e "$repo/.git" ]] || continue
        (( total += 1 ))
        print -r -- "[*] $repo"
        if ! git_dir=$(command git -C "$repo" rev-parse --absolute-git-dir); then
            print -u2 -r -- '[!] No se pudo abrir el repositorio.'
            (( failed += 1 ))
            continue
        fi

        busy=0
        for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer BISECT_LOG; do
            [[ -e "$git_dir/$marker" ]] && busy=1
        done
        if (( busy )); then
            print -r -- '[-] Omitido: hay una operación Git en curso.'
            (( skipped += 1 ))
            continue
        fi
        if ! changes=$(command git -C "$repo" status --porcelain --untracked-files=all --ignore-submodules=none); then
            print -u2 -r -- '[!] No se pudo comprobar el estado.'
            (( failed += 1 ))
            continue
        fi
        if [[ -n "$changes" ]]; then
            print -r -- '[-] Omitido: hay cambios locales o archivos sin seguimiento.'
            (( skipped += 1 ))
            continue
        fi
        if ! branch=$(command git -C "$repo" symbolic-ref --quiet --short HEAD); then
            print -r -- '[-] Omitido: HEAD separado (sin rama activa).'
            (( skipped += 1 ))
            continue
        fi
        if ! upstream=$(command git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
            print -r -- "[-] Omitido: $branch no tiene upstream disponible."
            (( skipped += 1 ))
            continue
        fi

        print -r -- "[*] $branch <- $upstream (solo fast-forward)"
        if command git -C "$repo" -c submodule.recurse=false pull \
                --ff-only --no-rebase --no-autostash --no-recurse-submodules; then
            (( updated += 1 ))
        else
            print -u2 -r -- '[!] Falló la actualización; revisa el mensaje de Git.'
            (( failed += 1 ))
        fi
    done

    print -r -- "Repositorios: $total | Al día/actualizados: $updated | Omitidos: $skipped | Errores: $failed"
    (( skipped == 0 && failed == 0 ))
}

# Configure global git identity and editor; GitHub credentials come from gh.
function git_config() {
    emulate -L zsh

    local username="$1" email="$2"
    if [[ -z "$username" || -z "$email" ]]; then
        print -u2 -- "Usage: git_config <UserName> <Email>"
        return 1
    fi

    git config --global user.name "$username"   || return 1
    git config --global user.email "$email"     || return 1
    git config --global core.autocrlf input

    local editor=""
    if [[ -n "$EDITOR" ]] && (( $+commands[${EDITOR%% *}] )); then
        editor="$EDITOR"
    elif (( $+commands[code] )); then
        editor="code --wait"
    fi
    if [[ -n "$editor" ]]; then
        git config --global core.editor "$editor"
    else
        print -u2 -- "[!] No usable editor found; leaving core.editor untouched."
    fi

    if (( ! $+commands[gh] )); then
        print -u2 -- "[!] gh not found; install it and rerun to set up GitHub credentials."
        return 1
    fi
    gh auth status --hostname github.com &> /dev/null ||
        gh auth login --hostname github.com --git-protocol https || return 1

    # Same as `gh auth setup-git`, but through mise's shim: setup-git writes the
    # path of gh's versioned install directory, which breaks after a gh upgrade.
    local gh_bin="$HOME/.local/share/mise/shims/gh" host
    [[ -x "$gh_bin" ]] || gh_bin="${commands[gh]}"
    for host in github.com gist.github.com; do
        git config --global --unset-all "credential.https://$host.helper"
        git config --global --add "credential.https://$host.helper" ''
        git config --global --add "credential.https://$host.helper" "!$gh_bin auth git-credential"
    done

    print -r -- "[+] Git configured for '$username' (GitHub credentials via gh)"
}

alias ll='eza -lhg'
alias lll='/bin/ls --hyperlink=auto'
alias la='eza -a'
alias l='eza -lg'
alias lla='eza -lag'
alias ls='eza'
alias cat='bat'
alias icat="kitten icat"
alias cd="z"
alias fastfetch="$HOME/.config/fastfetch/wh01s17.sh"

eval "$(zoxide init zsh)"

export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim

[[ -r "$HOME/.config/omarchy/bar/scripts/ctf-aliases.zsh" ]] && \
  source "$HOME/.config/omarchy/bar/scripts/ctf-aliases.zsh"

[[ -r "$HOME/.config/omarchy/bar/scripts/git-branch-hook.zsh" ]] && \
  source "$HOME/.config/omarchy/bar/scripts/git-branch-hook.zsh"

export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v "$HOME/.local/share/mise/shims" | paste -sd ':' -)"

# NVM: the default Node goes straight onto PATH and nvm itself loads on first
# use; sourcing it at startup cost ~0.9 s. Follows the default alias chain
# (default -> lts/* -> lts/<name> -> vX.Y.Z), else the newest installed version.
export NVM_DIR="$HOME/.config/nvm"
() {
  local ver=default i
  for i in 1 2 3; do
    [[ -r $NVM_DIR/alias/$ver ]] && ver=$(<$NVM_DIR/alias/$ver)
  done
  if [[ ! -d $NVM_DIR/versions/node/$ver ]]; then
    local -a installed=($NVM_DIR/versions/node/v*(NnOn:t))
    ver=${installed[1]-}
  fi
  [[ -n $ver ]] && path=("$NVM_DIR/versions/node/$ver/bin" $path)
}
nvm() {
  unfunction nvm
  source /usr/share/nvm/init-nvm.sh
  nvm "$@"
}

eval "$(starship init zsh)"

# Separate completed commands from the next prompt, but not shell startup.
typeset -gi _prompt_command_ran=0
_prompt_sparse_preexec() {
  _prompt_command_ran=1
}
_prompt_sparse_precmd() {
  if (( _prompt_command_ran )); then
    print
    _prompt_command_ran=0
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook preexec _prompt_sparse_preexec
add-zsh-hook precmd _prompt_sparse_precmd
