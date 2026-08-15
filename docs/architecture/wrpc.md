# WRPC and Firmware

The embedded WRPC firmware is built from the vendored `vendor/wrpc-sw` source with the DE5a Master and Slave configurations in `firmware/configs/`. The generated MIF is a build product and is staged under `build/firmware/` before Quartus compilation.

The baseline Master and Slave MIF files are retained in `artifacts/EXP-BASELINE-RS422/` with their SHA256 values in the experiment metadata.
