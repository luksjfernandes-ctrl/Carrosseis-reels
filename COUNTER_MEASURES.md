# COUNTER_MEASURES.md

**Repositorio:** `carrosseis-reels`
**Origem:** Pre-Mortem IV - Auditoria Adversarial 2026-05-10
**Referencia Notion:** https://www.notion.so/35c2d8a76b8b81cb945efd5a4316ad51
**Atualizado:** 2026-05-10
**Status do repo:** ZONA CINZA - DECIS�O FOR�ADA

---

## VEREDICTO DESTE REPOSIT�RIO

- **Ultimo commit em main:** 2026-04-20 (`Publica conteudo 2026-04-20 carousel-2026-04-18-chrome-one-click-prompts`)
- **Dias em silencio:** 20
- **Branches claude/* paralelas sem merge:** 6 (`clever-cray-drnFC`, `fervent-pascal-YGi3U`, `fervent-pascal-drMKY`, `fervent-pascal-xF4Va`, `laughing-edison-DP6ox`, `zealous-ride-fhk5O`)
- **Pre-Mortem II identificou esta pipeline como VETOR CATAST�FICO.** Resposta operacional foi parar de usa-la, nao consertar.
- **PM-III CM-A1 prescreveu mergear `claude/laughing-edison-DP6ox` para main.** N�O EXECUTADO.

**Recomendacao adversarial da PM-IV:** DESLIGAR ou refundar inteiramente. Custo de manter = custo de refazer. Sem decisao, e peso morto.

---

## P0 - EXECUTAR EM 48 HORAS (vencimento 2026-05-12)

### CM-A. Decidir destino: MANTER / CONGELAR / DESLIGAR
**Vetor neutralizado:** PM-III CM-20 (vencida 2026-05-10), PM-IV V17 (zona cinza)
**Acao:** Operador commit a `STATUS.md` neste repo com uma das tres decisoes:
- **MANTER** = aceitar CM-B abaixo, mergear `claude/laughing-edison-DP6ox` em main, executar PM-II CM-01..CM-11, restabelecer cadencia diaria de posts em 14 dias.
- **CONGELAR** = Vercel em modo manutencao, credenciais Cloudinary/Make/Meta rotacionadas e revogadas, README aviso "pipeline pausada indefinidamente". Voltar quando houver banda.
- **DESLIGAR** = backup zip dos cenarios Make, lista de posts ja publicados, assets. DNS removido. Repo arquivado via GitHub Settings.
**Aceite:** `STATUS.md` em main com decisao explicita + data + responsavel + criterio de revisao.

### CM-B. (apenas se MANTER) Mergear PM-II em main
**Vetor neutralizado:** PM-III CM-A1, V13 (contramedida orfa)
**Acao:**
- Abrir PR de `claude/laughing-edison-DP6ox` -> `main`. Resolver conflitos. Mergear. Deletar a branch.
- Auditar com `git log --all --oneline -- COUNTER_MEASURES.md` qualquer outra branch claude/* com COUNTER_MEASURES e reconciliar.
- Deletar branches stale: `clever-cray-drnFC`, `fervent-pascal-*` (3 branches), `zealous-ride-fhk5O` se nao tiverem trabalho unico.
**Aceite:** `gh api repos/luksjfernandes-ctrl/carrosseis-reels/contents/COUNTER_MEASURES.md` retorna 200 sem `?ref=`. `git branch -r --no-merged main` lista apenas branches deliberadamente vivas.

### CM-C. (apenas se CONGELAR ou DESLIGAR) Rotacao de credenciais
**Vetor neutralizado:** PM-I V1, PM-II V9 (credenciais expostas)
**Acao:**
- Rotacionar: Cloudinary API key/secret, Make webhook URLs, Meta/Instagram token, Supabase service_role (se aplicavel).
- Mover qualquer `.env` rastreado para vault (1Password/Bitwarden) e revogar a versao vazada.
- Adicionar `.env*` ao `.gitignore` se ainda nao estiver.
**Aceite:** `git log --all --diff-filter=A -- '*.env*'` mostra commits antigos mas o conteudo da credencial atual nao corresponde mais ao vazado.

---

## P1 - APENAS SE MANTER (vencimento 2026-05-17)

### CM-D. Idempotency_key + dedup robusta (PM-II CM-01, CM-06)
**Acao:**
- No cenario Make, adicionar `idempotency_key` baseado em hash do conteudo do post + data.
- Tabela/arquivo `published.json` com mapping `idempotency_key -> post_id` para detectar duplicatas antes de publicar.
**Aceite:** rodar o cenario 2x com mesmo input -> 1 post publicado.

### CM-E. Cloudinary upload em vez de fetch (PM-II CM-03)
**Acao:**
- Eliminar dependencia de baixar SHA-pinned de branch publica. Subir asset direto via Cloudinary API antes de gerar post.
**Aceite:** post publicado nao referencia URL bruto do GitHub raw.

### CM-F. Sanitizar caption antes de shell/Python (PM-II CM-02)
**Acao:**
- Toda interpolacao de string vinda de input externo em comando shell precisa de quote/escape ou ser passada como argumento (nao concatenada).
**Aceite:** caption com `;` `$()` `\`` e ignorada como literal.

### CM-G. Branch de producao no-ephemeral (PM-II CM-05)
**Acao:**
- Renomear `main` para `production` ou manter `main` e estabelecer policy: deploys da pipeline vem **apenas** de uma branch durable.
**Aceite:** Make consome de branch documentada, nao de `claude/*`.

### CM-H. Cron monitor do cenario Make (PM-II CM-08)
**Acao:**
- Pingar webhook de health 1x/dia. Se falhar 2x consecutivas, alerta via Sentry/Logtail.
**Aceite:** alerta dispara em derrubada simulada.

### CM-I. RUNBOOK.md de incidentes (PM-II CM-11)
**Acao:**
- Documentar: "post nao publicou", "imagem quebrada", "rate limit Meta", "Make scenario desligou", "Cloudinary 401". Cada cenario com passos de diagnostico e correcao.
**Aceite:** `docs/RUNBOOK.md` com >= 5 cenarios cobertos.

---

## P2 - APENAS SE MANTER (vencimento 2026-06-09)

### CM-J. Reescrever pipeline em Python com testes (PM-II CM-10)
**Acao:** migrar da arquitetura Make-centric para script Python local com testes unitarios. Make como fallback de notificacao apenas.
**Aceite:** pipeline rodavel local com `python publish.py --dry-run`. Cobertura >= 50%.

### CM-K. Separar SexuS.app deste repo (PM-II CM-09)
**Acao:** se houver codigo de SexuS.app ainda neste repo, extrair para repo proprio com decisao MANTER/CONGELAR/DESLIGAR equivalente.
**Aceite:** este repo contem apenas pipeline de carrossel.

---

## ITENS HERDADOS (TODOS DEPENDEM DE CM-A)

PM-II CM-01..CM-11: todos ABERTOS desde 2026-04-28 (12 dias).
PM-III CM-A1: PERSISTENTEMENTE ABERTO desde 2026-05-03 (7 dias).
PM-III CM-20: VENCIDA HOJE com 0% de execucao.

---

## REGRA DE AUDITORIA

- PM-V abre em 2026-05-17.
- Se ate la nao houver `STATUS.md` em main com decisao explicita, **PM-V vai recomendar DESLIGAR sem segunda chance**.
- Documento existente apenas em branch claude/* nao conta como executado.

**Proxima revisao:** 2026-05-17
