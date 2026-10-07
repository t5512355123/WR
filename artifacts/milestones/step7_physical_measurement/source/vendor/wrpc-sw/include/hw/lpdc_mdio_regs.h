#ifndef __CHEBY__LPDC_MDIO__H__
#define __CHEBY__LPDC_MDIO__H__
#define LPDC_MDIO_SIZE 8192 /* 0x2000 = 8KB */

/* Low Phase Drift Calibration Control Register */
#define LPDC_MDIO_CTRL 0x0UL
#define LPDC_MDIO_CTRL_TX_SW_RESET 0x1UL
#define LPDC_MDIO_CTRL_TX_ENABLE 0x2UL
#define LPDC_MDIO_CTRL_RX_ENABLE 0x4UL
#define LPDC_MDIO_CTRL_RX_SW_RESET 0x8UL
#define LPDC_MDIO_CTRL_PLL_SW_RESET 0x10UL
#define LPDC_MDIO_CTRL_AUX_RESET 0x20UL
#define LPDC_MDIO_CTRL_COMMA_TARGET_POS_MASK 0x3fc0UL
#define LPDC_MDIO_CTRL_COMMA_TARGET_POS_SHIFT 6
#define LPDC_MDIO_CTRL_DMTD_CLK_SEL_MASK 0xc000UL
#define LPDC_MDIO_CTRL_DMTD_CLK_SEL_SHIFT 14

/* Low Phase Drift Calibration Status Register */
#define LPDC_MDIO_STAT 0x4UL
#define LPDC_MDIO_STAT_PLL_LOCKED 0x1UL
#define LPDC_MDIO_STAT_LINK_UP 0x2UL
#define LPDC_MDIO_STAT_LINK_ALIGNED 0x4UL
#define LPDC_MDIO_STAT_TX_RST_DONE 0x8UL
#define LPDC_MDIO_STAT_TXUSRPLL_LOCKED 0x10UL
#define LPDC_MDIO_STAT_RX_RST_DONE 0x20UL
#define LPDC_MDIO_STAT_COMMA_CURRENT_POS_MASK 0x7f80UL
#define LPDC_MDIO_STAT_COMMA_CURRENT_POS_SHIFT 7
#define LPDC_MDIO_STAT_COMMA_POS_VALID 0x8000UL

/* Low Phase Drift Calibration Control Register 2 */
#define LPDC_MDIO_CTRL2 0x8UL
#define LPDC_MDIO_CTRL2_RX_RATE_MASK 0x7UL
#define LPDC_MDIO_CTRL2_RX_RATE_SHIFT 0
#define LPDC_MDIO_CTRL2_RX_LATCH_PATTERN 0x8UL
#define LPDC_MDIO_CTRL2_RX_GEARBOX_PLL_RESET 0x10UL
#define LPDC_MDIO_CTRL2_RX_GEARBOX_PLL_LOCKED 0x20UL
#define LPDC_MDIO_CTRL2_RX_CDR_LOCKED 0x40UL

/* None */
#define LPDC_MDIO_IDLE_PAT 0x40UL
#define LPDC_MDIO_IDLE_PAT_SIZE 4 /* 0x4 */

/* None */
#define LPDC_MDIO_IDLE_PAT_DATA 0x0UL

/* Xilinx DRP registers, specific to the transceiver */
#define LPDC_MDIO_DRP_REGS 0x1000UL
#define ADDR_MASK_LPDC_MDIO_DRP_REGS 0x1000UL
#define LPDC_MDIO_DRP_REGS_SIZE 4096 /* 0x1000 = 4KB */

#ifndef __ASSEMBLER__
struct lpdc_mdio {
  /* [0x0]: REG (rw) Low Phase Drift Calibration Control Register */
  uint32_t CTRL;

  /* [0x4]: REG (ro) Low Phase Drift Calibration Status Register */
  uint32_t STAT;

  /* [0x8]: REG (rw) Low Phase Drift Calibration Control Register 2 */
  uint32_t CTRL2;

  /* padding to: 16 words */
  uint32_t __padding_0[13];

  /* [0x40]: REPEAT (no description) */
  struct idle_pat {
    /* [0x0]: REG (ro) (no description) */
    uint32_t data;
  } idle_pat[12];

  /* padding to: 16 words */
  uint32_t __padding_1[4];

  /* padding to: 1024 words */
  uint32_t __padding_2[992];

  /* [0x1000]: SUBMAP Xilinx DRP registers, specific to the transceiver */
  uint32_t drp_regs[1024];
};
#endif /* !__ASSEMBLER__*/

#endif /* __CHEBY__LPDC_MDIO__H__ */
