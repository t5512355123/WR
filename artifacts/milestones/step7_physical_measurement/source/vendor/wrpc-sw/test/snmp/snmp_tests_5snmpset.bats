load snmp_test_config
load snmp_test_helpers

@test "set wrpcPtpConfigDeltaTx" {
  helper_snmpset wrpcPtpConfigDeltaTx.0 141415
  helper_snmpget wrpcPtpConfigDeltaTx.0 141415
}

@test "set read only wrpcSpllHlock" {
  run snmpset $SNMP_OPTIONS $TARGET_IP wrpcSpllHlock.0 = 141415
  [ "$status" -eq 2 ]
}

@test "set wrpcPtpConfigDeltaTx with two different values" {
  helper_snmpset wrpcPtpConfigDeltaTx.0 141415
  helper_snmpget wrpcPtpConfigDeltaTx.0 141415
  helper_snmpset wrpcPtpConfigDeltaTx.0 151516
  helper_snmpget wrpcPtpConfigDeltaTx.0 151516
}

@test "set wrpcPtpConfigDeltaRx with two different values" {
  helper_snmpset wrpcPtpConfigDeltaRx.0 141416
  helper_snmpget wrpcPtpConfigDeltaRx.0 141416
  helper_snmpset wrpcPtpConfigDeltaRx.0 151517
  helper_snmpget wrpcPtpConfigDeltaRx.0 151517
}

@test "set wrpcPtpConfigAlpha with two different values" {
  helper_snmpset wrpcPtpConfigAlpha.0 141417
  helper_snmpget wrpcPtpConfigAlpha.0 141417
  helper_snmpset wrpcPtpConfigAlpha.0 151518
  helper_snmpget wrpcPtpConfigAlpha.0 151518
}

@test "set wrpcPtpConfigSfpPn with two different values" {
  helper_snmpset wrpcPtpConfigSfpPn.0 "TEST sfp"
  helper_snmpget wrpcPtpConfigSfpPn.0 "TEST sfp"
  helper_snmpset wrpcPtpConfigSfpPn.0 "sfp other"
  helper_snmpget wrpcPtpConfigSfpPn.0 "sfp other"
}

@test "set wrpcPtpConfigSfpPn with empty value" {
  helper_snmpset wrpcPtpConfigSfpPn.0 ""
  helper_snmpget wrpcPtpConfigSfpPn.0 ""
}

@test "set wrpcPtpConfigSfpPn with too long value (error from host)" {
  # set known value first
  helper_snmpset wrpcPtpConfigSfpPn.0 "TEST sfp1"
  # set too long, bad length (error from snmpget program)
  run snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigSfpPn.0 = "0123456789012345678"
  [ "$status" -eq 1 ]
  # expect value to be not changed
  helper_snmpget wrpcPtpConfigSfpPn.0 "TEST sfp1"
}

@test "set wrpcPtpConfigSfpPn with too long value (error from target)" {
  # set known value first
  helper_snmpset wrpcPtpConfigSfpPn.0 "TEST sfp2"
  # set too long, bad length (error from target)
  run snmpset $SNMP_OPTIONS_NO_M $TARGET_IP .1.3.6.1.4.1.96.101.1.6.3.0 s "0123456789012345678"
  echo $status
  [ "$status" -eq 2 ]
  # expect value to be not changed
  helper_snmpget wrpcPtpConfigSfpPn.0 "TEST sfp2"
}

@test "set wrong type of wrpcPtpConfigSfpPn" {
  # set known value first
  helper_snmpset wrpcPtpConfigSfpPn.0 "TEST sfp3"
  # set too long, bad length (error from target)
  run snmpset $SNMP_OPTIONS_NO_M $TARGET_IP .1.3.6.1.4.1.96.101.1.6.3.0 i "012345678"
  echo $status
  [ "$status" -eq 2 ]
  # expect value to be not changed
  helper_snmpget wrpcPtpConfigSfpPn.0 "TEST sfp3"
}

@test "erase sfp database" {
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = eraseFlash | grep applySuccessful | wc -l)"
  [ "$result" -eq 1 ]
}

@test "erase sfp database test helper" {
  helper_erase_sfp_database
}

@test "add sfp with invalid PN to the database" {
  # Empty PN is invalid

  # erase database first
  helper_erase_sfp_database
  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "11112"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "11113"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "11114"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 ""
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep "applyFailedInvalidPN" | wc -l)"
  [ "$result" -eq 1 ]
}

@test "add sfp to the database" {
  # erase database first
  helper_erase_sfp_database
  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 1234
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 4343
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 1258
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashCurrentSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]
}


@test "add 3 sfps to the database" {
  # following entries should be written to the database
  # sfp show
  # 1: PN:test PN1         dTx:    11112 dRx:    11113 alpha:    11114
  # 2: PN:test PN2         dTx:    22223 dRx:    22224 alpha:    22225
  # 3: PN:test PN3         dTx:    33334 dRx:    33335 alpha:    33336

  # erase database first
  helper_erase_sfp_database
  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "11112"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "11113"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "11114"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN1"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  echo $result
  [ "$result" -eq 1 ]

  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "22223"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "22224"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "22225"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN2"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "33334"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "33335"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "33336"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN3"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  # check the sfp database content
  helper_snmpget wrpcSfpPn.1 "test PN1"
  helper_snmpget wrpcSfpDeltaTx.1 "11112"
  helper_snmpget wrpcSfpDeltaRx.1 "11113"
  helper_snmpget wrpcSfpAlpha.1 "11114"
  helper_snmpget wrpcSfpPn.2 "test PN2"
  helper_snmpget wrpcSfpDeltaTx.2 "22223"
  helper_snmpget wrpcSfpDeltaRx.2 "22224"
  helper_snmpget wrpcSfpAlpha.2 "22225"
  helper_snmpget wrpcSfpPn.3 "test PN3"
  helper_snmpget wrpcSfpDeltaTx.3 "33334"
  helper_snmpget wrpcSfpDeltaRx.3 "33335"
  helper_snmpget wrpcSfpAlpha.3 "33336"
}


@test "add 4 sfps to the database (one to much)" {
  # following entries should be written to the database, 4th should generate error
  # sfp show
  # 1: PN:test PN1         dTx:    11112 dRx:    11113 alpha:    11114
  # 2: PN:test PN2         dTx:    22223 dRx:    22224 alpha:    22225
  # 3: PN:test PN3         dTx:    33334 dRx:    33335 alpha:    33336

  # erase database first
  helper_erase_sfp_database
  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "11112"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "11113"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "11114"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN1"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "22223"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "22224"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "22225"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN2"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "33334"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "33335"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "33336"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN3"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "44445"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "44446"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "44447"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN4"
  # add sfp to the database, it is full now. "applyFailedI2CError" is returned when SFPS_MAX is more than SDBFS can actually keep
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applyFailedDBFull" -e "applyFailedI2CError" | wc -l)"
  snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp > aaa.txt

  [ "$result" -eq 1 ]

  helper_snmpget wrpcSfpPn.1 "test PN1"
  helper_snmpget wrpcSfpDeltaTx.1 "11112"
  helper_snmpget wrpcSfpDeltaRx.1 "11113"
  helper_snmpget wrpcSfpAlpha.1 "11114"
  helper_snmpget wrpcSfpPn.2 "test PN2"
  helper_snmpget wrpcSfpDeltaTx.2 "22223"
  helper_snmpget wrpcSfpDeltaRx.2 "22224"
  helper_snmpget wrpcSfpAlpha.2 "22225"
  helper_snmpget wrpcSfpPn.3 "test PN3"
  helper_snmpget wrpcSfpDeltaTx.3 "33334"
  helper_snmpget wrpcSfpDeltaRx.3 "33335"
  helper_snmpget wrpcSfpAlpha.3 "33336"
}


@test "add 3 sfps to the database, test replacement" {
  # following entries should be written to the database, 4th should replace second entry
  # unfortunately it is not possible to verify these entries now via snmp (edit: it is possible)
  # sfp show
  # 1: PN:test PN1         dTx:    11112 dRx:    11113 alpha:    11114
  # 2: PN:test PN2         dTx:    99991 dRx:    99992 alpha:    99993
  # 3: PN:test PN3         dTx:    33334 dRx:    33335 alpha:    33336

  # erase database first
  helper_erase_sfp_database
  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "11112"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "11113"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "11114"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN1"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "22223"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "22224"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "22225"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN2"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "33334"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "33335"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "33336"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN3"
  # add sfp to the database, we don't care if match was successful
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  #set delta TX for SFP
  helper_snmpset wrpcPtpConfigDeltaTx.0 "99991"
  #set delta RX for SFP
  helper_snmpset wrpcPtpConfigDeltaRx.0 "99992"
  #set delta Alpha for SFP
  helper_snmpset wrpcPtpConfigAlpha.0 "99993"
  #set PN of SFP
  helper_snmpset wrpcPtpConfigSfpPn.0 "test PN2"
  # add sfp to the database, it is full now
  result="$(snmpset $SNMP_OPTIONS $TARGET_IP wrpcPtpConfigApply.0 = writeToFlashGivenSfp | grep -e "applySuccessful" -e "applySuccessfulMatchFailed" | wc -l)"
  [ "$result" -eq 1 ]

  helper_snmpget wrpcSfpPn.1 "test PN1"
  helper_snmpget wrpcSfpDeltaTx.1 "11112"
  helper_snmpget wrpcSfpDeltaRx.1 "11113"
  helper_snmpget wrpcSfpAlpha.1 "11114"
  helper_snmpget wrpcSfpPn.2 "test PN2"
  helper_snmpget wrpcSfpDeltaTx.2 "99991"
  helper_snmpget wrpcSfpDeltaRx.2 "99992"
  helper_snmpget wrpcSfpAlpha.2 "99993"
  helper_snmpget wrpcSfpPn.3 "test PN3"
  helper_snmpget wrpcSfpDeltaTx.3 "33334"
  helper_snmpget wrpcSfpDeltaRx.3 "33335"
  helper_snmpget wrpcSfpAlpha.3 "33336"
}

