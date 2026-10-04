# Independent Laptop verification

2026-10-04. Live-transfer manifest:15/15 SHA256 matches. Replay-transfer
manifest:37/37 SHA256 matches. No raw files rewritten during analysis.

Unchanged `step6_time_valid_300s.analyze_file()` on replay qualified-capture.log
equals Pain qualified-result.json exactly, including complete DONE counts,
sample sequence/gap guards and both-board verdict PASS_TIME_VALID_300S.
Master1190/1190,302852ms span,257ms max gap; Slave1190/1190,302870ms,256ms.
The live-baseline result was also independently recomputed and equal.

Updated acquisition analyzer results are saved separately in
`laptop-replay-acquisition.json` and `laptop-live-phase-context.json`; original
Pain acquisition.json remains untouched. Do not equate observer elapsed with
boot elapsed, phase-labelled startup values with pure fine-phase error, or
software arithmetic with actuator response.

30 current acquisition/source/TIME_VALID tests and25 readonly VUART/transport
tests passed on Laptop. Both replay wrapper syntax and scoped diff checks
passed. Pain actually ran27 earlier Python cases plus22 actual native-C cases
before replay; newer Laptop tests do not retroactively change that record.

Verified root-products.tar.gz SHA256
134f06f90755919f0db815b230aacabb8504700a9e92b813264808a9033b9596.
All53 archive entries are tracked build/ or output/ files with no traversal
or absolute paths. Restored those derived products into Laptop root only;
all frozen milestones and the protected Pain archive remain unchanged.
