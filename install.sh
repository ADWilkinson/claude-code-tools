#!/bin/bash

# Claude Code Tools Installation Script
# Author: Andrew Wilkinson (github.com/ADWilkinson)
# Installs custom agents, commands, skills, hooks, and statusline configuration

set -e

VERSION="1.3.0"

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
INSTALL_SKILLS=true
INSTALL_HOOKS=true

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
            elif [[ $line =~ ^[[:space:]]*Skill:[[:space:]]*(.+)$ ]]; then
                skill_name="${BASH_REMATCH[1]}"
                rm -rf "$CLAUDE_DIR/skills/$skill_name"
                [ -d "$BACKUP_DIR/skills/$skill_name" ] && cp -R "$BACKUP_DIR/skills/$skill_name" "$CLAUDE_DIR/skills/"
            elif [[ $line =~ ^[[:space:]]*Hook:[[:space:]]*(.+)$ ]]; then
                filename="${BASH_REMATCH[1]}"
                rm -f "$CLAUDE_DIR/hooks/$filename"
                [ -f "$BACKUP_DIR/hooks/$filename" ] && cp "$BACKUP_DIR/hooks/$filename" "$CLAUDE_DIR/hooks/"
            elif [[ $line =~ ^[[:space:]]*Statusline:[[:space:]]*(.+)$ ]]; then
                filename="${BASH_REMATCH[1]}"
                rm -f "$CLAUDE_DIR/$filename"
                [ -f "$BACKUP_DIR/statusline/$filename" ] && cp "$BACKUP_DIR/statusline/$filename" "$CLAUDE_DIR/"
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
        local dirs=()
        [ "$INSTALL_AGENTS" = true ] && dirs+=("$CLAUDE_DIR/agents")
        [ "$INSTALL_COMMANDS" = true ] && dirs+=("$CLAUDE_DIR/commands")
        [ "$INSTALL_SKILLS" = true ] && dirs+=("$CLAUDE_DIR/skills")
        [ "$INSTALL_HOOKS" = true ] && dirs+=("$CLAUDE_DIR/hooks")
        if [ ${#dirs[@]} -gt 0 ]; then
            print_dry "Would create directories: ${dirs[*]}"
        else
            print_dry "No directories to create"
        fi
        return
    fi
    [ "$INSTALL_AGENTS" = true ] && mkdir -p "$CLAUDE_DIR/agents"
    [ "$INSTALL_COMMANDS" = true ] && mkdir -p "$CLAUDE_DIR/commands"
    [ "$INSTALL_SKILLS" = true ] && mkdir -p "$CLAUDE_DIR/skills"
    [ "$INSTALL_HOOKS" = true ] && mkdir -p "$CLAUDE_DIR/hooks"
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
    mkdir -p "$BACKUP_DIR/skills"
    mkdir -p "$BACKUP_DIR/hooks"
    mkdir -p "$BACKUP_DIR/statusline"
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

    if [ "$INSTALL_SKILLS" = true ] && [ -d "skills" ]; then
        for skill_dir in skills/*; do
            if [ -d "$skill_dir" ]; then
                skill_name=$(basename "$skill_dir")
                echo "Skill: $skill_name" >> "$BACKUP_DIR/metadata/manifest.txt"
                if [ -d "$CLAUDE_DIR/skills/$skill_name" ]; then
                    cp -R "$CLAUDE_DIR/skills/$skill_name" "$BACKUP_DIR/skills/"
                    ((files_backed_up++)) || true
                    print_verbose "Backed up: $skill_name"
                fi
            fi
        done
    fi

    if [ "$INSTALL_HOOKS" = true ] && [ -d "hooks" ]; then
        for hook_file in hooks/*; do
            if [ -f "$hook_file" ]; then
                hook_name=$(basename "$hook_file")
                echo "Hook: $hook_name" >> "$BACKUP_DIR/metadata/manifest.txt"
                if [ -f "$CLAUDE_DIR/hooks/$hook_name" ]; then
                    cp "$CLAUDE_DIR/hooks/$hook_name" "$BACKUP_DIR/hooks/"
                    ((files_backed_up++)) || true
                    print_verbose "Backed up: $hook_name"
                fi
            fi
        done
    fi

    if [ "$INSTALL_STATUSLINE" = true ]; then
        local statusline_name="flying-dutchman-statusline.sh"
        echo "Statusline: $statusline_name" >> "$BACKUP_DIR/metadata/manifest.txt"
        if [ -f "$CLAUDE_DIR/$statusline_name" ]; then
            cp "$CLAUDE_DIR/$statusline_name" "$BACKUP_DIR/statusline/"
            ((files_backed_up++)) || true
            print_verbose "Backed up: $statusline_name"
        fi
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

install_skills() {
    if [ "$INSTALL_SKILLS" = false ]; then
        return
    fi

    print_status "Installing skills..."

    if [ ! -d "skills" ]; then
        print_warning "No skills directory found, skipping"
        return
    fi

    local count=0
    for skill_dir in skills/*; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            if [ "$DRY_RUN" = true ]; then
                if [ -f "$skill_dir/install.sh" ]; then
                    print_dry "Would install skill: $skill_name (installer)"
                else
                    print_dry "Would install skill: $skill_name"
                fi
            else
                if [ -f "$skill_dir/install.sh" ]; then
                    print_verbose "Running installer for: $skill_name"
                    if [ -x "$skill_dir/install.sh" ]; then
                        "$skill_dir/install.sh" --claude-dir "$CLAUDE_DIR"
                    else
                        bash "$skill_dir/install.sh" --claude-dir "$CLAUDE_DIR"
                    fi
                else
                    mkdir -p "$CLAUDE_DIR/skills/$skill_name"
                    (cd "$skill_dir" && tar -cf - .) | (cd "$CLAUDE_DIR/skills/$skill_name" && tar -xf -)
                    print_verbose "Installed: $skill_name"
                fi
            fi
            ((count++)) || true
        fi
    done

    print_success "Installed $count skills"
}

install_hooks() {
    if [ "$INSTALL_HOOKS" = false ]; then
        return
    fi

    print_status "Installing hooks..."

    if [ ! -d "hooks" ]; then
        print_warning "No hooks directory found, skipping"
        return
    fi

    local count=0
    for hook_file in hooks/*; do
        if [ -f "$hook_file" ]; then
            hook_name=$(basename "$hook_file")
            if [ "$DRY_RUN" = true ]; then
                print_dry "Would install hook: $hook_name"
            else
                cp "$hook_file" "$CLAUDE_DIR/hooks/"
                chmod +x "$CLAUDE_DIR/hooks/$hook_name"
                print_verbose "Installed: $hook_name"
            fi
            ((count++)) || true
        fi
    done

    print_success "Installed $count hooks"
    if [ "$DRY_RUN" = false ] && [ $count -gt 0 ]; then
        print_warning "Remember to enable hooks in $CLAUDE_DIR/settings.json (see hooks/README.md)"
    fi
}

install_statusline() {
    if [ "$INSTALL_STATUSLINE" = false ]; then
        return
    fi

    print_status "Installing statusline..."

    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    STATUSLINE_SOURCE="$SCRIPT_DIR/statusline/flying-dutchman-statusline.sh"
    STATUSLINE_DEST="$CLAUDE_DIR/flying-dutchman-statusline.sh"

    if [ ! -f "$STATUSLINE_SOURCE" ]; then
        print_warning "Statusline script not found, skipping"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        print_dry "Would install statusline: $STATUSLINE_DEST"
        return
    fi

    cp "$STATUSLINE_SOURCE" "$STATUSLINE_DEST"
    chmod +x "$STATUSLINE_DEST"

    SETTINGS_FILE="$CLAUDE_DIR/settings.json"

    if [ -f "$SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
        cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup"
        jq --arg statusline "$STATUSLINE_DEST" \
           '.statusline = $statusline' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && \
           mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
        print_success "Configured statusline in settings.json"
    else
        print_warning "Add to settings.json: \"statusline\": \"$STATUSLINE_DEST\""
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

    if [ "$INSTALL_SKILLS" = true ] && [ -d "skills" ]; then
        echo "  Skills:"
        for skill_dir in skills/*; do
            if [ -d "$skill_dir" ]; then
                skill_name=$(basename "$skill_dir")
                if [ -f "$skill_dir/install.sh" ]; then
                    echo "    $skill_name (installer)"
                else
                    echo "    $skill_name"
                fi
            fi
        done
        echo
    fi

    if [ "$INSTALL_HOOKS" = true ] && [ -d "hooks" ]; then
        echo "  Hooks:"
        for hook_file in hooks/*; do
            if [ -f "$hook_file" ]; then
                echo "    $(basename "$hook_file")"
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
        echo "  $agent_count agents in $CLAUDE_DIR/agents/"
    fi

    if [ "$INSTALL_COMMANDS" = true ]; then
        local cmd_count=$(ls -1 "$CLAUDE_DIR/commands"/*.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  $cmd_count commands in $CLAUDE_DIR/commands/"
    fi

    if [ "$INSTALL_SKILLS" = true ]; then
        local skill_count=$(ls -1 "$CLAUDE_DIR/skills"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
        echo "  $skill_count skills in $CLAUDE_DIR/skills/"
    fi

    if [ "$INSTALL_HOOKS" = true ]; then
        local hook_count=$(ls -1 "$CLAUDE_DIR/hooks"/* 2>/dev/null | wc -l | tr -d ' ')
        echo "  $hook_count hooks in $CLAUDE_DIR/hooks/"
    fi

    echo
    echo -e "${BOLD}Usage:${NC}"
    echo "  Agents are auto-invoked by Claude Code via the Task tool"
    echo "  Commands: /deslop, /repo-polish, /update-claudes, /minimize-ui, /lighthouse, etc."
    echo "  Skills auto-activate based on your prompt"
    echo "  Hooks require settings.json configuration (see hooks/README.md)"
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
    echo "  --skills-only       Only install skills"
    echo "  --hooks-only        Only install hooks"
    echo "  --no-skills         Skip skill installation"
    echo "  --no-hooks          Skip hook installation"
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
                INSTALL_SKILLS=false
                INSTALL_HOOKS=false
                shift
                ;;
            --commands-only)
                INSTALL_AGENTS=false
                INSTALL_STATUSLINE=false
                INSTALL_SKILLS=false
                INSTALL_HOOKS=false
                shift
                ;;
            --skills-only)
                INSTALL_AGENTS=false
                INSTALL_COMMANDS=false
                INSTALL_STATUSLINE=false
                INSTALL_HOOKS=false
                shift
                ;;
            --hooks-only)
                INSTALL_AGENTS=false
                INSTALL_COMMANDS=false
                INSTALL_STATUSLINE=false
                INSTALL_SKILLS=false
                shift
                ;;
            --no-skills)
                INSTALL_SKILLS=false
                shift
                ;;
            --no-hooks)
                INSTALL_HOOKS=false
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
    if [ ! -d "agents" ] && [ ! -d "commands" ] && [ ! -d "skills" ] && [ ! -d "hooks" ]; then
        print_error "Run this script from the claude-code-tools directory"
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
    install_skills
    install_hooks
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
