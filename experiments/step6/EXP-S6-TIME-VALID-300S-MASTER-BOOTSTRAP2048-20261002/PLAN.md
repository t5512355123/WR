# Same-session TIME_VALID 300-second qualification

Scope: the user's revised target is exported TIME_VALID on both boards for
at least 300 seconds. No timing-closure or sustained offset <60 ps gate is
added. The preceding Master Helper recovery diagnostic did NOT pass; its
unlocked Helper/unready ptracker caveat must stay visible in the result.

No firmware, RTL, gain, threshold, calibration, clock, reset or output-enable
change. No new compile or programming is performed for this observation.
Use the exact images compiled from 40c38801 and already programmed Slave then
Master at 13:48:28/13:48:46 +08:00. Laptop publishes this plan/experiment label,
Pain pulls it, then the existing read-only verifier observes that live session.

Run scripts/monitor/verify_time_valid_300s.sh. Its existing readiness polling
is bounded by 1800 seconds. Each board then gets a 303-second capture with
250-ms requested sample spacing. Every row must have exported STATUS_TIME_VALID
1, the observed span must exceed 300000 ms, max gap <=1000 ms, named board
identity / sample sequence / DONE count must agree, and transport errors must
fail closed. No rows are dropped to manufacture a qualifying interval.

The capture is sequential across boards; it does not prove simultaneous
edge skew, civil-time correctness, full fine timestamp correctness, or
cycle-by-cycle continuity between samples. Report those limits, and do not
claim Master Helper has been repaired. A failed capture is retained, not
relabeled. Keep the protected Pain archive untouched.

Return raw captures, checksums, build/program evidence and actual SOFs to
Laptop; analyze and publish the verdict through GitHub, then synchronize Pain.
