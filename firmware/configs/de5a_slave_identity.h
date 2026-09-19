#ifndef DE5A_SLAVE_IDENTITY_H
#define DE5A_SLAVE_IDENTITY_H

/* Slave fallback identity for the DE5a WR node. */
#define DE5A_FALLBACK_MAC_0 0x02
#define DE5A_FALLBACK_MAC_1 0x00
#define DE5A_FALLBACK_MAC_2 0x22
#define DE5A_FALLBACK_MAC_3 0x33
#define DE5A_FALLBACK_MAC_4 0x44
#define DE5A_FALLBACK_MAC_5 0x02

/* F4b keeps the legacy multi-parameter Main-PI candidate disabled. */
#define DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE 0

/* F4K: independent, role-specific Main Kp override.  A1/A2 use 300;
 * the approved B arm changes only this value to 600. */
#define DE5A_MAIN_PI_KP_OVERRIDE 300
#define DE5A_F4L_MAIN_PHASE_DIAG 0

/* Causal candidate: narrow only the Slave Main frequency-lock acceptance
 * window. The Master identity intentionally does not define this override. */
#define DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE 20

/* Step5 causal candidate: keep frequency-branch Ki=1, but use Ki=0 only
 * for Main phase-branch pi_update(). */
#define DE5A_MAIN_PHASE_PI_KI_ZERO 1

/* F5: enable the single Main frequency-to-phase bumpless-preload treatment. */
#define DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD 1

#endif
