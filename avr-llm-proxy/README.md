# AVR LLM Proxy

Este es un servicio proxy simple que actúa como orquestador entre AVR Core y tu API externa.

## ¿Qué hace?

1. Recibe el texto transcrito del usuario desde AVR Core
2. Lo envía a tu API externa (el recurso que maneja el flujo de conversación)
3. Devuelve la respuesta de tu API a AVR Core
4. AVR Core convierte la respuesta en voz para el usuario

## Configuración

### 1. Variables de entorno

Crea un archivo `.env` con:

```env
# API Key de Deepgram
DEEPGRAM_API_KEY=tu_key_aqui

# URL de tu API externa
API_URL=http://tu-api.com/endpoint
API_METHOD=POST  # o GET

# Opcional: Headers adicionales para tu API
API_HEADERS={"Authorization":"Bearer token"}
```

### 2. Ejecutar

```bash
docker-compose -f docker-compose-custom-api.yml up -d
```

## Formato de la API

Tu API debe aceptar POST requests con este formato:

```json
{
  "message": "Texto que dijo el usuario",
  "conversation_id": "ID de la conversación",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

Y debe responder con:

```json
{
  "response": "Respuesta que se le dirá al usuario"
}
```

O simplemente:

```json
{
  "message": "Respuesta que se le dirá al usuario"
}
```

## Flujo completo

```
Usuario habla → ASR (Deepgram) → Texto → LLM Proxy → Tu API
                                                                ↓
Usuario escucha ← TTS (Deepgram) ← Audio ← AVR Core ← Respuesta
```

## Personalización

Si necesitas personalizar el formato de la petición o respuesta, edita `avr-llm-proxy/server.js`.


