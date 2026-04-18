#!/bin/bash
# Publica carrossel no Instagram via Make + Cloudinary
# Fluxo: slides PNG → JPG → Cloudinary (URL pública) → Webhook Make → Meta Graph API

set -e
source "$(dirname "$0")/.env"

CAROUSEL_DIR="${1:-}"

# Encontra o carrossel mais recente se não especificado
if [ -z "$CAROUSEL_DIR" ]; then
  CAROUSEL_DIR=$(ls -d "$(dirname "$0")"/carousel-* 2>/dev/null | tail -1)
fi

if [ -z "$CAROUSEL_DIR" ] || [ ! -d "$CAROUSEL_DIR" ]; then
  echo "Erro: pasta do carrossel não encontrada. Uso: $0 [caminho/carousel-xxx]"
  exit 1
fi

echo "Carrossel: $CAROUSEL_DIR"

# Valida variáveis obrigatórias
for VAR in CLOUDINARY_CLOUD_NAME CLOUDINARY_API_KEY CLOUDINARY_API_SECRET MAKE_WEBHOOK_URL; do
  if [ -z "${!VAR}" ]; then
    echo "Erro: $VAR não configurado no .env"
    exit 1
  fi
done

# Converte PNGs para JPG e faz upload no Cloudinary
IMAGES_JSON="["
PRIMEIRO=true

for SLIDE in "$CAROUSEL_DIR"/slide-*.png "$CAROUSEL_DIR"/slide-*.jpg; do
  [ -f "$SLIDE" ] || continue

  BASENAME=$(basename "$SLIDE" | sed 's/\.[^.]*$//')
  CAROUSEL_NAME=$(basename "$CAROUSEL_DIR")
  PUBLIC_ID="${CAROUSEL_NAME}/${BASENAME}"

  # Converte para JPG temporário (Meta exige image/jpeg)
  JPG_TEMP="/tmp/${BASENAME}.jpg"
  sips -s format jpeg "$SLIDE" --out "$JPG_TEMP" -s formatOptions 85 > /dev/null 2>&1

  echo "Enviando $BASENAME para Cloudinary..."

  TIMESTAMP=$(date +%s)
  SIGNATURE_STRING="public_id=${PUBLIC_ID}&timestamp=${TIMESTAMP}${CLOUDINARY_API_SECRET}"
  SIGNATURE=$(echo -n "$SIGNATURE_STRING" | shasum -a 256 | awk '{print $1}')

  RESPONSE=$(curl -s -X POST \
    "https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/image/upload" \
    -F "file=@${JPG_TEMP}" \
    -F "public_id=${PUBLIC_ID}" \
    -F "timestamp=${TIMESTAMP}" \
    -F "api_key=${CLOUDINARY_API_KEY}" \
    -F "signature=${SIGNATURE}")

  URL=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('secure_url',''))" 2>/dev/null)

  if [ -z "$URL" ]; then
    echo "Erro no upload de $BASENAME:"
    echo "$RESPONSE"
    rm -f "$JPG_TEMP"
    exit 1
  fi

  echo "  → $URL"
  rm -f "$JPG_TEMP"

  if [ "$PRIMEIRO" = true ]; then
    IMAGES_JSON="${IMAGES_JSON}\"${URL}\""
    PRIMEIRO=false
  else
    IMAGES_JSON="${IMAGES_JSON},\"${URL}\""
  fi
done

IMAGES_JSON="${IMAGES_JSON}]"

# Extrai caption do config.json ou usa padrão
CONFIG="$CAROUSEL_DIR/config.json"
if [ -f "$CONFIG" ]; then
  CAPTION=$(python3 -c "
import json
with open('$CONFIG') as f:
    c = json.load(f)
slides = c.get('slides', [])
texts = []
for s in slides:
    for t in s.get('tweets', []):
        txt = t.get('text', '')
        if txt:
            texts.append(txt)
# Caption = primeiro slide + hashtags
caption = texts[0] if texts else 'Instituto Apolíneo'
print(caption)
" 2>/dev/null || echo "Instituto Apolíneo")
else
  CAPTION="Instituto Apolíneo"
fi

# Monta e dispara payload para o Make
echo ""
echo "Disparando webhook Make..."

PAYLOAD=$(python3 -c "
import json
images = json.loads('$IMAGES_JSON')
caption = '''$CAPTION'''
payload = {'images': images, 'caption': caption}
print(json.dumps(payload))
")

HEADERS=(-H "Content-Type: application/json")
if [ -n "${MAKE_API_KEY:-}" ]; then
  HEADERS+=(-H "x-make-apikey: ${MAKE_API_KEY}")
fi

HTTP_STATUS=$(curl -s -o /tmp/make_response.json -w "%{http_code}" \
  "${HEADERS[@]}" \
  -d "$PAYLOAD" \
  "$MAKE_WEBHOOK_URL")

RESPONSE_BODY=$(cat /tmp/make_response.json)

echo "Status Make: $HTTP_STATUS"
echo "Resposta: $RESPONSE_BODY"

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo ""
  echo "Publicado com sucesso!"
  # Move carrossel para postados
  mv "$CAROUSEL_DIR" "$(dirname "$0")/postados/"
  echo "Pasta movida para postados/"
else
  echo ""
  echo "Falha no webhook Make (HTTP $HTTP_STATUS). Verifique MAKE_WEBHOOK_URL no .env"
  exit 1
fi
