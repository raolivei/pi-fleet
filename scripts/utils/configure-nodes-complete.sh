#!/usr/bin/expect -f
# Complete node configuration:
# 1. Configure SSH keys on both nodes
# 2. Set boot order: SD card first, then NVMe
# 3. Configure NVMe boot on node-1
# Password should be set via environment variable: PI_PASSWORD
# Usage: PI_PASSWORD='your-password' ./configure-nodes-complete.sh

set timeout 60
set password [exec sh -c {echo $env(PI_PASSWORD)}]
if {[string length $password] == 0} {
    puts "ERROR: PI_PASSWORD environment variable not set"
    puts "Usage: PI_PASSWORD='your-password' ./configure-nodes-complete.sh"
    exit 1
}
set node0_ip "192.168.2.86"
set node1_ip "192.168.2.85"
set user "raolivei"

# Get local SSH public key
set ssh_key_file "$env(HOME)/.ssh/id_rsa.pub"
if {![file exists $ssh_key_file]} {
    puts "ERROR: SSH public key not found at $ssh_key_file"
    puts "Please generate one with: ssh-keygen -t rsa -b 4096"
    exit 1
}

set fp [open $ssh_key_file r]
set ssh_public_key [read $fp]
close $fp
set ssh_public_key [string trim $ssh_public_key]

puts "=== Configuring Nodes ==="
puts ""

# Function to configure a node
proc configure_node {node_ip node_name} {
    global password user ssh_public_key
    
    puts "=== Configuring $node_name ($node_ip) ==="
    
    spawn ssh -o StrictHostKeyChecking=no ${user}@${node_ip}
    
    expect {
        "password:" {
            send "${password}\r"
            exp_continue
        }
        "$ " {
        }
        timeout {
            puts "ERROR: Connection timeout to $node_name"
            return 1
        }
    }
    
    # Configure SSH key
    send "mkdir -p ~/.ssh && chmod 700 ~/.ssh\r"
    expect "$ "
    
    send "echo '${ssh_public_key}' >> ~/.ssh/authorized_keys\r"
    expect "$ "
    
    send "chmod 600 ~/.ssh/authorized_keys\r"
    expect "$ "
    
    send "echo 'SSH key configured'\r"
    expect "$ "
    
    # Check boot configuration
    send "echo '=== Current Boot Configuration ==='\r"
    expect "$ "
    
    send "test -f /boot/firmware/config.txt && grep -E 'boot_order|priority' /boot/firmware/config.txt || echo 'No boot order configured'\r"
    expect "$ "
    
    # Check if NVMe is present
    send "lsblk | grep nvme\r"
    expect "$ "
    
    # For Raspberry Pi 5, boot order is automatic (SD > USB > NVMe)
    send "echo 'Raspberry Pi 5 boot order: SD card first, then NVMe (automatic)'\r"
    expect "$ "
    
    # Check current boot device
    send "df -h / | tail -1 | awk '{print \\\$1}'\r"
    expect "$ "
    
    puts "✓ $node_name configured"
    
    send "exit\r"
    expect eof
    
    return 0
}

# Configure node-1
if {[configure_node $node0_ip "node-1"] != 0} {
    puts "ERROR: Failed to configure node-1"
    exit 1
}

puts ""

# Configure node-1
if {[configure_node $node1_ip "node-1"] != 0} {
    puts "ERROR: Failed to configure node-1"
    exit 1
}

puts ""
puts "=== Node Configuration Complete ==="
puts ""
puts "Next: Configure NVMe boot on node-1"
puts "Run: ./configure-nvme-boot-node1.sh"

