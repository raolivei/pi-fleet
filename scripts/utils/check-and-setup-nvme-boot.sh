#!/usr/bin/expect -f
# Check and setup NVMe boot on node-1

set timeout 300
set password "ac0df36b52"
set node1_ip "192.168.2.85"
set user "raolivei"

puts "=== Checking NVMe Boot on node-1 ==="
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

# Check current boot device
send "echo '=== Current Boot Status ==='\r"
expect "$ "

send "df -h / | tail -1\r"
expect "$ "

send "lsblk | grep -E 'nvme|mmc'\r"
expect "$ "

# Check if NVMe boot partition has cmdline.txt
send "test -f /mnt/nvme-boot/cmdline.txt && echo 'NVMe boot partition has cmdline.txt' || echo 'NVMe boot partition missing cmdline.txt'\r"
expect "$ "

send "if [ -f /mnt/nvme-boot/cmdline.txt ]; then echo 'Current cmdline.txt:'; cat /mnt/nvme-boot/cmdline.txt; fi\r"
expect "$ "

# Check fstab on NVMe root
send "test -f /mnt/nvme-root/etc/fstab && echo 'NVMe root has fstab' || echo 'NVMe root missing fstab'\r"
expect "$ "

puts ""
puts "=== Analysis ==="
puts "If node-1 is booting from SD card (mmcblk0) but NVMe has partitions,"
puts "you need to run the NVMe boot setup script."
puts ""
puts "To setup NVMe boot, run on node-1:"
puts "  cd ~/WORKSPACE/raolivei/pi-fleet/scripts/storage"
puts "  sudo ./setup-nvme-boot.sh"
puts ""
puts "This will:"
puts "  1. Clone OS from SD card to NVMe"
puts "  2. Configure boot to use NVMe"
puts "  3. Keep SD card as backup"
puts ""
puts "Boot order (Pi 5 default): SD card first, then NVMe"

send "exit\r"
expect eof

