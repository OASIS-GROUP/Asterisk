# 🚀 Instrucciones Rápidas - Solución Canales Zombie

## ⚡ Inicio Rápido

### 1️⃣ Reiniciar el Sistema con las Mejoras

```bash
cd /Users/angels/Documents/Clipp-SAS/Docker/avr-infra

# Detener servicios actuales
docker-compose -f docker-compose-custom-api.yml down

# Iniciar con las nuevas configuraciones
docker-compose -f docker-compose-custom-api.yml up -d
```

### 2️⃣ Verificar que Todo Funciona

```bash
# Ver todos los contenedores (deberías ver avr-channel-monitor)
docker-compose -f docker-compose-custom-api.yml ps

# Ver logs del monitor de canales
docker logs -f avr-channel-monitor
```

Deberías ver algo como:
```
🔍 Monitor de hangup iniciado - limpia solo después de detectar finalizaciones
```

### 3️⃣ Monitorear Durante una Llamada

Mientras haces una llamada de prueba, en otra terminal ejecuta:

```bash
# Ver estado en tiempo real
./asterisk/check-channels.sh

# O ver los logs del monitor
tail -f /tmp/asterisk-cleanup.log
```

## 📊 Comandos Útiles

### Ver Estado Actual de Canales
```bash
./asterisk/check-channels.sh
```

### Limpiar Canales Manualmente (Emergencia)
```bash
./clean-calls.sh
```

### Ver Logs de Limpieza
```bash
tail -f /tmp/asterisk-cleanup.log
```

### Ver Logs de Asterisk
```bash
docker logs -f avr-asterisk
```

### Ver Logs del Monitor
```bash
docker logs -f avr-channel-monitor
```

### Reiniciar Solo el Monitor
```bash
docker-compose -f docker-compose-custom-api.yml restart avr-channel-monitor
```

## ✅ Qué Cambió

### Archivos Modificados:
- ✏️ `asterisk/conf/extensions.conf` - Agregado handler de hangup y timeouts
- ✏️ `asterisk/conf/pjsip.conf` - Agregados timeouts RTP
- ✏️ `docker-compose-custom-api.yml` - Agregado servicio de monitoreo
- ✏️ `asterisk/cleanup-on-hangup.sh` - Mejorado el script de limpieza

### Archivos Nuevos:
- ✨ `asterisk/check-channels.sh` - Script para verificar estado
- ✨ `SOLUCION_CANALES_ZOMBIE.md` - Documentación completa
- ✨ `INSTRUCCIONES_RAPIDAS.md` - Este archivo

## 🎯 Prueba Completa

1. **Hacer una llamada de prueba**
   - Llama a tu extensión configurada
   - Habla durante 10-15 segundos
   - Cuelga la llamada

2. **Verificar limpieza automática**
   ```bash
   ./asterisk/check-channels.sh
   ```
   
   Deberías ver:
   ```
   ✅ No hay canales activos - Sistema limpio
   ```

3. **Revisar el log**
   ```bash
   tail -20 /tmp/asterisk-cleanup.log
   ```
   
   Deberías ver algo como:
   ```
   [2025-11-03 16:45:10] 📞 Nueva llamada detectada (canales: 0 → 2)
   [2025-11-03 16:45:25] 📞 Detección: Llamada finalizada (canales: 2 → 0)
   [2025-11-03 16:45:28] ✅ Todas las llamadas finalizadas - Sistema limpio
   ```

## ⚠️ Problemas Comunes

### "El monitor no está corriendo"
```bash
docker-compose -f docker-compose-custom-api.yml restart avr-channel-monitor
```

### "Los canales siguen sin limpiarse"
```bash
# 1. Ver logs del monitor
docker logs avr-channel-monitor

# 2. Verificar conectividad
docker exec avr-asterisk asterisk -rx "core show channels"

# 3. Limpiar manualmente
./clean-calls.sh
```

### "Llamadas se cortan muy rápido"
Editar `docker-compose-custom-api.yml` y aumentar:
```yaml
- MAX_CALL_DURATION=1200    # 20 minutos en lugar de 10
- SESSION_TIMEOUT=900        # 15 minutos
```

Luego reiniciar:
```bash
docker-compose -f docker-compose-custom-api.yml restart avr-core
```

## 📞 Contacto / Ayuda

Si necesitas más ayuda, revisa el archivo `SOLUCION_CANALES_ZOMBIE.md` para documentación completa y troubleshooting detallado.

---

**✨ Solución implementada el 3 de Noviembre, 2025**

