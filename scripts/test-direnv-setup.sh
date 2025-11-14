#!/usr/bin/env zsh
# Test script for direnv setup
# Run this in your actual terminal with: zsh test-direnv-setup.sh

echo "🧪 Testing direnv setup for workspace isolation"
echo "=" | tr '=' '\n' | head -60 | tr '\n' '=' && echo

# Test 1: Home directory (no environment)
echo ""
echo "📍 Test 1: Home directory (should have no project environment)"
cd ~
echo "   WORKSPACE_TYPE: ${WORKSPACE_TYPE:-<not set>}"
echo "   VIRTUAL_ENV: ${VIRTUAL_ENV:-<not set>}"
echo "   Python: $(which python || echo '<not found>')"
echo ""

# Test 2: Personal workspace root
echo "📍 Test 2: Personal workspace root (raolivei)"
cd ~/WORKSPACE/raolivei
sleep 0.5  # Give direnv time to load
echo "   WORKSPACE_TYPE: ${WORKSPACE_TYPE:-<not set>}"
echo "   PERSONAL_PROJECT: ${PERSONAL_PROJECT:-<not set>}"
echo "   VIRTUAL_ENV: ${VIRTUAL_ENV:-<not set>}"
echo "   Python: $(which python || echo '<not found>')"
echo ""

# Test 3: SwimTO project
echo "📍 Test 3: SwimTO project (should activate .venv)"
cd ~/WORKSPACE/raolivei/swimTO
sleep 0.5  # Give direnv time to load
echo "   WORKSPACE_TYPE: ${WORKSPACE_TYPE:-<not set>}"
echo "   PROJECT_NAME: ${PROJECT_NAME:-<not set>}"
echo "   VIRTUAL_ENV: ${VIRTUAL_ENV:-<not set>}"
echo "   Python path: $(which python || echo '<not found>')"
if [[ -n "$(which python)" ]]; then
    echo "   Python version: $(python --version 2>&1)"
    echo "   Python location: $(python -c 'import sys; print(sys.prefix)' 2>&1)"
fi
echo ""

# Test 4: Check if venv python is being used
echo "📍 Test 4: Verify venv is active (not pyenv)"
cd ~/WORKSPACE/raolivei/swimTO
EXPECTED_VENV="${HOME}/WORKSPACE/raolivei/swimTO/.venv"
ACTUAL_PYTHON="$(which python)"

if [[ "$ACTUAL_PYTHON" == "$EXPECTED_VENV/bin/python" ]]; then
    echo "   ✅ SUCCESS: Using local .venv Python"
elif [[ "$ACTUAL_PYTHON" == *"pyenv"* ]]; then
    echo "   ❌ FAIL: Still using pyenv Python"
    echo "   Expected: $EXPECTED_VENV/bin/python"
    echo "   Actual: $ACTUAL_PYTHON"
elif [[ "$ACTUAL_PYTHON" == *"/usr/bin/python"* ]] || [[ "$ACTUAL_PYTHON" == *"/usr/local/bin/python"* ]]; then
    echo "   ❌ FAIL: Using system Python"
    echo "   Expected: $EXPECTED_VENV/bin/python"
    echo "   Actual: $ACTUAL_PYTHON"
else
    echo "   ⚠️  UNKNOWN: Python path unexpected"
    echo "   Expected: $EXPECTED_VENV/bin/python"
    echo "   Actual: $ACTUAL_PYTHON"
fi
echo ""

# Test 5: Leave project
echo "📍 Test 5: Leave project (should deactivate)"
cd ~/WORKSPACE/raolivei
sleep 0.5
echo "   VIRTUAL_ENV: ${VIRTUAL_ENV:-<not set>}"
echo "   PROJECT_NAME: ${PROJECT_NAME:-<not set>}"
echo ""

# Test 6: Check isolation from corporate workspace
echo "📍 Test 6: Corporate workspace (should use pyenv)"
if [[ -d ~/WORKSPACE/momentive_emu ]]; then
    cd ~/WORKSPACE/momentive_emu
    sleep 0.5
    echo "   WORKSPACE_TYPE: ${WORKSPACE_TYPE:-<not set>}"
    echo "   PERSONAL_PROJECT: ${PERSONAL_PROJECT:-<not set>}"
    echo "   Python: $(which python || echo '<not found>')"
    if [[ -n "$(which python)" ]] && [[ "$(which python)" == *"pyenv"* ]]; then
        echo "   ✅ Corporate workspace using pyenv as expected"
    fi
else
    echo "   ⚠️  Corporate workspace directory not found, skipping test"
fi
echo ""

# Summary
echo "=" | tr '=' '\n' | head -60 | tr '\n' '=' && echo
echo "🏁 Testing complete!"
echo ""
echo "Expected results:"
echo "  ✅ Personal workspace (raolivei): WORKSPACE_TYPE=personal"
echo "  ✅ SwimTO project: Uses .venv Python (not pyenv)"
echo "  ✅ Leaving project: Deactivates venv"
echo "  ✅ Corporate workspace: Uses pyenv"
echo ""

