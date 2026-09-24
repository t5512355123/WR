# Rejected initial Master build

This build completed successfully in Quartus 17.0 Build 595, but its firmware
MIF embedded the enclosing repository's current version string rather than the
frozen Step 5 source version. The SOF was not programmed. The files here are
retained as diagnostic evidence for that provenance error.

Expected frozen version:
`master-diagnostic-baseline-20260817-1175-g26e138fd`

Embedded in this attempt's `master.bin`:
`master-diagnostic-baseline-20260817-1359-g59317b4d`

Historical Master MIF SHA-256:
`b1e65e19dbcee7f718d93eab72f9469b734be7065e404b56676dca56d9ff4efb`

This attempt's Master MIF SHA-256:
`a09861b7753f9267892f690e5b818688ea17f22d2432ebcd7cf8fe9b0273af10`

The next build pins the two upstream Make variables carrying this version
metadata. It must regenerate the MIF and both SOFs before any programming.
