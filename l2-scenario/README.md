# L2 MLAG lab (SONiC Lite)

This folder contains reference **full** `config_db_[MM].json` snapshots for four switches (11–14) and **incremental** `config_db_[N]_mlag.json` overlays (`N`=1…4 mapped to switches 11…14 as in the Files table below) that contain only MLAG-related tables (plus the minimum `FEATURE`, `PORT`, LAG, and VLAN pieces those features depend on).

## Topology

Two MLAG pairs form a diamond between host **A** (dual-homed to the upper pair) and host **B** (dual-homed to the lower pair).

```
              ┌───────────┐
              │  Host A   │
              └─────┬─────┘
          ┌─────────┴─────────┐
   ┌──────┴─────┐       ┌─────┴──────┐
   │ SONiC Lite │───────│ SONiC Lite │
   │      1     │───────│     2      │
   └──────┬─────┘       └─────┬──────┘
          │                   │
   ┌──────┴─────┐       ┌─────┴──────┐
   │ SONiC Lite │───────│ SONiC Lite │
   │      3     │───────│     4      │
   └──────┬─────┘       └─────┬──────┘
          └─────────┬─────────┘
              ┌─────┴─────┐
              │  Host B   │
              └───────────┘
```

**Configuration**

- **Upper pair (switches 11 & 12):** MCLAG domain id `1`, peer keepalive on **Vlan4094** (`10.10.10.0/30`).
- **Lower pair (switches 13 & 14):** MCLAG domain id `2`, peer keepalive on **Vlan4094** (`10.10.20.0/30`).
- **Customer VLAN:** **Vlan10** is carried tagged on the peer **PortChannel1** and untagged on access **PortChannel2** and **PortChannel3** (toward hosts and inter-tier links).

### Port roles (same layout on every switch)

| PortChannel | Member ports   | Role |
|-------------|----------------|------|
| PortChannel1 | Ethernet28, Ethernet32 | MLAG **peer link** between the two switches in the pair |
| PortChannel2 | Ethernet4 | One side of vertical / host attachment (see cabling below) |
| PortChannel3 | Ethernet0 | Other side of vertical / host attachment |

### Intended cabling (matches the diagram above)

| Link | Left | Right |
|------|------|-------|
| Peer link (upper) | 11: Eth28, Eth32 | 12: Eth28, Eth32 (two cables; LACP) |
| Peer link (lower) | 13: Eth28, Eth32 | 14: Eth28, Eth32 |
| Upper cross | 11: PortChannel2 (Eth4) | 13: PortChannel2 (Eth4) |
| Upper cross | 12: PortChannel2 (Eth4) | 14: PortChannel2 (Eth4) |
| Host A | 11: PortChannel3 (Eth0) | A (LACP bond or two legs to one host) |
| Host A | 12: PortChannel3 (Eth0) | A |
| Host B | 13: PortChannel3 (Eth0) | B |
| Host B | 14: PortChannel3 (Eth0) | B |

## Reproducing the setup

1. **Hardware / VM:** Four SONiC nodes (or vSONiC) with interfaces that can match the `PORT` / `PORTCHANNEL_MEMBER` layout, or edit the overlay JSONs so member ports match `show interface status` on your SKU.
2. **Cable** as in the table above (peer links first, then vertical links, then hosts).
3. **Baseline config** on each switch: start from factory or your standard default so `CONFIG_DB` already contains correct `PORT` definitions for your platform. If the default already defines `Ethernet0`, `Ethernet4`, `Ethernet28`, and `Ethernet32`, the overlay mainly updates `admin_status` and adds LAG/MCLAG objects.
4. **Copy** the matching overlay onto each topology node (**1**–**4**).
5. **Load the overlay** (merges into `CONFIG_DB`):

   ```bash
   sudo config load /path/to/config_db_1_mlag.json -y
   ```

   Repeat with `config_db_2_mlag.json` … `config_db_4_mlag.json` on switches **2**–**4** respectively.

6. **Persist and apply** (exact commands depend on image; typical pattern):

   ```bash
   sudo config save -y
   ```

7. **Verify MLAG** on each pair:

   ```bash
   show mclag brief
   show interfaces portchannel
   ```

8. **Hosts:** Place **A** and **B** in the same L2 subnet on **VLAN 10** (e.g. `192.168.10.0/24`). Use an **802.3ad** bond on each host across the two links to PortChannel3 on the pair, or bring up both links in the same VLAN with a single bridge—your OS network stack choice.

---

## Appendix: Host connectivity checks (Linux on A and B)

Assume **Vlan10** is the user L2 domain and you chose **192.168.10.0/24**: host **A** uses **192.168.10.10/24**, host **B** uses **192.168.10.20/24**.

### Bonding

Configure:
```bash
modprobe bonding
```

For debian:
```
auto bond0
iface bond0 inet manual
	bond-slaves eth1 eth2
	bond-mode 802.3ad
	bond-lacp-rate fast
```

### Host A

Configure:
```bash
# Link and VLAN (example: bond across two NICs to the upper pair)
ip -br link show
ip addr show dev bond0

# Addressing
sudo ip addr add 192.168.10.10/24 dev bond0
sudo ip link set bond0 up
```

Verify:
```bash
# LACP partner state (if using bonding)
cat /proc/net/bonding/bond0

# Reachability to B
ping -c 4 192.168.10.20
ip neigh show 192.168.10.20

# Broadcast domain / ARP
arping -I bond0 -c 3 192.168.10.20
```

### Host B

Configure
```bash
ip -br link show
ip addr show dev bond0

sudo ip addr add 192.168.10.20/24 dev bond0
sudo ip link set bond0 up
```

Verify:
```bash
cat /proc/net/bonding/bond0
ping -c 4 192.168.10.10
ip neigh show 192.168.10.10
arping -I bond0 -c 3 192.168.10.10
```

### Quick interpretation

- **`ping` succeeds** end-to-end across both MLAG hops: data plane and VLAN 10 are correct.
- **`ip neigh`** shows **A**’s MAC on **B** (and vice versa): ARP/ND works on the shared VLAN.
- **`/proc/net/bonding/bond0`** (on hosts using LACP) should show **MII Status: up** and an **Aggregator ID** on both slave interfaces when both legs to 11/12 (or 13/14) are healthy.
