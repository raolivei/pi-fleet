#!/usr/bin/expect -f
# Run NVMe boot setup with automatic confirmation

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

# Run setup with automatic yes to all prompts
send "cd ~ && echo 'y' | sudo ./setup-nvme-boot.sh 2>&1 | tee /tmp/nvme-setup.log\r"

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
        break
    }
    "Setup Complete" {
        puts "\n✓ Setup complete!"
        break
    }
    timeout {
        puts "\nSetup is running... (this takes 10-30 minutes)"
        puts "Monitor progress: ssh raolivei@192.168.2.85 'tail -f /tmp/nvme-setup.log'"
        exp_continue
    }
    eof {
        puts "\nSetup process completed"
    }
}

send "exit\r"
expect eof

puts ""
puts "=== Next Steps ==="
puts "1. Check log: ssh raolivei@192.168.2.85 'tail -f /tmp/nvme-setup.log'"
puts "2. When complete, reboot: ssh raolivei@192.168.2.85 'sudo reboot'"
puts "3. After reboot, verify: ssh raolivei@192.168.2.85 'df -h /'"

