#!/bin/bash
#----------------------------------------------------------------------------
#--     Id: Check-ORACLE_BASE-V1.0 2015-08-17
#----------------------------------------------------------------------------
#--     IT Now
#--
#----------------------------------------------------------------------------
#--     File-Name........:  Check-ORACLE_BASE-V1.1.sh
#--     Author...........:  Sergio Alba
#--     Editor...........:  Sergio Alba
#--     Date.............:  2015-08-26
#--     Revision.........:  1
#--     Purpose..........:  Comprueba que el directorio BASE de Oracle coincide con el standard /opt/oracle y que tamaño tiene.
#--     Usage............:  ./Check-ORACLE_BASE-V1.1.sh
#--     Group/Privileges.:  root
#--     Input parameters.:  ninguno
#--     Called by........:  -
#--     Restrictions.....:  -
#--     Notes............:
#----------------------------------------------------------------------------
#--     Revision history: SA Extraccio punto de montaje para comprobar si el disco es fisico o cabina.
#----------------------------------------------------------------------------
#Declaracion de variables
ALL_DATABASES=`ps -ef |grep ora_pmon |grep -v grep | awk '{print $8}' |cut -c 10-`
VHOST=`hostname`
VLOG=$VHOST.log
VSQL=$VHOST.sql
#Bucle
for DB in $ALL_DATABASES
do
#Variable Bucle
        VUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
        VPID=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $2}'`
        VORACLE_HOME=`pwdx "$VPID"| sed 's/\/dbs//g' | cut -d ":" -f 2 | cut -c 2-`
        VORACLE_BASE=`df -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $6}'`
        VSAIZ=`df -h -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $2}'`
        VMP=`cat /etc/fstab | grep /opt/oracle | sed 1q | awk '{print $1}'`
echo "HOSTNAME= $VHOST BASE= $VORACLE_BASE SAIZ= $VSAIZ PUNTO_MONTAJE= $VMP" >> $VLOG
echo "INSERT INTO cocoloco (HOSTNAME,BASE,SAIZ,PUNTO_MONTAJE) VALUES ('$VHOST','$VORACLE_BASE','$VSAIZ','$VMP');" >> $VSQL
done
