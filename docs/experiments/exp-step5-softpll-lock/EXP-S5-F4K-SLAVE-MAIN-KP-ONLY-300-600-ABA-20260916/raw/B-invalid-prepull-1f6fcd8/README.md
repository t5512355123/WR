# Excluded B Capture — Pre-pull Source

This directory is preserved for audit only. It is not a F4K B arm.

The capture was started before Pain successfully pulled source commit
34013477. Its build-info files report source commit 1f6fcd89096dbfa4dfc9ac0f744a6a1fe08449a5, and the Slave MIF matched the A1 Kp=300 build. The observer metadata said B/Kp=600, but the programmed image identity did not support that claim.

Do not pass this directory to the F4K comparator. The authoritative B arm is
raw/B/ and its build identity is recorded in B/manifest.json.

