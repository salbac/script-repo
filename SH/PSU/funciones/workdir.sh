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
