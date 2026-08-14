#!/usr/bin/env bash
# Beweist zweierlei: ohne gesetzte Variablen verhaelt sich das Image exakt wie
# upstream, und mit gesetzten Variablen greift der Patch tatsaechlich.
set -euo pipefail
IMAGE="${1:?Aufruf: smoke.sh <image>}"

# 4000x1000 Testbild. Kurze Kante 1000, lange 4000.
PROBE='
const sharp = require("sharp");
const { resizeImageBuffer } = require("/app/api/server/services/Files/images/resize");
sharp({ create: { width: 4000, height: 1000, channels: 3, background: { r: 0, g: 0, b: 0 } } })
  .png().toBuffer()
  .then((buf) => resizeImageBuffer(buf, "high"))
  .then((r) => { console.log(r.width + "x" + r.height); })
  .catch((e) => { console.error(e); process.exit(1); });
'

echo "== ohne Variablen: muss upstream-Verhalten zeigen (2000x500) =="
GOT=$(docker run --rm --entrypoint node "$IMAGE" -e "$PROBE")
echo "   $GOT"
[ "$GOT" = "2000x500" ] || { echo "FEHLER: erwartet 2000x500, bekommen $GOT"; exit 1; }

echo "== mit IMAGE_MAX_SHORT_SIDE=2000 / IMAGE_MAX_LONG_SIDE=8000: unveraendert (4000x1000) =="
GOT=$(docker run --rm --entrypoint node \
  -e IMAGE_MAX_SHORT_SIDE=2000 -e IMAGE_MAX_LONG_SIDE=8000 "$IMAGE" -e "$PROBE")
echo "   $GOT"
[ "$GOT" = "4000x1000" ] || { echo "FEHLER: erwartet 4000x1000, bekommen $GOT"; exit 1; }

echo "== Unsinn in der Variablen faellt auf den Standard zurueck (2000x500) =="
GOT=$(docker run --rm --entrypoint node -e IMAGE_MAX_SHORT_SIDE=abc "$IMAGE" -e "$PROBE")
echo "   $GOT"
[ "$GOT" = "2000x500" ] || { echo "FEHLER: erwartet 2000x500, bekommen $GOT"; exit 1; }

echo "== alle Pruefungen bestanden =="
