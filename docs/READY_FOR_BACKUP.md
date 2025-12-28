# Ready for Backup - Status Summary

## ✅ Current Working Configuration

### node-0 (eldertree)

- **Hostname**: `eldertree` / `node-0`
- **wlan0 IP**: `192.168.2.86` (internet access)
- **eth0 IP**: `10.0.0.1/24` (gigabit connection)
- **Internet**: ✅ Working
- **NVMe data**: 95GB at `/mnt/nvme`

### node-1

- **Hostname**: `node-1`
- **wlan0 IP**: `192.168.2.85` (internet access)
- **eth0 IP**: `10.0.0.2/24` (gigabit connection)
- **Internet**: ✅ Working
- **Backup location**: `/mnt/nvme-backup/eldertree-backup` (178GB available)

## ✅ What's Ready

1. ✅ **Gigabit network configured** - Isolated switch with 10.0.0.0/24 subnet
2. ✅ **SSH keys shared** - Passwordless node-to-node communication
3. ✅ **Backup location ready** - node-1 NVMe root partition (178GB available)
4. ✅ **Backup script updated** - Uses eth0 IPs for fast transfer

## Network Configuration

**Isolated Switch Setup:**

- Switch is **not connected to router** - only connects the two Pis
- eth0 uses separate subnet: `10.0.0.0/24`
- wlan0 keeps internet access: `192.168.2.0/24`
- See `docs/GIGABIT_NETWORK_SETUP.md` for full details

## Backup Status

**Current Backup:**

- Source: node-0 `/mnt/nvme` (95GB)
- Destination: node-1 `/mnt/nvme-backup/eldertree-backup`
- Connection: eth0 (10.0.0.1 → 10.0.0.2) via gigabit switch
- Speed: ~110 MB/s
- Status: In progress

**To start backup:**

```bash
cd pi-fleet
./scripts/storage/backup-eldertree-to-node1-nvme.sh
```

**To check backup progress:**

```bash
tail -f /tmp/eldertree-backup.log
```

## Backup Script Details

- **Script**: `pi-fleet/scripts/storage/backup-eldertree-to-node1-nvme.sh`
- **Destination**: `node-1:/mnt/nvme-backup/eldertree-backup/`
- **Method**: rsync over SSH via eth0 (gigabit)
- **SSH access**: Uses wlan0 IPs (192.168.2.86/192.168.2.85)
- **Data transfer**: Uses eth0 IPs (10.0.0.1/10.0.0.2)

## Network Configuration

**Working Solution:**

- Isolated switch with separate subnet (10.0.0.0/24)
- Static IPs on eth0 are safe because switch isn't connected to router
- No gateway or DNS on eth0 - preserves internet via wlan0
- See `docs/GIGABIT_NETWORK_SETUP.md` for complete details

## Verification Checklist

Once node-0 is online:

- [ ] node-0 SSH access works
- [ ] node-0 internet connectivity works
- [ ] Get node-0 eth0 MAC address
- [ ] Configure router DHCP reservations
- [ ] Verify node-to-node connectivity (ping between 192.168.2.83 and 192.168.2.85)
- [ ] Check node-0 NVMe data size: `du -sh /mnt/nvme`
- [ ] Start backup process
