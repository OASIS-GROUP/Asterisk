#!/bin/bash
# Script para limpiar canales zombie en Asterisk
# Solo limpia después de 8 minutos (mucho más conservador)

LOG_FILE="/tmp/asterisk-cleanup.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "Script de limpieza de canales iniciado (limpia después de 8 minutos)"

while true; do
    sleep 15
    
    # Obtener número de canales activos
    CHANNEL_COUNT=$(docker exec avr-asterisk asterisk -rx "core show channels concise" 2>/dev/null | grep -c "^PJSIP\|^AudioSocket")
    
    if [ "$CHANNEL_COUNT" -gt 0 ]; then
        # Obtener información detallada de canales
        CHANNEL_INFO=$(docker exec avr-asterisk asterisk -rx "core show channels verbose" 2>/dev/null)
        
        # Buscar canales con más de 8 minutos (00:08:00)
        # Formato: 00:08:XX o 00:09:XX o 00:1X:XX o más
        if echo "$CHANNEL_INFO" | grep -E "PJSIP|AudioSocket" | grep -qE "00:0[8-9]:|00:[1-9][0-9]:|0[1-9]:[0-9][0-9]:"; then
            log_message "⚠️  Detectados canales zombie con más de 8 minutos - Limpiando..."
            docker exec avr-asterisk asterisk -rx "channel request hangup all" >/dev/null 2>&1
            log_message "✓ Canales zombie limpiados"
            sleep 2
            
            # Verificar limpieza
            NEW_COUNT=$(docker exec avr-asterisk asterisk -rx "core show channels concise" 2>/dev/null | grep -c "^PJSIP\|^AudioSocket")
            log_message "Canales después de limpieza: $NEW_COUNT"
        fi
    fi
done
