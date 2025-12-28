#!/usr/bin/expect -f
# Run NVMe boot setup on node-1 in background with nohup
# Password should be set via environment variable: PI_PASSWORD
# Usage: PI_PASSWORD='your-password' ./run-nvme-setup-background.sh

set timeout 30
set password [exec sh -c {echo $env(PI_PASSWORD)}]
if {[string length $password] == 0} {
    puts "ERROR: PI_PASSWORD environment variable not set"
    puts "Usage: PI_PASSWORD='your-password' ./run-nvme-setup-background.sh"
    exit 1
}
set node1_ip "192.168.2.85"
set user "raolivei"

puts "=== Starting NVMe Boot Setup on node-1 ==="
puts "This will run in the background and take 10-30 minutes..."
puts ""

spawn ssh -o StrictHostKeyChecking=no ${user}@${node1_ip}

expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "$ " {
    }
    timeout {
        puts "ERROR: Connection timeout"
        exit 1
    }
}

# Start setup in background with nohup and log output
send "cd ~/WORKSPACE/raolivei/pi-fleet/scripts/storage && nohup sudo ./setup-nvme-boot.sh < /dev/null > /tmp/nvme-setup.log 2>&1 &\r"
expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "$ " {
    }
}

# Get the process ID
send "echo \\\$!\r"
expect "$ "

send "sleep 2\r"
expect "$ "

# Check if it's running
send "ps aux | grep setup-nvme-boot | grep -v grep || echo 'Process not found'\r"
expect "$ "

puts ""
puts "✓ Setup started in background"
puts ""
puts "To monitor progress:"
puts "  ssh raolivei@192.168.2.85"
puts "  tail -f /tmp/nvme-setup.log"
puts ""
puts "To check if still running:"
puts "  ps aux | grep setup-nvme-boot"
puts ""
puts "The setup will:"
puts "  1. Clone OS from SD card to NVMe (10-30 minutes)"
puts "  2. Configure boot to use NVMe"
puts "  3. Keep SD card as backup"
puts ""
puts "After completion, reboot node-1:"
puts "  ssh raolivei@192.168.2.85"
puts "  sudo reboot"

send "exit\r"
expect eof

