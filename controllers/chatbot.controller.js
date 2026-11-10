const axios = require('axios');
const logger = require('../config/logger');

async function chat(req, res, next) {
  try {
    const { message, history = [] } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return res.status(503).json({ error: 'Chatbot service not configured' });
    }

    const systemPrompt = `You are WC Fantasy Assistant, an AI chatbot for a Fantasy Football application dedicated to the FIFA World Cup 2026. You help users with:
- Team composition advice and player recommendations
- Understanding the scoring system and rules
- League strategy and transfer tips
- World Cup 2026 match information and predictions
- General fantasy football questions

Be friendly, concise, and football-knowledgeable. Respond in the same language the user writes in.`;

    const contents = [];
    for (const msg of history) {
      contents.push({
        role: msg.role === 'user' ? 'user' : 'model',
        parts: [{ text: msg.content }],
      });
    }
    contents.push({ role: 'user', parts: [{ text: message }] });

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${apiKey}`;

    const response = await axios.post(url, {
      system_instruction: { parts: [{ text: systemPrompt }] },
      contents,
    }, { timeout: 30000 });

    const reply = response.data.candidates?.[0]?.content?.parts?.[0]?.text
      || 'Sorry, I could not generate a response.';

    res.json({ reply });
  } catch (err) {
    if (err.response?.status === 429) {
      return res.status(429).json({ error: 'Chatbot rate limit reached. Please try again later.' });
    }
    logger.error('Chatbot error', { error: err.message });
    next(err);
  }
}

module.exports = { chat };
