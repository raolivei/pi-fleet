#!/bin/bash
# Clean restart of PhotoRec recovery
# Kills existing sessions and restarts properly

set -e

# Configuration
PI_HOST="${PI_HOST:-eldertree.local}"
PI_USER="${PI_USER:-raolivei}"
PI_PASSWORD="${PI_PASSWORD:-Control01!}"
TMUX_SESSION="photorec-recovery"
SOURCE_DEVICE="/dev/sda"
RECOVERY_DEST="/media/raolivei/3230-3738/recovered_files"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}$1${NC}"
    echo "=========================================="
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Run command on Pi
run_on_pi() {
    sshpass -p "$PI_PASSWORD" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "$1"
}

print_header "PhotoRec Clean Restart"

# Step 1: Check current status
print_info "Step 1: Checking current recovery status..."

FILES_RECOVERED=$(run_on_pi "find $RECOVERY_DEST/recup_dir.* -type f 2>/dev/null | wc -l" | tr -d '\r\n')
TOTAL_SIZE=$(run_on_pi "du -sh $RECOVERY_DEST 2>/dev/null | awk '{print \$1}'" | tr -d '\r\n')

if [ -n "$FILES_RECOVERED" ] && [ "$FILES_RECOVERED" != "0" ]; then
    print_success "Current recovery status:"
    print_info "  Files recovered: $FILES_RECOVERED"
    print_info "  Total size: $TOTAL_SIZE"
else
    print_warning "No files recovered yet"
fi

echo ""

# Step 2: Kill existing processes
print_info "Step 2: Stopping existing PhotoRec processes..."

# Kill PhotoRec processes
run_on_pi "sudo pkill -f photorec 2>/dev/null || true"
sleep 2

# Kill tmux session
run_on_pi "tmux kill-session -t $TMUX_SESSION 2>/dev/null || true"
sleep 1

# Verify processes are stopped
REMAINING=$(run_on_pi "ps aux | grep -E 'photorec|testdisk' | grep -v grep | wc -l" | tr -d '\r\n')
if [ "$REMAINING" = "0" ]; then
    print_success "All PhotoRec processes stopped"
else
    print_warning "Some processes may still be running"
    run_on_pi "ps aux | grep -E 'photorec|testdisk' | grep -v grep"
fi

echo ""

# Step 3: Verify destination
print_info "Step 3: Verifying recovery destination..."

if ! run_on_pi "test -d $RECOVERY_DEST" 2>/dev/null; then
    print_error "Recovery destination not found: $RECOVERY_DEST"
    print_info "Creating destination..."
    run_on_pi "sudo mkdir -p $RECOVERY_DEST && sudo chmod 777 $RECOVERY_DEST"
fi

# Check free space
FREE_SPACE=$(run_on_pi "df -h $RECOVERY_DEST 2>/dev/null | tail -1 | awk '{print \$4}'" | tr -d '\r\n')
print_info "Free space: $FREE_SPACE"

if [ -z "$FREE_SPACE" ]; then
    print_error "Cannot determine free space"
    exit 1
fi

print_success "Recovery destination ready: $RECOVERY_DEST"
echo ""

# Step 4: Check for session files
print_info "Step 4: Checking for existing session files..."

SESSION_FILES=$(run_on_pi "ls -1 $RECOVERY_DEST/*.ses $RECOVERY_DEST/*.se2 2>/dev/null | wc -l" | tr -d '\r\n')

if [ "$SESSION_FILES" -gt 0 ]; then
    print_success "Found existing session files - PhotoRec will offer to continue"
    run_on_pi "ls -lh $RECOVERY_DEST/*.ses $RECOVERY_DEST/*.se2 2>/dev/null | head -5"
else
    print_info "No session files found - will start fresh recovery"
fi

echo ""

# Step 5: Verify device
print_info "Step 5: Verifying source device..."

if ! run_on_pi "test -b $SOURCE_DEVICE" 2>/dev/null; then
    print_error "Source device not found: $SOURCE_DEVICE"
    print_info "Available devices:"
    run_on_pi "lsblk -o NAME,SIZE,MODEL | grep -v '^loop\|^zram'"
    exit 1
fi

DEVICE_SIZE=$(run_on_pi "lsblk -o NAME,SIZE | grep $(basename $SOURCE_DEVICE) | head -1 | awk '{print \$2}'" | tr -d '\r\n')
print_success "Source device: $SOURCE_DEVICE ($DEVICE_SIZE)"
echo ""

# Step 6: Start PhotoRec
print_info "Step 6: Starting PhotoRec in tmux session..."

run_on_pi "tmux new-session -d -s $TMUX_SESSION"
sleep 1

# Send commands to tmux
run_on_pi "tmux send-keys -t $TMUX_SESSION 'cd $RECOVERY_DEST' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'clear' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"========================================\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"PhotoRec Recovery - Restarted\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"========================================\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"Source: $SOURCE_DEVICE\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"Destination: $RECOVERY_DEST\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"Starting PhotoRec...\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'echo \"\"' C-m"
run_on_pi "tmux send-keys -t $TMUX_SESSION 'sudo photorec $SOURCE_DEVICE' C-m"

print_success "PhotoRec started in tmux session: $TMUX_SESSION"
echo ""

# Step 7: Wait and check status
print_info "Step 7: Waiting for PhotoRec to initialize..."
sleep 5

# Check if PhotoRec is running
PHOTOREC_RUNNING=$(run_on_pi "ps aux | grep photorec | grep -v grep | grep -v sudo | wc -l" | tr -d '\r\n')

if [ "$PHOTOREC_RUNNING" -gt 0 ]; then
    print_success "PhotoRec is running"
else
    print_warning "PhotoRec process not found - may need manual interaction"
fi

echo ""

# Step 8: Instructions
print_header "Next Steps"

echo "1. Connect to PhotoRec session:"
echo "   ssh $PI_USER@$PI_HOST"
echo "   tmux attach -t $TMUX_SESSION"
echo ""
echo "2. In PhotoRec interface:"
if [ "$SESSION_FILES" -gt 0 ]; then
    echo "   - PhotoRec will ask: 'Continue previous session? (Y/N)'"
    echo "   - Press Y to continue from where it left off"
    echo "   - Or press N to start fresh"
else
    echo "   - Select [Proceed]"
    echo "   - Disk: $SOURCE_DEVICE"
    echo "   - Partition: [Whole disk] or [No partition]"
    echo "   - Filesystem: [Other]"
    echo "   - File types: [All] or select specific"
    echo "   - Destination: $RECOVERY_DEST"
    echo "   - Press Y to start"
fi
echo ""
echo "3. Detach from tmux:"
echo "   Press Ctrl+B, then D"
echo "   (Recovery continues in background)"
echo ""
echo "4. Monitor progress:"
echo "   ssh $PI_USER@$PI_HOST 'find $RECOVERY_DEST/recup_dir.* -type f 2>/dev/null | wc -l'"
echo "   ssh $PI_USER@$PI_HOST 'du -sh $RECOVERY_DEST'"
echo ""
print_warning "Recovery will take 8-24 hours. Be patient!"

echo ""
print_info "Current recovery status:"
print_info "  Files: $FILES_RECOVERED"
print_info "  Size: $TOTAL_SIZE"
print_info "  Session: $TMUX_SESSION"

