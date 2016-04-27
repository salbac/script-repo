#FUNCIONES

#Funcion que crea un fichero con las variables de entorno que necesita ORACLE
#Parametros de entrara SID de la BD y path donde dejara el fichero
#El fichero generado sera SID.env

function oracle_env_file(){
#Parametros de entrada
DB=$1
RDIR=$2
#Variables
DBPID=`ps -ef | grep pmon_"$DB" | grep -v grep | awk '{print $2}'`
DBUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
OB=`cat /etc/oraInst.loc | grep inventory_loc | awk -F "=" '{print $2}' | sed 's/\/oraInventory//g'`
OH=`pwdx "$DBPID" | cut -d ":" -f 2 | sed 's/ \//\//g' | sed 's/\/dbs//g'`
ENVF=$RDIR/$DB.env
#Creacion fichero env`
touch $ENVF
chmod 777 $ENVF
cat <<-EOF >$ENVF
export ORACLE_SID=$DBPID
export ORACLE_BASE=$OB
export ORACLE_HOME=$OH
EOF
}