# COUNTER_MEASURES.md

**Reposit�rio:** `carrosseis-reels`
**Origem:** Pre-Mortem II  Audit. Adversarial 2026-04-28
**Refer�ncia Notion:** https://www.notion.so/3502d8a76b8b819a929efd3c46e070ad
**Princpio:** Cada item � uma a��o executvel, com critrio de aceite verificvel. Ambiguidade  inimiga.

---

## P0  EXECUTAR EM 48 HORAS

### CM-01. Estancar muta��o de blueprint do cenrio Make
**Vetor neutralizado:** 7.1, 7.2, 7.3
**A��o:**
- Parar de usar `scenarios_update` para reescrever o blueprint a cada execu��o.
- Migrar a rotina para o blueprint webhook permanente (passo 12.1) como **estado nico**.
- Disparar publica��o exclusivamente via `POST` no webhook (`MAKE_WEBHOOK_URL`) com payload `{images, caption, idempotency_key}`.
- Adicionar `idempotency_key = sha256(carousel_dir + content_hash)` no payload e validar no incio do flow Make (router que descarta duplicado).
**Aceite:** zero chamadas de `scenarios_deactivate` / `scenarios_activate` em 7 dias consecutivos. Zero double-posts no log de execu��es.

### CM-02. Sanitizar caption antes de injetar em shell/Python
**Vetor neutralizado:** 7.4
**A��o:** em `publicar_make.sh`, substituir o heredoc Python por:
- ler caption como arquivo: `printf '%s' "$CAPTION" > /tmp/caption.txt`
- montar payload via `python3 build_payload.py /tmp/caption.txt /tmp/images.json`  script dedicado que usa `json.dumps` em ambos.
- proibir interpola��o de `$CAPTION` em string Python literal.
**Aceite:** caption contendo `'''`, `` ` ``, `$()`, `\n`, aspas e emojis publica sem quebrar pipeline. Teste manual com payload adversarial commitado em `tests/captions/`.

### CM-03. Remover depend�ncia de SHA de branch ephemeral nas URLs de imagem
**Vetor neutralizado:** 7.5
**A��o:**
- URLs Cloudinary devem fazer `image/upload` (storage), no `image/fetch` (proxy).
- Cada slide  carregado uma vez no Cloudinary com `public_id` derivado de `carousel_name/slide-NN` e o `secure_url` do Cloudinary  o que vai para o Meta.
- Eliminar qualquer URL `raw.githubusercontent.com/{SHA}/...` do payload do Make.
**Aceite:** `grep -r "raw.githubusercontent.com" .` retorna zero ocorr�ncias em scripts de publica��o e em blueprints Make. Posts antigos seguem com imagem mesmo se a branch for reescrita.

### CM-04. Rotacionar e isolar segredos
**Vetor neutralizado:** 9 (extens�o do Vetor 1 da auditoria anterior)
**A��o:**
- Rotacionar `CLOUDINARY_API_SECRET`, `MAKE_WEBHOOK_URL` (regenerar hook), `MAKE_API_KEY`.
- Mover `.env` para gerenciador (1Password CLI / `op run` ou Doppler). N�o sourcear `.env` plano.
- Confirmar `.env` em `.gitignore` (j est, mas auditar `git log --all --full-history -- .env` para garantir que nunca foi commitado neste repo).
**Aceite:** `git log --all --full-history -- .env` vazio. Scripts rodam via `op run -- ./publicar_make.sh` ou equivalente.

---

## P1  EXECUTAR EM 7 DIAS

### CM-05. Eleger branch de produ��o no estilo no-ephemeral
**Vetor neutralizado:** 7.5, diagnstico estrutural #4
**A��o:**
- Branch de produ��o do conte�do = `main`. Ponto.
- Remover `claude/zealous-ride-fhk5O` como refer�ncia em `agente-routine-config.md` e qualquer blueprint Make.
- Configurar prote��o de branch em `main`: probe direct push, exigir PR.
**Aceite:** `agente-routine-config.md` cita exclusivamente `main`. `gh api repos/.../branches/main/protection` retorna regras ativas.

### CM-06. Idempot�ncia e dedup robusta no pipeline de publica��o
**Vetor neutralizado:** 7.2, 7.3
**A��o:**
- Antes de qualquer chamada que crie post no Meta, consultar `mcp__Make__executions_list` filtrado por `idempotency_key` do payload.
- Substituir janela de 10 minutos por checagem determinstica: existe execu��o com mesma chave  abortar.
- Persistir mapa `carousel_dir  executionId  igMediaId` em `published.json` (commitado).
**Aceite:** rodar `publicar_make.sh` duas vezes consecutivas no mesmo carrossel  segunda execu��o termina com `duplicate-skipped` sem chamar Meta.

### CM-07. Substituir `sips` por ferramenta cross-platform
**Vetor neutralizado:** 7.7
**A��o:** trocar `sips -s format jpeg` por `magick convert` (ImageMagick) ou `cwebp`/`vips`. Adicionar checagem de bin�rio no incio do script (`command -v magick || exit 1`).
**Aceite:** `publicar_make.sh` roda em Linux container CI (GitHub Actions) sem erro.

### CM-08. Monitor de sa�de do cenrio Make
**Vetor neutralizado:** 7.1, observabilidade
**A��o:**
- Cron GitHub Actions a cada 30 min: `mcp__Make__scenarios_get-detail(scenarioId: 4783082)`.
- Se `isActive=false` ou blueprint difere do hash esperado  abrir issue automtica e enviar webhook para Slack/Discord.
**Aceite:** desativar manualmente o cenrio em ambiente de teste  alerta dispara em <30 min.

### CM-09. Separar reposit�rio de produto e pipeline
**Vetor neutralizado:** diagnstico estrutural
**A��o:** mover `SexuS.app/` para reposit�rio prprio. `carrosseis-reels` fica exclusivamente para pipeline + conte�do.
**Aceite:** raiz do `carrosseis-reels` contm apenas: `publicar*.sh`, `agente-routine-config.md`, `COUNTER_MEASURES.md`, `postados/`, `carousel-*/`, `.gitignore`, `README.md`, `tests/`.

---

## P2  EXECUTAR EM 30 DIAS

### CM-10. Reescrever pipeline em Python com testes
**Vetor neutralizado:** 7 inteiro
**A��o:** substituir bash + heredoc Python por mdulo Python (`pipeline/`) com:
- `cloudinary_uploader.py`, `make_publisher.py`, `caption_builder.py`, `archive.py`.
- Testes pytest cobrindo: caption adversarial, falha Cloudinary, retry, dedup.
- CLI: `python -m pipeline publish carousel-2026-XX-XX-slug`.
**Aceite:** cobertura e60% no mdulo `pipeline/`. CI green em PR de teste.

### CM-11. Documentar runbook de incidentes da pipeline
**Vetor neutralizado:** documenta��o dessincronizada
**A��o:** criar `RUNBOOK.md` com cenrios:
- Cenrio Make travado em single-shot  comando para restaurar blueprint.
- Webhook auth invalidado  rotina de recria��o.
- Cloudinary com quota estourada  bypass manual.
- Imagens 404 em posts antigos  procedimento de re-fetch + re-upload.
**Aceite:** runbook revisado por simula��o de cada cenrio.

### CM-12. Auditoria das 5 frentes silenciosas
**Vetor neutralizado:** Vetor 9
**A��o:** para cada um de `facesb-questoes`, `holl-jonas-advocacia`, `instituto-apolineo-ui`, `looksmaxxingapollo`, `scribeflow`:
- Criar `COUNTER_MEASURES.md` espec�fico no branch designado pela diretiva atual de desenvolvimento.
- Decidir e documentar: **manter, congelar ou desligar**. Sem terceira via.
- `congelar` = colocar Vercel em manuten�ncia, remover credenciais ativas, tag `frozen-2026-04`.
- `desligar` = takedown ordenado: backup, DNS off, repo arquivado.
**Aceite:** cada repo tem `STATUS.md` com decis�o, data e respons�vel. Nenhum repo na zona cinza.

---

## ITENS HERDADOS DA AUDITORIA DE 2026-04-19 (AINDA ABERTOS)

| ID | Vetor | A��o | Status |
| --- | --- | --- | --- |
| H-01 | V1 | Remover `.env` rastreado em `facesb-questoes` + rotacionar Supabase | ABERTO |
| H-02 | V1 | Apagar service_role key do markdown em `looksmaxxingapollo` + rotacionar | ABERTO |
| H-03 | V2 | Criar staging para `scribeflow` e `looksmaxxingapollo` | ABERTO |
| H-04 | V2 | Adicionar testes (meta inicial: 30%) em `scribeflow` | ABERTO |
| H-05 | V3 | Documentar acessos cr�ticos em vault compartilhado | ABERTO |
| H-06 | V4 | Drop de tabelas rf�s no Supabase looksmaxxing | ABERTO |
| H-07 | V4 | Limpar arquivos de build commitados (`build-*.txt`, `lint-*.txt`) | ABERTO |
| H-08 | V5 | Decidir destino de `holl-jonas-advocacia` e `instituto-apolineo-ui` | ABERTO |
| H-09 | V6 | Instalar Sentry (ou equivalente) em todos os apps em prod | ABERTO |

**Toda a��o herdada permanece ABERTA at� commit verificvel. CM-12 absorve o triagem dos repos silenciosos.**

---

## REGRA DE AUDITORIA

- Cada item desta lista tem dono nico, deadline e crit�rio de aceite objetivo.
- Item sem prova de execu��o em 7 dias do deadline  escalado para o topo do prximo Pre-Mortem.
- A pr�xima auditoria adversarial verificar este arquivo: itens marcados como conclu�dos sem evid�ncia ser�o tratados como **alucina��o documental** (vide nota final do Pre-Mortem II) e revertidos para ABERTO com penalidade de prioridade.

**ltima atualiza��o:** 2026-04-28
**Pr�xima revis�o:** 2026-05-05
