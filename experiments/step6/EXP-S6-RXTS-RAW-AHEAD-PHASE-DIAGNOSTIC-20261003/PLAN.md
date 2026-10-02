# Passive packet-specific RX timestamp experiment

Baseline: `67582a8b` / actual FPGA input `4ba9df59`, strict role-corrected
validity, Master HPLL physical step64, acquisition /2, tracking /12. Last
660 s capture: CKO -3158..3839 ps, no strict entry, Slave validity remained0.

Only intervention: bounded RAM recorder after the existing RX linearizer,
and a fixed read-only `pll rxts PAGE` query. No timestamp/calibration/control
algorithm, PI, gains, timeout, detector, port, RTL, SDC or SDB changes. Root
code only; frozen milestones and protected Pain archive untouched.

Workflow: Laptop edit/test/push -> Pain exact pull -> native tests/firmware
build -> Laptop pin fresh MIF hashes/push -> Pain pull/full compile/program ->
short strict health smoke -> single-session timestamp query -> data/checksums
back Laptop -> analysis/REPORT/push. No advisors.

32 recent PTP messages (Sync=0, Delay_Req=1, Follow_Up=8, Delay_Resp=9),
18 raw uint32 words each. Page0 takes an independent RAM snapshot; pages1..7
read that frozen copy. Producer is the serialized WRPC main loop, not ISR.
Each record includes ID, message/domain/sequence, source clock identity/port,
raw seconds/nsec/ahead/ptracker phase, active T24P, actual linearized result
and wire body timestamp. Follow_Up/Delay_Resp carry remote T1/T4; zero bodies
in two-step Sync/Delay_Req are NOT valid remote timestamps. Word4 flags:
bit16=correct, bit17=ahead, bit18=chosen falling branch; low16=source port.
Words5..6 raw sec,7 raw ns,8 raw phase,9 T24P,10..11 linearized sec,
12 linearized ns,13 linearized phase,14..15 wire sec,16 wire ns,17 period ps.

Two boards are queried sequentially by one JTAG reader. Console output can
perturb task timing: no concurrent dashboard/reader, bounded pages (<1KB
response each), record query duration, compare strict health before/after.
32-record histories are NOT continuous over a whole capture; deduplicate
IDs and disclose omissions. Snapshot ID/total/count and page completion must
match, all words must be present, resets/link/PLL guards must remain stable.
Short smoke first; stop on invalid pages, transport timeout, reset, link/PLL
loss or changed Master validity. At most four snapshots per board and540s
actual query session. No automatic calibration, role flip, power cycle or
PI tuning. Capture cannot establish the strict300s goal by itself.

Analysis: reproduce unchanged linearization for each correct raw stamp;
inspect raw ahead/phase/T24P selection and modulo8ns effects. Match wire
sequence/domain/source identity explicitly, not PC read order; Delay_Req
and Sync sequence counters are separate. Arithmetic matches prove recorder
consistency, not physical correctness. Near8ns steps correlated with selection
are a suspect, not automatic proof of timestamp causality. Smooth raw phase
variation also does not isolate PI without coherent control-update evidence.
