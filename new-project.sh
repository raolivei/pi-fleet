#!/bin/bash
# ============================================
# NEW PERSONAL PROJECT SETUP SCRIPT
# ============================================
# Quick setup for new personal Python projects with direnv

set -e

PROJECT_NAME="${1}"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "❌ Error: Project name required"
    echo ""
    echo "Usage: ./new-project.sh <project-name>"
    echo ""
    echo "Example:"
    echo "  ./new-project.sh my-awesome-app"
    exit 1
fi

PROJECT_DIR="$HOME/WORKSPACE/raolivei/$PROJECT_NAME"

if [[ -d "$PROJECT_DIR" ]]; then
    echo "❌ Error: Project directory already exists: $PROJECT_DIR"
    exit 1
fi

echo "🏗️  Creating new personal project: $PROJECT_NAME"
echo ""

# Create project directory
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create venv
echo "📦 Creating virtual environment..."
python3 -m venv .venv

# Create .envrc from template
echo "⚙️  Setting up direnv..."
cp "$HOME/WORKSPACE/raolivei/.envrc-template" .envrc

# Allow direnv
direnv allow .

# Create .gitignore
echo "📝 Creating .gitignore..."
cat > .gitignore << 'EOF'
# Python
.venv/
venv/
env/
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Environment
.env
.env.local
.direnv/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Testing
.pytest_cache/
.coverage
htmlcov/
EOF

# Create basic README
echo "📄 Creating README..."
cat > README.md << EOF
# $PROJECT_NAME

Personal project - part of raolivei workspace.

## Setup

This project uses direnv for automatic environment activation.

\`\`\`bash
cd ~/WORKSPACE/raolivei/$PROJECT_NAME
# Environment activates automatically!
\`\`\`

## Development

\`\`\`bash
# Install dependencies
pip install -r requirements.txt

# Run tests
pytest
\`\`\`

## Environment

- Workspace: Personal (raolivei)
- Python: \$(python --version)
- Virtual Environment: .venv/
EOF

# Create empty requirements.txt
touch requirements.txt

echo ""
echo "✅ Project '$PROJECT_NAME' created successfully!"
echo ""
echo "📍 Location: $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_DIR"
echo "  # Environment will activate automatically"
echo "  pip install <your-packages>"
echo ""
