#!/usr/bin/expect -f
# Automated fix using expect to handle SSH password
# Password should be set via environment variable: PI_PASSWORD
# Usage: PI_PASSWORD='your-password' ./fix-sd-card-auto.sh

set timeout 30
set node0_ip "192.168.2.86"
set node0_user "raolivei"
set password [exec sh -c {echo $env(PI_PASSWORD)}]
if {[string length $password] == 0} {
    puts "ERROR: PI_PASSWORD environment variable not set"
    puts "Usage: PI_PASSWORD='your-password' ./fix-sd-card-auto.sh"
    exit 1
}

spawn ssh -o StrictHostKeyChecking=no ${node0_user}@${node0_ip}

expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "Permission denied" {
        puts "ERROR: Authentication failed"
        exit 1
    }
    "$ " {
        # Connected
    }
    "# " {
        # Connected as root
    }
    timeout {
        puts "ERROR: Connection timeout"
        exit 1
    }
}

# Find USB device (sda)
send "lsblk | grep sd\r"
expect "$ "

# Mount root partition
send "sudo mkdir -p /mnt/sd-fix-root\r"
expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "$ " {
    }
}

send "sudo mount /dev/sda2 /mnt/sd-fix-root\r"
expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "$ " {
    }
}

# Backup and fix fstab
send "sudo cp /mnt/sd-fix-root/etc/fstab /mnt/sd-fix-root/etc/fstab.bak.`date +%Y%m%d-%H%M%S`\r"
expect "$ "

send "sudo sed -i 's|defaults 0 2|defaults,nofail 0 2|g' /mnt/sd-fix-root/etc/fstab\r"
expect "$ "

# Show fixed fstab
send "echo '=== Fixed fstab ===' && cat /mnt/sd-fix-root/etc/fstab\r"
expect "$ "

# Unmount
send "sudo umount /mnt/sd-fix-root\r"
expect {
    "password:" {
        send "${password}\r"
        exp_continue
    }
    "$ " {
    }
}

send "exit\r"
expect eof

puts "\n✓ SD card fixed! You can now remove it from node-0 and put it back in node-1."
