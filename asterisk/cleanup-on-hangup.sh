#!/bin/sh
# Script inteligente: limpia canales zombie SOLO cuando detecta un hangup
# No interfiere con llamadas activas normales
# Compatible con sh (no requiere bash)

LOG_FILE="/tmp/asterisk-cleanup.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "🔍 Monitor de hangup iniciado - limpia solo después de detectar finalizaciones"

# Variable para rastrear el conteo anterior de canales
PREV_COUNT=0

# Contador de intentos fallidos
FAILED_ATTEMPTS=0
MAX_FAILED_ATTEMPTS=5

while true; do
    sleep 3
    
    # Obtener número actual de canales con manejo de errores
    CHANNEL_OUTPUT=$(docker exec avr-asterisk asterisk -rx "core show channels concise" 2>&1)
    EXEC_STATUS=$?
    
    # Verificar si el comando docker exec falló (código de salida != 0)
    if [ $EXEC_STATUS -ne 0 ]; then
        FAILED_ATTEMPTS=$((FAILED_ATTEMPTS + 1))
        if [ "$FAILED_ATTEMPTS" -ge "$MAX_FAILED_ATTEMPTS" ]; then
            log_message "⚠️  No se puede conectar con Asterisk después de $FAILED_ATTEMPTS intentos"
            FAILED_ATTEMPTS=0
            sleep 30
        fi
        continue
    fi
    
    FAILED_ATTEMPTS=0
    
    # Contar canales
    CURRENT_COUNT=$(echo "$CHANNEL_OUTPUT" | grep -E "^PJSIP|^AudioSocket" | wc -l)
    # Limpiar espacios
    CURRENT_COUNT=$(echo "$CURRENT_COUNT" | tr -d ' ')
    # Asegurar que sea un número
    case "$CURRENT_COUNT" in
        ''|*[!0-9]*) CURRENT_COUNT=0 ;;
    esac
    
    # Si el conteo disminuyó (indicando que una llamada terminó)
    if [ "$PREV_COUNT" -gt "$CURRENT_COUNT" ] && [ "$CURRENT_COUNT" -gt 0 ]; then
        log_message "📞 Detección: Llamada finalizada (canales: $PREV_COUNT → $CURRENT_COUNT)"
        
        # Esperar 3 segundos para que Asterisk limpie naturalmente
        sleep 3
        
        # Verificar si todavía hay canales (serían zombie)
        ZOMBIE_OUTPUT=$(docker exec avr-asterisk asterisk -rx "core show channels concise" 2>/dev/null)
        ZOMBIE_COUNT=$(echo "$ZOMBIE_OUTPUT" | grep -E "^PJSIP|^AudioSocket" | wc -l | tr -d ' ')
        case "$ZOMBIE_COUNT" in
            ''|*[!0-9]*) ZOMBIE_COUNT=0 ;;
        esac
        
        if [ "$ZOMBIE_COUNT" -gt 0 ]; then
            log_message "⚠️  Detectados $ZOMBIE_COUNT canales zombie después del hangup - Limpiando..."
            
            # Obtener lista de canales
            CHANNELS=$(echo "$ZOMBIE_OUTPUT" | grep -E "^PJSIP|^AudioSocket" | cut -d'!' -f1)
            
            if [ -n "$CHANNELS" ]; then
                # Colgar cada canal específicamente
                echo "$CHANNELS" | while IFS= read -r channel; do
                    if [ -n "$channel" ]; then
                        log_message "  🔨 Colgando canal: $channel"
                        docker exec avr-asterisk asterisk -rx "channel request hangup $channel" >/dev/null 2>&1
                        sleep 0.5
                    fi
                done
                
                sleep 2
                FINAL_OUTPUT=$(docker exec avr-asterisk asterisk -rx "core show channels concise" 2>/dev/null)
                FINAL_COUNT=$(echo "$FINAL_OUTPUT" | grep -E "^PJSIP|^AudioSocket" | wc -l | tr -d ' ')
                case "$FINAL_COUNT" in
                    ''|*[!0-9]*) FINAL_COUNT=0 ;;
                esac
                log_message "✅ Limpieza completada - Canales restantes: $FINAL_COUNT"
            else
                log_message "⚠️  No se pudieron obtener canales para limpiar"
            fi
        else
            log_message "✅ Llamada finalizada correctamente - No hay canales zombie"
        fi
    fi
    
    # Si el conteo bajó a cero
    if [ "$PREV_COUNT" -gt 0 ] && [ "$CURRENT_COUNT" -eq 0 ]; then
        log_message "✅ Todas las llamadas finalizadas - Sistema limpio"
    fi
    
    # Si el conteo aumentó (nueva llamada)
    if [ "$CURRENT_COUNT" -gt "$PREV_COUNT" ]; then
        log_message "📞 Nueva llamada detectada (canales: $PREV_COUNT → $CURRENT_COUNT)"
    fi
    
    PREV_COUNT=$CURRENT_COUNT
done
