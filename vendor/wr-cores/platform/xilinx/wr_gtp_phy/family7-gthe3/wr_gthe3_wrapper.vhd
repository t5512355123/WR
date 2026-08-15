library ieee;
use ieee.std_logic_1164.all;

entity wr_gthe3_wrapper is
  port (
    CPLLPD               : in  std_logic;
    CPLLLOCK             : out std_logic;

    RXCDRLOCK            : out std_logic;
    RXRESETDONE          : out std_logic;
    GTRXRESET            : in  std_logic;
    RXPROGDIVRESET       : in  std_logic;

    GTTXRESET            : in  std_logic;
    TXRESETDONE          : out std_logic;
    TXPROGDIVRESET       : in  std_logic;

    RXPCSRESET : in std_logic;

    
      GTHTXN               : out std_logic;
      GTHTXP               : out std_logic;
      GTPOWERGOOD          : out std_logic;
      RXBYTEISALIGNED      : out std_logic;
      RXCOMMADET           : out std_logic;
      RXCTRL0              : out std_logic_vector(15 downto 0);
      RXCTRL1              : out std_logic_vector(15 downto 0);
      RXCTRL2              : out std_logic_vector(7 downto 0);
      RXCTRL3              : out std_logic_vector(7 downto 0);
      RXDATA               : out std_logic_vector(127 downto 0);
      RXOUTCLK             : out std_logic;
      RXPHALIGNDONE        : out std_logic;
      RXPMARESETDONE       : out std_logic;
      RXSYNCDONE           : out std_logic;
      
      TXOUTCLK             : out std_logic;
      TXPHALIGNDONE        : out std_logic;
      TXPMARESETDONE       : out std_logic;
      TXSYNCDONE           : out std_logic;
      RXDLYSRESET : in std_logic;
      DRPCLK               : in  std_logic;
      GTHRXN               : in  std_logic;
      GTHRXP               : in  std_logic;
      GTREFCLK0            : in  std_logic;
      RXSLIDE              : in  std_logic;
      RXSYNCALLIN          : in  std_logic;
      RXUSERRDY            : in  std_logic;
      RXUSRCLK2            : in  std_logic;
      TXCTRL2              : in  std_logic_vector(7 downto 0);
      TXDATA               : in  std_logic_vector(127 downto 0);
      TXDLYSRESET          : in  std_logic;
      TXSYNCALLIN          : in  std_logic;
      TXUSERRDY            : in  std_logic;
      TXUSRCLK2            : in  std_logic
    );
end wr_gthe3_wrapper;

architecture rtl of wr_gthe3_wrapper is

  component GTHE3_CHANNEL is
    generic (
      ACJTAG_DEBUG_MODE            : bit;
      ACJTAG_MODE                  : bit;
      ACJTAG_RESET                 : bit;
      ADAPT_CFG0                   : std_logic_vector(15 downto 0);
      ADAPT_CFG1                   : std_logic_vector(15 downto 0);
      ALIGN_COMMA_DOUBLE           : string;
      ALIGN_COMMA_ENABLE           : std_logic_vector(9 downto 0);
      ALIGN_COMMA_WORD             : integer;
      ALIGN_MCOMMA_DET             : string;
      ALIGN_MCOMMA_VALUE           : std_logic_vector(9 downto 0);
      ALIGN_PCOMMA_DET             : string;
      ALIGN_PCOMMA_VALUE           : std_logic_vector(9 downto 0);
      A_RXOSCALRESET               : bit;
      A_RXPROGDIVRESET             : bit;
      A_TXPROGDIVRESET             : bit;
      CBCC_DATA_SOURCE_SEL         : string;
      CDR_SWAP_MODE_EN             : bit;
      CHAN_BOND_KEEP_ALIGN         : string;
      CHAN_BOND_MAX_SKEW           : integer;
      CHAN_BOND_SEQ_1_1            : std_logic_vector(9 downto 0);
      CHAN_BOND_SEQ_1_2            : std_logic_vector(9 downto 0);
      CHAN_BOND_SEQ_1_3            : std_logic_vector(9 downto 0);
      CHAN_BOND_SEQ_1_4            : std_logic_vector(9 downto 0);
      CHAN_BOND_SEQ_1_ENABLE       : std_logic_vector(3 downto 0);
      CHAN_BOND_SEQ_2_1            : std_logic_vector(9 downto 0);
      CHAN_BOND_SEQ_2_2            : std_logic_vector(9 downto 0);
      CHAN_BOND_SEQ_2_3            : std_logic_vector(9 downto 0);
      CHAN_BOND_SEQ_2_4            : std_logic_vector(9 downto 0);
      CHAN_BOND_SEQ_2_ENABLE       : std_logic_vector(3 downto 0);
      CHAN_BOND_SEQ_2_USE          : string;
      CHAN_BOND_SEQ_LEN            : integer;
      CLK_CORRECT_USE              : string;
      CLK_COR_KEEP_IDLE            : string;
      CLK_COR_MAX_LAT              : integer;
      CLK_COR_MIN_LAT              : integer;
      CLK_COR_PRECEDENCE           : string;
      CLK_COR_REPEAT_WAIT          : integer;
      CLK_COR_SEQ_1_1              : std_logic_vector(9 downto 0);
      CLK_COR_SEQ_1_2              : std_logic_vector(9 downto 0);
      CLK_COR_SEQ_1_3              : std_logic_vector(9 downto 0);
      CLK_COR_SEQ_1_4              : std_logic_vector(9 downto 0);
      CLK_COR_SEQ_1_ENABLE         : std_logic_vector(3 downto 0);
      CLK_COR_SEQ_2_1              : std_logic_vector(9 downto 0);
      CLK_COR_SEQ_2_2              : std_logic_vector(9 downto 0);
      CLK_COR_SEQ_2_3              : std_logic_vector(9 downto 0);
      CLK_COR_SEQ_2_4              : std_logic_vector(9 downto 0);
      CLK_COR_SEQ_2_ENABLE         : std_logic_vector(3 downto 0);
      CLK_COR_SEQ_2_USE            : string;
      CLK_COR_SEQ_LEN              : integer;
      CPLL_CFG0                    : std_logic_vector(15 downto 0);
      CPLL_CFG1                    : std_logic_vector(15 downto 0);
      CPLL_CFG2                    : std_logic_vector(15 downto 0);
      CPLL_CFG3                    : std_logic_vector(5 downto 0);
      CPLL_FBDIV                   : integer;
      CPLL_FBDIV_45                : integer;
      CPLL_INIT_CFG0               : std_logic_vector(15 downto 0);
      CPLL_INIT_CFG1               : std_logic_vector(7 downto 0);
      CPLL_LOCK_CFG                : std_logic_vector(15 downto 0);
      CPLL_REFCLK_DIV              : integer;
      DDI_CTRL                     : std_logic_vector(1 downto 0);
      DDI_REALIGN_WAIT             : integer;
      DEC_MCOMMA_DETECT            : string;
      DEC_PCOMMA_DETECT            : string;
      DEC_VALID_COMMA_ONLY         : string;
      DFE_D_X_REL_POS              : bit;
      DFE_VCM_COMP_EN              : bit;
      DMONITOR_CFG0                : std_logic_vector(9 downto 0);
      DMONITOR_CFG1                : std_logic_vector(7 downto 0);
      ES_CLK_PHASE_SEL             : bit;
      ES_CONTROL                   : std_logic_vector(5 downto 0);
      ES_ERRDET_EN                 : string;
      ES_EYE_SCAN_EN               : string;
      ES_HORZ_OFFSET               : std_logic_vector(11 downto 0);
      ES_PMA_CFG                   : std_logic_vector(9 downto 0);
      ES_PRESCALE                  : std_logic_vector(4 downto 0);
      ES_QUALIFIER0                : std_logic_vector(15 downto 0);
      ES_QUALIFIER1                : std_logic_vector(15 downto 0);
      ES_QUALIFIER2                : std_logic_vector(15 downto 0);
      ES_QUALIFIER3                : std_logic_vector(15 downto 0);
      ES_QUALIFIER4                : std_logic_vector(15 downto 0);
      ES_QUAL_MASK0                : std_logic_vector(15 downto 0);
      ES_QUAL_MASK1                : std_logic_vector(15 downto 0);
      ES_QUAL_MASK2                : std_logic_vector(15 downto 0);
      ES_QUAL_MASK3                : std_logic_vector(15 downto 0);
      ES_QUAL_MASK4                : std_logic_vector(15 downto 0);
      ES_SDATA_MASK0               : std_logic_vector(15 downto 0);
      ES_SDATA_MASK1               : std_logic_vector(15 downto 0);
      ES_SDATA_MASK2               : std_logic_vector(15 downto 0);
      ES_SDATA_MASK3               : std_logic_vector(15 downto 0);
      ES_SDATA_MASK4               : std_logic_vector(15 downto 0);
      EVODD_PHI_CFG                : std_logic_vector(10 downto 0);
      EYE_SCAN_SWAP_EN             : bit;
      FTS_DESKEW_SEQ_ENABLE        : std_logic_vector(3 downto 0);
      FTS_LANE_DESKEW_CFG          : std_logic_vector(3 downto 0);
      FTS_LANE_DESKEW_EN           : string;
      GEARBOX_MODE                 : std_logic_vector(4 downto 0);
      GM_BIAS_SELECT               : bit;
      LOCAL_MASTER                 : bit;
      OOBDIVCTL                    : std_logic_vector(1 downto 0);
      OOB_PWRUP                    : bit;
      PCI3_AUTO_REALIGN            : string;
      PCI3_PIPE_RX_ELECIDLE        : bit;
      PCI3_RX_ASYNC_EBUF_BYPASS    : std_logic_vector(1 downto 0);
      PCI3_RX_ELECIDLE_EI2_ENABLE  : bit;
      PCI3_RX_ELECIDLE_H2L_COUNT   : std_logic_vector(5 downto 0);
      PCI3_RX_ELECIDLE_H2L_DISABLE : std_logic_vector(2 downto 0);
      PCI3_RX_ELECIDLE_HI_COUNT    : std_logic_vector(5 downto 0);
      PCI3_RX_ELECIDLE_LP4_DISABLE : bit;
      PCI3_RX_FIFO_DISABLE         : bit;
      PCIE_BUFG_DIV_CTRL           : std_logic_vector(15 downto 0);
      PCIE_RXPCS_CFG_GEN3          : std_logic_vector(15 downto 0);
      PCIE_RXPMA_CFG               : std_logic_vector(15 downto 0);
      PCIE_TXPCS_CFG_GEN3          : std_logic_vector(15 downto 0);
      PCIE_TXPMA_CFG               : std_logic_vector(15 downto 0);
      PCS_PCIE_EN                  : string;
      PCS_RSVD0                    : std_logic_vector(15 downto 0);
      PCS_RSVD1                    : std_logic_vector(2 downto 0);
      PD_TRANS_TIME_FROM_P2        : std_logic_vector(11 downto 0);
      PD_TRANS_TIME_NONE_P2        : std_logic_vector(7 downto 0);
      PD_TRANS_TIME_TO_P2          : std_logic_vector(7 downto 0);
      PLL_SEL_MODE_GEN12           : std_logic_vector(1 downto 0);
      PLL_SEL_MODE_GEN3            : std_logic_vector(1 downto 0);
      PMA_RSV1                     : std_logic_vector(15 downto 0);
      PROCESS_PAR                  : std_logic_vector(2 downto 0);
      RATE_SW_USE_DRP              : bit;
      RESET_POWERSAVE_DISABLE      : bit;
      RXBUFRESET_TIME              : std_logic_vector(4 downto 0);
      RXBUF_ADDR_MODE              : string;
      RXBUF_EIDLE_HI_CNT           : std_logic_vector(3 downto 0);
      RXBUF_EIDLE_LO_CNT           : std_logic_vector(3 downto 0);
      RXBUF_EN                     : string;
      RXBUF_RESET_ON_CB_CHANGE     : string;
      RXBUF_RESET_ON_COMMAALIGN    : string;
      RXBUF_RESET_ON_EIDLE         : string;
      RXBUF_RESET_ON_RATE_CHANGE   : string;
      RXBUF_THRESH_OVFLW           : integer;
      RXBUF_THRESH_OVRD            : string;
      RXBUF_THRESH_UNDFLW          : integer;
      RXCDRFREQRESET_TIME          : std_logic_vector(4 downto 0);
      RXCDRPHRESET_TIME            : std_logic_vector(4 downto 0);
      RXCDR_CFG0                   : std_logic_vector(15 downto 0);
      RXCDR_CFG0_GEN3              : std_logic_vector(15 downto 0);
      RXCDR_CFG1                   : std_logic_vector(15 downto 0);
      RXCDR_CFG1_GEN3              : std_logic_vector(15 downto 0);
      RXCDR_CFG2                   : std_logic_vector(15 downto 0);
      RXCDR_CFG2_GEN3              : std_logic_vector(15 downto 0);
      RXCDR_CFG3                   : std_logic_vector(15 downto 0);
      RXCDR_CFG3_GEN3              : std_logic_vector(15 downto 0);
      RXCDR_CFG4                   : std_logic_vector(15 downto 0);
      RXCDR_CFG4_GEN3              : std_logic_vector(15 downto 0);
      RXCDR_CFG5                   : std_logic_vector(15 downto 0);
      RXCDR_CFG5_GEN3              : std_logic_vector(15 downto 0);
      RXCDR_FR_RESET_ON_EIDLE      : bit;
      RXCDR_HOLD_DURING_EIDLE      : bit;
      RXCDR_LOCK_CFG0              : std_logic_vector(15 downto 0);
      RXCDR_LOCK_CFG1              : std_logic_vector(15 downto 0);
      RXCDR_LOCK_CFG2              : std_logic_vector(15 downto 0);
      RXCDR_PH_RESET_ON_EIDLE      : bit;
      RXCFOK_CFG0                  : std_logic_vector(15 downto 0);
      RXCFOK_CFG1                  : std_logic_vector(15 downto 0);
      RXCFOK_CFG2                  : std_logic_vector(15 downto 0);
      RXDFELPMRESET_TIME           : std_logic_vector(6 downto 0);
      RXDFELPM_KL_CFG0             : std_logic_vector(15 downto 0);
      RXDFELPM_KL_CFG1             : std_logic_vector(15 downto 0);
      RXDFELPM_KL_CFG2             : std_logic_vector(15 downto 0);
      RXDFE_CFG0                   : std_logic_vector(15 downto 0);
      RXDFE_CFG1                   : std_logic_vector(15 downto 0);
      RXDFE_GC_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_GC_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_GC_CFG2                : std_logic_vector(15 downto 0);
      RXDFE_H2_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_H2_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_H3_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_H3_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_H4_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_H4_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_H5_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_H5_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_H6_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_H6_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_H7_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_H7_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_H8_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_H8_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_H9_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_H9_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_HA_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_HA_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_HB_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_HB_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_HC_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_HC_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_HD_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_HD_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_HE_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_HE_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_HF_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_HF_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_OS_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_OS_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_UT_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_UT_CFG1                : std_logic_vector(15 downto 0);
      RXDFE_VP_CFG0                : std_logic_vector(15 downto 0);
      RXDFE_VP_CFG1                : std_logic_vector(15 downto 0);
      RXDLY_CFG                    : std_logic_vector(15 downto 0);
      RXDLY_LCFG                   : std_logic_vector(15 downto 0);
      RXELECIDLE_CFG               : string;
      RXGBOX_FIFO_INIT_RD_ADDR     : integer;
      RXGEARBOX_EN                 : string;
      RXISCANRESET_TIME            : std_logic_vector(4 downto 0);
      RXLPM_CFG                    : std_logic_vector(15 downto 0);
      RXLPM_GC_CFG                 : std_logic_vector(15 downto 0);
      RXLPM_KH_CFG0                : std_logic_vector(15 downto 0);
      RXLPM_KH_CFG1                : std_logic_vector(15 downto 0);
      RXLPM_OS_CFG0                : std_logic_vector(15 downto 0);
      RXLPM_OS_CFG1                : std_logic_vector(15 downto 0);
      RXOOB_CFG                    : std_logic_vector(8 downto 0);
      RXOOB_CLK_CFG                : string;
      RXOSCALRESET_TIME            : std_logic_vector(4 downto 0);
      RXOUT_DIV                    : integer;
      RXPCSRESET_TIME              : std_logic_vector(4 downto 0);
      RXPHBEACON_CFG               : std_logic_vector(15 downto 0);
      RXPHDLY_CFG                  : std_logic_vector(15 downto 0);
      RXPHSAMP_CFG                 : std_logic_vector(15 downto 0);
      RXPHSLIP_CFG                 : std_logic_vector(15 downto 0);
      RXPH_MONITOR_SEL             : std_logic_vector(4 downto 0);
      RXPI_CFG0                    : std_logic_vector(1 downto 0);
      RXPI_CFG1                    : std_logic_vector(1 downto 0);
      RXPI_CFG2                    : std_logic_vector(1 downto 0);
      RXPI_CFG3                    : std_logic_vector(1 downto 0);
      RXPI_CFG4                    : bit;
      RXPI_CFG5                    : bit;
      RXPI_CFG6                    : std_logic_vector(2 downto 0);
      RXPI_LPM                     : bit;
      RXPI_VREFSEL                 : bit;
      RXPMACLK_SEL                 : string;
      RXPMARESET_TIME              : std_logic_vector(4 downto 0);
      RXPRBS_ERR_LOOPBACK          : bit;
      RXPRBS_LINKACQ_CNT           : integer;
      RXSLIDE_AUTO_WAIT            : integer;
      RXSLIDE_MODE                 : string;
      RXSYNC_MULTILANE             : bit;
      RXSYNC_OVRD                  : bit;
      RXSYNC_SKIP_DA               : bit;
      RX_AFE_CM_EN                 : bit;
      RX_BIAS_CFG0                 : std_logic_vector(15 downto 0);
      RX_BUFFER_CFG                : std_logic_vector(5 downto 0);
      RX_CAPFF_SARC_ENB            : bit;
      RX_CLK25_DIV                 : integer;
      RX_CLKMUX_EN                 : bit;
      RX_CLK_SLIP_OVRD             : std_logic_vector(4 downto 0);
      RX_CM_BUF_CFG                : std_logic_vector(3 downto 0);
      RX_CM_BUF_PD                 : bit;
      RX_CM_SEL                    : std_logic_vector(1 downto 0);
      RX_CM_TRIM                   : std_logic_vector(3 downto 0);
      RX_CTLE3_LPF                 : std_logic_vector(7 downto 0);
      RX_DATA_WIDTH                : integer;
      RX_DDI_SEL                   : std_logic_vector(5 downto 0);
      RX_DEFER_RESET_BUF_EN        : string;
      RX_DFELPM_CFG0               : std_logic_vector(3 downto 0);
      RX_DFELPM_CFG1               : bit;
      RX_DFELPM_KLKH_AGC_STUP_EN   : bit;
      RX_DFE_AGC_CFG0              : std_logic_vector(1 downto 0);
      RX_DFE_AGC_CFG1              : std_logic_vector(2 downto 0);
      RX_DFE_KL_LPM_KH_CFG0        : std_logic_vector(1 downto 0);
      RX_DFE_KL_LPM_KH_CFG1        : std_logic_vector(2 downto 0);
      RX_DFE_KL_LPM_KL_CFG0        : std_logic_vector(1 downto 0);
      RX_DFE_KL_LPM_KL_CFG1        : std_logic_vector(2 downto 0);
      RX_DFE_LPM_HOLD_DURING_EIDLE : bit;
      RX_DISPERR_SEQ_MATCH         : string;
      RX_DIVRESET_TIME             : std_logic_vector(4 downto 0);
      RX_EN_HI_LR                  : bit;
      RX_EYESCAN_VS_CODE           : std_logic_vector(6 downto 0);
      RX_EYESCAN_VS_NEG_DIR        : bit;
      RX_EYESCAN_VS_RANGE          : std_logic_vector(1 downto 0);
      RX_EYESCAN_VS_UT_SIGN        : bit;
      RX_FABINT_USRCLK_FLOP        : bit;
      RX_INT_DATAWIDTH             : integer;
      RX_PMA_POWER_SAVE            : bit;
      RX_PROGDIV_CFG               : real;
      RX_SAMPLE_PERIOD             : std_logic_vector(2 downto 0);
      RX_SIG_VALID_DLY             : integer;
      RX_SUM_DFETAPREP_EN          : bit;
      RX_SUM_IREF_TUNE             : std_logic_vector(3 downto 0);
      RX_SUM_RES_CTRL              : std_logic_vector(1 downto 0);
      RX_SUM_VCMTUNE               : std_logic_vector(3 downto 0);
      RX_SUM_VCM_OVWR              : bit;
      RX_SUM_VREF_TUNE             : std_logic_vector(2 downto 0);
      RX_TUNE_AFE_OS               : std_logic_vector(1 downto 0);
      RX_WIDEMODE_CDR              : bit;
      RX_XCLK_SEL                  : string;
      SAS_MAX_COM                  : integer;
      SAS_MIN_COM                  : integer;
      SATA_BURST_SEQ_LEN           : std_logic_vector(3 downto 0);
      SATA_BURST_VAL               : std_logic_vector(2 downto 0);
      SATA_CPLL_CFG                : string;
      SATA_EIDLE_VAL               : std_logic_vector(2 downto 0);
      SATA_MAX_BURST               : integer;
      SATA_MAX_INIT                : integer;
      SATA_MAX_WAKE                : integer;
      SATA_MIN_BURST               : integer;
      SATA_MIN_INIT                : integer;
      SATA_MIN_WAKE                : integer;
      SHOW_REALIGN_COMMA           : string;
      SIM_MODE                     : string;
      SIM_RECEIVER_DETECT_PASS     : string;
      SIM_RESET_SPEEDUP            : string;
      SIM_TX_EIDLE_DRIVE_LEVEL     : bit;
      SIM_VERSION                  : integer;
      TAPDLY_SET_TX                : std_logic_vector(1 downto 0);
      TEMPERATUR_PAR               : std_logic_vector(3 downto 0);
      TERM_RCAL_CFG                : std_logic_vector(14 downto 0);
      TERM_RCAL_OVRD               : std_logic_vector(2 downto 0);
      TRANS_TIME_RATE              : std_logic_vector(7 downto 0);
      TST_RSV0                     : std_logic_vector(7 downto 0);
      TST_RSV1                     : std_logic_vector(7 downto 0);
      TXBUF_EN                     : string;
      TXBUF_RESET_ON_RATE_CHANGE   : string;
      TXDLY_CFG                    : std_logic_vector(15 downto 0);
      TXDLY_LCFG                   : std_logic_vector(15 downto 0);
      TXDRVBIAS_N                  : std_logic_vector(3 downto 0);
      TXDRVBIAS_P                  : std_logic_vector(3 downto 0);
      TXFIFO_ADDR_CFG              : string;
      TXGBOX_FIFO_INIT_RD_ADDR     : integer;
      TXGEARBOX_EN                 : string;
      TXOUT_DIV                    : integer;
      TXPCSRESET_TIME              : std_logic_vector(4 downto 0);
      TXPHDLY_CFG0                 : std_logic_vector(15 downto 0);
      TXPHDLY_CFG1                 : std_logic_vector(15 downto 0);
      TXPH_CFG                     : std_logic_vector(15 downto 0);
      TXPH_MONITOR_SEL             : std_logic_vector(4 downto 0);
      TXPI_CFG0                    : std_logic_vector(1 downto 0);
      TXPI_CFG1                    : std_logic_vector(1 downto 0);
      TXPI_CFG2                    : std_logic_vector(1 downto 0);
      TXPI_CFG3                    : bit;
      TXPI_CFG4                    : bit;
      TXPI_CFG5                    : std_logic_vector(2 downto 0);
      TXPI_GRAY_SEL                : bit;
      TXPI_INVSTROBE_SEL           : bit;
      TXPI_LPM                     : bit;
      TXPI_PPMCLK_SEL              : string;
      TXPI_PPM_CFG                 : std_logic_vector(7 downto 0);
      TXPI_SYNFREQ_PPM             : std_logic_vector(2 downto 0);
      TXPI_VREFSEL                 : bit;
      TXPMARESET_TIME              : std_logic_vector(4 downto 0);
      TXSYNC_MULTILANE             : bit;
      TXSYNC_OVRD                  : bit;
      TXSYNC_SKIP_DA               : bit;
      TX_CLK25_DIV                 : integer;
      TX_CLKMUX_EN                 : bit;
      TX_DATA_WIDTH                : integer;
      TX_DCD_CFG                   : std_logic_vector(5 downto 0);
      TX_DCD_EN                    : bit;
      TX_DEEMPH0                   : std_logic_vector(5 downto 0);
      TX_DEEMPH1                   : std_logic_vector(5 downto 0);
      TX_DIVRESET_TIME             : std_logic_vector(4 downto 0);
      TX_DRIVE_MODE                : string;
      TX_EIDLE_ASSERT_DELAY        : std_logic_vector(2 downto 0);
      TX_EIDLE_DEASSERT_DELAY      : std_logic_vector(2 downto 0);
      TX_EML_PHI_TUNE              : bit;
      TX_FABINT_USRCLK_FLOP        : bit;
      TX_IDLE_DATA_ZERO            : bit;
      TX_INT_DATAWIDTH             : integer;
      TX_LOOPBACK_DRIVE_HIZ        : string;
      TX_MAINCURSOR_SEL            : bit;
      TX_MARGIN_FULL_0             : std_logic_vector(6 downto 0);
      TX_MARGIN_FULL_1             : std_logic_vector(6 downto 0);
      TX_MARGIN_FULL_2             : std_logic_vector(6 downto 0);
      TX_MARGIN_FULL_3             : std_logic_vector(6 downto 0);
      TX_MARGIN_FULL_4             : std_logic_vector(6 downto 0);
      TX_MARGIN_LOW_0              : std_logic_vector(6 downto 0);
      TX_MARGIN_LOW_1              : std_logic_vector(6 downto 0);
      TX_MARGIN_LOW_2              : std_logic_vector(6 downto 0);
      TX_MARGIN_LOW_3              : std_logic_vector(6 downto 0);
      TX_MARGIN_LOW_4              : std_logic_vector(6 downto 0);
      TX_MODE_SEL                  : std_logic_vector(2 downto 0);
      TX_PMADATA_OPT               : bit;
      TX_PMA_POWER_SAVE            : bit;
      TX_PROGCLK_SEL               : string;
      TX_PROGDIV_CFG               : real;
      TX_QPI_STATUS_EN             : bit;
      TX_RXDETECT_CFG              : std_logic_vector(13 downto 0);
      TX_RXDETECT_REF              : std_logic_vector(2 downto 0);
      TX_SAMPLE_PERIOD             : std_logic_vector(2 downto 0);
      TX_SARC_LPBK_ENB             : bit;
      TX_XCLK_SEL                  : string;
      USE_PCS_CLK_PHASE_SEL        : bit;
      WB_MODE                      : std_logic_vector(1 downto 0));
    port (
      BUFGTCE              : out std_logic_vector(2 downto 0);
      BUFGTCEMASK          : out std_logic_vector(2 downto 0);
      BUFGTDIV             : out std_logic_vector(8 downto 0);
      BUFGTRESET           : out std_logic_vector(2 downto 0);
      BUFGTRSTMASK         : out std_logic_vector(2 downto 0);
      CPLLFBCLKLOST        : out std_ulogic;
      CPLLLOCK             : out std_ulogic;
      CPLLREFCLKLOST       : out std_ulogic;
      DMONITOROUT          : out std_logic_vector(16 downto 0);
      DRPDO                : out std_logic_vector(15 downto 0);
      DRPRDY               : out std_ulogic;
      EYESCANDATAERROR     : out std_ulogic;
      GTHTXN               : out std_ulogic;
      GTHTXP               : out std_ulogic;
      GTPOWERGOOD          : out std_ulogic;
      GTREFCLKMONITOR      : out std_ulogic;
      PCIERATEGEN3         : out std_ulogic;
      PCIERATEIDLE         : out std_ulogic;
      PCIERATEQPLLPD       : out std_logic_vector(1 downto 0);
      PCIERATEQPLLRESET    : out std_logic_vector(1 downto 0);
      PCIESYNCTXSYNCDONE   : out std_ulogic;
      PCIEUSERGEN3RDY      : out std_ulogic;
      PCIEUSERPHYSTATUSRST : out std_ulogic;
      PCIEUSERRATESTART    : out std_ulogic;
      PCSRSVDOUT           : out std_logic_vector(11 downto 0);
      PHYSTATUS            : out std_ulogic;
      PINRSRVDAS           : out std_logic_vector(7 downto 0);
      RESETEXCEPTION       : out std_ulogic;
      RXBUFSTATUS          : out std_logic_vector(2 downto 0);
      RXBYTEISALIGNED      : out std_ulogic;
      RXBYTEREALIGN        : out std_ulogic;
      RXCDRLOCK            : out std_ulogic;
      RXCDRPHDONE          : out std_ulogic;
      RXCHANBONDSEQ        : out std_ulogic;
      RXCHANISALIGNED      : out std_ulogic;
      RXCHANREALIGN        : out std_ulogic;
      RXCHBONDO            : out std_logic_vector(4 downto 0);
      RXCLKCORCNT          : out std_logic_vector(1 downto 0);
      RXCOMINITDET         : out std_ulogic;
      RXCOMMADET           : out std_ulogic;
      RXCOMSASDET          : out std_ulogic;
      RXCOMWAKEDET         : out std_ulogic;
      RXCTRL0              : out std_logic_vector(15 downto 0);
      RXCTRL1              : out std_logic_vector(15 downto 0);
      RXCTRL2              : out std_logic_vector(7 downto 0);
      RXCTRL3              : out std_logic_vector(7 downto 0);
      RXDATA               : out std_logic_vector(127 downto 0);
      RXDATAEXTENDRSVD     : out std_logic_vector(7 downto 0);
      RXDATAVALID          : out std_logic_vector(1 downto 0);
      RXDLYSRESETDONE      : out std_ulogic;
      RXELECIDLE           : out std_ulogic;
      RXHEADER             : out std_logic_vector(5 downto 0);
      RXHEADERVALID        : out std_logic_vector(1 downto 0);
      RXMONITOROUT         : out std_logic_vector(6 downto 0);
      RXOSINTDONE          : out std_ulogic;
      RXOSINTSTARTED       : out std_ulogic;
      RXOSINTSTROBEDONE    : out std_ulogic;
      RXOSINTSTROBESTARTED : out std_ulogic;
      RXOUTCLK             : out std_ulogic;
      RXOUTCLKFABRIC       : out std_ulogic;
      RXOUTCLKPCS          : out std_ulogic;
      RXPHALIGNDONE        : out std_ulogic;
      RXPHALIGNERR         : out std_ulogic;
      RXPMARESETDONE       : out std_ulogic;
      RXPRBSERR            : out std_ulogic;
      RXPRBSLOCKED         : out std_ulogic;
      RXPRGDIVRESETDONE    : out std_ulogic;
      RXQPISENN            : out std_ulogic;
      RXQPISENP            : out std_ulogic;
      RXRATEDONE           : out std_ulogic;
      RXRECCLKOUT          : out std_ulogic;
      RXRESETDONE          : out std_ulogic;
      RXSLIDERDY           : out std_ulogic;
      RXSLIPDONE           : out std_ulogic;
      RXSLIPOUTCLKRDY      : out std_ulogic;
      RXSLIPPMARDY         : out std_ulogic;
      RXSTARTOFSEQ         : out std_logic_vector(1 downto 0);
      RXSTATUS             : out std_logic_vector(2 downto 0);
      RXSYNCDONE           : out std_ulogic;
      RXSYNCOUT            : out std_ulogic;
      RXVALID              : out std_ulogic;
      TXBUFSTATUS          : out std_logic_vector(1 downto 0);
      TXCOMFINISH          : out std_ulogic;
      TXDLYSRESETDONE      : out std_ulogic;
      TXOUTCLK             : out std_ulogic;
      TXOUTCLKFABRIC       : out std_ulogic;
      TXOUTCLKPCS          : out std_ulogic;
      TXPHALIGNDONE        : out std_ulogic;
      TXPHINITDONE         : out std_ulogic;
      TXPMARESETDONE       : out std_ulogic;
      TXPRGDIVRESETDONE    : out std_ulogic;
      TXQPISENN            : out std_ulogic;
      TXQPISENP            : out std_ulogic;
      TXRATEDONE           : out std_ulogic;
      TXRESETDONE          : out std_ulogic;
      TXSYNCDONE           : out std_ulogic;
      TXSYNCOUT            : out std_ulogic;
      CFGRESET             : in  std_ulogic;
      CLKRSVD0             : in  std_ulogic;
      CLKRSVD1             : in  std_ulogic;
      CPLLLOCKDETCLK       : in  std_ulogic;
      CPLLLOCKEN           : in  std_ulogic;
      CPLLPD               : in  std_ulogic;
      CPLLREFCLKSEL        : in  std_logic_vector(2 downto 0);
      CPLLRESET            : in  std_ulogic;
      DMONFIFORESET        : in  std_ulogic;
      DMONITORCLK          : in  std_ulogic;
      DRPADDR              : in  std_logic_vector(8 downto 0);
      DRPCLK               : in  std_ulogic;
      DRPDI                : in  std_logic_vector(15 downto 0);
      DRPEN                : in  std_ulogic;
      DRPWE                : in  std_ulogic;
      EVODDPHICALDONE      : in  std_ulogic;
      EVODDPHICALSTART     : in  std_ulogic;
      EVODDPHIDRDEN        : in  std_ulogic;
      EVODDPHIDWREN        : in  std_ulogic;
      EVODDPHIXRDEN        : in  std_ulogic;
      EVODDPHIXWREN        : in  std_ulogic;
      EYESCANMODE          : in  std_ulogic;
      EYESCANRESET         : in  std_ulogic;
      EYESCANTRIGGER       : in  std_ulogic;
      GTGREFCLK            : in  std_ulogic;
      GTHRXN               : in  std_ulogic;
      GTHRXP               : in  std_ulogic;
      GTNORTHREFCLK0       : in  std_ulogic;
      GTNORTHREFCLK1       : in  std_ulogic;
      GTREFCLK0            : in  std_ulogic;
      GTREFCLK1            : in  std_ulogic;
      GTRESETSEL           : in  std_ulogic;
      GTRSVD               : in  std_logic_vector(15 downto 0);
      GTRXRESET            : in  std_ulogic;
      GTSOUTHREFCLK0       : in  std_ulogic;
      GTSOUTHREFCLK1       : in  std_ulogic;
      GTTXRESET            : in  std_ulogic;
      LOOPBACK             : in  std_logic_vector(2 downto 0);
      LPBKRXTXSEREN        : in  std_ulogic;
      LPBKTXRXSEREN        : in  std_ulogic;
      PCIEEQRXEQADAPTDONE  : in  std_ulogic;
      PCIERSTIDLE          : in  std_ulogic;
      PCIERSTTXSYNCSTART   : in  std_ulogic;
      PCIEUSERRATEDONE     : in  std_ulogic;
      PCSRSVDIN            : in  std_logic_vector(15 downto 0);
      PCSRSVDIN2           : in  std_logic_vector(4 downto 0);
      PMARSVDIN            : in  std_logic_vector(4 downto 0);
      QPLL0CLK             : in  std_ulogic;
      QPLL0REFCLK          : in  std_ulogic;
      QPLL1CLK             : in  std_ulogic;
      QPLL1REFCLK          : in  std_ulogic;
      RESETOVRD            : in  std_ulogic;
      RSTCLKENTX           : in  std_ulogic;
      RX8B10BEN            : in  std_ulogic;
      RXBUFRESET           : in  std_ulogic;
      RXCDRFREQRESET       : in  std_ulogic;
      RXCDRHOLD            : in  std_ulogic;
      RXCDROVRDEN          : in  std_ulogic;
      RXCDRRESET           : in  std_ulogic;
      RXCDRRESETRSV        : in  std_ulogic;
      RXCHBONDEN           : in  std_ulogic;
      RXCHBONDI            : in  std_logic_vector(4 downto 0);
      RXCHBONDLEVEL        : in  std_logic_vector(2 downto 0);
      RXCHBONDMASTER       : in  std_ulogic;
      RXCHBONDSLAVE        : in  std_ulogic;
      RXCOMMADETEN         : in  std_ulogic;
      RXDFEAGCCTRL         : in  std_logic_vector(1 downto 0);
      RXDFEAGCHOLD         : in  std_ulogic;
      RXDFEAGCOVRDEN       : in  std_ulogic;
      RXDFELFHOLD          : in  std_ulogic;
      RXDFELFOVRDEN        : in  std_ulogic;
      RXDFELPMRESET        : in  std_ulogic;
      RXDFETAP10HOLD       : in  std_ulogic;
      RXDFETAP10OVRDEN     : in  std_ulogic;
      RXDFETAP11HOLD       : in  std_ulogic;
      RXDFETAP11OVRDEN     : in  std_ulogic;
      RXDFETAP12HOLD       : in  std_ulogic;
      RXDFETAP12OVRDEN     : in  std_ulogic;
      RXDFETAP13HOLD       : in  std_ulogic;
      RXDFETAP13OVRDEN     : in  std_ulogic;
      RXDFETAP14HOLD       : in  std_ulogic;
      RXDFETAP14OVRDEN     : in  std_ulogic;
      RXDFETAP15HOLD       : in  std_ulogic;
      RXDFETAP15OVRDEN     : in  std_ulogic;
      RXDFETAP2HOLD        : in  std_ulogic;
      RXDFETAP2OVRDEN      : in  std_ulogic;
      RXDFETAP3HOLD        : in  std_ulogic;
      RXDFETAP3OVRDEN      : in  std_ulogic;
      RXDFETAP4HOLD        : in  std_ulogic;
      RXDFETAP4OVRDEN      : in  std_ulogic;
      RXDFETAP5HOLD        : in  std_ulogic;
      RXDFETAP5OVRDEN      : in  std_ulogic;
      RXDFETAP6HOLD        : in  std_ulogic;
      RXDFETAP6OVRDEN      : in  std_ulogic;
      RXDFETAP7HOLD        : in  std_ulogic;
      RXDFETAP7OVRDEN      : in  std_ulogic;
      RXDFETAP8HOLD        : in  std_ulogic;
      RXDFETAP8OVRDEN      : in  std_ulogic;
      RXDFETAP9HOLD        : in  std_ulogic;
      RXDFETAP9OVRDEN      : in  std_ulogic;
      RXDFEUTHOLD          : in  std_ulogic;
      RXDFEUTOVRDEN        : in  std_ulogic;
      RXDFEVPHOLD          : in  std_ulogic;
      RXDFEVPOVRDEN        : in  std_ulogic;
      RXDFEVSEN            : in  std_ulogic;
      RXDFEXYDEN           : in  std_ulogic;
      RXDLYBYPASS          : in  std_ulogic;
      RXDLYEN              : in  std_ulogic;
      RXDLYOVRDEN          : in  std_ulogic;
      RXDLYSRESET          : in  std_ulogic;
      RXELECIDLEMODE       : in  std_logic_vector(1 downto 0);
      RXGEARBOXSLIP        : in  std_ulogic;
      RXLATCLK             : in  std_ulogic;
      RXLPMEN              : in  std_ulogic;
      RXLPMGCHOLD          : in  std_ulogic;
      RXLPMGCOVRDEN        : in  std_ulogic;
      RXLPMHFHOLD          : in  std_ulogic;
      RXLPMHFOVRDEN        : in  std_ulogic;
      RXLPMLFHOLD          : in  std_ulogic;
      RXLPMLFKLOVRDEN      : in  std_ulogic;
      RXLPMOSHOLD          : in  std_ulogic;
      RXLPMOSOVRDEN        : in  std_ulogic;
      RXMCOMMAALIGNEN      : in  std_ulogic;
      RXMONITORSEL         : in  std_logic_vector(1 downto 0);
      RXOOBRESET           : in  std_ulogic;
      RXOSCALRESET         : in  std_ulogic;
      RXOSHOLD             : in  std_ulogic;
      RXOSINTCFG           : in  std_logic_vector(3 downto 0);
      RXOSINTEN            : in  std_ulogic;
      RXOSINTHOLD          : in  std_ulogic;
      RXOSINTOVRDEN        : in  std_ulogic;
      RXOSINTSTROBE        : in  std_ulogic;
      RXOSINTTESTOVRDEN    : in  std_ulogic;
      RXOSOVRDEN           : in  std_ulogic;
      RXOUTCLKSEL          : in  std_logic_vector(2 downto 0);
      RXPCOMMAALIGNEN      : in  std_ulogic;
      RXPCSRESET           : in  std_ulogic;
      RXPD                 : in  std_logic_vector(1 downto 0);
      RXPHALIGN            : in  std_ulogic;
      RXPHALIGNEN          : in  std_ulogic;
      RXPHDLYPD            : in  std_ulogic;
      RXPHDLYRESET         : in  std_ulogic;
      RXPHOVRDEN           : in  std_ulogic;
      RXPLLCLKSEL          : in  std_logic_vector(1 downto 0);
      RXPMARESET           : in  std_ulogic;
      RXPOLARITY           : in  std_ulogic;
      RXPRBSCNTRESET       : in  std_ulogic;
      RXPRBSSEL            : in  std_logic_vector(3 downto 0);
      RXPROGDIVRESET       : in  std_ulogic;
      RXQPIEN              : in  std_ulogic;
      RXRATE               : in  std_logic_vector(2 downto 0);
      RXRATEMODE           : in  std_ulogic;
      RXSLIDE              : in  std_ulogic;
      RXSLIPOUTCLK         : in  std_ulogic;
      RXSLIPPMA            : in  std_ulogic;
      RXSYNCALLIN          : in  std_ulogic;
      RXSYNCIN             : in  std_ulogic;
      RXSYNCMODE           : in  std_ulogic;
      RXSYSCLKSEL          : in  std_logic_vector(1 downto 0);
      RXUSERRDY            : in  std_ulogic;
      RXUSRCLK             : in  std_ulogic;
      RXUSRCLK2            : in  std_ulogic;
      SIGVALIDCLK          : in  std_ulogic;
      TSTIN                : in  std_logic_vector(19 downto 0);
      TX8B10BBYPASS        : in  std_logic_vector(7 downto 0);
      TX8B10BEN            : in  std_ulogic;
      TXBUFDIFFCTRL        : in  std_logic_vector(2 downto 0);
      TXCOMINIT            : in  std_ulogic;
      TXCOMSAS             : in  std_ulogic;
      TXCOMWAKE            : in  std_ulogic;
      TXCTRL0              : in  std_logic_vector(15 downto 0);
      TXCTRL1              : in  std_logic_vector(15 downto 0);
      TXCTRL2              : in  std_logic_vector(7 downto 0);
      TXDATA               : in  std_logic_vector(127 downto 0);
      TXDATAEXTENDRSVD     : in  std_logic_vector(7 downto 0);
      TXDEEMPH             : in  std_ulogic;
      TXDETECTRX           : in  std_ulogic;
      TXDIFFCTRL           : in  std_logic_vector(3 downto 0);
      TXDIFFPD             : in  std_ulogic;
      TXDLYBYPASS          : in  std_ulogic;
      TXDLYEN              : in  std_ulogic;
      TXDLYHOLD            : in  std_ulogic;
      TXDLYOVRDEN          : in  std_ulogic;
      TXDLYSRESET          : in  std_ulogic;
      TXDLYUPDOWN          : in  std_ulogic;
      TXELECIDLE           : in  std_ulogic;
      TXHEADER             : in  std_logic_vector(5 downto 0);
      TXINHIBIT            : in  std_ulogic;
      TXLATCLK             : in  std_ulogic;
      TXMAINCURSOR         : in  std_logic_vector(6 downto 0);
      TXMARGIN             : in  std_logic_vector(2 downto 0);
      TXOUTCLKSEL          : in  std_logic_vector(2 downto 0);
      TXPCSRESET           : in  std_ulogic;
      TXPD                 : in  std_logic_vector(1 downto 0);
      TXPDELECIDLEMODE     : in  std_ulogic;
      TXPHALIGN            : in  std_ulogic;
      TXPHALIGNEN          : in  std_ulogic;
      TXPHDLYPD            : in  std_ulogic;
      TXPHDLYRESET         : in  std_ulogic;
      TXPHDLYTSTCLK        : in  std_ulogic;
      TXPHINIT             : in  std_ulogic;
      TXPHOVRDEN           : in  std_ulogic;
      TXPIPPMEN            : in  std_ulogic;
      TXPIPPMOVRDEN        : in  std_ulogic;
      TXPIPPMPD            : in  std_ulogic;
      TXPIPPMSEL           : in  std_ulogic;
      TXPIPPMSTEPSIZE      : in  std_logic_vector(4 downto 0);
      TXPISOPD             : in  std_ulogic;
      TXPLLCLKSEL          : in  std_logic_vector(1 downto 0);
      TXPMARESET           : in  std_ulogic;
      TXPOLARITY           : in  std_ulogic;
      TXPOSTCURSOR         : in  std_logic_vector(4 downto 0);
      TXPOSTCURSORINV      : in  std_ulogic;
      TXPRBSFORCEERR       : in  std_ulogic;
      TXPRBSSEL            : in  std_logic_vector(3 downto 0);
      TXPRECURSOR          : in  std_logic_vector(4 downto 0);
      TXPRECURSORINV       : in  std_ulogic;
      TXPROGDIVRESET       : in  std_ulogic;
      TXQPIBIASEN          : in  std_ulogic;
      TXQPISTRONGPDOWN     : in  std_ulogic;
      TXQPIWEAKPUP         : in  std_ulogic;
      TXRATE               : in  std_logic_vector(2 downto 0);
      TXRATEMODE           : in  std_ulogic;
      TXSEQUENCE           : in  std_logic_vector(6 downto 0);
      TXSWING              : in  std_ulogic;
      TXSYNCALLIN          : in  std_ulogic;
      TXSYNCIN             : in  std_ulogic;
      TXSYNCMODE           : in  std_ulogic;
      TXSYSCLKSEL          : in  std_logic_vector(1 downto 0);
      TXUSERRDY            : in  std_ulogic;
      TXUSRCLK             : in  std_ulogic;
      TXUSRCLK2            : in  std_ulogic);
  end component GTHE3_CHANNEL;

begin


  U_The_GTHE3 : GTHE3_CHANNEL
    generic map (
      ACJTAG_DEBUG_MODE            => '0',
      ACJTAG_MODE                  => '0',
      ACJTAG_RESET                 => '0',
      ADAPT_CFG0                   => "1111100000000000",
      ADAPT_CFG1                   => "0000000000000000",
      ALIGN_COMMA_DOUBLE           => "FALSE",
      ALIGN_COMMA_ENABLE           => "1111111111",
      ALIGN_COMMA_WORD             => 2,
      ALIGN_MCOMMA_DET             => "TRUE",
      ALIGN_MCOMMA_VALUE           => "1010000011",
      ALIGN_PCOMMA_DET             => "TRUE",
      ALIGN_PCOMMA_VALUE           => "0101111100",
      A_RXOSCALRESET               => '0',
      A_RXPROGDIVRESET             => '0',
      A_TXPROGDIVRESET             => '0',
      CBCC_DATA_SOURCE_SEL         => "DECODED",
      CDR_SWAP_MODE_EN             => '0',
      CHAN_BOND_KEEP_ALIGN         => "FALSE",
      CHAN_BOND_MAX_SKEW           => 1,
      CHAN_BOND_SEQ_1_1            => "0000000000",
      CHAN_BOND_SEQ_1_2            => "0000000000",
      CHAN_BOND_SEQ_1_3            => "0000000000",
      CHAN_BOND_SEQ_1_4            => "0000000000",
      CHAN_BOND_SEQ_1_ENABLE       => "1111",
      CHAN_BOND_SEQ_2_1            => "0000000000",
      CHAN_BOND_SEQ_2_2            => "0000000000",
      CHAN_BOND_SEQ_2_3            => "0000000000",
      CHAN_BOND_SEQ_2_4            => "0000000000",
      CHAN_BOND_SEQ_2_ENABLE       => "1111",
      CHAN_BOND_SEQ_2_USE          => "FALSE",
      CHAN_BOND_SEQ_LEN            => 1,
      CLK_CORRECT_USE              => "FALSE",
      CLK_COR_KEEP_IDLE            => "FALSE",
      CLK_COR_MAX_LAT              => 20,
      CLK_COR_MIN_LAT              => 18,
      CLK_COR_PRECEDENCE           => "TRUE",
      CLK_COR_REPEAT_WAIT          => 0,
      CLK_COR_SEQ_1_1              => "0100000000",
      CLK_COR_SEQ_1_2              => "0100000000",
      CLK_COR_SEQ_1_3              => "0100000000",
      CLK_COR_SEQ_1_4              => "0100000000",
      CLK_COR_SEQ_1_ENABLE         => "1111",
      CLK_COR_SEQ_2_1              => "0100000000",
      CLK_COR_SEQ_2_2              => "0100000000",
      CLK_COR_SEQ_2_3              => "0100000000",
      CLK_COR_SEQ_2_4              => "0100000000",
      CLK_COR_SEQ_2_ENABLE         => "1111",
      CLK_COR_SEQ_2_USE            => "FALSE",
      CLK_COR_SEQ_LEN              => 1,
      CPLL_CFG0                    => "0110011111111000",
      CPLL_CFG1                    => "1010010010101100",
      CPLL_CFG2                    => "0000000000000111",
      CPLL_CFG3                    => "000000",
      CPLL_FBDIV                   => 5,
      CPLL_FBDIV_45                => 4,
      CPLL_INIT_CFG0               => "0000001010110010",
      CPLL_INIT_CFG1               => "00000000",
      CPLL_LOCK_CFG                => "0000000111101000",
      CPLL_REFCLK_DIV              => 1,
      DDI_CTRL                     => "00",
      DDI_REALIGN_WAIT             => 15,
      DEC_MCOMMA_DETECT            => "TRUE",
      DEC_PCOMMA_DETECT            => "TRUE",
      DEC_VALID_COMMA_ONLY         => "FALSE",
      DFE_D_X_REL_POS              => '0',
      DFE_VCM_COMP_EN              => '0',
      DMONITOR_CFG0                => "0000000000",
      DMONITOR_CFG1                => "00000000",
      ES_CLK_PHASE_SEL             => '0',
      ES_CONTROL                   => "000000",
      ES_ERRDET_EN                 => "FALSE",
      ES_EYE_SCAN_EN               => "FALSE",
      ES_HORZ_OFFSET               => "000000000000",
      ES_PMA_CFG                   => "0000000000",
      ES_PRESCALE                  => "00000",
      ES_QUALIFIER0                => "0000000000000000",
      ES_QUALIFIER1                => "0000000000000000",
      ES_QUALIFIER2                => "0000000000000000",
      ES_QUALIFIER3                => "0000000000000000",
      ES_QUALIFIER4                => "0000000000000000",
      ES_QUAL_MASK0                => "0000000000000000",
      ES_QUAL_MASK1                => "0000000000000000",
      ES_QUAL_MASK2                => "0000000000000000",
      ES_QUAL_MASK3                => "0000000000000000",
      ES_QUAL_MASK4                => "0000000000000000",
      ES_SDATA_MASK0               => "0000000000000000",
      ES_SDATA_MASK1               => "0000000000000000",
      ES_SDATA_MASK2               => "0000000000000000",
      ES_SDATA_MASK3               => "0000000000000000",
      ES_SDATA_MASK4               => "0000000000000000",
      EVODD_PHI_CFG                => "00000000000",
      EYE_SCAN_SWAP_EN             => '0',
      FTS_DESKEW_SEQ_ENABLE        => "1111",
      FTS_LANE_DESKEW_CFG          => "1111",
      FTS_LANE_DESKEW_EN           => "FALSE",
      GEARBOX_MODE                 => "00000",
      GM_BIAS_SELECT               => '0',
      LOCAL_MASTER                 => '1',
      OOBDIVCTL                    => "00",
      OOB_PWRUP                    => '0',
      PCI3_AUTO_REALIGN            => "OVR_1K_BLK",
      PCI3_PIPE_RX_ELECIDLE        => '0',
      PCI3_RX_ASYNC_EBUF_BYPASS    => "00",
      PCI3_RX_ELECIDLE_EI2_ENABLE  => '0',
      PCI3_RX_ELECIDLE_H2L_COUNT   => "000000",
      PCI3_RX_ELECIDLE_H2L_DISABLE => "000",
      PCI3_RX_ELECIDLE_HI_COUNT    => "000000",
      PCI3_RX_ELECIDLE_LP4_DISABLE => '0',
      PCI3_RX_FIFO_DISABLE         => '0',
      PCIE_BUFG_DIV_CTRL           => "0001000000000000",
      PCIE_RXPCS_CFG_GEN3          => "0000001010100100",
      PCIE_RXPMA_CFG               => "0000000000001010",
      PCIE_TXPCS_CFG_GEN3          => "0010110010100100",
      PCIE_TXPMA_CFG               => "0000000000001010",
      PCS_PCIE_EN                  => "FALSE",
      PCS_RSVD0                    => "0000000000000000",
      PCS_RSVD1                    => "000",
      PD_TRANS_TIME_FROM_P2        => "000000111100",
      PD_TRANS_TIME_NONE_P2        => "00011001",
      PD_TRANS_TIME_TO_P2          => "01100100",
      PLL_SEL_MODE_GEN3            => "11",
      PLL_SEL_MODE_GEN12           => "00",
      PMA_RSV1                     => "1111000000000000",
      PROCESS_PAR                  => "010",
      RATE_SW_USE_DRP              => '1',
      RESET_POWERSAVE_DISABLE      => '0',
      RXBUFRESET_TIME              => "00011",
      RXBUF_ADDR_MODE              => "FAST",
      RXBUF_EIDLE_HI_CNT           => "1000",
      RXBUF_EIDLE_LO_CNT           => "0000",
      RXBUF_EN                     => "FALSE",
      RXBUF_RESET_ON_CB_CHANGE     => "TRUE",
      RXBUF_RESET_ON_COMMAALIGN    => "FALSE",
      RXBUF_RESET_ON_EIDLE         => "FALSE",
      RXBUF_RESET_ON_RATE_CHANGE   => "TRUE",
      RXBUF_THRESH_OVFLW           => 0,
      RXBUF_THRESH_OVRD            => "FALSE",
      RXBUF_THRESH_UNDFLW          => 0,
      RXCDRFREQRESET_TIME          => "00001",
      RXCDRPHRESET_TIME            => "00001",
      RXCDR_CFG0_GEN3              => "0000000000000000",
      RXCDR_CFG0                   => "0000000000000000",
      RXCDR_CFG1_GEN3              => "0000000000000000",
      RXCDR_CFG1                   => "0000000000000000",
      RXCDR_CFG2                   => "0000011101000110",
      RXCDR_CFG2_GEN3              => "0000011111100110",
      RXCDR_CFG3_GEN3              => "0000000000000000",
      RXCDR_CFG3                   => "0000000000000000",
      RXCDR_CFG4                   => "0000000000000000",
      RXCDR_CFG4_GEN3              => "0000000000000000",
      RXCDR_CFG5                   => "0000000000000000",
      RXCDR_CFG5_GEN3              => "0000000000000000",
      RXCDR_FR_RESET_ON_EIDLE      => '0',
      RXCDR_HOLD_DURING_EIDLE      => '0',
      RXCDR_LOCK_CFG0              => "0100010010000000",
      RXCDR_LOCK_CFG1              => "0101111111111111",
      RXCDR_LOCK_CFG2              => "0111011111000011",
      RXCDR_PH_RESET_ON_EIDLE      => '0',
      RXCFOK_CFG0                  => "0100000000000000",
      RXCFOK_CFG1                  => "0000000001100101",
      RXCFOK_CFG2                  => "0000000000101110",
      RXDFELPMRESET_TIME           => "0001111",
      RXDFELPM_KL_CFG0             => "0000000000000000",
      RXDFELPM_KL_CFG1             => "0000000000110010",
      RXDFELPM_KL_CFG2             => "0000000000000000",
      RXDFE_CFG0                   => "0000101000000000",
      RXDFE_CFG1                   => "0000000000000000",
      RXDFE_GC_CFG0                => "0000000000000000",
      RXDFE_GC_CFG1                => "0111100001110000",
      RXDFE_GC_CFG2                => "0000000000000000",
      RXDFE_H2_CFG0                => "0000000000000000",
      RXDFE_H2_CFG1                => "0000000000000000",
      RXDFE_H3_CFG0                => "0100000000000000",
      RXDFE_H3_CFG1                => "0000000000000000",
      RXDFE_H4_CFG0                => "0010000000000000",
      RXDFE_H4_CFG1                => "0000000000000011",
      RXDFE_H5_CFG0                => "0010000000000000",
      RXDFE_H5_CFG1                => "0000000000000011",
      RXDFE_H6_CFG0                => "0010000000000000",
      RXDFE_H6_CFG1                => "0000000000000000",
      RXDFE_H7_CFG0                => "0010000000000000",
      RXDFE_H7_CFG1                => "0000000000000000",
      RXDFE_H8_CFG0                => "0010000000000000",
      RXDFE_H8_CFG1                => "0000000000000000",
      RXDFE_H9_CFG0                => "0010000000000000",
      RXDFE_H9_CFG1                => "0000000000000000",
      RXDFE_HA_CFG0                => "0010000000000000",
      RXDFE_HA_CFG1                => "0000000000000000",
      RXDFE_HB_CFG0                => "0010000000000000",
      RXDFE_HB_CFG1                => "0000000000000000",
      RXDFE_HC_CFG0                => "0000000000000000",
      RXDFE_HC_CFG1                => "0000000000000000",
      RXDFE_HD_CFG0                => "0000000000000000",
      RXDFE_HD_CFG1                => "0000000000000000",
      RXDFE_HE_CFG0                => "0000000000000000",
      RXDFE_HE_CFG1                => "0000000000000000",
      RXDFE_HF_CFG0                => "0000000000000000",
      RXDFE_HF_CFG1                => "0000000000000000",
      RXDFE_OS_CFG0                => "1000000000000000",
      RXDFE_OS_CFG1                => "0000000000000000",
      RXDFE_UT_CFG0                => "1000000000000000",
      RXDFE_UT_CFG1                => "0000000000000011",
      RXDFE_VP_CFG0                => "1010101000000000",
      RXDFE_VP_CFG1                => "0000000000110011",
      RXDLY_CFG                    => "0000000000011111",
      RXDLY_LCFG                   => "0000000000110000",
      RXELECIDLE_CFG               => "Sigcfg_4",
      RXGBOX_FIFO_INIT_RD_ADDR     => 4,
      RXGEARBOX_EN                 => "FALSE",
      RXISCANRESET_TIME            => "00001",
      RXLPM_CFG                    => "0000000000000000",
      RXLPM_GC_CFG                 => "0001000000000000",
      RXLPM_KH_CFG0                => "0000000000000000",
      RXLPM_KH_CFG1                => "0000000000000010",
      RXLPM_OS_CFG0                => "1000000000000000",
      RXLPM_OS_CFG1                => "0000000000000010",
      RXOOB_CFG                    => "000000110",
      RXOOB_CLK_CFG                => "PMA",
      RXOSCALRESET_TIME            => "00011",
      RXOUT_DIV                    => 4,
      RXPCSRESET_TIME              => "00011",
      RXPHBEACON_CFG               => "0000000000000000",
      RXPHDLY_CFG                  => "0010000000100000",
      RXPHSAMP_CFG                 => "0010000100000000",
      RXPHSLIP_CFG                 => "0110011000100010",
      RXPH_MONITOR_SEL             => "00000",
      RXPI_CFG0                    => "01",
      RXPI_CFG1                    => "01",
      RXPI_CFG2                    => "01",
      RXPI_CFG3                    => "01",
      RXPI_CFG4                    => '1',
      RXPI_CFG5                    => '1',
      RXPI_CFG6                    => "011",
      RXPI_LPM                     => '0',
      RXPI_VREFSEL                 => '0',
      RXPMACLK_SEL                 => "DATA",
      RXPMARESET_TIME              => "00011",
      RXPRBS_ERR_LOOPBACK          => '0',
      RXPRBS_LINKACQ_CNT           => 15,
      RXSLIDE_AUTO_WAIT            => 7,
      RXSLIDE_MODE                 => "PCS",
      RXSYNC_MULTILANE             => '0',
      RXSYNC_OVRD                  => '0',
      RXSYNC_SKIP_DA               => '0',
      RX_AFE_CM_EN                 => '0',
      RX_BIAS_CFG0                 => "0000101010110100",
      RX_BUFFER_CFG                => "000000",
      RX_CAPFF_SARC_ENB            => '0',
      RX_CLK25_DIV                 => 5,
      RX_CLKMUX_EN                 => '1',
      RX_CLK_SLIP_OVRD             => "00000",
      RX_CM_BUF_CFG                => "1010",
      RX_CM_BUF_PD                 => '0',
      RX_CM_SEL                    => "11",
      RX_CM_TRIM                   => "1010",
      RX_CTLE3_LPF                 => "00000001",
      RX_DATA_WIDTH                => 20,
      RX_DDI_SEL                   => "000000",
      RX_DEFER_RESET_BUF_EN        => "TRUE",
      RX_DFELPM_CFG0               => "0110",
      RX_DFELPM_CFG1               => '1',
      RX_DFELPM_KLKH_AGC_STUP_EN   => '1',
      RX_DFE_AGC_CFG0              => "10",
      RX_DFE_AGC_CFG1              => "000",
      RX_DFE_KL_LPM_KH_CFG0        => "01",
      RX_DFE_KL_LPM_KH_CFG1        => "000",
      RX_DFE_KL_LPM_KL_CFG0        => "01",
      RX_DFE_KL_LPM_KL_CFG1        => "000",
      RX_DFE_LPM_HOLD_DURING_EIDLE => '0',
      RX_DISPERR_SEQ_MATCH         => "TRUE",
      RX_DIVRESET_TIME             => "00001",
      RX_EN_HI_LR                  => '0',
      RX_EYESCAN_VS_CODE           => "0000000",
      RX_EYESCAN_VS_NEG_DIR        => '0',
      RX_EYESCAN_VS_RANGE          => "00",
      RX_EYESCAN_VS_UT_SIGN        => '0',
      RX_FABINT_USRCLK_FLOP        => '0',
      RX_INT_DATAWIDTH             => 0,
      RX_PMA_POWER_SAVE            => '0',
      RX_PROGDIV_CFG               => 0.00,
      RX_SAMPLE_PERIOD             => "111",
      RX_SIG_VALID_DLY             => 11,
      RX_SUM_DFETAPREP_EN          => '0',
      RX_SUM_IREF_TUNE             => "1100",
      RX_SUM_RES_CTRL              => "11",
      RX_SUM_VCMTUNE               => "0000",
      RX_SUM_VCM_OVWR              => '0',
      RX_SUM_VREF_TUNE             => "000",
      RX_TUNE_AFE_OS               => "10",
      RX_WIDEMODE_CDR              => '0',
      RX_XCLK_SEL                  => "RXUSR",
      SAS_MAX_COM                  => 64,
      SAS_MIN_COM                  => 36,
      SATA_BURST_SEQ_LEN           => "1110",
      SATA_BURST_VAL               => "100",
      SATA_CPLL_CFG                => "VCO_3000MHZ",
      SATA_EIDLE_VAL               => "100",
      SATA_MAX_BURST               => 8,
      SATA_MAX_INIT                => 21,
      SATA_MAX_WAKE                => 7,
      SATA_MIN_BURST               => 4,
      SATA_MIN_INIT                => 12,
      SATA_MIN_WAKE                => 4,
      SHOW_REALIGN_COMMA           => "FALSE",
      SIM_MODE                     => "FAST",
      SIM_RECEIVER_DETECT_PASS     => "TRUE",
      SIM_RESET_SPEEDUP            => "TRUE",
      SIM_TX_EIDLE_DRIVE_LEVEL     => '0',
      SIM_VERSION                  => 2,
      TAPDLY_SET_TX                => "00",
      TEMPERATUR_PAR               => "0010",
      TERM_RCAL_CFG                => "100001000010000",
      TERM_RCAL_OVRD               => "000",
      TRANS_TIME_RATE              => "00001110",
      TST_RSV0                     => "00000000",
      TST_RSV1                     => "00000000",
      TXBUF_EN                     => "FALSE",
      TXBUF_RESET_ON_RATE_CHANGE   => "TRUE",
      TXDLY_CFG                    => "0000000000001001",
      TXDLY_LCFG                   => "0000000001010000",
      TXDRVBIAS_N                  => "1010",
      TXDRVBIAS_P                  => "1010",
      TXFIFO_ADDR_CFG              => "LOW",
      TXGBOX_FIFO_INIT_RD_ADDR     => 4,
      TXGEARBOX_EN                 => "FALSE",
      TXOUT_DIV                    => 4,
      TXPCSRESET_TIME              => "00011",
      TXPHDLY_CFG0                 => "0010000000100000",
      TXPHDLY_CFG1                 => "0000000001110101",
      TXPH_CFG                     => "0000100110000000",
      TXPH_MONITOR_SEL             => "00000",
      TXPI_CFG0                    => "01",
      TXPI_CFG1                    => "01",
      TXPI_CFG2                    => "01",
      TXPI_CFG3                    => '1',
      TXPI_CFG4                    => '1',
      TXPI_CFG5                    => "011",
      TXPI_GRAY_SEL                => '0',
      TXPI_INVSTROBE_SEL           => '0',
      TXPI_LPM                     => '0',
      TXPI_PPMCLK_SEL              => "TXUSRCLK2",
      TXPI_PPM_CFG                 => "00000000",
      TXPI_SYNFREQ_PPM             => "001",
      TXPI_VREFSEL                 => '0',
      TXPMARESET_TIME              => "00011",
      TXSYNC_MULTILANE             => '0',
      TXSYNC_OVRD                  => '0',
      TXSYNC_SKIP_DA               => '0',
      TX_CLK25_DIV                 => 5,
      TX_CLKMUX_EN                 => '1',
      TX_DATA_WIDTH                => 20,
      TX_DCD_CFG                   => "000010",
      TX_DCD_EN                    => '0',
      TX_DEEMPH0                   => "000000",
      TX_DEEMPH1                   => "000000",
      TX_DIVRESET_TIME             => "00001",
      TX_DRIVE_MODE                => "DIRECT",
      TX_EIDLE_ASSERT_DELAY        => "100",
      TX_EIDLE_DEASSERT_DELAY      => "011",
      TX_EML_PHI_TUNE              => '0',
      TX_FABINT_USRCLK_FLOP        => '0',
      TX_IDLE_DATA_ZERO            => '0',
      TX_INT_DATAWIDTH             => 0,
      TX_LOOPBACK_DRIVE_HIZ        => "FALSE",
      TX_MAINCURSOR_SEL            => '0',
      TX_MARGIN_FULL_0             => "1001111",
      TX_MARGIN_FULL_1             => "1001110",
      TX_MARGIN_FULL_2             => "1001100",
      TX_MARGIN_FULL_3             => "1001010",
      TX_MARGIN_FULL_4             => "1001000",
      TX_MARGIN_LOW_0              => "1000110",
      TX_MARGIN_LOW_1              => "1000101",
      TX_MARGIN_LOW_2              => "1000011",
      TX_MARGIN_LOW_3              => "1000010",
      TX_MARGIN_LOW_4              => "1000000",
      TX_MODE_SEL                  => "000",
      TX_PMADATA_OPT               => '0',
      TX_PMA_POWER_SAVE            => '0',
      TX_PROGCLK_SEL               => "PREPI",
      TX_PROGDIV_CFG               => 0.00,
      TX_QPI_STATUS_EN             => '0',
      TX_RXDETECT_CFG              => "00000000110010",
      TX_RXDETECT_REF              => "100",
      TX_SAMPLE_PERIOD             => "111",
      TX_SARC_LPBK_ENB             => '0',
      TX_XCLK_SEL                  => "TXUSR",
      USE_PCS_CLK_PHASE_SEL        => '0',
      WB_MODE                      => "00" )
    port map (
      BUFGTCE              => open,
      BUFGTCEMASK          => open,
      BUFGTDIV             => open,
      BUFGTRESET           => open,
      BUFGTRSTMASK         => open,
      CPLLFBCLKLOST        => open,
      CPLLLOCK             => CPLLLOCK,
      CPLLREFCLKLOST       => open,
      DMONITOROUT          => open,
      DRPDO                => open,
      DRPRDY               => open,
      EYESCANDATAERROR     => open,
      GTHTXN               => GTHTXN,
      GTHTXP               => GTHTXP,
      GTPOWERGOOD          => GTPOWERGOOD,
      GTREFCLKMONITOR      => open,
      PCIERATEGEN3         => open,
      PCIERATEIDLE         => open,
      PCIERATEQPLLPD       => open,
      PCIERATEQPLLRESET    => open,
      PCIESYNCTXSYNCDONE   => open,
      PCIEUSERGEN3RDY      => open,
      PCIEUSERPHYSTATUSRST => open,
      PCIEUSERRATESTART    => open,
      PCSRSVDOUT           => open,
      PHYSTATUS            => open,
      PINRSRVDAS           => open,
      RESETEXCEPTION       => open,
      RXBUFSTATUS          => open,
      RXBYTEISALIGNED      => RXBYTEISALIGNED,
      RXBYTEREALIGN        => open,
      RXCDRLOCK            => RXCDRLOCK,
      RXCDRPHDONE          => open,
      RXCHANBONDSEQ        => open,
      RXCHANISALIGNED      => open,
      RXCHANREALIGN        => open,
      RXCHBONDO            => open,
      RXCLKCORCNT          => open,
      RXCOMINITDET         => open,
      RXCOMMADET           => RXCOMMADET,
      RXCOMSASDET          => open,
      RXCOMWAKEDET         => open,
      RXCTRL0              => RXCTRL0,
      RXCTRL1              => RXCTRL1,
      RXCTRL2              => RXCTRL2,
      RXCTRL3              => RXCTRL3,
      RXDATA               => RXDATA,
      RXDATAEXTENDRSVD     => open,
      RXDATAVALID          => open,
      RXDLYSRESETDONE      => open,
      RXELECIDLE           => open,
      RXHEADER             => open,
      RXHEADERVALID        => open,
      RXMONITOROUT         => open,
      RXOSINTDONE          => open,
      RXOSINTSTARTED       => open,
      RXOSINTSTROBEDONE    => open,
      RXOSINTSTROBESTARTED => open,
      RXOUTCLK             => RXOUTCLK,
      RXOUTCLKFABRIC       => open,
      RXOUTCLKPCS          => open,
      RXPHALIGNDONE        => RXPHALIGNDONE,
      RXPHALIGNERR         => open,
      RXPMARESETDONE       => RXPMARESETDONE,
      RXPRBSERR            => open,
      RXPRBSLOCKED         => open,
      RXPRGDIVRESETDONE    => open,
      RXQPISENN            => open,
      RXQPISENP            => open,
      RXRATEDONE           => open,
      RXRECCLKOUT          => open,
      RXRESETDONE          => RXRESETDONE,
      RXSLIDERDY           => open,
      RXSLIPDONE           => open,
      RXSLIPOUTCLKRDY      => open,
      RXSLIPPMARDY         => open,
      RXSTARTOFSEQ         => open,
      RXSTATUS             => open,
      RXSYNCDONE           => RXSYNCDONE,
      RXSYNCOUT            => open,
      RXVALID              => open,
      TXBUFSTATUS          => open,
      TXCOMFINISH          => open,
      TXDLYSRESETDONE      => open,
      TXOUTCLK             => TXOUTCLK,
      TXOUTCLKFABRIC       => open,
      TXOUTCLKPCS          => open,
      TXPHALIGNDONE        => TXPHALIGNDONE,
      TXPHINITDONE         => open,
      TXPMARESETDONE       => TXPMARESETDONE,
      TXPRGDIVRESETDONE    => open,
      TXQPISENN            => open,
      TXQPISENP            => open,
      TXRATEDONE           => open,
      TXRESETDONE          => TXRESETDONE,
      TXSYNCDONE           => TXSYNCDONE,
      TXSYNCOUT            => open,
      CFGRESET             => '0',
      CLKRSVD0             => '0',
      CLKRSVD1             => '0',
      CPLLLOCKDETCLK       => '0',
      CPLLLOCKEN           => '1',
      CPLLPD               => CPLLPD,
      CPLLREFCLKSEL        => "001",
      CPLLRESET            => '0',
      DMONFIFORESET        => '0',
      DMONITORCLK          => '0',
      DRPADDR              => "000000000",
      DRPCLK               => DRPCLK,
      DRPDI                => x"0000",
      DRPEN                => '0',
      DRPWE                => '0',
      EVODDPHICALDONE      => '0',
      EVODDPHICALSTART     => '0',
      EVODDPHIDRDEN        => '0',
      EVODDPHIDWREN        => '0',
      EVODDPHIXRDEN        => '0',
      EVODDPHIXWREN        => '0',
      EYESCANMODE          => '0',
      EYESCANRESET         => '0',
      EYESCANTRIGGER       => '0',
      GTGREFCLK            => '0',
      GTHRXN               => GTHRXN,
      GTHRXP               => GTHRXP,
      GTNORTHREFCLK0       => '0',
      GTNORTHREFCLK1       => '0',
      GTREFCLK0            => GTREFCLK0,
      GTREFCLK1            => '0',
      GTRESETSEL           => '0',
      GTRSVD               => x"0000",
      GTRXRESET            => GTRXRESET,
      GTSOUTHREFCLK0       => '0',
      GTSOUTHREFCLK1       => '0',
      GTTXRESET            => GTTXRESET,
      LOOPBACK             => "000",
      LPBKRXTXSEREN        => '0',
      LPBKTXRXSEREN        => '0',
      PCIEEQRXEQADAPTDONE  => '0',
      PCIERSTIDLE          => '0',
      PCIERSTTXSYNCSTART   => '0',
      PCIEUSERRATEDONE     => '0',
      PCSRSVDIN            => x"0000",
      PCSRSVDIN2           => "00000",
      PMARSVDIN            => "00000",
      QPLL0CLK             => '0',
      QPLL0REFCLK          => '0',
      QPLL1CLK             => '0',
      QPLL1REFCLK          => '0',
      RESETOVRD            => '0',
      RSTCLKENTX           => '0',
      RX8B10BEN            => '1',
      RXBUFRESET           => '0',
      RXCDRFREQRESET       => '0',
      RXCDRHOLD            => '0',
      RXCDROVRDEN          => '0',
      RXCDRRESET           => '0',
      RXCDRRESETRSV        => '0',
      RXCHBONDEN           => '0',
      RXCHBONDI            => "00000",
      RXCHBONDLEVEL        => "000",
      RXCHBONDMASTER       => '0',
      RXCHBONDSLAVE        => '0',
      RXCOMMADETEN         => '1',
      RXDFEAGCCTRL         => "01",
      RXDFEAGCHOLD         => '0',
      RXDFEAGCOVRDEN       => '0',
      RXDFELFHOLD          => '0',
      RXDFELFOVRDEN        => '0',
      RXDFELPMRESET        => '0',
      RXDFETAP10HOLD       => '0',
      RXDFETAP10OVRDEN     => '0',
      RXDFETAP11HOLD       => '0',
      RXDFETAP11OVRDEN     => '0',
      RXDFETAP12HOLD       => '0',
      RXDFETAP12OVRDEN     => '0',
      RXDFETAP13HOLD       => '0',
      RXDFETAP13OVRDEN     => '0',
      RXDFETAP14HOLD       => '0',
      RXDFETAP14OVRDEN     => '0',
      RXDFETAP15HOLD       => '0',
      RXDFETAP15OVRDEN     => '0',
      RXDFETAP2HOLD        => '0',
      RXDFETAP2OVRDEN      => '0',
      RXDFETAP3HOLD        => '0',
      RXDFETAP3OVRDEN      => '0',
      RXDFETAP4HOLD        => '0',
      RXDFETAP4OVRDEN      => '0',
      RXDFETAP5HOLD        => '0',
      RXDFETAP5OVRDEN      => '0',
      RXDFETAP6HOLD        => '0',
      RXDFETAP6OVRDEN      => '0',
      RXDFETAP7HOLD        => '0',
      RXDFETAP7OVRDEN      => '0',
      RXDFETAP8HOLD        => '0',
      RXDFETAP8OVRDEN      => '0',
      RXDFETAP9HOLD        => '0',
      RXDFETAP9OVRDEN      => '0',
      RXDFEUTHOLD          => '0',
      RXDFEUTOVRDEN        => '0',
      RXDFEVPHOLD          => '0',
      RXDFEVPOVRDEN        => '0',
      RXDFEVSEN            => '0',
      RXDFEXYDEN           => '1',
      RXDLYBYPASS          => '0',
      RXDLYEN              => '0',
      RXDLYOVRDEN          => '0',
      RXDLYSRESET          => RXDLYSRESET,
      RXELECIDLEMODE       => "11",
      RXGEARBOXSLIP        => '0',
      RXLATCLK             => '0',
      RXLPMEN              => '1',
      RXLPMGCHOLD          => '0',
      RXLPMGCOVRDEN        => '0',
      RXLPMHFHOLD          => '0',
      RXLPMHFOVRDEN        => '0',
      RXLPMLFHOLD          => '0',
      RXLPMLFKLOVRDEN      => '0',
      RXLPMOSHOLD          => '0',
      RXLPMOSOVRDEN        => '0',
      RXMCOMMAALIGNEN      => '0',
      RXMONITORSEL         => "00",
      RXOOBRESET           => '0',
      RXOSCALRESET         => '0',
      RXOSHOLD             => '0',
      RXOSINTCFG           => "1101",
      RXOSINTEN            => '1',
      RXOSINTHOLD          => '0',
      RXOSINTOVRDEN        => '0',
      RXOSINTSTROBE        => '0',
      RXOSINTTESTOVRDEN    => '0',
      RXOSOVRDEN           => '0',
      RXOUTCLKSEL          => "010",
      RXPCOMMAALIGNEN      => '0',
      RXPCSRESET           => RXPCSRESET,
      RXPD                 => "00",
      RXPHALIGN            => '0',
      RXPHALIGNEN          => '0',
      RXPHDLYPD            => '0',
      RXPHDLYRESET         => '0',
      RXPHOVRDEN           => '0',
      RXPLLCLKSEL          => "00",
      RXPMARESET           => '0',
      RXPOLARITY           => '0',
      RXPRBSCNTRESET       => '0',
      RXPRBSSEL            => "0000",
      RXPROGDIVRESET       => RXPROGDIVRESET,
      RXQPIEN              => '0',
      RXRATE               => "000",
      RXRATEMODE           => '0',
      RXSLIDE              => RXSLIDE,
      RXSLIPOUTCLK         => '0',
      RXSLIPPMA            => '0',
      RXSYNCALLIN          => RXSYNCALLIN,
      RXSYNCIN             => '0',
      RXSYNCMODE           => '1',
      RXSYSCLKSEL          => "00",
      RXUSERRDY            => RXUSERRDY,
      RXUSRCLK             => RXUSRCLK2,
      RXUSRCLK2            => RXUSRCLK2,
      SIGVALIDCLK          => '0',
      TSTIN                => x"00000",
      TX8B10BBYPASS        => x"00",
      TX8B10BEN            => '1',
      TXBUFDIFFCTRL        => "000",
      TXCOMINIT            => '0',
      TXCOMSAS             => '0',
      TXCOMWAKE            => '0',
      TXCTRL0              => x"0000",
      TXCTRL1              => x"0000",
      TXCTRL2              => TXCTRL2,
      TXDATA               => TXDATA,
      TXDATAEXTENDRSVD     => "00000000",
      TXDEEMPH             => '0',
      TXDETECTRX           => '0',
      TXDIFFCTRL           => "1100",
      TXDIFFPD             => '0',
      TXDLYBYPASS          => '0',
      TXDLYEN              => '0',
      TXDLYHOLD            => '0',
      TXDLYOVRDEN          => '0',
      TXDLYSRESET          => TXDLYSRESET,
      TXDLYUPDOWN          => '0',
      TXELECIDLE           => '0',
      TXHEADER             => "000000",
      TXINHIBIT            => '0',
      TXLATCLK             => '0',
      TXMAINCURSOR         => "1000000",
      TXMARGIN             => "000",
      TXOUTCLKSEL          => "011",
      TXPCSRESET           => '0',
      TXPD                 => "00",
      TXPDELECIDLEMODE     => '0',
      TXPHALIGN            => '0',
      TXPHALIGNEN          => '0',
      TXPHDLYPD            => '0',
      TXPHDLYRESET         => '0',
      TXPHDLYTSTCLK        => '0',
      TXPHINIT             => '0',
      TXPHOVRDEN           => '0',
      TXPIPPMEN            => '0',
      TXPIPPMOVRDEN        => '0',
      TXPIPPMPD            => '0',
      TXPIPPMSEL           => '0',
      TXPIPPMSTEPSIZE      => "00000",
      TXPISOPD             => '0',
      TXPLLCLKSEL          => "00",
      TXPMARESET           => '0',
      TXPOLARITY           => '0',
      TXPOSTCURSOR         => "00000",
      TXPOSTCURSORINV      => '0',
      TXPRBSFORCEERR       => '0',
      TXPRBSSEL            => "0000",
      TXPRECURSOR          => "00000",
      TXPRECURSORINV       => '0',
      TXPROGDIVRESET       => TXPROGDIVRESET,
      TXQPIBIASEN          => '0',
      TXQPISTRONGPDOWN     => '0',
      TXQPIWEAKPUP         => '0',
      TXRATE               => "000",
      TXRATEMODE           => '0',
      TXSEQUENCE           => "0000000",
      TXSWING              => '0',
      TXSYNCALLIN          => TXSYNCALLIN,
      TXSYNCIN             => '0',
      TXSYNCMODE           => '1',
      TXSYSCLKSEL          => "00",
      TXUSERRDY            => TXUSERRDY,
      TXUSRCLK             => TXUSRCLK2,
      TXUSRCLK2            => TXUSRCLK2);

end rtl;

