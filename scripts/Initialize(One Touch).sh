#!/bin/bash
# =====================================================
# Master Script
# =====================================================

echo "🚀 Starting Full Lab Deployment..."

# Stage 1: Newtorks
echo -e "\n[STAGE 1/4] Creating Networks..."
bash 01-create-networks.sh
if [ $? -ne 0 ]; then echo "❌ Stage 1 Failed"; exit 1; fi

# Stage 2: Gateway
echo -e "\n[STAGE 2/4] Deploying Gateway VM..."
# script waiting virt-install to end cause of --wait -1 int (01-create-networks_3.sh)
bash 02-create-gateway-vm.sh

# Checking Gateway to answer ---
echo -e "\n⏳ Waiting for Gateway (10.10.10.2) to respond on internal bridge..."
MAX_RETRIES=30
COUNT=0

while ! ping -c 1 -W 1 10.10.10.2 > /dev/null 2>&1; do
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Gateway timed out after $MAX_RETRIES minutes. Check the console!"
        exit 1
    fi
    echo "Still waiting for Gateway... ($COUNT/$MAX_RETRIES minutes)"
    sleep 60  # Check every 60 sec
done

echo "✅ Gateway is UP and responding! Proceeding to Clients..."

echo -e "\n[STAGE 3] Deploying Clients"
bash 03-create-fedora-clients.sh &
PID1=$! # Keep Process ID Client 1

bash "04-create-fedora-clients(ping_to_03).sh" &
PID2=$! # Keep Process ID Client 2

echo "Both Clients are installing in the background..."
echo "Monitor their progress in the Konsole windows that opened."

# Περιμένουμε να τελειώσουν και οι δύο εγκαταστάσεις
wait $PID1
wait $PID2

echo -e "\n✅ ALL STAGES COMPLETED!"
echo "Client 1 is should pinging google.com."
echo "Client 2 is should scanning/pinging Client 1."

echo -e "\n✅ ALL STAGES COMPLETED SUCCESSFULLY!"