#!/bin/bash
# Script para guardar el Caller ID usando el UUID como clave

UUID=$1
CALLER_NUM=$2
CALLER_FILE="/tmp/callerid-${UUID}.txt"

# Guardar el número del llamante
echo "${CALLER_NUM}" > "${CALLER_FILE}"

# Limpiar archivos antiguos (más de 1 hora)
find /tmp/ -name "callerid-*.txt" -mmin +60 -delete 2>/dev/null

exit 0

