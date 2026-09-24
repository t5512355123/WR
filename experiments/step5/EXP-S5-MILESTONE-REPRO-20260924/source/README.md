# Frozen Step 5 reproduction source candidate

This standalone source tree reproduces historical Step 5 source commit
`26e138fdc0bfc8426704b397141d563cf4d580a2`. The only later source overlay is the read-only F4L observer
and matching offline test from `47d9a394e53eda31476c82de2a85ad82573494ed`, which corrected the
300-second observer contract without changing firmware or RTL.

The old repository paths were relocated into the current layout. Only QSF and
top-level VHDL relative paths were changed; `SOURCE_MANIFEST.tsv` records each
historical Git blob, package path, transformation, and packaged SHA-256.
`../analysis/package_step5_source.py` verifies the source identity.

The JTAG build/program wrappers were copied byte-for-byte from the validated
Step 4 frozen package and are explicitly tooling, not Step 5 historical source.
Build products are generated under this package's ignored `build/` and
`quartus/output_files_*_jtag/` directories.

This is a candidate only. It becomes a formal Step 5 milestone only after
clean Master/Slave builds, programming both DE5a boards, and the required
continuous 300-second four-lock runtime validation.
