#!/bin/bash

###########
#VARIABLES#
###########

ORACLE_BASE=/opt/oracle
LDATE=$(date "+%d-%m-%Y_%H:%M:%S")
HOST=`hostname`
FLOG=InstPSU_$HOST-$LDATE.log
LOG=$ORACLE_BASE/admin/work/APAR/LOG/$FLOG
SQLD=$ORACLE_BASE/admin/work/APAR/SQL
BCKD=$ORACLE_BASE/admin/work/APAR/BCK
OSARCH=`uname -i`
DBBIN=`awk -F":" '{ print $2 | "sort -u" }' $ORACLE_BASE/admin/work/APAR/LOG/db.log`
GRID_HOME=`ps -ef | grep oraagent.bin | grep -v grep | awk '{print $8|"sort -u"}' | sed 's/\/bin\/oraagent.bin//g' | grep -v sed`
ORAINV=`cat /etc/oraInst.loc | grep oraInventory | awk -F"=" '{print $2}'`
###########
#FUNCTIONS#
###########

#Escritura en LOG
function echolog(){
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
umount /opt/oracle/admin/work/APAR/REPO
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
		chmod -R 777 APAR 
		touch APAR/LOG/$FLOG
		echolog INFO "Log file inicializado."
		echo "#################################" >> $LOG 
		echo "#Creacion directorios de trabajo#" >> $LOG
		echo "#################################" >> $LOG
		echolog INFO "Directorio base creado en $ORACLE_BASE/admin/work/APAR"
		echolog INFO "Directorio de variables entorno creado en $ORACLE_BASE/admin/work/APAR/ENV"
		echolog INFO "Directorio de parche PSU Datbase creado en $ORACLE_BASE/admin/work/APAR/DBPSU"
		echolog INFO "Directorio de parche PSU Grid Infraestructure creado en $ORACLE_BASE/admin/work/APAR/GIPSU"
		echolog INFO "Directorio de backup creado en $ORACLE_BASE/admin/work/APAR/BCK"
		echolog INFO "Directorio de log creado en $ORACLE_BASE/admin/work/APAR/LOG"
		echolog INFO "Directorio de Repositorio creado en $ORACLE_BASE/admin/work/APAR/REPO"
		echolog INFO "Directorio de scripts sql creado en $ORACLE_BASE/admin/work/APAR/SQL"
	else
		echo "El directorio de trabajo $ORACLE_BASE/admin/work no existe." > ./ERROR_$HOST-$LDATE.log
		exit 1
fi
}

function sqlfile(){
echo "######################" >> $LOG
echo "#Creacion ficeros SQL#" >> $LOG
echo "######################" >> $LOG

cat <<-EOF > $SQLD/query_db_info.sql
		set serveroutput on;
	set verify on
	set termout on
	set feedback off
	set linesize 130

	DECLARE
		ora_psu			varchar2(20);
		ora_version		varchar2(10);
		ora_rac			varchar2(10);
		ora_dg			varchar2(10);
		ora_dg_type		varchar2(10);
	BEGIN
	---
	--- PSU
	---
	SELECT * INTO ora_psu FROM (SELECT comments FROM sys.registry\$history WHERE bundle_series = 'PSU' ORDER BY action_time) psu WHERE ROWNUM <= 1 ORDER BY rownum;
	---
	--- VERSION
	---
	SELECT version INTO ora_version FROM v\$instance;
	---
	---RAC
	---
	SELECT value INTO ora_rac FROM v\$parameter WHERE name='cluster_database';
	---
	---Data Guard
	---
	SELECT value INTO ora_dg FROM v\$parameter WHERE name='dg_broker_start';
	---
	---Data Guard TYPE
	---
	SELECT database_role INTO ora_dg_type FROM v\$database;
	---
	--- PRINT 
	---
	dbms_output.put_line(ora_psu||':'||ora_version||':'||ora_rac||':'||ora_dg||':'||ora_dg_type);
	
	---
	END;
	/
	exit;
	EOF
chmod 777 $SQLD/query_db_info.sql
if [ -a $SQLD/query_db_info.sql ];
	then
	echolog INFO "Fichero SQL query_db_info.sql generado correctamente"
	else
	echolog ERROR "Fallo al crear query_db_info.sql"
	exit 1
fi
}

function envfile(){
#Variable que contiene todas las BBDD levantadas 
local ALL_DATABASES=`ps -ef |grep ora_pmon |grep -v grep | awk '{print $8}' |cut -c 10-`

echo "##########################################" >> $LOG
echo "#Creacion ficeros de variables de entorno#" >> $LOG
echo "##########################################" >> $LOG

for DB in $ALL_DATABASES
do
	#Variables que extraen la informacion necesaria para generar el ENV por cada BBDD
	local VUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
	local VPID=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $2}'`
	local VORACLE_HOME=`pwdx "$VPID"| sed 's/\/dbs//g' | cut -d ":" -f 2 | cut -c 2-`
	local UPATH=`runuser -l "$VUSER" -c "echo "$PATH""` 
	local VPATH=$VORACLE_HOME/bin:$UPATH
	local VORACLE_BASE=`df -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $6}'`
	local ENVFILE=$ORACLE_BASE/admin/work/APAR/ENV/$DB.env
	#Creacion de fichero ENV por cada BBDD
	touch $ORACLE_BASE/admin/work/APAR/ENV/$DB.env
	chmod 777 $ORACLE_BASE/admin/work/APAR/ENV/$DB.env
	echo export ORACLE_SID=$DB >>$ENVFILE
	echo export ORACLE_HOME=$VORACLE_HOME >>$ENVFILE
	echo export PATH=$VPATH >>$ENVFILE
	echo export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib >>$ENVFILE
	echo export ORACLE_BASE=/opt/oracle >>$ENVFILE
	#Control errores
	if [ -a $ENVFILE ];
	then
	echolog INFO "Fichero ENV generado para la BBDD $DB"
	else
	echolog ERROR "Fallo al crear ficher ENV para la BBDD $DB"
	exit 1
	fi
	#Creacion fichero info BBDD
	runuser -l $VUSER -c ". ${ENVFILE} ; sqlplus -s / as sysdba @$ORACLE_BASE/admin/work/APAR/SQL/query_db_info.sql" > $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log
	DBVERSION=`awk -F ":" '{print $2}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	DBPSU=`awk -F ":" '{print $1}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	RAC=`awk -F ":" '{print $3}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	DATAGUARD=`awk -F ":" '{print $4}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	DATAGUARDTYPE=`awk -F ":" '{print $5}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	OPATCHVERSION=`runuser -l $VUSER -c "$VORACLE_HOME/OPatch/opatch version | cut -d ":" -f 2| sed 's/OPatch succeeded.//g' | awk 'NF > 0'"`
	touch $ORACLE_BASE/admin/work/APAR/LOG/db.log
	chmod 777 $ORACLE_BASE/admin/work/APAR/LOG/db.log
	echo "$DB:$VORACLE_HOME:$DBVERSION:$DBPSU:$OPATCHVERSION:$RAC:$DATAGUARD:$DATAGUARDTYPE:$VUSER" >> $ORACLE_BASE/admin/work/APAR/LOG/db.log	
done
}

function repo(){
echo "######################" >> $LOG				
echo "#Descarga de parches #" >> $LOG
echo "######################" >> $LOG
local PATCH=$1
local PTYPE=$2 
mount cosysdbt02:/mnt/REPOSITORIO /opt/oracle/admin/work/APAR/REPO
if [ $PTYPE = DB ];
	then
		case $PATCH in #Parches DB
			linux_11.2.0.4_64)
			cp $ORACLE_BASE/admin/work/APAR/REPO/p19769489_112040_Linux-x86-64.zip $ORACLE_BASE/admin/work/APAR/DBPSU/ 
			;;
			linux_11.2.0.4)
			cp $ORACLE_BASE/admin/work/APAR/REPO/p19769489_112040_LINUX.zip $ORACLE_BASE/admin/work/APAR/DBPSU/
			;;
			linux_11.2.0.3_64)
			cp $ORACLE_BASE/admin/work/APAR/REPO/p19769496_112030_Linux-x86-64.zip $ORACLE_BASE/admin/work/APAR/DBPSU/
			;;
			linux_11.2.0.3)
			cp $ORACLE_BASE/admin/work/APAR/REPO/p19769496_112030_LINUX.zip $ORACLE_BASE/admin/work/APAR/DBPSU/
			;;
		esac
	else
		case $PATCH in #Parches Grid Infraestructure
			linux_11.2.0.4_64)
			cp $ORACLE_BASE/admin/work/APAR/REPO/.zip $ORACLE_BASE/admin/work/APAR/GIPSU/ 
			;;
			linux_11.2.0.4)
			cp $ORACLE_BASE/admin/work/APAR/REPO/.zip $ORACLE_BASE/admin/work/APAR/GIPSU/
			;;
			linux_11.2.0.3_64)
			cp $ORACLE_BASE/admin/work/APAR/REPO/.zip $ORACLE_BASE/admin/work/APAR/GIPSU/
			;;
			linux_11.2.0.3)
			cp $ORACLE_BASE/admin/work/APAR/REPO/.zip $ORACLE_BASE/admin/work/APAR/GIPSU/
			;;
		esac
	fi
}

#Backup Binarios Oracle 
function bckora(){
	#Variables funcion
	local BINARY_TYPE=$1
	#Seleccion tipo de backup
	case "$BINARY_TYPE" in
		DB)
		echolog "Iniciando backup de los binarios de BBDD."
		cd $ORACLE_HOME
		tar -c ./ | gzip -c > $BCKDIR/ora_"$BINARY_TYPE"_soft_$DBVERSION_`hostname`_`date +%Y%m%d`.tar.gz
			if [ $? = 0 ];
			then
				echolog INFO "Backup de los binarios de BBDD finalizado."
			else
				echolog ERROR "Fallo en el backup de los binarios de BBDD."
			fi
		;;
		GI)
		echolog "Iniciando backup de los binarios de Grid Infraestructure."
		cd $GRID_HOME
		tar -c ./ | gzip -c > $BCKD/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.tar.gz
			if [ $? = 0 ];
			then
				echolog INFO "Backup de los binarios de Grid Infraestructure finalizado"
			else
				echolog "Fallo en el backup de los binarios de Grid Infraestructure."
			fi
		;;
		OI)
		echolog "Iniciando backup de Oracle Inventory."
		cd $ORAINV
		tar -c ./ | gzip -c > $BCKD/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.tar.gz
			#echo $?
			if [ $? = 0 ];
			then
				echolog INFO "Backup del Oracle Inventory finalizado";
			else
				echolog ERROR "Fallo en el backup del Oracle Inventory.";
			fi
		;;
		OCR)
		echolog INFO "Iniciando backup de la configuracion del Oracle Cluster Registry."
		$GRID_HOME/bin/ocrconfig -export $BCKD/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.ocr
			if [ $? = 0 ];
			then
				echolog INFO "Backup de la configuracion Oracle Cluster Registry finalizado"
			else
				echolog ERROR "Fallo en el backup de la configuracion Oracle Cluster Registry."
			fi
		;;
	esac
}
#Funcion prerequisitos
function prereq(){
#Variables
local USER=$1
local ORACLE_HOME=$2
local PATCH=$3
#Prerequisitos
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -oh $ORACLE_HOME -phBaseDir $PATCH
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -oh $ORACLE_HOME -phBaseDir $PATCH
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -oh $ORACLE_HOME -phBaseDir $PATCH
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -oh $ORACLE_HOME -phBaseDir $PATCH
}

######
#MAIN#
######

#Creacion directorio de trabajo
workdir
#Creacion SQL files
sqlfile
#Creacion ENV file
envfile	
#Copia PSU DB
for HBIN in $DBBIN
do
DBVERSION=`grep $HBIN $ORACLE_BASE/admin/work/APAR/LOG/db.log | awk -F":" '{ print $3 }' `
if [[ $DBVERSION = 11.2.0.4 && $OSARCH = x86_64 ]];
	then
	repo linux_11.2.0.4_64 DB
	else
	if [[ $DBVERSION = 11.2.0.4 && $OSARCH = i386 ]];
		then
		repo linux_11.2.0.4 DB
		else
		if [[ $DBVERSION = 11.2.0.3 && $OSARCH = x86_64 ]];
			then
			repo linux_11.2.0.3_64 DB
			else
			if [[ $DBVRSION = 11.2.0.3 && $OSARCH = i386 ]];
			then
			repo linux_11.2.0.3_64 DB
			fi
		fi
	fi
fi
done
#Copia PSU GI
for HBIN in $DBBIN
do
DBVERSION=`grep $HBIN $ORACLE_BASE/admin/work/APAR/LOG/db.log | awk -F":" '{ print $3 }' `
if [[ $DBVERSION = 11.2.0.4 && $OSARCH = x86_64 ]];
	then
	repo linux_11.2.0.4_64 GI
	else
	if [[ $DBVERSION = 11.2.0.4 && $OSARCH = i386 ]];
		then
		repo linux_11.2.0.4 GI
		else
		if [[ $DBVERSION = 11.2.0.3 && $OSARCH = x86_64 ]];
			then
			repo linux_11.2.0.3_64 GI
			else
			if [[ $DBVRSION = 11.2.0.3 && $OSARCH = i386 ]];
			then
			repo linux_11.2.0.3_64 GI
			fi
		fi
	fi
fi
done
#Backup OCR
#if [ $RAC = TRUE ];
#	then bckora OCR
#	fi
#Backup OraInventory
#bckora OI
#Backup Grid
#if [ -n $GRID_HOME ];
#	then bckora GI
#	fi
#bckora Orabin
#for n in $DBBIN
#do
#bckora DB
#done
#Prerequisitos 
ALL_OH=
for OH in $ALL_OH  
do
local VUSER=`cat db.log | grep $OH | awk -F ":" '{print $9}'`
prereq $VUSER $OH /opt/oracle/admin/work/APAR/
done
