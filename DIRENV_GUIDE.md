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
./new-project.sh my-new-app

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
├── new-project.sh              # Helper script
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
