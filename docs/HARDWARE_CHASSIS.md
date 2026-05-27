# ElderTree physical chassis

Cluster **software and operations** are documented in this repo. **Mechanical CAD** (OpenSCAD, prints, assembly) lives in [**eldertree-chassis**](https://github.com/raolivei/eldertree-chassis).

## Hardware summary

| Layer | Component |
|-------|-----------|
| Base | EcoFlow River 3 (UPS / portable AC) |
| Network | TP-Link TL-SG1008MP (8-port PoE+) |
| Compute | 3× Raspberry Pi 5 (8GB), NVMe boot, M.2 NVMe M-key & PoE+ HAT |
| Cooling | Open-frame airflow; 120 mm top exhaust; HAT fans (Ansible `poe_fan_temp*`) |

**Power path:** River 3 AC → switch → PoE+ to each Pi.

**Cluster network:** eth0 on isolated `10.0.0.0/24` via switch ([GIGABIT_NETWORK_SETUP.md](GIGABIT_NETWORK_SETUP.md)); wlan0 on `192.168.2.101–103`.

## Documentation map

| Topic | Location |
|-------|----------|
| Dimensions, BOM, prints | [eldertree-chassis/docs/](https://github.com/raolivei/eldertree-chassis/tree/main/docs) |
| Parametric source | [config.scad](https://github.com/raolivei/eldertree-chassis/blob/main/cad/openscad/config.scad) |
| Assembly / power-on | [assembly.md](https://github.com/raolivei/eldertree-chassis/blob/main/docs/assembly.md) |
| Runbook (physical) | [eldertree-docs runbook](https://docs.eldertree.xyz/runbook/hardware/chassis) |

## Cluster switch

The eldertree **eth0** fabric uses an isolated **TP-Link TL-SG1008MP** (PoE+, 153 W budget). Older pi-fleet docs referenced a non-PoE **SG105** during bring-up; treat SG1008MP as current for chassis and eth0 cabling.
