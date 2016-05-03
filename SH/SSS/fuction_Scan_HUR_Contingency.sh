function Scan_HUR_Contingency {
  #Variables
  ASM_SID=`ps -ef | grep asm_pmon | grep -v grep | awk '{print $8}' | awk -F "_" '{print $3}'`
  ASM_PID=`ps -ef | grep asm_pmon | grep -v grep | awk '{print $2}'`
  ASM_HOME=`pwdx $ASM_PID | awk -F ": " '{print $2}' | awk -F "/" '{print $1 "/"$2 "/"$3 "/"$4}'`
  ASM_USER=`ps -ef | grep asm_pmon | grep -v grep | awk '{print $1}'`
  SQLPLUS=$ASM_HOME/bin/sqlplus
  RUNUSER=/sbin/runuser
  LSDG=`cat <<EOF `

  #Main

}
