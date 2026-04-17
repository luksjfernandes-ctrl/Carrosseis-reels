#!/bin/bash
# Faz upload de uma imagem para o Cloudinary e retorna a URL pública
# Uso: ./upload_cloudinary.sh /caminho/para/imagem.png

set -e
source "$(dirname "$0")/.env"

FILE="$1"
FILENAME=$(basename "$FILE" | sed 's/\.[^.]*$//')
TIMESTAMP=$(date +%s)
SIGNATURE_STRING="public_id=${FILENAME}&timestamp=${TIMESTAMP}${CLOUDINARY_API_SECRET}"
SIGNATURE=$(echo -n "$SIGNATURE_STRING" | shasum -a 256 | awk '{print $1}')

RESPONSE=$(curl -s -X POST \
  "https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/image/upload" \
  -F "file=@${FILE}" \
  -F "public_id=${FILENAME}" \
  -F "timestamp=${TIMESTAMP}" \
  -F "api_key=${CLOUDINARY_API_KEY}" \
  -F "signature=${SIGNATURE}")

echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['secure_url'])"
