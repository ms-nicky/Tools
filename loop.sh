#!/usr/bin/env bash

while true; do
  echo "[INFO] Membuat tunnel baru Pinggy..."
  ssh -p 443 \
    -R0:localhost:3389 \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=2 \
    KUtxLGQQXWm+tcp@free.pinggy.io

  echo "[WARN] Tunnel terputus, reconnect dalam 5 detik..."
  sleep 5
done
