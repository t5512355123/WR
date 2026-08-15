#! /bin/bash -x
PROTO=udp
#IP_ADR=10.16.10.11
IP_ADR="$1"
let utclo=0x`eb-read -p $PROTO/$IP_ADR 0x220308/4` # pps utc lo
let cycle=0x`eb-read -p $PROTO/$IP_ADR 0x220304/4` # pps cycle count

let later=utclo+5
eb-write -p $PROTO/$IP_ADR 0x140010/4 0 # utchi
eb-write -p $PROTO/$IP_ADR 0x140014/4 `printf 0x%x $later` #utclo
eb-write -p $PROTO/$IP_ADR 0x140018/4 `printf 0x%x $cycle` #cycle
eb-write -p $PROTO/$IP_ADR 0x14001C/4 0xffffffff # toggle led 0
eb-write -p $PROTO/$IP_ADR 0x140000/4 0 # enqueue command

let later=utclo+6
eb-write -p $PROTO/$IP_ADR 0x140010/4 0 # utchi
eb-write -p $PROTO/$IP_ADR 0x140014/4 `printf 0x%x $later` #utclo
eb-write -p $PROTO/$IP_ADR 0x140018/4 `printf 0x%x $cycle` #cycle
eb-write -p $PROTO/$IP_ADR 0x14001C/4 0xffffffff # toggle led 0
eb-write -p $PROTO/$IP_ADR 0x140000/4 0 # enqueue command

