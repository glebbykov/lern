const http = require('http');
const os = require('os');

const PORT = 3000;

const server = http.createServer((req, res) => {
  if (req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ message: `hello from ${os.hostname()}` }));
});

server.listen(PORT, () => {
  console.log(`listening on :${PORT}`);
});
