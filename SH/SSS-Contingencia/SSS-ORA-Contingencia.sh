#!/bin/bash
#----------------------------------------------------------------------------
#--     Id:
#----------------------------------------------------------------------------
#--
#--
#----------------------------------------------------------------------------
#--     File-Name........:  SSS-ORA-Contingencia.sh
#--     Author...........:  Sergio Alba
#--     Editor...........:  Sergio Alba
#--     Date.............:  2/5/2016
#--     Revision.........:
#--     Purpose..........:  Deteccion servidores con Oracle en contingencia por HUR
#--     Usage............:  SSS-ORA-Contingencia.sh
#--     Group/Privileges.:  root
#--     Input parameters.:  Nada
#--     Called by........:
#--     Restrictions.....:
#--     Notes............:
#----------------------------------------------------------------------------
#--		 Revision history:
#----------------------------------------------------------------------------

###########
#Variables#
###########
ASM_SID=`ps -ef | grep asm_pmon | grep -v grep | awk '{print $8}' | awk -F "_" '{print $3}'`
ASM_PID=`ps -ef | grep asm_pmon | grep -v grep | awk '{print $2}'`
ASM_HOME=`pwdx $ASM_PID | awk -F ": " '{print $2}' | awk -F "/" '{print $1 "/"$2 "/"$3 "/"$4}'`
ASM_USER=`ps -ef | grep asm_pmon | grep -v grep | awk '{print $1}'`
TEMPDIR=`mktemp -d "/tmp/XXXXXXX"`
ENVFILE=$TEMPDIR/asm.env
LSDG=$TEMDIR/lsdg.sql

######
#MAIN#
######
chmod -R 777 $TEMPDIR
touch $TEMPDIR/asm.env
touch $TEMPDIR/lsdg.sql
touch $TEMPDIR/lsdg.log
chmod 777 $TEMPDIR/*.*

cat <<EOF >>$ENVFILE
export ORACLE_SID=$ASM_SID
export ORACLE_HOME=$ASM_HOME
EOF

cat <<EOF >>$LSDG
select name, state, type, total_mb, free_mb from v$asm_diskgroup;
exit;
EOF

#/sbin/runuser -l $ASM_USER -c ". ${ENVFILE} ; $ASM_HOME/bin/sqlplus -s / as sysdba @$TEMDIR/lsdg.sql" > $TEMFILE/lsdg.log
