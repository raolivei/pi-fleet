#!/usr/bin/expect -f
# Configure NVMe boot on node-1
# Check if NVMe is already set up for boot, if not, set it up
# Password should be set via environment variable: PI_PASSWORD
# Usage: PI_PASSWORD='your-password' ./configure-nvme-boot-node1.sh

set timeout 300
set password [exec sh -c {echo $env(PI_PASSWORD)}]
if {[string length $password] == 0} {
    puts "ERROR: PI_PASSWORD environment variable not set"
    puts "Usage: PI_PASSWORD='your-password' ./configure-nvme-boot-node1.sh"
    exit 1
}
set node1_ip "192.168.2.85"
set user "raolivei"

puts "=== Configuring NVMe Boot on node-1 ==="
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

# Check current setup
send "echo '=== Checking NVMe Boot Setup ==='\r"
expect "$ "

send "lsblk | grep -E 'nvme|mmc'\r"
expect "$ "

# Check if NVMe has boot and root partitions
send "if [ -b /dev/nvme0n1p1 ] && [ -b /dev/nvme0n1p2 ]; then echo 'NVMe has boot and root partitions'; else echo 'NVMe needs setup'; fi\r"
expect "$ "

# Check current boot device
send "df -h / | tail -1\r"
expect "$ "

# Check if boot partition on NVMe has boot files
send "sudo mount /dev/nvme0n1p1 /mnt/nvme-boot-check 2>/dev/null && ls /mnt/nvme-boot-check/cmdline.txt 2>/dev/null && echo 'Boot partition has cmdline.txt' || echo 'Boot partition check failed'\r"
expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "$ " {
    }
}

# Check cmdline.txt on NVMe boot partition
send "if [ -f /mnt/nvme-boot-check/cmdline.txt ]; then echo 'cmdline.txt content:'; cat /mnt/nvme-boot-check/cmdline.txt; sudo umount /mnt/nvme-boot-check 2>/dev/null; fi\r"
expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "$ " {
    }
}

# Check if we're already booting from NVMe
send "ROOT_DEV=\$(df -h / | tail -1 | awk '{print \\\$1}'); if echo \\\$ROOT_DEV | grep -q nvme; then echo 'Already booting from NVMe: '\\\$ROOT_DEV; else echo 'Booting from: '\\\$ROOT_DEV ' (not NVMe)'; fi\r"
expect "$ "

puts ""
puts "If NVMe is not set up for boot, you'll need to run:"
puts "  cd ~/WORKSPACE/raolivei/pi-fleet/scripts/storage"
puts "  sudo ./setup-nvme-boot.sh"
puts ""
puts "This will clone the OS from SD card to NVMe and configure boot."

send "exit\r"
expect eof
