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

#endif
