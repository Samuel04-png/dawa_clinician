#!/usr/bin/env bash
# Launch the dev proxy + Flutter Web against the real Dawa edge device.
# Usage: tool/run_web_dev.sh [device-ip] [web-port]
# Device host: argument, else $EDGE_DEVICE_IP, else dawa.local.
# Non-patient images only; confirm the board is idle first.
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:-${EDGE_DEVICE_IP:-dawa.local}}"
WEB_PORT="${2:-5100}"
HUB_REMOTE_PORT="${EDGE_DEVICE_HUB_PORT_REMOTE:-80}"
HUB_PORT="${EDGE_PROXY_HUB_PORT:-8080}"
CERVICAL_PORT="${EDGE_PROXY_CERVICAL_PORT:-8085}"
ULTRASOUND_PORT="${EDGE_PROXY_ULTRASOUND_PORT:-8086}"
ORIGIN="http://localhost:${WEB_PORT}"

echo "[Dev] device=$DEVICE origin=$ORIGIN"
for port in "$WEB_PORT" "$HUB_PORT" "$CERVICAL_PORT" "$ULTRASOUND_PORT"; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "[Dev] port $port is already in use; stop its owner or choose another web port." >&2
    exit 1
  fi
done
echo "[Dev] checking device directly..."
curl --noproxy '*' -fsS --max-time 8 "http://${DEVICE}:${HUB_REMOTE_PORT}/api/status" >/dev/null \
  || { echo "[Dev] device hub unreachable at http://${DEVICE}:${HUB_REMOTE_PORT}"; exit 1; }

dart tool/edge_dev_proxy.dart --device "$DEVICE" --allow-origin "$ORIGIN" \
  --hub-remote-port "$HUB_REMOTE_PORT" \
  --hub-listen-port "$HUB_PORT" --cervical-listen-port "$CERVICAL_PORT" \
  --ultrasound-listen-port "$ULTRASOUND_PORT" &
PROXY_PID=$!
trap 'kill $PROXY_PID 2>/dev/null || true' EXIT

for _ in $(seq 1 20); do
  if ! kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "[Dev] proxy exited before becoming ready" >&2
    wait "$PROXY_PID" || true
    exit 1
  fi
  if curl -fsS --max-time 8 -H "Origin: $ORIGIN" \
      "http://localhost:${HUB_PORT}/api/status" >/dev/null 2>&1; then OK=1; break; fi
  sleep 0.5
done
[ "${OK:-0}" = 1 ] || { echo "[Dev] proxy cannot reach device"; exit 1; }
echo "[Dev] proxy OK: http://localhost:${HUB_PORT} -> http://${DEVICE}:${HUB_REMOTE_PORT}"
echo "[Dev] cervical: http://localhost:${CERVICAL_PORT} -> http://${DEVICE}:8085"
echo "[Dev] ultrasound: http://localhost:${ULTRASOUND_PORT} -> http://${DEVICE}:8086"
echo "[Dev] model management enabled; browser base URL http://localhost"

flutter run --no-pub -d chrome --web-hostname localhost --web-port "$WEB_PORT" \
  --dart-define=EDGE_DEVICE_BASE_URL=http://localhost \
  --dart-define=EDGE_DEVICE_HUB_PORT="$HUB_PORT" \
  --dart-define=EDGE_DEVICE_CERVICAL_PORT="$CERVICAL_PORT" \
  --dart-define=EDGE_DEVICE_ULTRASOUND_PORT="$ULTRASOUND_PORT" \
  --dart-define=EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED=true \
  --dart-define=EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED=true
