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

function extractPorts(){
	ports="$(cat $1 | grep -oP '\d{1,5}/open' | awk '{print $1}' FS='/' | xargs | tr ' ' ',')"
	ip_address="$(cat $1 | grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | sort -u | head -n 1)"
	echo -e "\n[*] Extracting information...\n" > extractPorts.tmp
	echo -e "\t[*] IP Address: $ip_address"  >> extractPorts.tmp
	echo -e "\t[*] Open ports: $ports\n"  >> extractPorts.tmp
	echo $ports | tr -d '\n' | xclip -sel clip
	echo -e "[*] Ports copied to clipboard\n"  >> extractPorts.tmp
	cat extractPorts.tmp; rm extractPorts.tmp
}

function mkt(){
	mkdir nmap content exploits && touch user_flag.txt root_flag.txt notes.txt
}

function git_config () {
    username="$1"
    email="$2"
    git_token="$3"

    if [[ -z "$username" || -z  "$email" || -z "$git_token" ]]; then
        echo "Use: git_config <UserName> <Email> <Git Token>"
        return 1
    fi

    git config --global user.email "$email"
    git config --global user.name "$username"
    git config --global core.autocrlf input

    if command -v code >/dev/null 2>&1; then
        git config --global core.editor "code --wait"
    else
        echo "[!] VS Code ('code') is not installed or not in PATH. Skipping editor configuration."
    fi

    git config --global credential.helper store

    echo "https://$username:$git_token@github.com" > ~/.git-credentials

    echo "[+] Git successfully configured for '$username'"
}

function ipinfo() {
    ip="$1"
    # Get your apikey from https://ipgeolocation.io/
    apikey_ipgeo="fd2b09ece3d84f73994428bced02dbcc"
    mode="$2"

    if [[ -z "$ip" ]]; then
        echo "Use: ipinfo <IP> [--whois] [--geo] [--info]"
        return 1
    fi

    if [[ "$mode" == "--whois" ]]; then
        echo "===== WHOIS FILTERED INFO ====="
        host "$ip"
        whois "$ip" | grep -E 'CIDR|OrgName|NetName|Country|OrgTechEmail'
        return 0
    fi

	if [[ "$mode" == "--geo" ]]; then
        echo -e "\n===== ipgeolocation.io ====="
		curl -s "https://api.ipgeolocation.io/v2/ipgeo?apiKey=$apikey_ipgeo&ip=$ip" | jq .
        return 0
    fi

	if [[ "$mode" == "--info" ]]; then
        echo "===== ipinfo.io ====="
		curl -s "https://ipinfo.io/$ip" | jq .
        return 0
    fi

    echo "===== ipinfo.io ====="
    curl -s "https://ipinfo.io/$ip" | jq .

    echo -e "\n===== ip-api.com ====="
    curl -s "http://ip-api.com/json/$ip" | jq .

    echo -e "\n===== ipwhois.app ====="
    curl -s "https://ipwhois.app/json/$ip" | jq .

    echo -e "\n===== ipapi.co ====="
    curl -s "https://ipapi.co/$ip/json/" | jq .

    echo -e "\n===== ipgeolocation.io ====="
    curl -s "https://api.ipgeolocation.io/v2/ipgeo?apiKey=$apikey_ipgeo&ip=$ip" | jq .

    echo -e "\n===== host / whois ====="
    host "$ip"
    whois "$ip" | grep -E 'OrgName|OrgTechEmail|Country|CIDR|NetName'
}

function subdomain_enum() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo "Uso: subdomain_enum <dominio>"; return 1; }

    echo "[*] Enumerando subdominios para: $domain"
    local tmpfile=$(mktemp)

    if command -v subfinder >/dev/null 2>&1; then
        echo "[+] Usando subfinder..."
        subfinder -d "$domain" -silent >> "$tmpfile"
    else
        echo "[!] subfinder no está instalado."
    fi

    if command -v amass >/dev/null 2>&1; then
        echo "[+] Usando amass (modo pasivo)..."
        amass enum -passive -d "$domain" >> "$tmpfile"
    else
        echo "[!] amass no está instalado."
    fi

    echo
    echo "[*] Subdominios únicos encontrados:"
    sort -u "$tmpfile"
    rm "$tmpfile"
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

source "$HOME/.config/waybar/scripts/ctf-aliases.zsh"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v "$HOME/.local/share/mise/shims" | paste -sd ':' -)"
nvm use default >/dev/null
