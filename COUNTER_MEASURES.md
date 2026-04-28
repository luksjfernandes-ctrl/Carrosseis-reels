# COUNTER_MEASURES.md

**Repositorio:** `carrosseis-reels`
**Origem:** Pre-Mortem II - Auditoria Adversarial 2026-04-28
**Referencia Notion:** https://www.notion.so/3502d8a76b8b819a929efd3c46e070ad
**Principio:** Cada item e uma acao executavel, com criterio de aceite verificavel. Ambiguidade e inimiga.

---

## P0 - EXECUTAR EM 48 HORAS

### CM-01. Estancar mutacao de blueprint do cenario Make
**Vetor neutralizado:** 7.1, 7.2, 7.3
**Acao:**
- Parar de usar `scenarios_update` para reescrever o blueprint a cada execucao.
- Migrar a rotina para o blueprint webhook permanente (passo 12.1) como estado UNICO.
- Disparar publicacao exclusivamente via `POST` no webhook (`MAKE_WEBHOOK_URL`) com payload `{images, caption, idempotency_key}`.
- Adicionar `idempotency_key = sha256(carousel_dir + content_hash)` no payload e validar no inicio do flow Make (router que descarta duplicado).
**Aceite:** zero chamadas de `scenarios_deactivate` / `scenarios_activate` em 7 dias consecutivos. Zero double-posts no log de execucoes.

### CM-02. Sanitizar caption antes de injetar em shell/Python
**Vetor neutralizado:** 7.4
**Acao:** em `publicar_make.sh`, substituir o heredoc Python por:
- ler caption como arquivo: `printf '%s' "$CAPTION" > /tmp/caption.txt`
- montar payload via `python3 build_payload.py /tmp/caption.txt /tmp/images.json` -- script dedicado que usa `json.dumps` em ambos.
- proibir interpolacao de `$CAPTION` em string Python literal.
**Aceite:** caption contendo aspas triplas, backtick, `$()`, `\n`, aspas e emojis publica sem quebrar pipeline. Teste manual com payload adversarial commitado em `tests/captions/`.

### CM-03. Remover dependencia de SHA de branch ephemeral nas URLs de imagem
**Vetor neutralizado:** 7.5
**Acao:**
- URLs Cloudinary devem usar `image/upload` (storage), nao `image/fetch` (proxy).
- Cada slide e carregado uma vez no Cloudinary com `public_id` derivado de `carousel_name/slide-NN`. O `secure_url` retornado e o que vai para o Meta.
- Eliminar qualquer URL `raw.githubusercontent.com/{SHA}/...` do payload do Make.
**Aceite:** `grep -r "raw.githubusercontent.com" .` retorna zero ocorrencias em scripts de publicacao e em blueprints Make. Posts antigos seguem com imagem mesmo se a branch for reescrita.

### CM-04. Rotacionar e isolar segredos
**Vetor neutralizado:** Vetor 9 (extensao do Vetor 1 da auditoria anterior)
**Acao:**
- Rotacionar `CLOUDINARY_API_SECRET`, `MAKE_WEBHOOK_URL` (regenerar hook), `MAKE_API_KEY`.
- Mover `.env` para gerenciador (1Password CLI / `op run` ou Doppler). Nao sourcear `.env` plano.
- Confirmar `.env` em `.gitignore` (ja esta), mas auditar `git log --all --full-history -- .env` para garantir que nunca foi commitado neste repo.
**Aceite:** `git log --all --full-history -- .env` vazio. Scripts rodam via `op run -- ./publicar_make.sh` ou equivalente.

---

## P1 - EXECUTAR EM 7 DIAS

### CM-05. Eleger branch de producao no-ephemeral
**Vetor neutralizado:** 7.5, diagnostico estrutural #4
**Acao:**
- Branch de producao do conteudo = `main`. Ponto.
- Remover `claude/zealous-ride-fhk5O` como referencia em `agente-routine-config.md` e em qualquer blueprint Make.
- Configurar protecao de branch em `main`: proibir push direto, exigir PR.
**Aceite:** `agente-routine-config.md` cita exclusivamente `main`. `gh api repos/.../branches/main/protection` retorna regras ativas.

### CM-06. Idempotencia e dedup robusta no pipeline de publicacao
**Vetor neutralizado:** 7.2, 7.3
**Acao:**
- Antes de qualquer chamada que crie post no Meta, consultar `mcp__Make__executions_list` filtrado por `idempotency_key` do payload.
- Substituir janela de 10 minutos por checagem deterministica: existe execucao com mesma chave -> abortar.
- Persistir mapa `carousel_dir -> executionId -> igMediaId` em `published.json` (commitado).
**Aceite:** rodar `publicar_make.sh` duas vezes consecutivas no mesmo carrossel: a segunda execucao termina com `duplicate-skipped` sem chamar Meta.

### CM-07. Substituir `sips` por ferramenta cross-platform
**Vetor neutralizado:** 7.7
**Acao:** trocar `sips -s format jpeg` por `magick convert` (ImageMagick) ou `cwebp`/`vips`. Adicionar checagem de binario no inicio do script (`command -v magick || exit 1`).
**Aceite:** `publicar_make.sh` roda em container Linux CI (GitHub Actions) sem erro.

### CM-08. Monitor de saude do cenario Make
**Vetor neutralizado:** 7.1, observabilidade
**Acao:**
- Cron GitHub Actions a cada 30 min: `mcp__Make__scenarios_get-detail(scenarioId: 4783082)`.
- Se `isActive=false` ou blueprint difere do hash esperado -> abrir issue automatica e enviar webhook para Slack/Discord.
**Aceite:** desativar manualmente o cenario em ambiente de teste -> alerta dispara em menos de 30 min.

### CM-09. Separar repositorio de produto e pipeline
**Vetor neutralizado:** diagnostico estrutural
**Acao:** mover `SexuS.app/` para repositorio proprio. `carrosseis-reels` fica exclusivamente para pipeline + conteudo.
**Aceite:** raiz do `carrosseis-reels` contem apenas: `publicar*.sh`, `agente-routine-config.md`, `COUNTER_MEASURES.md`, `postados/`, `carousel-*/`, `.gitignore`, `README.md`, `tests/`.

---

## P2 - EXECUTAR EM 30 DIAS

### CM-10. Reescrever pipeline em Python com testes
**Vetor neutralizado:** Vetor 7 inteiro
**Acao:** substituir bash + heredoc Python por modulo Python (`pipeline/`) com:
- `cloudinary_uploader.py`, `make_publisher.py`, `caption_builder.py`, `archive.py`.
- Testes pytest cobrindo: caption adversarial, falha Cloudinary, retry, dedup.
- CLI: `python -m pipeline publish carousel-2026-XX-XX-slug`.
**Aceite:** cobertura >= 60% no modulo `pipeline/`. CI green em PR de teste.

### CM-11. Documentar runbook de incidentes da pipeline
**Vetor neutralizado:** documentacao dessincronizada
**Acao:** criar `RUNBOOK.md` com cenarios:
- Cenario Make travado em single-shot -> comando para restaurar blueprint.
- Webhook auth invalidado -> rotina de recriacao.
- Cloudinary com quota estourada -> bypass manual.
- Imagens 404 em posts antigos -> procedimento de re-fetch + re-upload.
**Aceite:** runbook revisado por simulacao de cada cenario.

### CM-12. Auditoria das 5 frentes silenciosas
**Vetor neutralizado:** Vetor 9
**Acao:** para cada um de `facesb-questoes`, `holl-jonas-advocacia`, `instituto-apolineo-ui`, `looksmaxxingapollo`, `scribeflow`:
- Criar `COUNTER_MEASURES.md` especifico no branch designado pela diretiva atual de desenvolvimento.
- Decidir e documentar: **manter, congelar ou desligar**. Sem terceira via.
- `congelar` = colocar Vercel em manutencao, remover credenciais ativas, tag `frozen-2026-04`.
- `desligar` = takedown ordenado: backup, DNS off, repo arquivado.
**Aceite:** cada repo tem `STATUS.md` com decisao, data e responsavel. Nenhum repo na zona cinza.

---

## ITENS HERDADOS DA AUDITORIA DE 2026-04-19 (AINDA ABERTOS)

| ID   | Vetor | Acao                                                                   | Status |
| ---- | ----- | ---------------------------------------------------------------------- | ------ |
| H-01 | V1    | Remover `.env` rastreado em `facesb-questoes` + rotacionar Supabase    | ABERTO |
| H-02 | V1    | Apagar service_role key do markdown em `looksmaxxingapollo` + rotacionar | ABERTO |
| H-03 | V2    | Criar staging para `scribeflow` e `looksmaxxingapollo`                 | ABERTO |
| H-04 | V2    | Adicionar testes (meta inicial: 30%) em `scribeflow`                   | ABERTO |
| H-05 | V3    | Documentar acessos criticos em vault compartilhado                     | ABERTO |
| H-06 | V4    | Drop de tabelas orfas no Supabase looksmaxxing                         | ABERTO |
| H-07 | V4    | Limpar arquivos de build commitados (`build-*.txt`, `lint-*.txt`)      | ABERTO |
| H-08 | V5    | Decidir destino de `holl-jonas-advocacia` e `instituto-apolineo-ui`    | ABERTO |
| H-09 | V6    | Instalar Sentry (ou equivalente) em todos os apps em producao          | ABERTO |

**Toda acao herdada permanece ABERTA ate commit verificavel. CM-12 absorve a triagem dos repos silenciosos.**

---

## REGRA DE AUDITORIA

- Cada item desta lista tem dono unico, deadline e criterio de aceite objetivo.
- Item sem prova de execucao em 7 dias do deadline -> escalado para o topo do proximo Pre-Mortem.
- A proxima auditoria adversarial vai verificar este arquivo: itens marcados como concluidos sem evidencia serao tratados como **alucinacao documental** (vide nota final do Pre-Mortem II) e revertidos para ABERTO com penalidade de prioridade.

**Ultima atualizacao:** 2026-04-28
**Proxima revisao:** 2026-05-05
