#!/bin/bash
# Generates test traffic against the demo service for pipeline verification
BASE_URL="http://localhost:8080"

echo "Generating test traffic..."

for i in $(seq 1 20); do
  curl -s "$BASE_URL/" > /dev/null
  curl -s "$BASE_URL/health" > /dev/null
  sleep 0.5
done

# Generate some slow requests for latency testing
for i in $(seq 1 3); do
  curl -s "$BASE_URL/slow" > /dev/null
done

# Generate some errors for error rate testing
for i in $(seq 1 5); do
  curl -s "$BASE_URL/error" > /dev/null
done

echo "Done. Check Tempo and Loki for traces and logs."
