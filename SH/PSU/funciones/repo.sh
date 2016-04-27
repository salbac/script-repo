#Funcion que conecta con el repositorio de software y copia el parche correspondiente segun los parametros de entrada
function repo(){
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
			cp $ORACLE_BASE/admin/work/APAR/REPO/p19955028_112040_Linux-x86-64.zip $ORACLE_BASE/admin/work/APAR/GIPSU/ 
			;;
			linux_11.2.0.4)
			cp $ORACLE_BASE/admin/work/APAR/REPO/p19955028_112040_LINUX.zip $ORACLE_BASE/admin/work/APAR/GIPSU/
			;;
			linux_11.2.0.3_64)
			cp $ORACLE_BASE/admin/work/APAR/REPO/p19971343_112030_Linux-x86-64.zip $ORACLE_BASE/admin/work/APAR/GIPSU/
			;;
			linux_11.2.0.3)
			cp $ORACLE_BASE/admin/work/APAR/REPO/p19971343_112030_LINUX.zip $ORACLE_BASE/admin/work/APAR/GIPSU/
			;;
		esac
	fi
}
