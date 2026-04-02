const express = require('express');
const app = express();
const PORT = 3000;

app.get('/healthz', (req, res) => res.json({ status: 'ok' }));
app.get('/', (req, res) => res.json({ message: `hello from ${require('os').hostname()}` }));

app.listen(PORT, () => console.log(`listening on :${PORT}`));
