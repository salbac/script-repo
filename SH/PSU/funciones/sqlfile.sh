function sqlfile(){
echo "######################" >> $LOG
echo "#Creacion ficeros SQL#" >> $LOG
echo "######################" >> $LOG

cat <<-EOF > $SQLD/query_db_info.sql
		set serveroutput on;
	set verify on
	set termout on
	set feedback on
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
