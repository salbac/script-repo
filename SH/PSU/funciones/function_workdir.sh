#!/bin/bash
ORACLE_BASE=/opt/oracle

#Funcion
#Escritura en LOG
function echolog(){
local LDATE=$(date "+%d-%m-%Y_%H:%M:%S")
local FLOG=InstPSU_$HOST-$LDATE.log
local LOG=$ORACLE_BASE/admin/work/APAR/LOG/$FLOG
local MSGLOG=$1
case "$MSGLOG" in
	INFO)
	echo "INFO@${LDATE}: $@"  | awk '{printf ("%s\n", $0);system("");}'  | tee -a ${LOG} >&2
	;;
	ERROR)
	echo "ERROR@${LDATE}: $@"  | awk '{printf ("%s\n", $0);system("");}' | tee -a ${LOG} >&2
	;;
	WARNING)
	echo "WARNING@${LDATE}: $@"  | awk '{printf ("%s\n", $0);system("");}' | tee -a ${LOG} >&2
	;;
esac
}

#Funcion que genera el directorio de trabajo.
function workdir(){
local LDATE=$(date "+%d-%m-%Y_%H:%M:%S")
local HOST=`hostname`
local FLOG=InstPSU_$HOST-$LDATE.log
local LOG=$ORACLE_BASE/admin/work/APAR/LOG/$FLOG

rm -rf $ORACLE_BASE/admin/work/APAR
#Condicionales que determinan si el directorio de trabajo existe.
if [ -d $ORACLE_BASE/admin/work ];
	then
		cd $ORACLE_BASE/admin/work
		mkdir APAR
		mkdir APAR/ENV
		mkdir APAR/DBPSU
		mkdir APAR/GIPSU
		mkdir APAR/BCK
		mkdir APAR/LOG
		mkdir APAR/REPO
		mkdir APAR/SQL
		chmod -R 750 APAR 
		touch APAR/LOG/$FLOG
		echolog INFO "Log file inicializado"
		echolog INFO "Directorio base creado en $ORACLE_BASE/admin/work/APAR"
		echolog INFO "Directorio de variables entorno creado en $ORACLE_BASE/admin/work/APAR/ENV"
		echolog INFO "Directorio de parche PSU Datbase creado en $ORACLE_BASE/admin/work/APAR/DBPSU"
		echolog INFO "Directorio de parche PSU Grid Infraestructure creado en $ORACLE_BASE/admin/work/APAR/GIPSU"
		echolog INFO "Directorio de backup creado en $ORACLE_BASE/admin/work/APAR/BCK"
		echolog INFO "Directorio de log creado en $ORACLE_BASE/admin/work/APAR/log"
		echolog INFO "Directorio de Repositorio creado en $ORACLE_BASE/admin/work/APAR/REPO"
		echolog INFO "Directorio de scripts sql creado en $ORACLE_BASE/admin/work/APAR/SQL"
	else
		exit 1
fi
}

workdir