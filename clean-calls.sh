#!/bin/bash
# Script para limpiar manualmente todas las llamadas activas en Asterisk

echo "Verificando canales activos..."
docker exec avr-asterisk asterisk -rx "core show channels"

read -p "¿Deseas colgar todos los canales activos? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]
then
    echo "Colgando todos los canales..."
    docker exec avr-asterisk asterisk -rx "channel request hangup all"
    sleep 2
    echo ""
    echo "Canales después de la limpieza:"
    docker exec avr-asterisk asterisk -rx "core show channels"
fi

