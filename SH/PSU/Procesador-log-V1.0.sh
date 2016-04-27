#!/bin/bash
#----------------------------------------------------------------------------
#--     Id: Procesador-log-V1.0 2015-09-03
#----------------------------------------------------------------------------
#--     IT Now
#--
#----------------------------------------------------------------------------
#--     File-Name........:  Procesador-log-V1.0.sh
#--     Author...........:  Sergio Alba
#--     Editor...........:  Sergio Alba
#--     Date.............:  2015-09-03
#--     Revision.........:  1
#--     Purpose..........:  Unifica los diferentes logs y sql en un solo fichero.
#--     Usage............:  ./Procesador-log-V1.0.sh
#--     Group/Privileges.:  root
#--     Input parameters.:  ninguno
#--     Called by........:  -
#--     Restrictions.....:  -
#--     Notes............:
#----------------------------------------------------------------------------
#--     Revision history: 
#----------------------------------------------------------------------------

#Control esxistencia ficheros de output
if [ -a ORA_FS.log ];
	then
		rm -rf ORA_FS.log
	fi
if [ -a ORA_FS.sql ];
	then
		rm -rf ORA_FS.sql		
	fi
#Variables del bucle
ALL_LOG=`ls -l *.log | awk '{print $9}'`
ALL_SQL=`ls -l *.sql | awk '{print $9}'`
#Bucle unificacion log
for LOG in $ALL_LOG
	do
	cat $LOG >> ORA_FS.log
	done
#Bucle unificacion sql
for SQL in $ALL_SQL
	do
	cat $SQL >> ORA_FS.sql
	done
	