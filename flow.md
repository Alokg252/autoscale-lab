Excellent. Let’s build a **complete, runnable mini–autoscaling lab**. Nothing hidden, nothing magical. You’ll be able to *watch* scaling happen.

I’ll give you:
• a fake backend that burns CPU under load
• Nginx reverse proxy
• Docker Compose setup
• an autoscaler script that scales based on CPU
• a way to generate load and observe behavior

This is intentionally simple and slightly crude. That’s how learning sticks.

---

## 1️⃣ Project structure

```
autoscale-lab/
├─ docker-compose.yml
├─ nginx/
│  └─ nginx.conf
├─ api/
│  ├─ Dockerfile
│  └─ server.js
└─ autoscaler.sh
```

---

## 2️⃣ Backend service (CPU-burning API)

This service responds slowly and eats CPU when hit.

### `api/server.js`

```js
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
```

### `api/Dockerfile`

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY server.js .
CMD ["node", "server.js"]
```

---

## 3️⃣ Nginx reverse proxy

Uses Docker DNS so scaling is automatic.

### `nginx/nginx.conf`

```nginx
events {}

http {
  upstream backend {
    server api:3000;
  }

  server {
    listen 80;

    location / {
      proxy_pass http://backend;
    }
  }
}
```

---

## 4️⃣ Docker Compose

This defines the *actuator* part of autoscaling.

### `docker-compose.yml`

```yaml
version: "3.9"

services:
  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "8080:80"
    depends_on:
      - api

  api:
    build: ./api
```

Start it:

```bash
docker compose up --build -d --scale api=2
```

Check:

```bash
curl http://localhost:8080
```

---

## 5️⃣ Autoscaler script (the brain)

This script:
• reads average CPU across api containers
• scales up/down based on thresholds

### `autoscaler.sh`

```bash
#!/bin/bash

MIN=2
MAX=6

while true; do
  CPU=$(docker stats api --no-stream --format "{{.CPUPerc}}" \
        | sed 's/%//' \
        | awk '{sum+=$1} END {if (NR>0) print sum/NR; else print 0}')

  COUNT=$(docker ps --filter "name=api" --format "{{.ID}}" | wc -l)

  echo "CPU: ${CPU}% | replicas: ${COUNT}"

  if (( $(echo "$CPU > 70" | bc -l) )) && [ "$COUNT" -lt "$MAX" ]; then
    NEW=$((COUNT + 1))
    echo "Scaling up → $NEW"
    docker compose up -d --scale api=$NEW
  fi

  if (( $(echo "$CPU < 30" | bc -l) )) && [ "$COUNT" -gt "$MIN" ]; then
    NEW=$((COUNT - 1))
    echo "Scaling down → $NEW"
    docker compose up -d --scale api=$NEW
  fi

  sleep 10
done
```

Make executable:

```bash
chmod +x autoscaler.sh
```

Run it in a separate terminal:

```bash
./autoscaler.sh
```

---

## 6️⃣ Generate load (the pressure)

Use `wrk` or `ab`.

```bash
wrk -t4 -c200 -d30s http://localhost:8080
```

Watch:
• autoscaler logs
• container count change
• response latency

Run:

```bash
docker ps
docker stats
```

You’ll see replicas grow under load and shrink afterward.

---

## 7️⃣ What you just built (important)

You implemented **real autoscaling mechanics**:

Signal → CPU usage
Controller → autoscaler.sh
Actuator → `docker compose --scale`
Discovery → Docker DNS
Load balancing → Nginx

This is the same loop Kubernetes uses — just handwritten and legible.

---

## 8️⃣ Natural next experiments

Try these to deepen intuition:
• increase CPU burn to 200ms
• add cooldown time before scaling down
• simulate crashes: `docker kill api_xxx`
• scale based on response time instead of CPU
• break it on purpose and observe recovery

When you later meet Kubernetes HPA, you’ll recognize it instantly. Same brain. Better muscles.

Autoscaling isn’t magic. It’s a nervous system. You just built one from scratch.
