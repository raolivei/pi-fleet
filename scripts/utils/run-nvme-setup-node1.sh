#!/usr/bin/expect -f
# Run NVMe boot setup on node-1

set timeout 3600
set password "ac0df36b52"
set node1_ip "192.168.2.85"
set user "raolivei"

puts "=== Running NVMe Boot Setup on node-1 ==="
puts "This will take 10-30 minutes..."
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

# Run the setup script
send "cd ~/WORKSPACE/raolivei/pi-fleet/scripts/storage && sudo ./setup-nvme-boot.sh\r"

# Handle interactive prompts
expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "Continue?" {
        send "y\r"
        exp_continue
    }
    "y/N" {
        send "y\r"
        exp_continue
    }
    "Have you backed up" {
        send "y\r"
        exp_continue
    }
    "This will erase" {
        send "y\r"
        exp_continue
    }
    "Ready to reboot" {
        puts "\n✓ Setup complete!"
        puts "The system is ready to reboot and boot from NVMe."
        break
    }
    "Setup Complete" {
        puts "\n✓ Setup complete!"
        break
    }
    timeout {
        puts "\nSetup is running (this takes 10-30 minutes)..."
        puts "You can check progress by SSHing to node-1"
        exp_continue
    }
    eof {
        puts "\nSetup completed or connection closed"
    }
}

send "exit\r"
expect eof

puts ""
puts "=== Next Steps ==="
puts "1. SSH to node-1: ssh raolivei@192.168.2.85"
puts "2. Reboot: sudo reboot"
puts "3. After reboot, verify: df -h / (should show nvme0n1p2)"

