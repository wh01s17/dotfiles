# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

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

# Configure global git identity and store a GitHub token.
# The token is prompted for when omitted, so it never lands in shell history.
function git_config() {
    emulate -L zsh

    local username="$1" email="$2" git_token="$3"
    if [[ -z "$username" || -z "$email" ]]; then
        print -u2 -- "Usage: git_config <UserName> <Email> [Git Token]"
        print -u2 -- "       Omit the token to be prompted for it (keeps it out of history)."
        return 1
    fi

    if [[ -z "$git_token" ]]; then
        read -rs "git_token?Git token (hidden): "
        print
    fi
    if [[ -z "$git_token" ]]; then
        print -u2 -- "[!] No token provided; aborting."
        return 1
    fi

    git config --global user.name "$username"   || return 1
    git config --global user.email "$email"     || return 1
    git config --global core.autocrlf input
    git config --global credential.helper store

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

    # Replace any existing github.com entry (a stale one would win) but keep
    # credentials for every other host instead of truncating the whole file.
    local creds="$HOME/.git-credentials" tmp
    tmp="$(mktemp)" || return 1
    [[ -f "$creds" ]] && grep -vF -- '@github.com' "$creds" > "$tmp"
    print -r -- "https://${username}:${git_token}@github.com" >> "$tmp"
    mv -- "$tmp" "$creds" || { rm -f -- "$tmp"; return 1; }
    chmod 600 -- "$creds"

    print -r -- "[+] Git configured for '$username' (credentials in $creds, mode 600)"
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
alias john="/home/wh01s17/Documentos/git-clones/john/run/john"
alias fastfetch="$HOME/.config/fastfetch/wh01s17.sh"

source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# export JOHN=/home/wh01s17/Documentos/git-clones/john/run/john

PATH="/home/wh01s17/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/home/wh01s17/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/home/wh01s17/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/home/wh01s17/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/wh01s17/perl5"; export PERL_MM_OPT;
eval "$(zoxide init zsh)"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/wh01s17/.lmstudio/bin"

# opencode
export PATH=/home/wh01s17/.opencode/bin:$PATH

export PATH="/home/wh01s17/.local/bin:$PATH"
export PATH=$PATH:/home/wh01s17/.local/share/gem/ruby/3.2.0/bin:/home/wh01s17/Documentos/git-clones/john/run
export EDITOR=nvim

[[ -r "$HOME/.config/omarchy/bar/scripts/ctf-aliases.zsh" ]] && \
  source "$HOME/.config/omarchy/bar/scripts/ctf-aliases.zsh"

[[ -r "$HOME/.config/omarchy/bar/scripts/git-branch-hook.zsh" ]] && \
  source "$HOME/.config/omarchy/bar/scripts/git-branch-hook.zsh"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v "$HOME/.local/share/mise/shims" | paste -sd ':' -)"
nvm use default >/dev/null
. /usr/share/nvm/init-nvm.sh
