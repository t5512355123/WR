Simple testbench which test the xwrf_loopback. For simulating with Riviera Pro, just change in Manifest.py the sim_tool="riviera". In case of Modelsim, change the sim_tool in Manifest.py and use the run_ci.do file.

For Riviera Pro run: 
  - `run_ci_riv.do` and use `wave_ci_riv.do`

For Modelsim run:
  - `run_ci.do` and use `wave.do`

Currently, for this testbench there are no check messages, but there is the opportunity to view the waveforms.

NOTE: Riviera-Pro, can run by default all the .do files that are used in Modelsim, but with this changes in these files, there is a reduce in the appearing warnings.
