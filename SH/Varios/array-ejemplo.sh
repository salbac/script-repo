#!/bin/bash

declare -a MyArray

MyArray=(Jose Sergio Fran Javi Miguel Silvia)

echo "
Contenifdo de la Array MyArray:
${MyArray[*]}
Registro 1:
${MyArray[0]}
Registro 2:
${MyArray[1]}
Registro 3:
${MyArray[2]}
Registro 4:
${MyArray[3]}
Registro 5:
${MyArray[4]}
Registro 6:
${MyArray[5]}
Numero de registros:
${#MyArray[@]}
"


