#!/bin/bash
# Publica o conteúdo novo no GitHub (dispara automação do Instagram)

cd "$(dirname "$0")"

HOJE=$(date +%Y-%m-%d)
NOVAS=$(git ls-files --others --exclude-standard | head -1 | cut -d'/' -f1)

echo "Adicionando arquivos..."
git add .

if git diff --cached --quiet; then
  echo "Nada novo para publicar."
  exit 0
fi

echo "Fazendo commit..."
git commit -m "Publica conteúdo $HOJE${NOVAS:+ — $NOVAS}"

echo "Enviando para o GitHub..."
git push origin main

echo "Pronto! Conteúdo enviado."
