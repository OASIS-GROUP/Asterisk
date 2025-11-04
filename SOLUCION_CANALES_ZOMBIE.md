# Solución al Problema de Canales Zombie en Asterisk

## 📋 Resumen del Problema

Los canales de llamadas en Asterisk no se estaban eliminando correctamente cuando finalizaba una llamada, causando canales "zombie" que permanecían activos indefinidamente.

## ✅ Soluciones Implementadas

### 1. **Mejoras en el Dialplan (`asterisk/conf/extensions.conf`)**

Se agregaron las siguientes mejoras:

- **Timeout Absoluto**: Se configuró un timeout de 600 segundos (10 minutos) para evitar llamadas infinitas
  ```
  Set(TIMEOUT(absolute)=600)
  ```

- **Opciones de Dial Mejoradas**: 
  - `120` - Timeout de 120 segundos para el Dial
  - `g` - Continuar en el dialplan después del Dial
  - `K` - Permitir que el llamador cuelgue con DTMF
  - `k` - Permitir que el llamado cuelgue con DTMF

- **Handler de Hangup**: Se agregó un handler específico para capturar eventos de colgado
  ```
  exten => h,1,NoOp(Hangup handler - cleaning up call)
  ```

### 2. **Configuración de Timeouts RTP en PJSIP (`asterisk/conf/pjsip.conf`)**

Se agregaron configuraciones de timeout para detectar cuando una llamada se ha desconectado:

```ini
rtp_timeout=60              # Timeout de 60 segundos sin paquetes RTP
rtp_timeout_hold=300        # Timeout de 5 minutos en hold
rtp_keepalive=15            # Enviar keepalive cada 15 segundos
timers=yes                  # Habilitar timers SIP
timers_min_se=90           # Mínimo session-expires
timers_sess_expires=1800   # Session expires de 30 minutos
```

Estos parámetros se aplicaron tanto al `endpoint-template` como al endpoint específico del `ht813`.

### 3. **Servicio de Monitoreo Automático (Docker Compose)**

Se agregó un nuevo servicio `avr-channel-monitor` que:

- Monitorea continuamente los canales de Asterisk
- Detecta cuando una llamada finaliza
- Espera 3 segundos para que Asterisk limpie naturalmente
- Si detecta canales zombie, los limpia automáticamente
- Se reinicia automáticamente si falla
- Genera logs detallados en `/tmp/asterisk-cleanup.log`

```yaml
avr-channel-monitor:
  image: docker:24-cli
  container_name: avr-channel-monitor
  restart: always
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - ./asterisk/cleanup-on-hangup.sh:/cleanup-on-hangup.sh
  command: sh /cleanup-on-hangup.sh
```

### 4. **Script de Limpieza Mejorado (`asterisk/cleanup-on-hangup.sh`)**

Mejoras implementadas:

- ✅ Manejo de errores robusto
- ✅ Logs con emojis para mejor visualización
- ✅ Detección inteligente de hangups (no interfiere con llamadas activas)
- ✅ Limpieza selectiva de canales zombie
- ✅ Reintentos automáticos en caso de fallo
- ✅ Notificaciones de nuevas llamadas y finalizaciones

### 5. **Configuración AVR Core Mejorada**

Se agregaron variables de entorno para mejor manejo de desconexiones:

```yaml
- CALL_END_DELAY=500              # Delay al finalizar llamada
- CLEANUP_ON_DISCONNECT=true      # Limpiar al desconectar
- FORCE_HANGUP_ON_ERROR=true      # Forzar hangup en errores
- MAX_CALL_DURATION=600           # Duración máxima de llamada
```

### 6. **Script de Verificación (`asterisk/check-channels.sh`)**

Nuevo script para verificar el estado de los canales manualmente:

```bash
./asterisk/check-channels.sh
```

Muestra:
- Número total de canales activos
- Canales PJSIP y AudioSocket separados
- Detalles de cada canal
- Últimas entradas del log de limpieza

## 🚀 Cómo Aplicar las Soluciones

### Paso 1: Detener los servicios actuales

```bash
docker-compose -f docker-compose-custom-api.yml down
```

### Paso 2: Aplicar permisos a los scripts

```bash
chmod +x asterisk/cleanup-on-hangup.sh
chmod +x asterisk/cleanup-channels.sh
chmod +x asterisk/check-channels.sh
chmod +x clean-calls.sh
```

### Paso 3: Reiniciar los servicios

```bash
docker-compose -f docker-compose-custom-api.yml up -d
```

### Paso 4: Verificar que el monitor está funcionando

```bash
# Ver logs del monitor
docker logs -f avr-channel-monitor

# O verificar el archivo de log
tail -f /tmp/asterisk-cleanup.log
```

## 📊 Monitoreo y Verificación

### Ver estado de canales en tiempo real

```bash
./asterisk/check-channels.sh
```

### Ver logs del monitor de canales

```bash
docker logs -f avr-channel-monitor
```

### Ver logs de limpieza

```bash
tail -f /tmp/asterisk-cleanup.log
```

### Limpiar canales manualmente (si es necesario)

```bash
./clean-calls.sh
```

### Verificar todos los contenedores

```bash
docker-compose -f docker-compose-custom-api.yml ps
```

## 🔍 Qué Esperar

### Comportamiento Normal

Cuando una llamada finaliza, verás en los logs:

```
[2025-11-03 10:30:15] 📞 Nueva llamada detectada (canales: 0 → 2)
[2025-11-03 10:32:20] 📞 Detección: Llamada finalizada (canales: 2 → 0)
[2025-11-03 10:32:23] ✅ Todas las llamadas finalizadas - Sistema limpio
```

### Si se detectan canales zombie

```
[2025-11-03 10:32:20] 📞 Detección: Llamada finalizada (canales: 2 → 1)
[2025-11-03 10:32:23] ⚠️  Detectados 1 canales zombie después del hangup - Limpiando...
[2025-11-03 10:32:23]   🔨 Colgando canal: PJSIP/ht813-00000001
[2025-11-03 10:32:25] ✅ Limpieza completada - Canales restantes: 0
```

## 🛠️ Troubleshooting

### Los canales siguen sin limpiarse

1. Verificar que el monitor está corriendo:
   ```bash
   docker ps | grep avr-channel-monitor
   ```

2. Revisar los logs del monitor:
   ```bash
   docker logs avr-channel-monitor
   ```

3. Verificar que el socket de Docker está montado correctamente

4. Reiniciar el servicio de monitor:
   ```bash
   docker-compose -f docker-compose-custom-api.yml restart avr-channel-monitor
   ```

### El monitor no puede conectarse a Asterisk

1. Verificar que Asterisk está corriendo:
   ```bash
   docker ps | grep avr-asterisk
   ```

2. Verificar la red de Docker:
   ```bash
   docker network inspect avr
   ```

3. Reiniciar Asterisk:
   ```bash
   docker-compose -f docker-compose-custom-api.yml restart avr-asterisk
   ```

### Las llamadas se cortan prematuramente

Si las llamadas se están cortando antes de tiempo, puedes ajustar:

1. **En `extensions.conf`**: Aumentar el timeout del Dial
   ```
   Dial(AudioSocket/${ARG1}/${UUID},300,gKk)  # 300 segundos = 5 minutos
   ```

2. **En `pjsip.conf`**: Aumentar los timeouts RTP
   ```ini
   rtp_timeout=120              # 2 minutos
   rtp_timeout_hold=600         # 10 minutos
   ```

3. **En `docker-compose-custom-api.yml`**: Ajustar timeouts del AVR Core
   ```yaml
   - MAX_CALL_DURATION=1200     # 20 minutos
   - SESSION_TIMEOUT=900        # 15 minutos
   ```

## 📈 Métricas Recomendadas

Para monitorear la efectividad de la solución:

1. **Número de canales zombie detectados** (debería disminuir a 0)
2. **Tiempo de limpieza** (debería ser < 5 segundos)
3. **Llamadas exitosas vs llamadas con problemas**
4. **Logs de errores en Asterisk**

## 🎯 Beneficios de la Solución

- ✅ **Limpieza automática**: No requiere intervención manual
- ✅ **No invasiva**: Solo actúa cuando detecta problemas
- ✅ **Logs detallados**: Fácil diagnóstico de problemas
- ✅ **Alta disponibilidad**: Se reinicia automáticamente si falla
- ✅ **Bajo overhead**: Solo se activa cuando es necesario
- ✅ **Múltiples capas**: Protección en el dialplan, PJSIP y monitoreo externo

## 📞 Soporte

Si sigues experimentando problemas:

1. Recopila los logs:
   ```bash
   docker logs avr-asterisk > asterisk.log
   docker logs avr-channel-monitor > monitor.log
   docker logs avr-core > core.log
   ```

2. Verifica el estado del sistema:
   ```bash
   ./asterisk/check-channels.sh > status.txt
   ```

3. Revisa los archivos de configuración para asegurar que los cambios se aplicaron correctamente

