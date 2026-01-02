const http = require("http");

function burnCpu(ms) {
  const end = Date.now() + ms;
  while (Date.now() < end) {}
}

const server = http.createServer((req, res) => {
  burnCpu(50); // simulate work
  res.end("ok\n");
});

server.listen(3000, () => {
  console.log("API listening on 3000");
});
