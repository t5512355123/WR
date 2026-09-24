# F4H PHY status source and schema

Experiment: `EXP-S5-F4H-PHY-STATUS-SOURCE-FIX-RETEST-20260916`

This is a host-observer correction only. The runtime image and all production
control logic remain unchanged.

## Source separation

| Logical field | Interface | Address/instance | Width | Meaning |
|---|---|---:|---:|---|
| `WDIAGS_CTRL_RAW` | WB mailbox | `0x00100A04` (`WRC_DIAGS_CTRL`) | 32 | Diagnostic `DATA_VALID` bit 0 and `DATA_SNAPSHOT` bit 8; not PHY status |
| `PSTAT_RAW` | WB mailbox | `0x00100A0C` (`WDIAG_PSTAT`) | 32 | Port link bit 0 and port locked bit 1; reported independently |
| `PHY_STATUS_PROBE0_RAW` | direct JTAG source probe | instance 0, role-specific `WR_SYNC_MASTER`/`WR_SYNC_SLAVE` | 64 | Physical WR sync status and link background |

The direct probe is the `sync_probe` signal in the selected runtime top:

```text
DE5a_wr_master_jtag.vhd: sync_probe -> WR_SYNC_MASTER, sld_instance_index=0
DE5a_wr_slave_jtag.vhd:  sync_probe -> WR_SYNC_SLAVE,  sld_instance_index=0
```

The F4H reader keeps the complete raw 64-bit value and records the source ID,
role, and host read start/end. It does not convert the raw value through a
decimal string.

## Direct probe bit mapping

The low 16 bits are assigned in the VHDL concatenation with bit 0 as the
rightmost signal:

| Field | Bit | Required by the unchanged PHY gate |
|---|---:|---:|
| `SI_CONFIG_DONE` | 0 | yes |
| `WR_READY` | 1 | yes |
| `CORE_TM_LINK_UP` | 2 | yes |
| `CORE_LINK_OK` | 3 | yes |
| `WR_RX_READY` | 6 | yes |
| `WR_TX_READY` | 7 | yes |
| `CPU_RESET_N` | 15 | no; retained separately |

The required mask is `0x000000CF` (bits 0, 1, 2, 3, 6, and 7). The higher
probe word retains background RX status, including
`WR_RX_LOCKED_TO_DATA` at bit 32 and `WR_RX_LOCKED_TO_REF` at bit 33.

`PHY_LINK_USABLE` is true only when the six required bits are all one and the
direct probe read is valid. A timeout, malformed/short raw value, or missing
source is `UNKNOWN`; it is never converted to zero or one to force a gate.
`PSTAT_LINK` and `PSTAT_LOCKED` are never used to fill missing direct PHY
bits.

## F4H replay invariants

- F4G legacy captures lacking `PHY_STATUS_PROBE0_RAW` are classified
  `PHY_SOURCE_NOT_CAPTURED`; they cannot be backfilled or upgraded.
- `WDIAGS_CTRL_RAW` is never used for PHY gate decoding.
- `WR_CORE_VALID` still requires transport, role identity, reset fields, and
  all required source fields; source correction does not relax those checks.
- Main/Helper CORE, L2 service-counter support intervals, cadence, and the
  10-second correlation rules are unchanged from F4G.
- `STEP5_PASS` and `MERGE_APPROVED` remain false for this 120-second
  diagnostic retest.
