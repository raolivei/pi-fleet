# Bell Giga Hub Router Information

**Router Details:**
- **Name:** Giga Hub
- **Hardware Version:** 5690-000001-000
- **Firmware Version:** 2.14
- **Rescue Version:** SGC84000C4
- **User Interface Version:** 7.3.28
- **ONT Serial Number:** SMBS038037CF

**Network Information:**
- **LAN MAC:** 78:8D:AF:69:A8:97
- **WAN MAC:** 78:8D:AF:69:A8:8F
- **Router IP:** 192.168.2.1
- **Admin URL:** http://192.168.2.1/?c=advancedtools

**Known Issues:**
- AP Isolation may be enabled by default, blocking Layer 2 communication between Wi-Fi clients
- This prevents MetalLB LoadBalancer IPs (192.168.2.200) from being accessible from Wi-Fi devices

**Documentation:**
- AP Isolation Guide: `scripts/disable-ap-isolation-guide.md`
- Connectivity Test: `scripts/test-metallb-connectivity.sh`
