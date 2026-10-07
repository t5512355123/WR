#ifndef DE5A_MASTER_IDENTITY_H
#define DE5A_MASTER_IDENTITY_H

/* Master fallback identity for the DE5a WR node. */
#define DE5A_FALLBACK_MAC_0 0x02
#define DE5A_FALLBACK_MAC_1 0x00
#define DE5A_FALLBACK_MAC_2 0x22
#define DE5A_FALLBACK_MAC_3 0x33
#define DE5A_FALLBACK_MAC_4 0x44
#define DE5A_FALLBACK_MAC_5 0x01

/* F4b keeps the legacy multi-parameter Main-PI candidate disabled. */
#define DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE 0

/* F4K reference image: Master Main Kp is fixed at the A1/A2 value. */
#define DE5A_MAIN_PI_KP_OVERRIDE 300
/* Threshold20 image: make F4L the diagnostic owner on both boards. */
#define DE5A_F4L_MAIN_PHASE_DIAG 1

/* Step5 causal candidate: keep frequency-branch Ki=1, but use Ki=0 only
 * for Main phase-branch pi_update(). */
#define DE5A_MAIN_PHASE_PI_KI_ZERO 1

/* F5: enable the single Main frequency-to-phase bumpless-preload treatment. */
#define DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD 1

#endif
