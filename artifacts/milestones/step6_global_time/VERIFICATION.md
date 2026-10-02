# Frozen checkout verification — 2026-10-02

Pain path: `/home/b10504072/04_WR/artifacts/milestones/step6_global_time/current`.
`prepare_current.sh` returned 0. The archive checksum, all retained current
compile-input checksums and both qualified SOF checksums passed. Git reports
this directory itself as the checkout root, not the moving parent repository.

At 15:11:53 Asia/Taipei, the archived `scripts/monitor/step1_6_dashboard.sh`
ran with ONCE=1, CLEAR_SCREEN=0 and returned 0. Both boards reported Step6
VALID, TIME_VALID=1 and PPS_VALID=1. Slave's five PLL lock bits were all 1.
Master Helper remained 0. TAI values were 4979/4983 in separately read
PPS snapshots; this does not establish simultaneous time agreement.
The exact output is retained in `verification-dashboard.log`.

The available source/RXTS/time-valid tests passed: 13/13. A broader optional
suite initially could not import its Helper test because Pain's system
Python lacks tkinter; seven Windows-oriented tests were skipped there.
The complete source/observer tests had already passed on Laptop before
freezing (40 tests), and the dashboard/gate tests subsequently passed (20).
Optional Tk-backed tests require a Python installation with Tcl/Tk support.
This dependency is not required by the live Quartus dashboard.

No firmware compile, FPGA compile, programming, reset, physical power-cycle
or new 300-second capture was performed during packaging verification.
The hardware qualification remains the retained original 1190-row-per-board
capture. Rebuilding is supported by the unchanged entry scripts, but a new
build/session must earn its own runtime verdict. Packaging does not prove
universal startup repeatability or resolve the Master Helper limitation.

The previous source/bitstreams are retained as historical files. The protected
`04_WR_archive_step6_pass` directory was not accessed or changed.
