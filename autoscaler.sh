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