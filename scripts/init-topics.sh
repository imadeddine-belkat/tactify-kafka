#!/bin/bash
set -e

BOOTSTRAP_SERVER=tactify-kafka:29092
TOPICS_FILE=/config/topics.yaml
MAX_RETRIES=30

echo "--- STARTING KAFKA TOPIC INITIALIZATION ---"

# 1. INSTALL yq
if ! command -v yq &> /dev/null; then
    echo "yq not found. Installing..."
    curl -L https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64 -o /usr/bin/yq
    chmod +x /usr/bin/yq
    echo "yq installed successfully."
fi

# 2. WAIT FOR KAFKA
echo "Waiting for Kafka to be ready at $BOOTSTRAP_SERVER..."
for i in $(seq 1 $MAX_RETRIES); do
  if tactify-kafka-topics --bootstrap-server "$BOOTSTRAP_SERVER" --list >/dev/null 2>&1; then
    echo "Kafka is ready!"
    break
  fi
  echo "Waiting for Kafka... ($i/$MAX_RETRIES)"
  if [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "ERROR: Kafka did not become ready. Exiting."
    exit 1
  fi
  sleep 2
done

# 3. CREATE TOPICS
echo "Reading topics from $TOPICS_FILE..."

# FIX: We use join(" ") instead of string interpolation to ensure clean output
yq -r '
  .tactify-kafka.defaults.replication as $default_rep |
  .tactify-kafka.topics[] |
  [.name, .partitions, (.replication // $default_rep)] | join(" ")
' "$TOPICS_FILE" | \
while read -r NAME PARTITIONS REPLICATION; do

  # Check if we actually got valid data (prevents empty line errors)
  if [ -z "$NAME" ]; then continue; fi

  echo "Processing topic: $NAME (Partitions: $PARTITIONS, Replication: $REPLICATION)"

  tactify-kafka-topics \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --create \
    --if-not-exists \
    --topic "$NAME" \
    --partitions "$PARTITIONS" \
    --replication-factor "$REPLICATION"

done

echo "--- INITIALIZATION COMPLETED ---"