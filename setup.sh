#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# nanobot setup script — install, configure, reset
# ─────────────────────────────────────────────────────────────

NANOBOT_HOME="${NANOBOT_HOME:-$HOME/.nanobot}"
CONFIG_FILE="${NANOBOT_CONFIG:-$NANOBOT_HOME/config.json}"
WORKSPACE_DIR="$NANOBOT_HOME/workspace"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*"; }
dim()   { echo -e "${DIM}$*${NC}"; }
header() { echo -e "\n${BOLD}${CYAN}── $* ──${NC}\n"; }

# ── Helpers ──────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

prompt_choice() {
    local prompt="$1" default="$2"
    read -rp "$(echo -e "${CYAN}$prompt${NC} [${default}]: ")" choice
    echo "${choice:-$default}"
}

prompt_secret() {
    local prompt="$1"
    read -rsp "$(echo -e "${CYAN}$prompt${NC}: ")" secret
    echo
    echo "$secret"
}

prompt_yes_no() {
    local prompt="$1" default="${2:-y}"
    local yn
    if [[ "$default" == "y" ]]; then
        read -rp "$(echo -e "${CYAN}$prompt${NC} [Y/n]: ")" yn
        yn="${yn:-y}"
    else
        read -rp "$(echo -e "${CYAN}$prompt${NC} [y/N]: ")" yn
        yn="${yn:-n}"
    fi
    [[ "$yn" =~ ^[Yy] ]]
}

check_python() {
    local py=""
    for candidate in python3 python; do
        if command_exists "$candidate"; then
            local ver
            ver="$("$candidate" --version 2>&1 | grep -oP '\d+\.\d+')"
            local major minor
            major="${ver%%.*}"
            minor="${ver#*.}"
            if (( major >= 3 && minor >= 11 )); then
                py="$candidate"
                break
            fi
        fi
    done
    if [[ -z "$py" ]]; then
        error "Python >=3.11 required. Found: $(python3 --version 2>&1 || echo 'none')"
        exit 1
    fi
    echo "$py"
}

# ── JSON helpers (pure bash + python one-liners) ─────────────
json_set() {
    local file="$1" key="$2" value="$3"
    local py
    py="$(check_python)"
    local win_file
    win_file="$(cygpath -w "$file" 2>/dev/null || echo "$file")"
    "$py" -c "
import json, sys, os
fp = r'''$win_file'''
if not os.path.exists(fp):
    os.makedirs(os.path.dirname(fp), exist_ok=True)
    with open(fp, 'w', encoding='utf-8') as f:
        json.dump({}, f)
with open(fp, encoding='utf-8') as f:
    d = json.load(f)
keys = '$key'.split('.')
obj = d
for k in keys[:-1]:
    obj = obj.setdefault(k, {})
try:
    v = json.loads('''$value''')
except (json.JSONDecodeError, ValueError):
    v = '''$value'''
obj[keys[-1]] = v
with open(fp, 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
"
}

json_get() {
    local file="$1" key="$2"
    local py
    py="$(check_python)"
    local win_file
    win_file="$(cygpath -w "$file" 2>/dev/null || echo "$file")"
    "$py" -c "
import json
fp = r'''$win_file'''
with open(fp, encoding='utf-8') as f:
    d = json.load(f)
keys = '$key'.split('.')
obj = d
for k in keys:
    obj = obj.get(k, '')
    if not isinstance(obj, dict) and k != keys[-1]:
        obj = ''
        break
print(obj if obj else '')
"
}

# ═════════════════════════════════════════════════════════════
# Actions
# ═════════════════════════════════════════════════════════════

do_install() {
    header "Install nanobot"

    local py
    py="$(check_python)"
    info "Python: $($py --version)"

    echo ""
    echo "  1) Source install (editable, recommended for dev)"
    echo "  2) pip install from PyPI"
    echo "  3) uv install from PyPI"
    echo ""
    local method
    method="$(prompt_choice "Install method" "1")"

    local extras=""
    if prompt_yes_no "Install dev dependencies?" "n"; then
        extras="dev"
    fi

    echo ""
    echo "  Optional extras: api, discord, matrix, weixin, wecom, langsmith"
    local extra_input
    extra_input="$(prompt_choice "Additional extras (comma-separated, or empty)" "")"
    if [[ -n "$extra_input" ]]; then
        extras="${extras:+$extras,}$extra_input"
    fi

    local pkg_spec="."
    if [[ -n "$extras" ]]; then
        pkg_spec=".[$extras]"
    fi

    case "$method" in
        1)
            if [[ ! -f "$REPO_DIR/pyproject.toml" ]]; then
                error "Not inside nanobot repo. Clone it first:"
                echo "  git clone https://github.com/HKUDS/nanobot.git && cd nanobot"
                exit 1
            fi
            info "Installing from source (editable)..."
            cd "$REPO_DIR"
            "$py" -m pip install -e "$pkg_spec"
            ;;
        2)
            local pip_spec="nanobot-ai"
            if [[ -n "$extras" ]]; then
                pip_spec="nanobot-ai[$extras]"
            fi
            info "Installing from PyPI..."
            "$py" -m pip install "$pip_spec"
            ;;
        3)
            if ! command_exists uv; then
                error "uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
                exit 1
            fi
            local uv_spec="nanobot-ai"
            if [[ -n "$extras" ]]; then
                uv_spec="nanobot-ai[$extras]"
            fi
            info "Installing via uv..."
            uv tool install "$uv_spec"
            ;;
        *)
            error "Invalid choice: $method"
            exit 1
            ;;
    esac

    if command_exists nanobot; then
        info "nanobot installed: $(nanobot --version)"
    else
        warn "nanobot not found in PATH. You may need to restart your shell."
    fi
}

do_configure() {
    header "Configure nanobot"

    # Ensure home directory exists
    mkdir -p "$NANOBOT_HOME"

    if [[ -f "$CONFIG_FILE" ]]; then
        warn "Config exists at $CONFIG_FILE"
        if ! prompt_yes_no "Reconfigure? (existing values will be preserved)" "y"; then
            return
        fi
    fi

    # Initialize config if missing
    if [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo '{}' > "$CONFIG_FILE"
        info "Created config at $CONFIG_FILE"
        # Let nanobot enrich it with defaults if available
        if command_exists nanobot; then
            local win_path
            win_path="$(cygpath -w "$CONFIG_FILE" 2>/dev/null || echo "$CONFIG_FILE")"
            nanobot onboard --config "$win_path" 2>/dev/null || true
        fi
    fi

    # Sanity check — ensure config file is valid JSON
    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo '{}' > "$CONFIG_FILE"
    fi

    # ── Provider ─────────────────────────────────────────────
    header "LLM Provider"
    echo "  1) openrouter     — access all models (recommended)"
    echo "  2) anthropic      — Claude direct"
    echo "  3) openai         — GPT direct"
    echo "  4) deepseek       — DeepSeek direct"
    echo "  5) gemini         — Gemini direct"
    echo "  6) groq           — Groq (fast inference)"
    echo "  7) ollama         — Local (Ollama)"
    echo "  8) custom         — Any OpenAI-compatible endpoint"
    echo ""
    local provider_choice
    provider_choice="$(prompt_choice "Provider" "1")"

    local provider_name="" api_key="" api_base="" model=""
    case "$provider_choice" in
        1) provider_name="openrouter" ;;
        2) provider_name="anthropic" ;;
        3) provider_name="openai" ;;
        4) provider_name="deepseek" ;;
        5) provider_name="gemini" ;;
        6) provider_name="groq" ;;
        7) provider_name="ollama" ;;
        8) provider_name="custom" ;;
        *) provider_name="$provider_choice" ;;
    esac

    # Provider-specific config
    case "$provider_name" in
        ollama)
            api_base="$(prompt_choice "Ollama URL" "http://localhost:11434/v1")"
            model="$(prompt_choice "Model" "ollama/llama3.2")"
            json_set "$CONFIG_FILE" "providers.ollama.apiBase" "$api_base"
            ;;
        custom)
            api_base="$(prompt_choice "API base URL" "http://localhost:8080/v1")"
            api_key="$(prompt_secret "API key (empty if not needed)")"
            model="$(prompt_choice "Model name" "default")"
            json_set "$CONFIG_FILE" "providers.custom.apiBase" "$api_base"
            if [[ -n "$api_key" ]]; then
                json_set "$CONFIG_FILE" "providers.custom.apiKey" "$api_key"
            fi

            local extra_hdr
            extra_hdr="$(prompt_choice "Extra headers as JSON (or empty)" "")"
            if [[ -n "$extra_hdr" ]]; then
                json_set "$CONFIG_FILE" "providers.custom.extraHeaders" "$extra_hdr"
            fi
            ;;
        *)
            api_key="$(prompt_secret "API key for $provider_name")"
            if [[ -z "$api_key" ]]; then
                warn "No API key provided. You'll need to add it to $CONFIG_FILE later."
            else
                json_set "$CONFIG_FILE" "providers.$provider_name.apiKey" "$api_key"
            fi

            # Suggest default model per provider
            local default_model=""
            case "$provider_name" in
                openrouter)  default_model="anthropic/claude-sonnet-4-20250514" ;;
                anthropic)   default_model="claude-sonnet-4-20250514" ;;
                openai)      default_model="gpt-4o" ;;
                deepseek)    default_model="deepseek-chat" ;;
                gemini)      default_model="gemini-2.0-flash" ;;
                groq)        default_model="llama-3.3-70b-versatile" ;;
            esac
            model="$(prompt_choice "Model" "$default_model")"
            ;;
    esac

    json_set "$CONFIG_FILE" "agents.defaults.model" "$model"
    if [[ "$provider_name" != "openrouter" ]]; then
        json_set "$CONFIG_FILE" "agents.defaults.provider" "$provider_name"
    fi

    # ── Web Search (optional) ────────────────────────────────
    if prompt_yes_no "Configure web search?" "n"; then
        echo ""
        echo "  1) brave        — requires API key"
        echo "  2) tavily       — requires API key"
        echo "  3) duckduckgo   — no config needed"
        echo "  4) jina         — free tier (10M tokens)"
        echo "  5) searxng      — self-hosted"
        echo ""
        local search_choice
        search_choice="$(prompt_choice "Search provider" "3")"

        case "$search_choice" in
            1)
                json_set "$CONFIG_FILE" "tools.web.search.provider" "brave"
                local bk
                bk="$(prompt_secret "Brave API key")"
                [[ -n "$bk" ]] && json_set "$CONFIG_FILE" "tools.web.search.apiKey" "$bk"
                ;;
            2)
                json_set "$CONFIG_FILE" "tools.web.search.provider" "tavily"
                local tk
                tk="$(prompt_secret "Tavily API key")"
                [[ -n "$tk" ]] && json_set "$CONFIG_FILE" "tools.web.search.apiKey" "$tk"
                ;;
            3)
                json_set "$CONFIG_FILE" "tools.web.search.provider" "duckduckgo"
                ;;
            4)
                json_set "$CONFIG_FILE" "tools.web.search.provider" "jina"
                local jk
                jk="$(prompt_secret "Jina API key (empty for free)")"
                [[ -n "$jk" ]] && json_set "$CONFIG_FILE" "tools.web.search.apiKey" "$jk"
                ;;
            5)
                json_set "$CONFIG_FILE" "tools.web.search.provider" "searxng"
                local su
                su="$(prompt_choice "SearXNG URL" "https://searx.example.com")"
                json_set "$CONFIG_FILE" "tools.web.search.baseUrl" "$su"
                ;;
        esac
    fi

    # ── Channel (optional) ───────────────────────────────────
    if prompt_yes_no "Enable a chat channel?" "n"; then
        echo ""
        echo "  1) telegram     5) feishu"
        echo "  2) discord      6) dingtalk"
        echo "  3) slack        7) matrix"
        echo "  4) whatsapp     8) email"
        echo ""
        local chan_choice
        chan_choice="$(prompt_choice "Channel" "1")"

        local chan_name=""
        case "$chan_choice" in
            1) chan_name="telegram" ;;
            2) chan_name="discord" ;;
            3) chan_name="slack" ;;
            4) chan_name="whatsapp" ;;
            5) chan_name="feishu" ;;
            6) chan_name="dingtalk" ;;
            7) chan_name="matrix" ;;
            8) chan_name="email" ;;
            *) chan_name="$chan_choice" ;;
        esac

        json_set "$CONFIG_FILE" "channels.$chan_name.enabled" "true"

        case "$chan_name" in
            telegram)
                local tg_token
                tg_token="$(prompt_secret "Telegram bot token")"
                [[ -n "$tg_token" ]] && json_set "$CONFIG_FILE" "channels.telegram.token" "$tg_token"
                ;;
            discord)
                local dc_token
                dc_token="$(prompt_secret "Discord bot token")"
                [[ -n "$dc_token" ]] && json_set "$CONFIG_FILE" "channels.discord.token" "$dc_token"
                ;;
            slack)
                local sb_token sa_token
                sb_token="$(prompt_secret "Slack bot token")"
                sa_token="$(prompt_secret "Slack app token")"
                [[ -n "$sb_token" ]] && json_set "$CONFIG_FILE" "channels.slack.botToken" "$sb_token"
                [[ -n "$sa_token" ]] && json_set "$CONFIG_FILE" "channels.slack.appToken" "$sa_token"
                ;;
            whatsapp)
                info "WhatsApp uses QR login. Run: nanobot channels login whatsapp"
                ;;
            feishu)
                local fs_id fs_secret
                fs_id="$(prompt_choice "Feishu App ID" "")"
                fs_secret="$(prompt_secret "Feishu App Secret")"
                [[ -n "$fs_id" ]] && json_set "$CONFIG_FILE" "channels.feishu.appId" "$fs_id"
                [[ -n "$fs_secret" ]] && json_set "$CONFIG_FILE" "channels.feishu.appSecret" "$fs_secret"
                ;;
            dingtalk)
                local dt_id dt_secret
                dt_id="$(prompt_choice "DingTalk Client ID" "")"
                dt_secret="$(prompt_secret "DingTalk Client Secret")"
                [[ -n "$dt_id" ]] && json_set "$CONFIG_FILE" "channels.dingtalk.clientId" "$dt_id"
                [[ -n "$dt_secret" ]] && json_set "$CONFIG_FILE" "channels.dingtalk.clientSecret" "$dt_secret"
                ;;
            matrix)
                local mx_token mx_user
                mx_token="$(prompt_secret "Matrix access token")"
                mx_user="$(prompt_choice "Matrix user ID" "@bot:matrix.org")"
                [[ -n "$mx_token" ]] && json_set "$CONFIG_FILE" "channels.matrix.accessToken" "$mx_token"
                [[ -n "$mx_user" ]] && json_set "$CONFIG_FILE" "channels.matrix.userId" "$mx_user"
                ;;
            email)
                warn "Email requires several fields. Edit $CONFIG_FILE directly."
                dim "See: https://github.com/HKUDS/nanobot#-chat-apps"
                ;;
        esac

        # Access control
        local allow_from
        allow_from="$(prompt_choice "allowFrom (comma-separated user IDs, or * for all)" "*")"
        if [[ "$allow_from" == "*" ]]; then
            json_set "$CONFIG_FILE" "channels.$chan_name.allowFrom" '["*"]'
        else
            local allow_json
            allow_json="[$(echo "$allow_from" | sed 's/[[:space:]]*,[[:space:]]*/","/g; s/^/"/; s/$/"/' )]"
            json_set "$CONFIG_FILE" "channels.$chan_name.allowFrom" "$allow_json"
        fi
    fi

    # ── Ports ────────────────────────────────────────────────
    if prompt_yes_no "Configure ports?" "n"; then
        local gw_port
        gw_port="$(prompt_choice "Gateway port" "18790")"
        if [[ "$gw_port" != "18790" ]]; then
            json_set "$CONFIG_FILE" "gateway.port" "$gw_port"
        fi

        local api_port
        api_port="$(prompt_choice "API server port" "8900")"
        if [[ "$api_port" != "8900" ]]; then
            json_set "$CONFIG_FILE" "api.port" "$api_port"
        fi

        local api_host
        api_host="$(prompt_choice "API server host" "127.0.0.1")"
        if [[ "$api_host" != "127.0.0.1" ]]; then
            json_set "$CONFIG_FILE" "api.host" "$api_host"
        fi
    fi

    # ── Security ─────────────────────────────────────────────
    if prompt_yes_no "Restrict tools to workspace? (sandbox mode)" "n"; then
        json_set "$CONFIG_FILE" "tools.restrictToWorkspace" "true"
    fi

    # ── Timezone ─────────────────────────────────────────────
    local tz
    tz="$(prompt_choice "Timezone (IANA)" "UTC")"
    if [[ "$tz" != "UTC" ]]; then
        json_set "$CONFIG_FILE" "agents.defaults.timezone" "$tz"
    fi

    echo ""
    info "Configuration saved to $CONFIG_FILE"
    dim "Edit directly: $CONFIG_FILE"
}

do_reset() {
    header "Reset nanobot"

    echo "  1) Reset config only (re-generate config.json with defaults)"
    echo "  2) Reset workspace only (re-sync templates, keep data)"
    echo "  3) Full reset (delete all data and start fresh)"
    echo ""
    local reset_choice
    reset_choice="$(prompt_choice "Reset type" "1")"

    case "$reset_choice" in
        1)
            if [[ -f "$CONFIG_FILE" ]]; then
                if prompt_yes_no "Reset $CONFIG_FILE to defaults? Current config will be lost" "n"; then
                    rm "$CONFIG_FILE"
                    if command_exists nanobot; then
                        local win_cfg
                        win_cfg="$(cygpath -w "$CONFIG_FILE" 2>/dev/null || echo "$CONFIG_FILE")"
                        nanobot onboard --config "$win_cfg"
                    else
                        echo '{}' > "$CONFIG_FILE"
                    fi
                    info "Config reset to defaults."
                fi
            else
                warn "No config file found at $CONFIG_FILE"
            fi
            ;;
        2)
            if [[ -d "$WORKSPACE_DIR" ]]; then
                if command_exists nanobot; then
                    local win_cfg
                    win_cfg="$(cygpath -w "$CONFIG_FILE" 2>/dev/null || echo "$CONFIG_FILE")"
                    nanobot onboard --config "$win_cfg"
                    info "Workspace templates re-synced."
                else
                    warn "nanobot not installed. Install first to sync templates."
                fi
            else
                warn "Workspace not found at $WORKSPACE_DIR"
            fi
            ;;
        3)
            if prompt_yes_no "DELETE all nanobot data at $NANOBOT_HOME? This cannot be undone" "n"; then
                echo ""
                warn "This will delete:"
                echo "  - $CONFIG_FILE"
                echo "  - $WORKSPACE_DIR (sessions, memory, skills)"
                echo "  - $NANOBOT_HOME/sessions/"
                echo "  - $NANOBOT_HOME/media/"
                echo "  - $NANOBOT_HOME/cron/"
                echo "  - $NANOBOT_HOME/bridge/"
                echo ""
                if prompt_yes_no "Are you absolutely sure?" "n"; then
                    rm -rf "$NANOBOT_HOME"
                    info "All nanobot data deleted."
                    info "Run './setup.sh install' then './setup.sh configure' to start fresh."
                else
                    warn "Aborted."
                fi
            fi
            ;;
    esac
}

do_status() {
    header "nanobot Status"

    # Python
    if command_exists python3; then
        info "Python: $(python3 --version)"
    else
        error "Python3 not found"
    fi

    # nanobot binary
    if command_exists nanobot; then
        info "nanobot: $(nanobot --version)"
    else
        error "nanobot not installed"
    fi

    # Config
    if [[ -f "$CONFIG_FILE" ]]; then
        info "Config: $CONFIG_FILE"
        local provider model
        provider="$(json_get "$CONFIG_FILE" "agents.defaults.provider" 2>/dev/null || echo "")"
        model="$(json_get "$CONFIG_FILE" "agents.defaults.model" 2>/dev/null || echo "")"
        [[ -n "$model" ]]    && dim "  Model:    $model"
        [[ -n "$provider" ]] && dim "  Provider: $provider"
    else
        warn "Config: not found ($CONFIG_FILE)"
    fi

    # Workspace
    if [[ -d "$WORKSPACE_DIR" ]]; then
        info "Workspace: $WORKSPACE_DIR"
    else
        warn "Workspace: not created"
    fi

    # Docker
    if command_exists docker; then
        info "Docker: $(docker --version | head -1)"
    else
        dim "Docker: not installed (optional)"
    fi
}

do_docker() {
    header "Docker Setup"

    if ! command_exists docker; then
        error "Docker not found. Install: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if [[ ! -f "$REPO_DIR/docker-compose.yml" ]]; then
        error "docker-compose.yml not found. Run from inside the nanobot repo."
        exit 1
    fi

    echo "  1) Build image"
    echo "  2) Start gateway"
    echo "  3) Run CLI"
    echo "  4) Stop gateway"
    echo "  5) View logs"
    echo ""
    local docker_choice
    docker_choice="$(prompt_choice "Action" "2")"

    cd "$REPO_DIR"
    case "$docker_choice" in
        1) docker compose build ;;
        2)
            docker compose run --rm nanobot-cli onboard 2>/dev/null || true
            docker compose up -d nanobot-gateway
            info "Gateway started on port 18790"
            ;;
        3) docker compose run --rm nanobot-cli agent ;;
        4)
            docker compose down
            info "Gateway stopped"
            ;;
        5) docker compose logs -f nanobot-gateway ;;
    esac
}

show_help() {
    echo -e "${BOLD}nanobot setup script${NC}"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  install     Install nanobot (source, pip, or uv)"
    echo "  configure   Configure provider, model, channels, search"
    echo "  reset       Reset config, workspace, or all data"
    echo "  status      Show current installation status"
    echo "  docker      Docker build/run/stop helpers"
    echo "  all         Run install + configure"
    echo ""
    echo "Environment:"
    echo "  NANOBOT_HOME    Base directory  (default: ~/.nanobot)"
    echo "  NANOBOT_CONFIG  Config path     (default: ~/.nanobot/config.json)"
}

# ═════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════

main() {
    local cmd="${1:-}"

    case "$cmd" in
        install)    do_install ;;
        configure)  do_configure ;;
        config)     do_configure ;;
        reset)      do_reset ;;
        status)     do_status ;;
        docker)     do_docker ;;
        all)
            do_install
            do_configure
            ;;
        -h|--help|help|"")
            show_help
            ;;
        *)
            error "Unknown command: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
