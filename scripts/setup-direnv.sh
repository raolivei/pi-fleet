#!/bin/bash
# Setup direnv for personal projects isolation
# Keeps pyenv for corporate work, uses direnv for personal projects

set -e

echo "🔧 Setting up direnv for personal projects isolation..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if direnv is installed
if ! command -v direnv &> /dev/null; then
    echo -e "${YELLOW}📦 Installing direnv...${NC}"
    brew install direnv
    echo -e "${GREEN}✅ direnv installed${NC}"
else
    echo -e "${GREEN}✅ direnv already installed${NC}"
fi

# Setup direnv hook in .zshrc if not already present
if ! grep -q "direnv hook zsh" ~/.zshrc; then
    echo ""
    echo -e "${BLUE}🔨 Adding direnv hook to ~/.zshrc...${NC}"
    cat >> ~/.zshrc << 'EOF'

# ============================================
# DIRENV - Auto-activate directory environments
# ============================================
eval "$(direnv hook zsh)"

# Workspace isolation helper
reset_python_env() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate 2>/dev/null || true
    fi
    unset VIRTUAL_ENV
    unset PYTHONPATH
    unset PROJECT_ROOT
    unset WORKSPACE_TYPE
}

# Auto-reset when leaving workspaces
chpwd() {
    local current_workspace=""
    
    if [[ "$PWD" == "$HOME/WORKSPACE/momentive_emu"* ]]; then
        current_workspace="corporate"
    elif [[ "$PWD" == "$HOME/WORKSPACE/raolivei"* ]]; then
        current_workspace="personal"
    fi
    
    # Clean up if we're not in a recognized workspace
    if [[ -z "$current_workspace" ]] && [[ -n "$WORKSPACE_TYPE" ]]; then
        reset_python_env
    fi
}
EOF
    echo -e "${GREEN}✅ Added direnv hook to ~/.zshrc${NC}"
else
    echo -e "${GREEN}✅ direnv hook already in ~/.zshrc${NC}"
fi

# Create .envrc for personal workspace root
echo ""
echo -e "${BLUE}🏠 Setting up personal workspace config...${NC}"
cat > ~/WORKSPACE/raolivei/.envrc << 'EOF'
# ============================================
# PERSONAL WORKSPACE ROOT CONFIG
# ============================================
# This applies to ALL projects under ~/WORKSPACE/raolivei/

export WORKSPACE_TYPE="personal"
export PERSONAL_PROJECT=true

# Ensure we use system Python, not corporate pyenv
export PYENV_VERSION=system

# Set personal bin paths first
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# Unset any corporate variables
unset COMPANY

echo "🏠 Personal workspace (raolivei) environment loaded"
EOF

echo -e "${GREEN}✅ Created ~/.WORKSPACE/raolivei/.envrc${NC}"

# Create .envrc for swimTO project
echo ""
echo -e "${BLUE}🏊 Setting up SwimTO project config...${NC}"
cat > ~/WORKSPACE/raolivei/swimTO/.envrc << 'EOF'
# ============================================
# SwimTO PROJECT CONFIG
# ============================================

# Load parent workspace config first
source_up

# Activate SwimTO virtual environment
source swimTO/bin/activate

# SwimTO-specific variables
export PROJECT_NAME="swimTO"
export PROJECT_ROOT="${PWD}"
export PYTHONPATH="${PWD}"

echo "🏊 SwimTO environment activated (venv: swimTO/bin/python)"
EOF

echo -e "${GREEN}✅ Created swimTO/.envrc${NC}"

# Create template for new projects
echo ""
echo -e "${BLUE}📄 Creating project template...${NC}"
cat > ~/WORKSPACE/raolivei/.envrc-template << 'EOF'
# ============================================
# PROJECT ENVIRONMENT CONFIG
# ============================================

# Load parent workspace config first
source_up

# Auto-detect and activate Python virtual environment
if [[ -d ".venv/bin" ]]; then
    source .venv/bin/activate
    VENV_PATH=".venv"
elif [[ -d "venv/bin" ]]; then
    source venv/bin/activate
    VENV_PATH="venv"
elif [[ -d "env/bin" ]]; then
    source env/bin/activate
    VENV_PATH="env"
fi

# Project-specific variables
export PROJECT_NAME="$(basename $PWD)"
export PROJECT_ROOT="${PWD}"
export PYTHONPATH="${PWD}"

if [[ -n "$VENV_PATH" ]]; then
    echo "🚀 ${PROJECT_NAME} environment activated (venv: ${VENV_PATH})"
else
    echo "⚠️  ${PROJECT_NAME} - no venv found (.venv, venv, or env)"
fi
EOF

echo -e "${GREEN}✅ Created .envrc-template${NC}"

# Create new project helper script
echo ""
echo -e "${BLUE}🛠️  Creating new-project helper script...${NC}"
cat > ~/WORKSPACE/raolivei/pi-fleet/scripts/new-project.sh << 'EOF'
#!/bin/bash
# Quick setup for new personal Python projects

PROJECT_NAME="${1}"
VENV_NAME="${2:-.venv}"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Usage: ./new-project.sh <project-name> [venv-name]"
    echo ""
    echo "Examples:"
    echo "  ./new-project.sh my-app           # Creates with .venv"
    echo "  ./new-project.sh my-app venv      # Creates with venv/"
    exit 1
fi

PROJECT_DIR="$HOME/WORKSPACE/raolivei/$PROJECT_NAME"

if [[ -d "$PROJECT_DIR" ]]; then
    echo "❌ Project directory already exists: $PROJECT_DIR"
    exit 1
fi

echo "📁 Creating project: $PROJECT_NAME"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create venv
echo "🐍 Creating virtual environment: $VENV_NAME"
python3 -m venv "$VENV_NAME"

# Copy template and customize
echo "⚙️  Setting up direnv..."
cp ~/WORKSPACE/raolivei/.envrc-template .envrc

# If using non-standard venv name, customize the .envrc
if [[ "$VENV_NAME" != ".venv" && "$VENV_NAME" != "venv" && "$VENV_NAME" != "env" ]]; then
    cat > .envrc << CUSTOM_ENVRC
# ============================================
# $PROJECT_NAME PROJECT CONFIG
# ============================================

# Load parent workspace config first
source_up

# Activate custom virtual environment
source $VENV_NAME/bin/activate

# Project-specific variables
export PROJECT_NAME="$PROJECT_NAME"
export PROJECT_ROOT="\${PWD}"
export PYTHONPATH="\${PWD}"

echo "🚀 $PROJECT_NAME environment activated (venv: $VENV_NAME)"
CUSTOM_ENVRC
fi

direnv allow .

# Create .gitignore
cat > .gitignore << 'GITIGNORE'
# Virtual environments
.venv/
venv/
env/
ENV/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python

# Environment
.env
.env.local
.direnv/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Testing
.pytest_cache/
.coverage
htmlcov/

# Build
dist/
build/
*.egg-info/
GITIGNORE

# Create basic README
cat > README.md << README
# $PROJECT_NAME

Personal project under raolivei workspace.

## Setup

This project uses direnv for automatic environment activation.

\`\`\`bash
cd $PROJECT_DIR
# Virtual environment activates automatically!
\`\`\`

## Development

\`\`\`bash
# Install dependencies
pip install -r requirements.txt

# Run tests
pytest
\`\`\`
README

# Create empty requirements.txt
touch requirements.txt

echo ""
echo "✅ Project '$PROJECT_NAME' created successfully!"
echo ""
echo "📂 Location: $PROJECT_DIR"
echo "🐍 Virtual env: $VENV_NAME"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_DIR"
echo "  # Environment will activate automatically!"
echo "  pip install <packages>"
echo ""
EOF

chmod +x ~/WORKSPACE/raolivei/pi-fleet/scripts/new-project.sh
echo -e "${GREEN}✅ Created new-project.sh helper script${NC}"

# Setup global gitignore for direnv files
echo ""
echo -e "${BLUE}📝 Configuring git to ignore .direnv/...${NC}"
if [[ ! -f ~/.gitignore_global ]]; then
    touch ~/.gitignore_global
fi

if ! grep -q ".direnv/" ~/.gitignore_global; then
    echo ".direnv/" >> ~/.gitignore_global
    git config --global core.excludesfile ~/.gitignore_global
    echo -e "${GREEN}✅ Added .direnv/ to global gitignore${NC}"
else
    echo -e "${GREEN}✅ .direnv/ already in global gitignore${NC}"
fi

# Allow direnv configs
echo ""
echo -e "${BLUE}🔓 Allowing direnv configurations...${NC}"
cd ~/WORKSPACE/raolivei
direnv allow .

cd ~/WORKSPACE/raolivei/swimTO
direnv allow .

echo -e "${GREEN}✅ direnv configurations allowed${NC}"

# Create quick reference guide
echo ""
echo -e "${BLUE}📚 Creating quick reference guide...${NC}"
cat > ~/WORKSPACE/raolivei/DIRENV_GUIDE.md << 'EOF'
# direnv Quick Reference for Personal Projects

## Overview

All projects under `~/WORKSPACE/raolivei/` use **direnv** for automatic environment activation.
Corporate work at `~/WORKSPACE/momentive_emu/` continues to use pyenv.

## How It Works

1. When you `cd` into a personal project, the virtual environment activates automatically
2. When you leave the project, it deactivates automatically
3. No manual `source venv/bin/activate` needed!

## Creating New Projects

```bash
cd ~/WORKSPACE/raolivei
./pi-fleet/scripts/new-project.sh my-new-app

cd my-new-app
# Environment activates automatically!
```

## Existing Projects

If you have an existing project without direnv:

```bash
cd ~/WORKSPACE/raolivei/existing-project

# Copy the template
cp ~/WORKSPACE/raolivei/.envrc-template .envrc

# Allow it
direnv allow .

# Done! Now it auto-activates
```

## Checking What's Active

```bash
# See if a venv is active
echo $VIRTUAL_ENV

# See what workspace you're in
echo $WORKSPACE_TYPE  # "personal" or "corporate"

# See current project
echo $PROJECT_NAME
```

## Troubleshooting

### Environment not activating?

```bash
# Check if direnv is working
direnv status

# Re-allow the directory
direnv allow .

# Reload shell config
source ~/.zshrc
```

### Need to edit the config?

```bash
# Edit the .envrc file
vim .envrc

# After editing, you must re-allow it
direnv allow .
```

### Want to disable temporarily?

```bash
# Disable direnv for current shell
direnv deny .

# Re-enable later
direnv allow .
```

## Directory Structure

```
~/WORKSPACE/raolivei/           # Personal workspace
├── .envrc                      # Workspace-level config
├── .envrc-template             # Template for new projects
├── pi-fleet/scripts/new-project.sh  # Helper script
├── DIRENV_GUIDE.md             # This file
│
├── swimTO/                     # Existing project
│   ├── .envrc                  # Project config (inherits workspace)
│   └── swimTO/                 # Virtual environment
│
└── future-project/             # New projects follow same pattern
    ├── .envrc
    └── .venv/
```

## Commands Reference

```bash
# Allow a directory's .envrc
direnv allow [path]

# Deny/block a directory's .envrc
direnv deny [path]

# Check direnv status
direnv status

# Reload current directory's .envrc
direnv reload

# Edit .envrc and auto-reload
direnv edit [path]
```

## Benefits

✅ Auto-activation on `cd`
✅ Auto-deactivation on exit
✅ Isolation between personal and corporate
✅ No manual environment management
✅ Project-specific environment variables
✅ Hierarchical configuration (workspace → project)

## Integration with VS Code

Add to your VS Code settings for better Python detection:

```json
{
  "python.terminal.activateEnvironment": false,
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python"
}
```

VS Code will detect the venv, and direnv handles terminal activation.
EOF

echo -e "${GREEN}✅ Created DIRENV_GUIDE.md${NC}"

# Final summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   🎉 Setup Complete! 🎉                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Reload your shell:"
echo "   ${YELLOW}source ~/.zshrc${NC}"
echo ""
echo "2. Test the setup:"
echo "   ${YELLOW}cd ~/WORKSPACE/raolivei/swimTO${NC}"
echo "   ${YELLOW}echo \$VIRTUAL_ENV${NC}  # Should show swimTO venv"
echo ""
echo "3. Create a new project:"
echo "   ${YELLOW}cd ~/WORKSPACE/raolivei${NC}"
echo "   ${YELLOW}./pi-fleet/scripts/new-project.sh my-test-project${NC}"
echo ""
echo "4. Read the guide:"
echo "   ${YELLOW}cat ~/WORKSPACE/raolivei/DIRENV_GUIDE.md${NC}"
echo ""
echo -e "${GREEN}📝 Files created:${NC}"
echo "   • ~/WORKSPACE/raolivei/.envrc (workspace config)"
echo "   • ~/WORKSPACE/raolivei/swimTO/.envrc (swimTO config)"
echo "   • ~/WORKSPACE/raolivei/.envrc-template (project template)"
echo "   • ~/WORKSPACE/raolivei/pi-fleet/scripts/new-project.sh (helper script)"
echo "   • ~/WORKSPACE/raolivei/DIRENV_GUIDE.md (reference guide)"
echo ""
echo -e "${BLUE}💡 Remember:${NC}"
echo "   • Personal projects: ${GREEN}direnv auto-activates${NC}"
echo "   • Corporate work: ${YELLOW}pyenv as usual${NC}"
echo "   • Complete isolation between workspaces! 🎯"
echo ""

