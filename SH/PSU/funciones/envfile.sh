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
#	DBVERSION=`awk -F ":" '{print $2}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	DBVERSION=11.2.0.3
	DBPSU=`awk -F ":" '{print $1}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	RAC=`awk -F ":" '{print $3}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	DATAGUARD=`awk -F ":" '{print $4}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	DATAGUARDTYPE=`awk -F ":" '{print $5}' $ORACLE_BASE/admin/work/APAR/SQL/query_db_info.log`
	OPATCHVERSION=`runuser -l $VUSER -c "$VORACLE_HOME/OPatch/opatch version | cut -d ":" -f 2| sed 's/OPatch succeeded.//g' | awk 'NF > 0'"`
	touch $ORACLE_BASE/admin/work/APAR/LOG/db.log
	chmod 777 $ORACLE_BASE/admin/work/APAR/LOG/db.log
	echo "$DB:$VORACLE_HOME:$DBVERSION:$DBPSU:$OPATCHVERSION:$RAC:$DATAGUARD:$DATAGUARDTYPE" >> $ORACLE_BASE/admin/work/APAR/LOG/db.log	
done
}
