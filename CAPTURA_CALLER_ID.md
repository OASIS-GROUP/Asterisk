# Captura de Número del Llamante

## 📞 ¿Qué hace?

El sistema ahora captura automáticamente el número de teléfono de quien está llamando y lo envía a tu API junto con cada mensaje.

## 🔧 Implementación

### 1. Asterisk (extensions.conf)
```
Set(UUID=${SHELL(uuidgen | tr -d '\n')})
Set(CALLER_NUM=${CALLERID(num)})
Set(CALLER_NAME=${CALLERID(name)})
NoOp(Caller ID: ${CALLER_NUM} - ${CALLER_NAME})
Set(RESULT=${SHELL(/etc/asterisk/save-caller-id.sh ${UUID} ${CALLER_NUM})})
Dial(AudioSocket/${ARG1}/${UUID},120,gKk)
```

Asterisk:
- Captura el **número del llamante** (`CALLERID(num)`)
- Captura el **nombre del llamante** (`CALLERID(name)`)
- Guarda el número en un archivo temporal usando el UUID como clave
- El archivo se guarda en el volumen compartido `/tmp` entre contenedores

### 2. Script Bash (save-caller-id.sh)
```bash
#!/bin/bash
UUID=$1
CALLER_NUM=$2
CALLER_FILE="/tmp/callerid-${UUID}.txt"
echo "${CALLER_NUM}" > "${CALLER_FILE}"
find /tmp/ -name "callerid-*.txt" -mmin +60 -delete
```

El script:
- Guarda el caller ID en `/tmp/callerid-{UUID}.txt`
- Limpia automáticamente archivos antiguos (>1 hora)

### 3. Docker Compose
```yaml
volumes:
  shared-tmp:
    driver: local

avr-asterisk:
  volumes:
    - ./asterisk/save-caller-id.sh:/etc/asterisk/save-caller-id.sh
    - shared-tmp:/tmp

avr-llm-proxy:
  volumes:
    - shared-tmp:/tmp
```

- Volumen compartido `/tmp` entre Asterisk y LLM Proxy
- Permite la comunicación de datos entre contenedores

### 4. Proxy LLM (server.js)
```javascript
const { message, uuid, callerid, caller_number, from } = req.body;
const fs = require('fs');

// Leer el número del archivo temporal
let callerNumber = callerid || caller_number || from || 'unknown';
if (uuid) {
    const callerIdFile = `/tmp/callerid-${uuid}.txt`;
    if (fs.existsSync(callerIdFile)) {
        callerNumber = fs.readFileSync(callerIdFile, 'utf8').trim();
        fs.unlinkSync(callerIdFile); // Limpiar después de leer
    }
}

const requestData = {
    phone: process.env.CLIPP_PHONE || '593985059132',
    text: message,
    caller_number: callerNumber,  // ← Número del llamante
    conversation_id: uuid
};
```

El proxy:
- Lee el número del llamante desde el archivo temporal
- Lo envía a tu API en cada request
- Limpia el archivo después de leerlo
- Lo registra en los logs

## 📡 Datos que Recibe tu API

Cada vez que el usuario habla, tu API recibe:

```json
{
  "phone": "593985059132",           // Tu número/bot (configurado en CLIPP_PHONE)
  "text": "hola, necesito ayuda",    // Lo que dijo el usuario
  "caller_number": "+593987654321",  // ← Número de quien llama
  "conversation_id": "uuid-único"    // ID de la conversación
}
```

## 🎯 Casos de Uso

### 1. Identificar al Usuario
```javascript
// En tu API
if (caller_number === '+593987654321') {
    return "Hola Juan, ¿en qué puedo ayudarte?";
}
```

### 2. Consultar Base de Datos
```javascript
const user = await database.findByPhone(caller_number);
if (user) {
    return `Hola ${user.name}, veo que tienes una orden pendiente...`;
}
```

### 3. Registro de Llamadas
```javascript
await callLogs.create({
    phone: caller_number,
    message: text,
    timestamp: new Date(),
    conversation_id: conversation_id
});
```

### 4. Integraciones CRM
```javascript
// Buscar en Salesforce, HubSpot, etc.
const contact = await crm.findContact(caller_number);
const history = await crm.getCallHistory(caller_number);
```

## 🔍 Debugging

### Ver el número del llamante en los logs:
```bash
docker logs -f avr-llm-proxy
```

Verás algo como:
```
📥 Received from AVR Core: { 
  message: 'hola', 
  uuid: 'abc-123', 
  callerNumber: '+593987654321' 
}
```

### Usar el endpoint de debug:
```bash
curl http://localhost:6017/debug
```

### Probar con un número específico:
Cuando hagas una llamada desde tu celular o línea telefónica, el sistema automáticamente capturará el número.

## ⚠️ Consideraciones

### Números Bloqueados/Privados
Si alguien llama con número oculto:
- `caller_number` será: `"anonymous"`, `"unknown"`, `"restricted"` o similar
- Tu API debe manejar estos casos

### Formato de Números
Los números pueden venir en diferentes formatos:
- `"+593987654321"` (internacional)
- `"0987654321"` (nacional)
- `"987654321"` (sin prefijo)

Recomendación: Normalizar en tu API usando una librería como `libphonenumber`

### Privacidad
El número del llamante es información personal. Asegúrate de:
- Cumplir con GDPR/LOPD
- No almacenar sin consentimiento
- Encriptar en base de datos
- Tener política de privacidad clara

## 🚀 Activar los Cambios

```bash
cd /Users/angels/Documents/Clipp-SAS/Docker/avr-infra

# Reiniciar servicios
docker-compose -f docker-compose-custom-api.yml restart avr-asterisk avr-llm-proxy

# O reiniciar todo
docker-compose -f docker-compose-custom-api.yml down
docker-compose -f docker-compose-custom-api.yml up -d
```

## 📝 Ejemplo Completo en tu API

```javascript
app.post('/api/bot/client/call/message/566895', async (req, res) => {
    const { phone, text, caller_number, conversation_id } = req.body;
    
    console.log(`Llamada de: ${caller_number}`);
    console.log(`Mensaje: ${text}`);
    
    // Buscar usuario en DB
    const user = await User.findOne({ phone: caller_number });
    
    let response;
    if (user) {
        // Usuario conocido
        response = `Hola ${user.name}! ` + await processKnownUser(text, user);
    } else {
        // Usuario nuevo
        response = await processNewUser(text, caller_number);
    }
    
    // Guardar log
    await CallLog.create({
        caller: caller_number,
        bot: phone,
        message: text,
        response: response,
        conversation_id: conversation_id,
        timestamp: new Date()
    });
    
    res.json({ message: response });
});
```

## ✅ Verificación

Para verificar que está funcionando:

1. Hacer una llamada al sistema
2. Decir algo
3. Revisar los logs: `docker logs -f avr-llm-proxy`
4. Deberías ver el número del llamante en la línea que dice "📥 Received from AVR Core"
5. Tu API debería recibir el `caller_number` en cada request

---

**Fecha de implementación:** 3 de Noviembre, 2025  
**Archivos modificados/creados:**
- `asterisk/conf/extensions.conf` - Captura del CALLERID
- `asterisk/save-caller-id.sh` - Script para guardar caller ID
- `avr-llm-proxy/server.js` - Lectura del caller ID
- `docker-compose-custom-api.yml` - Volumen compartido /tmp

