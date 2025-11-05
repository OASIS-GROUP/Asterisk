const express = require('express');
const axios = require('axios');
const bodyParser = require('body-parser');

const app = express();
const PORT = process.env.PORT || 6017;
// const API_URL = process.env.API_URL || 'https://dev.clipp.app/api/bot/client/call/message/566895';  //DESARROLLO
const API_URL = process.env.API_URL || 'https://api.clipp.app/api/bot/client/call/message/566897';   //PRODUCCION
const API_METHOD = process.env.API_METHOD || 'POST';
const API_TOKEN = process.env.API_TOKEN || '';

// Cache para mantener el callerNumber durante toda la conversación
const callerCache = new Map();

// Limpiar cache cada 30 minutos para evitar memory leaks
setInterval(() => {
    const now = Date.now();
    for (const [uuid, data] of callerCache.entries()) {
        // Eliminar entradas más antiguas de 30 minutos
        if (now - data.timestamp > 30 * 60 * 1000) {
            callerCache.delete(uuid);
            console.log(`🧹 Limpiando caller cache para UUID: ${uuid}`);
        }
    }
}, 5 * 60 * 1000); // Revisar cada 5 minutos

app.use(bodyParser.json());
app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

app.post('/prompt-stream', async (req, res) => {
    try {
        const { message, uuid, callerid, caller_number, from } = req.body;
        const fs = require('fs');
        const path = require('path');

        let callerNumber = callerid || caller_number || from || null;

        if (uuid && callerCache.has(uuid)) {
            callerNumber = callerCache.get(uuid).number;
        } else if (uuid) {
            const callerIdFile = `/tmp/callerid-${uuid}.txt`;
            try {
                if (fs.existsSync(callerIdFile)) {
                    callerNumber = fs.readFileSync(callerIdFile, 'utf8').trim();
                }
            } catch (err) {
                console.log('⚠️ No se pudo leer el archivo de caller ID:', err.message);
            }
        }

        if (!callerNumber) {
            callerNumber = 'unknown';
        }

        const originalCallerNumber = callerNumber;
        if (callerNumber && callerNumber !== 'unknown' && callerNumber.startsWith('0')) {
            callerNumber = '593' + callerNumber.substring(1);
            console.log(`📞 Número normalizado: ${originalCallerNumber} → ${callerNumber}`);
        }

        if (uuid && callerNumber !== 'unknown') {
            callerCache.set(uuid, {
                number: callerNumber,
                timestamp: Date.now()
            });
            console.log(`💾 Número guardado en cache para UUID: ${uuid}`);
        }

        console.log('📥 Received from AVR Core:', { message, uuid, callerNumber });


        const trimmedMessage = message.trim();
        const MIN_LENGTH = 2;

        if (!trimmedMessage || trimmedMessage.length < MIN_LENGTH) {

            const errorResponse = {
                type: "text",
                content: "No te entendí bien, ¿puedes repetirlo por favor?",
                conversation_id: uuid || null
            };

            console.log('✅ Sending repeat request:', errorResponse);
            res.json(errorResponse);
            return;
        }

        const requestData = {
            phone: callerNumber,
            text: message,
            conversation_id: uuid
        };

        console.log('📤 Sending to external API:', requestData);

        try {
            const headers = {
                'Content-Type': 'application/json'
            };
            if (API_TOKEN) {
                headers['Authorization'] = `Bearer ${API_TOKEN}`;
            }

            const axiosConfig = {
                headers: headers,
                timeout: 30000
            };

            let apiResponse = await axios.post(API_URL, requestData, axiosConfig);

            let responseText = "";

            if (apiResponse.data.message) {
                responseText = apiResponse.data.message;
            }

            const normalizedResponse = {
                type: "text",
                content: responseText,
                conversation_id: uuid || null
            };


            console.log('✅ Sending normalized response to AVR Core:', normalizedResponse);

            res.setHeader('Content-Type', 'application/json');
            res.setHeader('Cache-Control', 'no-cache');


            res.json(normalizedResponse);

        } catch (error) {
            console.error('❌ API Error:', error.message);
            console.error('Error details:', error.response?.data);

            const errorResponse = {
                type: "error",
                content: error.message || 'Failed to process request',
                conversation_id: uuid || null
            };

            console.error('Sending error response:', errorResponse);
            res.status(500).json(errorResponse);
        }

    } catch (error) {
        console.error('❌ Internal Error:', error);
        const errorResponse = {
            type: "error",
            content: 'Internal server error',
            conversation_id: null
        };
        res.status(500).json(errorResponse);
    }
});

app.listen(PORT, () => {
    console.log(`AVR LLM Proxy listening on port ${PORT}`);
    console.log(`Forwarding to: ${API_URL} (${API_METHOD})`);
    if (API_TOKEN) {
        console.log(`Using Authorization header`);
    }
});
