#!/bin/sh
# Subsystem scanner wrapper to support manual invocation.
# version 22.00
# Martin Denn <mdenn@de.ibm.com>, 2009-10-16
# $Id: mansub_scan.sh,v 1.5 2014/08/19 14:20:00 cvsdzmitry Exp $
# This script must reside in the same directory as subs_all.sh.
# Changelog:
# 12.00 2010-01-19 mdenn - added check for root
# 13.00 2010-01-19 mdenn - updated country list
# 13.01 2010-09-09 mdenn - new file name standard
# 2014-03-13 DF - fix for SUNOS. added default PATH to standard utilities

UOS="`uname|tr '[a-z]' '[A-Z]'`"
if [ $UOS = 'SUNOS' ]; then
PATH=/usr/xpg4/bin/:$PATH
fi

SH_LOCATION_TEST=`which sh`

if [ -z "$1" ]; then
  echo "USAGE: $0 cust_id" 1>&2
  echo "    where cust_id is either a customer id (preferred) or a valid" 1>&2
  echo "    ISO 3166-1 alpha-2 country code (like DE or FR)." 1>&2
  exit 1
fi
I_AM=`id | sed 's/^[^(]*(\([^)]*\)).*$/\1/'`
if [ "${I_AM}" != root ]; then
  echo "ERROR: you must be root to run this script." 1>&2
  exit 1
fi




CUST_ID="`echo $1|tr '[:lower:]' '[:upper:]'`"
CODES=":AC:AD:AE:AF:AG:AI:AL:AM:AN:AO:AQ:AR:AS:AT:AU:AW:AX:AZ:BA:BB:BD:BE:BF:BG:BH:BI:BJ:BL:BM:BN:BO:BR:BS:BT:BU:BV:BW:BY:BZ:CA:CC:CD:CF:CG:CH:CI:CK:CL:CM:CN:CO:CP:CR:CS:CU:CV:CX:CY:CZ:DE:DG:DJ:DK:DM:DO:DZ:EA:EC:EE:EG:EH:ER:ES:ET:EU:FI:FJ:FK:FM:FO:FR:FX:GA:GB:GD:GE:GF:GG:GH:GI:GL:GM:GN:GP:GQ:GR:GS:GT:GU:GW:GY:HK:HM:HN:HR:HT:HU:IC:ID:IE:IL:IM:IN:IO:IQ:IR:IS:IT:JE:JM:JO:JP:KE:KG:KH:KI:KM:KN:KP:KR:KW:KY:KZ:LA:LB:LC:LI:LK:LR:LS:LT:LU:LV:LY:MA:MC:MD:ME:MF:MG:MH:MK:ML:MM:MN:MO:MP:MQ:MR:MS:MT:MU:MV:MW:MX:MY:MZ:NA:NC:NE:NF:NG:NI:NL:NO:NP:NR:NT:NU:NZ:OM:PA:PE:PF:PG:PH:PK:PL:PM:PN:PR:PS:PT:PW:PY:QA:RE:RO:RS:RU:RW:SA:SB:SC:SD:SE:SF:SG:SH:SI:SJ:SK:SL:SM:SN:SO:SR:ST:SU:SV:SY:SZ:TA:TC:TD:TF:TG:TH:TJ:TK:TL:TM:TN:TO:TP:TR:TT:TV:TW:TZ:UA:UG:UK:UM:US:UY:UZ:VA:VC:VE:VG:VI:VN:VU:WF:WS:YE:YT:YU:ZA:ZM:ZR:ZW:"

CCODE=`echo ${CUST_ID} | sed 's/^\(..\).*$/\1/'`

if echo "${CUST_ID}" | grep '^..$' >/dev/null; then
  if echo "${CODES}" | grep ':'"${CUST_ID}"':' >/dev/null; then
    :
  else
    echo "ERROR: country_code \"${CUST_ID}\" is invalid. Please use a" 1>&2
    echo "    valid ISO 3166-1 alpha-2 code." 1>&2
    exit 1
  fi
else
    if echo "${CODES}" | grep ':'"${CCODE}"':' >/dev/null; then
    :
  else
    echo "ERROR: customer id \"${CUST_ID}\" is invalid. It must start" 1>&2
    echo "    with a valid ISO 3166-1 alpha-2 code." 1>&2
    exit 1
  fi
fi

TIMESTAMP=`date +%Y%m%d%H%M%S`
HOST=`uname -n`
COPYNAME=MAN-${CCODE}-${HOST}-${TIMESTAMP}.csv


SUBS_HOME=`dirname $0`
SUBS_HOME=`(cd "$SUBS_HOME"; pwd)`

"$SUBS_HOME"/subs_all.sh
sed -e 's/CUST_ID=[^;]*;/CUST_ID='"${CUST_ID}"';/'  "$SUBS_HOME"/subs_scanner_result.txt > $COPYNAME
echo Saving $COPYNAME
echo "SSL_ENABLED=${SSL_ENABLED}"
