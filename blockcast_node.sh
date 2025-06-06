#!/bin/bash

tput reset
tput civis

# SYSTEM COLOURS
show_orange() { echo -e "\e[33m$1\e[0m"; }
show_blue()   { echo -e "\e[34m$1\e[0m"; }
show_green()  { echo -e "\e[32m$1\e[0m"; }
show_red()    { echo -e "\e[31m$1\e[0m"; }
show_cyan()   { echo -e "\e[36m$1\e[0m"; }
show_purple() { echo -e "\e[35m$1\e[0m"; }
show_gray()   { echo -e "\e[90m$1\e[0m"; }
show_white()  { echo -e "\e[97m$1\e[0m"; }
show_blink()  { echo -e "\e[5m$1\e[0m"; }

# SYSTEM FUNCS
exit_script() {
    echo
    show_red   "🚫 Script terminated by user"
    show_gray  "────────────────────────────────────────────────────────────"
    show_orange "⚠️  All processes stopped. Returning to shell..."
    show_green "Goodbye, Agent. Stay legendary."
    echo
    sleep 1
    exit 0
}

incorrect_option() {
    echo
    show_red   "⛔️  Invalid option selected"
    show_orange "🔄  Please choose a valid option from the menu"
    show_gray  "Tip: Use numbers shown in brackets [1] [2] [3]..."
    echo
    sleep 1
}

process_notification() {
    local message="$1"
    local delay="${2:-1}"

    echo
    show_gray  "────────────────────────────────────────────────────────────"
    show_orange "🔔  $message"
    show_gray  "────────────────────────────────────────────────────────────"
    echo
    sleep "$delay"
}

run_commands() {
    local commands="$*"

    if eval "$commands"; then
        sleep 1
        show_green "✅ Success"
    else
        sleep 1
        show_red "❌ Error while executing command"
    fi
    echo
}

menu_header() {
    local container_status=$(docker inspect -f '{{.State.Status}}' blockcastd 2>/dev/null || echo "not installed")
    local node_status="🔴 OFFLINE"

    if [ "$container_status" = "running" ]; then
        node_status="🟢 ACTIVE"
    fi

    show_gray "────────────────────────────────────────────────────────────"
    show_cyan  "        ⚙️  BLOCKCAST NODE - CONTROL PANEL"
    show_gray "────────────────────────────────────────────────────────────"
    echo
    show_orange "Agent: $(whoami)   🕒 $(date +"%H:%M:%S")   📆 $(date +"%Y-%m-%d")"
    show_green  "Container: ${container_status^^}"
    show_blue   "Node status: $node_status"
    echo
}

menu_item() {
    local num="$1"
    local icon="$2"
    local title="$3"
    local description="$4"

    local formatted_line
    formatted_line=$(printf "  [%-1s] %-2s %-20s - %s" "$num" "$icon" "$title" "$description")
    show_blue "$formatted_line"
}

print_logo() {
    clear
    tput civis

    local logo_lines=(
        " .______     ______  .___________. "
        " |   _  \   /      | |           | "
        " |  |_)  | |  ,----'  ---|  |----  "
        " |   _  <  |  |          |  | "
        " |  |_)  | |   ----      |  | "
        " |______/   \______|     |__| "
    )

    local messages=(
        ">> Initializing Blockcast module..."
        ">> Establishing secure connection..."
        ">> Loading node configuration..."
        ">> Syncing with Blockcast Network..."
        ">> Checking system requirements..."
        ">> Terminal integrity: OK"
    )

    echo
    show_cyan "🛰️ INITIALIZING MODULE: \c"
    show_purple "BLOCKCAST NETWORK"
    show_gray "────────────────────────────────────────────────────────────"
    echo
    sleep 0.5

    show_gray "Loading: \c"
    for i in {1..30}; do
        echo -ne "\e[32m█\e[0m"
        sleep 0.02
    done
    show_green " [100%]"
    echo
    sleep 0.3

    for msg in "${messages[@]}"; do
        show_gray "$msg"
        sleep 0.15
    done
    echo
    sleep 0.5

    for line in "${logo_lines[@]}"; do
        show_cyan "$line"
        sleep 0.08
    done

    echo
    show_green "⚙️  SYSTEM STATUS: ACTIVE"
    show_orange ">> ACCESS GRANTED. WELCOME TO BLOCKCAST NETWORK."
    show_gray "[BLOCKCAST-NODE:latest / Secure Terminal Session]"
    echo

    echo -ne "\e[1;37mAwaiting commands"
    for i in {1..3}; do
        echo -ne "."
        sleep 0.4
    done
    echo -e "\e[0m"
    sleep 0.5

    tput cnorm
}

confirm_prompt() {
    local prompt="$1"
    read -p "$prompt (y/N): " response
    response=$(echo "$response" | xargs)
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

prompt_input() {
    local prompt="$1"
    local var
    read -p "$prompt" var
    echo "$var" | xargs
}

return_back () {
    show_gray "↩️  Returning to main menu..."
    sleep 0.5
}

check_curl() {
    if ! command -v curl &>/dev/null; then
        show_orange "ℹ️ curl not found. Installing..."
        run_commands "sudo apt-get update && sudo apt-get install -y curl" || {
            show_red "❌ Critical: curl is required but couldn't be installed"
            exit 1
        }
    fi
}

# NODE FUNC

get_compose_command() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    else
        show_red "❌ Neither 'docker-compose' nor 'docker compose' command found"
        return 1
    fi
}

docker_installation() {
    get_latest_docker_version() {
        local version=$(curl -s https://docs.docker.com/engine/release-notes/ | \
                      grep -oP 'Docker Engine \Kv?\d+\.\d+\.\d+' | head -1)

        if [[ -z "$version" ]]; then
            version=$(curl -s https://api.github.com/repos/moby/moby/releases/latest | \
                     jq -r '.tag_name' | grep -oP 'v?\d+\.\d+\.\d+')
        fi

        if [[ -z "$version" ]] && command -v apt-get &>/dev/null; then
            version=$(apt-cache madison docker-ce | awk '{print $3}' | sort -V | tail -1 | cut -d':' -f2)
        fi

        echo "${version:-24.0.0}" | sed 's/^v//'
    }

    get_latest_compose_version() {
        local version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | \
                      jq -r '.tag_name')

        if [[ -z "$version" || "$version" == "null" ]]; then
            version=$(curl -s https://docs.docker.com/compose/release-notes/ | \
                     grep -oP 'Compose \Kv?\d+\.\d+\.\d+' | head -1)
        fi

        echo "${version:-2.20.0}" | sed 's/^v//'
    }

    local steps=(
        "🔎 Checking system dependencies"
        "🌐 Fetching latest versions"
        "🧹 Removing old Docker versions"
        "🐳 Installing/updating Docker"
        "🔧 Configuring Docker permissions"
        "🔄 Installing/updating Docker Compose"
        "🚀 Starting Docker services"
        "✅ Verifying installation"
    )

    local current=0 total=${#steps[@]}
    step_progress() {
        current=$((current + 1))
        echo
        show_gray "[Step $current/$total] ${steps[$((current - 1))]}..."
        echo
        sleep 0.3
    }

    step_progress
    if ! command -v curl >/dev/null; then
        show_orange "ℹ️ curl not found. Installing..."
        run_commands "sudo apt-get update && sudo apt-get install -y curl" || {
            show_red "❌ Failed to install curl";
            exit 1;
        }
    fi

    if ! command -v jq >/dev/null; then
        show_orange "ℹ️ jq not found. Installing..."
        run_commands "sudo apt-get install -y jq" || {
            show_red "❌ Failed to install jq";
            show_gray "Some version checks may be limited";
        }
    fi

    step_progress
    LATEST_DOCKER=$(get_latest_docker_version)
    LATEST_COMPOSE=$(get_latest_compose_version)

    show_green "• Latest Docker: $LATEST_DOCKER"
    show_green "• Latest Docker Compose: $LATEST_COMPOSE"

    step_progress
    run_commands "sudo apt-get remove -y docker docker-engine docker.io containerd runc docker-compose docker-compose-plugin" || {
        show_orange "⚠️ Failed to remove some old packages"
    }

    step_progress
    NEED_DOCKER_UPDATE=true
    if command -v docker >/dev/null; then
        CURRENT_DOCKER=$(docker --version | grep -oP '[\d.]+' | head -1)
        if [ "$(printf '%s\n' "$LATEST_DOCKER" "$CURRENT_DOCKER" | sort -V | head -n1)" = "$LATEST_DOCKER" ]; then
            NEED_DOCKER_UPDATE=false
            show_green "✓ Docker is up-to-date (v$CURRENT_DOCKER)"
        fi
    fi

    if $NEED_DOCKER_UPDATE; then
        run_commands "curl -fsSL https://get.docker.com | sudo sh" && {
            show_green "✓ Docker installed successfully"
            newgrp docker <<EONG
            echo "Temporarily activating docker group..."
EONG
        } || {
            show_red "❌ Docker installation failed!"
            exit 1
        }
    fi

    step_progress
    if ! getent group docker | grep -q "\b$USER\b"; then
        run_commands "sudo usermod -aG docker $USER" && \
            show_green "✓ User added to docker group" || \
            show_red "❌ Failed to add user to docker group"
    else
        show_green "✓ User already in docker group"
    fi

    step_progress
    NEED_COMPOSE_UPDATE=true
    if docker compose version &>/dev/null; then
        CURRENT_COMPOSE=$(docker compose version | grep -oP '[\d.]+')
        if [ "$(printf '%s\n' "$LATEST_COMPOSE" "$CURRENT_COMPOSE" | sort -V | head -n1)" = "$LATEST_COMPOSE" ]; then
            NEED_COMPOSE_UPDATE=false
            show_green "✓ Docker Compose is up-to-date ($CURRENT_COMPOSE)"
        fi
    fi

    if $NEED_COMPOSE_UPDATE; then
        run_commands "sudo apt-get update && sudo apt-get install -y docker-compose-plugin" && {
            show_green "✓ Docker Compose installed successfully"
        } || {
            show_orange "⚠️ Trying alternative installation method..."
            run_commands "mkdir -p ~/.docker/cli-plugins && \
                         curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o ~/.docker/cli-plugins/docker-compose && \
                         chmod +x ~/.docker/cli-plugins/docker-compose" || {
                show_red "❌ All installation methods failed!"
                exit 1
            }
        }
    fi

    step_progress
    if ! systemctl is-active --quiet docker; then
        run_commands "sudo systemctl enable --now docker" && \
            show_green "✓ Docker daemon started" || \
            show_red "❌ Failed to start Docker daemon"
    else
        show_green "✓ Docker daemon already running"
    fi

    step_progress
    if docker ps >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        show_green "🎉 Installation successful!"
        echo
        show_blue "ℹ️ Versions:"
        docker --version
        docker compose version
        echo
        show_orange "⚠️ Important: Re-login or run 'newgrp docker' to apply permissions"
    else
        show_red "❌ Verification failed!"
        show_gray "Check logs above for errors"
        exit 1
    fi
}

install_dependencies() {
    process_notification "🔧 Installing system dependencies..."

    local steps=(
        "📥 Updating package list"
        "📦 Installing required packages"
        "🐳 Installing Docker"
    )

    local current=0 total=${#steps[@]}
    step_progress() {
        current=$((current + 1))
        echo
        show_gray "[Step $current/$total] ${steps[$((current - 1))]}..."
        echo
        sleep 0.3
    }

    step_progress
    run_commands "sudo apt-get update && sudo apt-get upgrade -y"

    step_progress
    run_commands "sudo apt install curl git wget jq nano mc tmux htop pkg-config tar unzip -y"

    step_progress
    docker_installation

    show_green "✅ All dependencies installed successfully"
}

install_node() {
    process_notification "🚀 Starting Blockcast Node installation..."

    if [ -d "beacon-docker-compose" ]; then
        show_orange "⚠️  Blockcast directory already exists"
        if confirm_prompt "Do you want to reinstall?"; then
            run_commands "rm -rf beacon-docker-compose"
        else
            return_back
            return
        fi
    fi

    local steps=(
        "📥 Cloning repository"
        "🐳 Starting containers"
        "🔍 Verifying installation"
    )

    local current=0 total=${#steps[@]}
    step_progress() {
        current=$((current + 1))
        echo
        show_gray "[Step $current/$total] ${steps[$((current - 1))]}..."
        echo
        sleep 0.3
    }

    step_progress
    if run_commands "git clone https://github.com/Blockcast/beacon-docker-compose.git"; then
        cd beacon-docker-compose || {
            show_red "❌ Failed to enter beacon-docker-compose directory"
            return 1
        }
    else
        return 1
    fi

    step_progress
    DC=$(get_compose_command) || return 1
    if run_commands "$DC up -d"; then
        show_green "✅ Containers started successfully"
    else
        return 1
    fi

    step_progress
    if docker ps | grep -q "blockcastd"; then
        show_green "✅ Blockcast Node is running"
        echo
    else
        show_red "❌ Blockcast container not running"
        return 1
    fi
}

register_node() {
    process_notification "📝 Registering Blockcast Node..."

    if [ ! -d "beacon-docker-compose" ]; then
        show_red "❌ Blockcast directory not found"
        return_back
        return
    fi

    cd beacon-docker-compose || {
        show_red "❌ Failed to enter beacon-docker-compose directory"
        return_back
        return
    }

    DC=$(get_compose_command) || return 1
    if run_commands "$DC exec blockcastd blockcastd init"; then
        show_green "✅ Node initialized successfully"
    else
        show_red "❌ Failed to initialize node"
    fi
    cd ..
}

view_logs() {
    process_notification "📜 Viewing Blockcast Node logs..."

    if docker ps | grep -q "blockcastd"; then
        show_orange "ℹ️  Press Ctrl+C to exit log view"
        echo
        docker logs -f blockcastd
    else
        show_red "❌ Blockcast container not running"
    fi
}

restart_node() {
    process_notification "🔄 Restarting Blockcast Node..."

    if [ ! -d "beacon-docker-compose" ]; then
        show_red "❌ Blockcast directory not found"
        return_back
        return
    fi

    cd beacon-docker-compose || {
        show_red "❌ Failed to enter beacon-docker-compose directory"
        return 1
    }

    DC=$(get_compose_command) || return 1
    if run_commands "$DC restart"; then
        show_green "✅ Node restarted successfully"
        sleep 2
        view_logs
    else
        show_red "❌ Failed to restart node"
    fi

    cd ..
}

update_node() {
    process_notification "🔄 Checking for updates..."

    LATEST_VERSION=$(curl -s https://api.github.com/repos/Blockcast/beacon-docker-compose/releases/latest | jq -r '.tag_name')
    CURRENT_VERSION=$(git -C beacon-docker-compose describe --tags 2>/dev/null || echo "unknown")

    if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
        show_orange "⚠️ Update available: $CURRENT_VERSION → $LATEST_VERSION"
        if confirm_prompt "Do you want to update?"; then
            delete_node
            install_node
        fi
    else
        show_green "✅ You have the latest version ($CURRENT_VERSION)"
    fi
}

delete_node() {
    process_notification "🗑️ Initiating Node Deletion Sequence..."
    show_gray "────────────────────────────────────────────────────────────"
    show_red   "⚠️  WARNING: This action is irreversible!"
    show_orange "• All node data will be permanently erased"
    show_orange "• All containers and images will be removed"
    show_orange "• Configuration files will be deleted"
    show_gray "────────────────────────────────────────────────────────────"

    if ! confirm_prompt "Are you absolutely sure you want to continue?"; then
        show_orange "🛑 Deletion sequence aborted by user"
        return_back
        return
    fi

    local steps=(
        "🔍 Locating Node components"
        "🛑 Stopping running containers"
        "🧹 Removing Docker resources"
        "📁 Deleting configuration files"
        "🧽 Final cleanup"
    )

    local current=0 total=${#steps[@]}
    step_progress() {
        current=$((current + 1))
        echo
        show_gray "[${current}/${total}] ${steps[$((current - 1))]}..."
        sleep 0.2
    }

    step_progress
    if [ ! -d "beacon-docker-compose" ]; then
        show_orange "ℹ️  Node directory not found (already deleted?)"
    else
        step_progress
        cd beacon-docker-compose || {
            show_red "❌ Critical: Cannot access node directory"
            return 1
        }

        DC=$(get_compose_command) || return 1
        if run_commands "$DC down --rmi all --volumes --remove-orphans"; then
            show_green "✓ All Docker resources removed"
        else
            show_red "⚠️  Partial cleanup - some components may remain"
        fi

        step_progress
        cd ..
        if run_commands "rm -rf beacon-docker-compose"; then
            show_green "✓ Node directory deleted"
        else
            show_red "❌ Failed to delete directory - check permissions"
        fi
    fi

    step_progress
    if [ -d "~/.blockcast" ]; then
        if run_commands "rm -rf ~/.blockcast"; then
            show_green "✓ Configuration files removed"
        else
            show_red "❌ Failed to remove config files"
        fi
    else
        show_orange "ℹ️  No configuration files found"
    fi

    step_progress
    show_gray "────────────────────────────────────────────────────────────"
    if docker ps -a | grep -q "blockcast"; then
        show_red "⚠️  Warning: Some Docker components still detected"
        show_gray "Try manual cleanup with: docker system prune -a --volumes"
    else
        show_green "✅ Verification: No Node components remaining"
    fi

    show_gray "────────────────────────────────────────────────────────────"
    show_green "🚀 Node deletion sequence completed"
    show_orange "ℹ️  System will return to main menu in 3 seconds..."
    sleep 3
}

main_menu() {
    check_curl
    print_logo

    while true; do
        menu_header
        show_gray "────────────────────────────────────────────────────────────"
        show_cyan "           🔋 BLOCKCAST NODE MENU"
        show_gray "────────────────────────────────────────────────────────────"
        sleep 0.3

        menu_item 1 "🚀" "Install Node"       "Install Blockcast Node"
        menu_item 2 "📝" "Register Node"      "Initialize the node"
        menu_item 3 "📜" "View Logs"          "View node logs"
        menu_item 4 "🔄" "Restart Node"       "Restart the node"
        menu_item 5 "🔄" "Update Node"        "Check for updates"
        menu_item 6 "🗑️" "Delete Node"        "Completely remove node"
        menu_item 7 "🚪" "Exit"               "Exit the control panel"

        show_gray "────────────────────────────────────────────────────────────"
        echo

        read -p "$(show_gray 'Select option ➤ ') " opt
        echo

        case $opt in
            1) install_dependencies; install_node ;;
            2) register_node ;;
            3) view_logs ;;
            4) restart_node ;;
            5) update_node ;;
            6) delete_node ;;
            7) exit_script ;;
            *) incorrect_option ;;
        esac
    done
}

main_menu
