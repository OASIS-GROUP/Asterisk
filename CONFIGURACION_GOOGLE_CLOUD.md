# Configuración en Google Cloud

## 🌐 Información del Servidor

- **IP Pública:** 35.226.73.203
- **Ubicación del HT813:** Red local (192.168.1.98)

## 📋 Cambios Realizados en la Configuración

### 1. Archivo: `asterisk/conf/pjsip.conf`

Se actualizaron las direcciones IP externas:
- `external_media_address=35.226.73.203`
- `external_signaling_address=35.226.73.203`

Se configuró el HT813 para registro dinámico (se conectará desde ubicación remota).

## 🔧 Configuración del Firewall en Google Cloud

Debes abrir los siguientes puertos en el firewall de Google Cloud:

### Puertos TCP:
```bash
# 5038  # AMI (Asterisk Manager Interface) - NO EXPONER, solo interno
5060  # SIP Signaling
8088  # ARI HTTP
8089  # ARI WebSocket
5001  # AVR Core (Opcional: puede ser solo interno)
6017  # AVR LLM Proxy (Opcional: puede ser solo interno)
```

### Puertos UDP:
```bash
5060       # SIP Signaling
10000-10050 # RTP Media (audio)
```

### Comando para crear reglas de firewall (ejecutar en Google Cloud Shell):

```bash
# Regla para puertos TCP (SIN puerto 5038 por seguridad)
gcloud compute firewall-rules create asterisk-tcp \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:5060,tcp:8088,tcp:8089 \
  --source-ranges=0.0.0.0/0

# Regla para puertos UDP (SIP y RTP)
gcloud compute firewall-rules create asterisk-udp \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=udp:5060,udp:10000-10050 \
  --source-ranges=0.0.0.0/0
```

## 📱 Configuración del Grandstream HT813

El HT813 (en 192.168.1.98) debe configurarse para conectarse al servidor en la nube:

### Configuración Web del HT813:

1. **Acceder al HT813:**
   - Navegar a: http://192.168.1.98
   - Usuario: admin
   - Contraseña: (tu contraseña)

2. **Configuración FXO PORT (perfil 1):**

   **SIP Server:**
   - Primary SIP Server: `35.226.73.203`
   - SIP Server Port: `5060`
   - SIP Transport: `TCP`

   **Autenticación:**
   - SIP User ID: `ht813`
   - Authenticate ID: `ht813`
   - Authenticate Password: `ht813password`
   - Name: `ht813`

   **NAT Settings:**
   - NAT Traversal: `Yes`
   - STUN Server: (dejar vacío o usar: `stun.l.google.com`)
   - Use NAT IP: (dejar vacío)
   - Keep-alive Interval: `20` segundos

   **Audio Settings:**
   - Preferred Vocoder: `PCMU`, `PCMA`, `GSM`
   - Use First Matching Vocoder: `Yes`

   **Advanced Settings:**
   - SIP Registration: `Yes`
   - Unregister On Reboot: `No`
   - Register Expiration: `3600` segundos
   - Outbound Proxy: (dejar vacío)
   - Local SIP port: `5060`

3. **Guardar y reiniciar el HT813**

## 🚀 Despliegue en Google Cloud

### 1. Conectarse al servidor:
```bash
gcloud compute ssh [NOMBRE_DE_TU_INSTANCIA] --zone=[TU_ZONA]
```

O usando SSH directo:
```bash
ssh usuario@35.226.73.203
```

### 2. Clonar el repositorio:
```bash
git clone git@github.com:OASIS-GROUP/Asterisk.git
cd Asterisk
```

### 3. Crear archivo de variables de entorno:

Crear un archivo `.env` con las siguientes variables:

```bash
# API Configuration
API_URL=https://dev.clipp.app/api/bot/client/call/message/566895
API_TOKEN=tu_token_aqui

# AMI Configuration
AMI_HOST=avr-asterisk
AMI_PORT=5038
AMI_USERNAME=avr
AMI_PASSWORD=avr

# Speech Configuration
SPEECH_LANGUAGE=es-US
TTS_LANGUAGE=es-US
TTS_GENDER=FEMALE
TTS_NAME=es-US-Neural2-A
TTS_SPEAKING_RATE=1.0
TTS_PITCH=0.0

# System Message
SYSTEM_MESSAGE=Hola, ¿cómo puedo ayudarte hoy?
```

### 4. Asegurar que existe el archivo google.json:

El archivo `google.json` debe contener las credenciales de Google Cloud para los servicios de Speech-to-Text y Text-to-Speech.

```bash
# Verificar que existe
ls -l google.json
```

### 5. Iniciar los servicios:
```bash
docker-compose -f docker-compose-custom-api.yml up -d
```

### 6. Verificar que los contenedores están corriendo:
```bash
docker-compose -f docker-compose-custom-api.yml ps
```

### 7. Ver logs en tiempo real:
```bash
docker-compose -f docker-compose-custom-api.yml logs -f
```

## 🔍 Verificación del Sistema

### Verificar que Asterisk está escuchando:
```bash
docker exec avr-asterisk asterisk -rx "pjsip show endpoints"
```

El HT813 debería aparecer como:
```
ht813                                      Not in use    0 of inf
```

### Verificar registro del HT813:
```bash
docker exec avr-asterisk asterisk -rx "pjsip show contacts"
```

Deberías ver algo como:
```
Contact:  ht813/sip:ht813@[IP_PUBLICA_HT813]:[PUERTO]   Avail   [TIEMPO]
```

### Verificar canales activos:
```bash
docker exec avr-asterisk asterisk -rx "core show channels"
```

### Ver logs de Asterisk:
```bash
docker exec avr-asterisk asterisk -rx "core set verbose 5"
docker-compose logs -f avr-asterisk
```

## 📞 Realizar Llamada de Prueba

1. **Desde un softphone SIP:**
   - Configurar extensión 1000
   - Server: `35.226.73.203:5060`
   - Usuario: `1000`
   - Contraseña: `1000`
   - Marcar: `5001`

2. **Desde línea telefónica conectada al HT813:**
   - El HT813 debería estar registrado en Asterisk
   - Las llamadas entrantes se procesarán automáticamente

## 🛠️ Troubleshooting

### El HT813 no se registra:
1. Verificar que los puertos están abiertos en el firewall de Google Cloud
2. Verificar que el HT813 puede alcanzar la IP 35.226.73.203:
   ```bash
   # Desde la red del HT813
   telnet 35.226.73.203 5060
   ```
3. Revisar logs del Asterisk:
   ```bash
   docker logs avr-asterisk
   ```

### No hay audio en las llamadas:
1. Verificar que los puertos UDP 10000-10050 están abiertos
2. Verificar la configuración de NAT en el HT813
3. Revisar logs de AVR Core:
   ```bash
   docker logs avr-core
   ```

### El LLM no responde:
1. Verificar que el API_URL es correcto
2. Verificar el API_TOKEN
3. Ver logs del proxy:
   ```bash
   docker logs avr-llm-proxy
   ```

## 🔄 Actualizar la Configuración

Si haces cambios en los archivos de configuración:

```bash
# Detener servicios
docker-compose -f docker-compose-custom-api.yml down

# Actualizar desde git (si es necesario)
git pull

# Reiniciar servicios
docker-compose -f docker-compose-custom-api.yml up -d

# Ver logs
docker-compose -f docker-compose-custom-api.yml logs -f
```

## 📊 Monitoreo

### Estado de los contenedores:
```bash
docker stats
```

### Uso de recursos:
```bash
docker system df
```

### Limpiar recursos no utilizados:
```bash
docker system prune -a
```

## 🔒 Seguridad

### Recomendaciones implementadas:
✅ El puerto AMI (5038) NO está expuesto públicamente - solo accesible internamente

### Recomendaciones adicionales:
1. Cambiar las contraseñas por defecto en `pjsip.conf`:
   - Password del usuario 1000: `1000`
   - Password del ht813: `ht813password`

2. Cambiar la contraseña del AMI en `manager.conf`:
   - Usuario: `avr`
   - Contraseña actual: `avr`

3. Limitar acceso por IP si es posible en el firewall

4. Usar certificados SSL/TLS para las conexiones SIP (SIPS)

5. Mantener el archivo `google.json` seguro (ya está en .gitignore)

6. Rotar el API_TOKEN periódicamente

7. Monitorear los logs regularmente para detectar intentos de acceso no autorizados

## 📝 Notas Adicionales

- El sistema está configurado para limpiar canales zombie automáticamente
- El timeout de llamadas está configurado a 600 segundos (10 minutos)
- Los archivos de caller ID se guardan temporalmente en `/tmp`
- El proxy LLM limpia el cache cada 30 minutos

