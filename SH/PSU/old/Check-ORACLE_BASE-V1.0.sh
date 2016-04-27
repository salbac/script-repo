#!/bin/bash
#----------------------------------------------------------------------------
#--     Id: Check-ORACLE_BASE-V1.0 2015-08-17
#----------------------------------------------------------------------------
#--     IT Now
#--
#----------------------------------------------------------------------------
#--     File-Name........:  Check-ORACLE_BASE-V1.0.sh
#--     Author...........:  Sergio Alba
#--     Editor...........:  Sergio Alba
#--     Date.............:  2015-08-26
#--     Revision.........:  0
#--     Purpose..........:  Comprueba que el directorio BASE de Oracle coincide con el standard /opt/oracle y que tamaño tiene.
#--     Usage............:  ./Check-ORACLE_BASE-V1.0.sh
#--     Group/Privileges.:  root
#--     Input parameters.:  ninguno
#--     Called by........:  -
#--     Restrictions.....:  -
#--     Notes............:
#----------------------------------------------------------------------------
#--              Revision history:
#----------------------------------------------------------------------------
#Declaracion de variables
        ALL_DATABASES=`ps -ef |grep ora_pmon |grep -v grep | awk '{print $8}' |cut -c 10-`
#Bucle
for DB in $ALL_DATABASES
do
#Variable Bucle
        VUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
        VPID=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $2}'`
        VORACLE_HOME=`pwdx "$VPID"| sed 's/\/dbs//g' | cut -d ":" -f 2 | cut -c 2-`
        VORACLE_BASE=`df -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $6}'`
        VSAIZ=`df -h -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $2}'`
        VBASE="/opt/oracle"
#Evaluacion de la condicion 
        if [ "$VORACLE_BASE" = "$VBASE" ];
        then
        echo "El directorio BASE de Oracle para el SID $DB es correcto."
        echo "Su tamaño es de $VSAIZ"
        else
        echo "El directorio BASE de Oracle para el SID $DB no es el correcto."
        fi
done

