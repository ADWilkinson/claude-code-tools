#!/bin/bash

# Claude Code Tools Installation Script
# Author: Andrew Wilkinson (github.com/ADWilkinson)
# Installs custom agents, commands, and statusline configuration

set -e

VERSION="1.2.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR=""
BACKUP_CREATED=false
INSTALL_SUCCESS=false
DRY_RUN=false
VERBOSE=false
INSTALL_AGENTS=true
INSTALL_COMMANDS=true
INSTALL_STATUSLINE=true

print_status() { echo -e "${BLUE}→${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_verbose() { [ "$VERBOSE" = true ] && echo -e "${CYAN}  $1${NC}"; }
print_dry() { [ "$DRY_RUN" = true ] && echo -e "${YELLOW}[DRY RUN]${NC} $1"; }

cleanup() {
    local exit_code=$?

    if [ "$DRY_RUN" = true ]; then
        return
    fi

    if [ "$exit_code" -ne 0 ] && [ "$BACKUP_CREATED" = true ]; then
        print_error "Installation failed! Rolling back..."
        rollback_installation
    elif [ "$exit_code" -eq 0 ] && [ "$INSTALL_SUCCESS" = true ] && [ "$BACKUP_CREATED" = true ]; then
        print_verbose "Cleaning up backup..."
        rm -rf "$BACKUP_DIR"
    fi
}

trap cleanup EXIT

rollback_installation() {
    if [ "$BACKUP_CREATED" = false ] || [ ! -d "$BACKUP_DIR" ]; then
        return 1
    fi

    if [ -f "$BACKUP_DIR/metadata/manifest.txt" ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*Agent:[[:space:]]*(.+\.md)$ ]]; then
                filename="${BASH_REMATCH[1]}"
                rm -f "$CLAUDE_DIR/agents/$filename"
                [ -f "$BACKUP_DIR/agents/$filename" ] && cp "$BACKUP_DIR/agents/$filename" "$CLAUDE_DIR/agents/"
            elif [[ $line =~ ^[[:space:]]*Command:[[:space:]]*(.+\.md)$ ]]; then
                filename="${BASH_REMATCH[1]}"
                rm -f "$CLAUDE_DIR/commands/$filename"
                [ -f "$BACKUP_DIR/commands/$filename" ] && cp "$BACKUP_DIR/commands/$filename" "$CLAUDE_DIR/commands/"
            fi
        done < "$BACKUP_DIR/metadata/manifest.txt"
    fi

    print_success "Rollback completed"
}

check_claude_installation() {
    if [ ! -d "$CLAUDE_DIR" ]; then
        print_error "Claude Code directory not found at $CLAUDE_DIR"
        print_error "Install Claude Code first: https://github.com/anthropics/claude-code"
        exit 1
    fi
    print_success "Found Claude Code at $CLAUDE_DIR"
}

create_directories() {
    if [ "$DRY_RUN" = true ]; then
        print_dry "Would create directories: $CLAUDE_DIR/agents, $CLAUDE_DIR/commands"
        return
    fi
    mkdir -p "$CLAUDE_DIR/agents"
    mkdir -p "$CLAUDE_DIR/commands"
    print_verbose "Directories ready"
}

backup_existing() {
    if [ "$DRY_RUN" = true ]; then
        print_dry "Would backup existing files"
        return
    fi

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="$CLAUDE_DIR/backup_$timestamp"

    mkdir -p "$BACKUP_DIR/agents"
    mkdir -p "$BACKUP_DIR/commands"
    mkdir -p "$BACKUP_DIR/metadata"

    echo "# Installation Manifest" > "$BACKUP_DIR/metadata/manifest.txt"
    echo "Timestamp: $(date)" >> "$BACKUP_DIR/metadata/manifest.txt"
    echo "Version: $VERSION" >> "$BACKUP_DIR/metadata/manifest.txt"
    echo "" >> "$BACKUP_DIR/metadata/manifest.txt"

    local files_backed_up=0

    if [ "$INSTALL_AGENTS" = true ] && [ -d "agents" ]; then
        for agent_file in agents/*.md; do
            if [ -f "$agent_file" ]; then
                agent_name=$(basename "$agent_file")
                echo "Agent: $agent_name" >> "$BACKUP_DIR/metadata/manifest.txt"
                if [ -f "$CLAUDE_DIR/agents/$agent_name" ]; then
                    cp "$CLAUDE_DIR/agents/$agent_name" "$BACKUP_DIR/agents/"
                    ((files_backed_up++)) || true
                    print_verbose "Backed up: $agent_name"
                fi
            fi
        done
    fi

    if [ "$INSTALL_COMMANDS" = true ] && [ -d "commands" ]; then
        for command_file in commands/*.md; do
            if [ -f "$command_file" ]; then
                command_name=$(basename "$command_file")
                echo "Command: $command_name" >> "$BACKUP_DIR/metadata/manifest.txt"
                if [ -f "$CLAUDE_DIR/commands/$command_name" ]; then
                    cp "$CLAUDE_DIR/commands/$command_name" "$BACKUP_DIR/commands/"
                    ((files_backed_up++)) || true
                    print_verbose "Backed up: $command_name"
                fi
            fi
        done
    fi

    BACKUP_CREATED=true

    if [ $files_backed_up -gt 0 ]; then
        print_warning "Backed up $files_backed_up existing files"
    fi
}

install_agents() {
    if [ "$INSTALL_AGENTS" = false ]; then
        return
    fi

    print_status "Installing agents..."

    if [ ! -d "agents" ]; then
        print_warning "No agents directory found, skipping"
        return
    fi

    local count=0
    for agent_file in agents/*.md; do
        if [ -f "$agent_file" ]; then
            agent_name=$(basename "$agent_file" .md)
            if [ "$DRY_RUN" = true ]; then
                print_dry "Would install agent: $agent_name"
            else
                cp "$agent_file" "$CLAUDE_DIR/agents/"
                print_verbose "Installed: $agent_name"
            fi
            ((count++)) || true
        fi
    done

    print_success "Installed $count agents"
}

install_commands() {
    if [ "$INSTALL_COMMANDS" = false ]; then
        return
    fi

    print_status "Installing commands..."

    if [ ! -d "commands" ]; then
        print_warning "No commands directory found, skipping"
        return
    fi

    local count=0
    for command_file in commands/*.md; do
        if [ -f "$command_file" ]; then
            command_name=$(basename "$command_file" .md)
            if [ "$DRY_RUN" = true ]; then
                print_dry "Would install command: /$command_name"
            else
                cp "$command_file" "$CLAUDE_DIR/commands/"
                print_verbose "Installed: /$command_name"
            fi
            ((count++)) || true
        fi
    done

    print_success "Installed $count commands"
}

install_statusline() {
    if [ "$INSTALL_STATUSLINE" = false ]; then
        return
    fi

    print_status "Installing statusline..."

    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    STATUSLINE_SCRIPT="$SCRIPT_DIR/statusline/flying-dutchman-statusline.sh"

    if [ ! -f "$STATUSLINE_SCRIPT" ]; then
        print_warning "Statusline script not found, skipping"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        print_dry "Would configure statusline: $STATUSLINE_SCRIPT"
        return
    fi

    chmod +x "$STATUSLINE_SCRIPT"

    SETTINGS_FILE="$CLAUDE_DIR/settings.json"

    if [ -f "$SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
        cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup"
        jq --arg statusline "$STATUSLINE_SCRIPT" \
           '.statusline = $statusline' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && \
           mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
        print_success "Configured statusline in settings.json"
    else
        print_warning "Add to settings.json: \"statusline\": \"$STATUSLINE_SCRIPT\""
    fi
}

show_preview() {
    echo
    echo -e "${BOLD}Files to install:${NC}"
    echo

    if [ "$INSTALL_AGENTS" = true ] && [ -d "agents" ]; then
        echo "  Agents:"
        for agent_file in agents/*.md; do
            if [ -f "$agent_file" ]; then
                agent_name=$(basename "$agent_file" .md)
                # Check if opus model
                if grep -q "model: opus" "$agent_file" 2>/dev/null; then
                    echo -e "    ${CYAN}$agent_name${NC} (opus)"
                else
                    echo "    $agent_name"
                fi
            fi
        done
        echo
    fi

    if [ "$INSTALL_COMMANDS" = true ] && [ -d "commands" ]; then
        echo "  Commands:"
        for command_file in commands/*.md; do
            if [ -f "$command_file" ]; then
                echo "    /$(basename "$command_file" .md)"
            fi
        done
        echo
    fi

    if [ "$INSTALL_STATUSLINE" = true ] && [ -f "statusline/flying-dutchman-statusline.sh" ]; then
        echo "  Statusline:"
        echo "    flying-dutchman-statusline.sh"
        echo
    fi
}

show_summary() {
    echo
    print_success "Installation complete!"
    echo
    echo -e "${BOLD}Installed:${NC}"

    if [ "$INSTALL_AGENTS" = true ]; then
        local agent_count=$(ls -1 "$CLAUDE_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  $agent_count agents in ~/.claude/agents/"
    fi

    if [ "$INSTALL_COMMANDS" = true ]; then
        local cmd_count=$(ls -1 "$CLAUDE_DIR/commands"/*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  $cmd_count commands in ~/.claude/commands/"
    fi

    echo
    echo -e "${BOLD}Usage:${NC}"
    echo "  Agents are auto-invoked by Claude Code via the Task tool"
    echo "  Commands: /repo-polish, /update-claudes, /minimize-ui"
    echo
}

show_help() {
    echo "Claude Code Tools Installer v$VERSION"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --claude-dir DIR    Custom Claude directory (default: ~/.claude)"
    echo "  --dry-run           Preview what would be installed without making changes"
    echo "  --agents-only       Only install agents"
    echo "  --commands-only     Only install commands"
    echo "  --no-statusline     Skip statusline installation"
    echo "  -v, --verbose       Show detailed output"
    echo "  -V, --version       Show version"
    echo "  -h, --help          Show this help"
    echo
    echo "Examples:"
    echo "  ./install.sh                    Install everything"
    echo "  ./install.sh --dry-run          Preview installation"
    echo "  ./install.sh --agents-only -v   Install only agents with verbose output"
    echo
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --claude-dir)
                CLAUDE_DIR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --agents-only)
                INSTALL_COMMANDS=false
                INSTALL_STATUSLINE=false
                shift
                ;;
            --commands-only)
                INSTALL_AGENTS=false
                INSTALL_STATUSLINE=false
                shift
                ;;
            --no-statusline)
                INSTALL_STATUSLINE=false
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -V|--version)
                echo "v$VERSION"
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    echo
    echo -e "${BOLD}Claude Code Tools Installer${NC} v$VERSION"
    echo "Author: Andrew Wilkinson"
    echo

    CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"

    # Check if we're in the right directory
    if [ ! -d "agents" ] && [ ! -d "commands" ]; then
        print_error "Run this script from the claude-code directory"
        exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
        echo
    fi

    show_preview
    check_claude_installation
    backup_existing
    create_directories
    install_agents
    install_commands
    install_statusline

    INSTALL_SUCCESS=true

    if [ "$DRY_RUN" = false ]; then
        show_summary
    else
        echo
        print_success "Dry run complete. Use without --dry-run to install."
    fi
}

main "$@"
