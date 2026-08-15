#ifndef __CHEBY__EP_MDIO__H__
#define __CHEBY__EP_MDIO__H__
#define EP_MDIO_SIZE 16384 /* 0x4000 = 16KB */

/* MDIO Control Register */
#define EP_MDIO_MCR 0x0UL
#define EP_MDIO_MCR_RESV_MASK 0x1fUL
#define EP_MDIO_MCR_RESV_SHIFT 0
#define EP_MDIO_MCR_UNI_EN 0x20UL
#define EP_MDIO_MCR_SPEED1000 0x40UL
#define EP_MDIO_MCR_CTST 0x80UL
#define EP_MDIO_MCR_FULLDPLX 0x100UL
#define EP_MDIO_MCR_ANRESTART 0x200UL
#define EP_MDIO_MCR_ISOLATE 0x400UL
#define EP_MDIO_MCR_PDOWN 0x800UL
#define EP_MDIO_MCR_ANENABLE 0x1000UL
#define EP_MDIO_MCR_SPEED100 0x2000UL
#define EP_MDIO_MCR_LOOPBACK 0x4000UL
#define EP_MDIO_MCR_RESET 0x8000UL

/* MDIO Status Register */
#define EP_MDIO_MSR 0x4UL
#define EP_MDIO_MSR_ERCAP 0x1UL
#define EP_MDIO_MSR_JCD 0x2UL
#define EP_MDIO_MSR_LSTATUS 0x4UL
#define EP_MDIO_MSR_ANEGCAPABLE 0x8UL
#define EP_MDIO_MSR_RFAULT 0x10UL
#define EP_MDIO_MSR_ANEGCOMPLETE 0x20UL
#define EP_MDIO_MSR_MFSUPPRESS 0x40UL
#define EP_MDIO_MSR_UNIDIRABLE 0x80UL
#define EP_MDIO_MSR_ESTATEN 0x100UL
#define EP_MDIO_MSR_100HALF2 0x200UL
#define EP_MDIO_MSR_100FULL2 0x400UL
#define EP_MDIO_MSR_10HALF 0x800UL
#define EP_MDIO_MSR_10FULL 0x1000UL
#define EP_MDIO_MSR_100HALF 0x2000UL
#define EP_MDIO_MSR_100FULL 0x4000UL
#define EP_MDIO_MSR_100BASE4 0x8000UL

/* MDIO PHY Identification Register 1 */
#define EP_MDIO_PHYSID1 0x8UL
#define EP_MDIO_PHYSID1_OUI_MASK 0xffffUL
#define EP_MDIO_PHYSID1_OUI_SHIFT 0

/* MDIO PHY Identification Register 2 */
#define EP_MDIO_PHYSID2 0xcUL
#define EP_MDIO_PHYSID2_REV_NUM_MASK 0xfUL
#define EP_MDIO_PHYSID2_REV_NUM_SHIFT 0
#define EP_MDIO_PHYSID2_MMNUM_MASK 0x3f0UL
#define EP_MDIO_PHYSID2_MMNUM_SHIFT 4
#define EP_MDIO_PHYSID2_OUI_MASK 0xfc00UL
#define EP_MDIO_PHYSID2_OUI_SHIFT 10

/* MDIO Auto-Negotiation Advertisement Register */
#define EP_MDIO_ADVERTISE 0x10UL
#define EP_MDIO_ADVERTISE_RSVD3_MASK 0x1fUL
#define EP_MDIO_ADVERTISE_RSVD3_SHIFT 0
#define EP_MDIO_ADVERTISE_FULL 0x20UL
#define EP_MDIO_ADVERTISE_HALF 0x40UL
#define EP_MDIO_ADVERTISE_PAUSE_MASK 0x180UL
#define EP_MDIO_ADVERTISE_PAUSE_SHIFT 7
#define EP_MDIO_ADVERTISE_RSVD2_MASK 0xe00UL
#define EP_MDIO_ADVERTISE_RSVD2_SHIFT 9
#define EP_MDIO_ADVERTISE_RFAULT_MASK 0x3000UL
#define EP_MDIO_ADVERTISE_RFAULT_SHIFT 12
#define EP_MDIO_ADVERTISE_RSVD1 0x4000UL
#define EP_MDIO_ADVERTISE_NPAGE 0x8000UL

/* MDIO Auto-Negotiation Link Partner Ability Register */
#define EP_MDIO_LPA 0x14UL
#define EP_MDIO_LPA_RSVD3_MASK 0x1fUL
#define EP_MDIO_LPA_RSVD3_SHIFT 0
#define EP_MDIO_LPA_FULL 0x20UL
#define EP_MDIO_LPA_HALF 0x40UL
#define EP_MDIO_LPA_PAUSE_MASK 0x180UL
#define EP_MDIO_LPA_PAUSE_SHIFT 7
#define EP_MDIO_LPA_RSVD2_MASK 0xe00UL
#define EP_MDIO_LPA_RSVD2_SHIFT 9
#define EP_MDIO_LPA_RFAULT_MASK 0x3000UL
#define EP_MDIO_LPA_RFAULT_SHIFT 12
#define EP_MDIO_LPA_LPACK 0x4000UL
#define EP_MDIO_LPA_NPAGE 0x8000UL

/* MDIO Auto-Negotiation Expansion Register */
#define EP_MDIO_EXPANSION 0x18UL
#define EP_MDIO_EXPANSION_RSVD1 0x1UL
#define EP_MDIO_EXPANSION_LWCP 0x2UL
#define EP_MDIO_EXPANSION_ENABLENPAGE 0x4UL
#define EP_MDIO_EXPANSION_RSVD2_MASK 0xfff8UL
#define EP_MDIO_EXPANSION_RSVD2_SHIFT 3

/* MDIO Extended Status Register */
#define EP_MDIO_ESTATUS 0x3cUL
#define EP_MDIO_ESTATUS_RSVD1_MASK 0xfffUL
#define EP_MDIO_ESTATUS_RSVD1_SHIFT 0
#define EP_MDIO_ESTATUS_1000_THALF 0x1000UL
#define EP_MDIO_ESTATUS_1000_TFULL 0x2000UL
#define EP_MDIO_ESTATUS_1000_XHALF 0x4000UL
#define EP_MDIO_ESTATUS_1000_XFULL 0x8000UL

/* White Rabbit-specific Configuration Register */
#define EP_MDIO_WR_SPEC 0x40UL
#define EP_MDIO_WR_SPEC_TX_CAL 0x1UL
#define EP_MDIO_WR_SPEC_RX_CAL_STAT 0x2UL
#define EP_MDIO_WR_SPEC_CAL_CRST 0x4UL
#define EP_MDIO_WR_SPEC_BSLIDE_MASK 0x1f0UL
#define EP_MDIO_WR_SPEC_BSLIDE_SHIFT 4

/* MDIO Extended Control Register */
#define EP_MDIO_ECTRL 0x44UL
#define EP_MDIO_ECTRL_LPBCK_VEC_MASK 0x7UL
#define EP_MDIO_ECTRL_LPBCK_VEC_SHIFT 0
#define EP_MDIO_ECTRL_SFP_TX_FAULT 0x8UL
#define EP_MDIO_ECTRL_SFP_LOSS 0x10UL
#define EP_MDIO_ECTRL_SFP_TX_DISABLE 0x20UL
#define EP_MDIO_ECTRL_TX_PRBS_SEL_MASK 0x700UL
#define EP_MDIO_ECTRL_TX_PRBS_SEL_SHIFT 8

/* Custom PHY-specific registers. */
#define EP_MDIO_PHY_SPECIFIC_REGS 0x2000UL
#define ADDR_MASK_EP_MDIO_PHY_SPECIFIC_REGS 0x2000UL
#define EP_MDIO_PHY_SPECIFIC_REGS_SIZE 8192 /* 0x2000 = 8KB */

struct ep_mdio {
  /* [0x0]: REG (rw) MDIO Control Register */
  uint32_t MCR;

  /* [0x4]: REG (ro) MDIO Status Register */
  uint32_t MSR;

  /* [0x8]: REG (ro) MDIO PHY Identification Register 1 */
  uint32_t PHYSID1;

  /* [0xc]: REG (ro) MDIO PHY Identification Register 2 */
  uint32_t PHYSID2;

  /* [0x10]: REG (rw) MDIO Auto-Negotiation Advertisement Register */
  uint32_t ADVERTISE;

  /* [0x14]: REG (ro) MDIO Auto-Negotiation Link Partner Ability Register */
  uint32_t LPA;

  /* [0x18]: REG (ro) MDIO Auto-Negotiation Expansion Register */
  uint32_t EXPANSION;

  /* padding to: 15 words */
  uint32_t __padding_0[8];

  /* [0x3c]: REG (ro) MDIO Extended Status Register */
  uint32_t ESTATUS;

  /* [0x40]: REG (rw) White Rabbit-specific Configuration Register */
  uint32_t WR_SPEC;

  /* [0x44]: REG (rw) MDIO Extended Control Register */
  uint32_t ECTRL;

  /* padding to: 2048 words */
  uint32_t __padding_1[2030];

  /* [0x2000]: SUBMAP Custom PHY-specific registers. */
  uint32_t phy_specific_regs[2048];
};

#endif /* __CHEBY__EP_MDIO__H__ */
