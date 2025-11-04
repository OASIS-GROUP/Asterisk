#!/bin/bash
# Script para verificar el estado de los canales en Asterisk

echo "════════════════════════════════════════════════════════════════"
echo "   Estado de Canales Asterisk"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Verificar si el contenedor está corriendo
if ! docker ps | grep -q avr-asterisk; then
    echo "❌ Error: El contenedor avr-asterisk no está ejecutándose"
    exit 1
fi

echo "📊 Resumen de Canales:"
echo "────────────────────────────────────────────────────────────────"
TOTAL_CHANNELS=$(docker exec avr-asterisk asterisk -rx "core show channels concise" 2>/dev/null | grep -v "^0 active" | wc -l)
PJSIP_CHANNELS=$(docker exec avr-asterisk asterisk -rx "core show channels concise" 2>/dev/null | grep -c "^PJSIP" || echo "0")
AUDIOSOCKET_CHANNELS=$(docker exec avr-asterisk asterisk -rx "core show channels concise" 2>/dev/null | grep -c "^AudioSocket" || echo "0")

echo "  Total de canales activos: $TOTAL_CHANNELS"
echo "  Canales PJSIP: $PJSIP_CHANNELS"
echo "  Canales AudioSocket: $AUDIOSOCKET_CHANNELS"
echo ""

if [ "$TOTAL_CHANNELS" -gt 0 ]; then
    echo "📋 Detalles de Canales:"
    echo "────────────────────────────────────────────────────────────────"
    docker exec avr-asterisk asterisk -rx "core show channels verbose" 2>/dev/null
    echo ""
    
    echo "🔍 Información Concisa:"
    echo "────────────────────────────────────────────────────────────────"
    docker exec avr-asterisk asterisk -rx "core show channels concise" 2>/dev/null | grep -E "^PJSIP|^AudioSocket"
    echo ""
else
    echo "✅ No hay canales activos - Sistema limpio"
    echo ""
fi

# Verificar logs de limpieza
if [ -f /tmp/asterisk-cleanup.log ]; then
    echo "📝 Últimas 10 entradas del log de limpieza:"
    echo "────────────────────────────────────────────────────────────────"
    tail -n 10 /tmp/asterisk-cleanup.log
    echo ""
fi

echo "════════════════════════════════════════════════════════════════"

