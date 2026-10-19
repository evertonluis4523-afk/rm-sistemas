# Carteira Everton

Aplicativo financeiro pessoal premium: rápido, offline-first, com contas, cartões,
metas, orçamentos, saúde financeira, insights automáticos e relatórios exportáveis.
Construído como PWA instalável — funciona como um app nativo em iOS, Android e desktop.

> Este é o **código-fonte** (React + TypeScript + Vite). O app publicado (build
> gerado) fica em [`../controle-gastos/`](../controle-gastos/), que é a pasta que o
> GitHub Pages efetivamente serve. Depois de alterar o código-fonte aqui, gere um
> novo build e copie para lá — veja "Publicar atualizações" abaixo.

## Stack

React 19 · TypeScript · Vite · IndexedDB (Dexie.js) · React Router · Framer Motion ·
Chart.js · React Hook Form + Zod · Material Symbols (auto-hospedado) · jsPDF ·
ExcelJS · date-fns · vite-plugin-pwa (Workbox)

## Arquitetura

```
src/
  components/     Componentes de UI (ui/, layout/, charts/, forms/, transaction/)
  pages/          Uma tela por rota (Dashboard, Transactions, Accounts, ...)
  hooks/          Hooks de dados (live queries reativas sobre o IndexedDB)
  services/       Regras de negócio: saúde financeira, insights, backup, export, auth
  database/       Schema do Dexie, categorias padrão, seed inicial
  models/         Tipos TypeScript de todas as entidades
  contexts/       Settings, AuthLock (PIN/biometria), Toast, Month
  styles/         Design tokens, fontes, estilos de componentes compartilhados
public/
  fonts/          Fontes auto-hospedadas (Inter, Sora, Material Symbols — subset)
  icons/          Ícones do PWA
```

## Como instalar e executar

Pré-requisitos: Node.js 20+ e npm.

```bash
cd controle-gastos-app
npm install
npm run dev
```

Abra o endereço mostrado no terminal (ex.: `http://localhost:5173/rm_contas/controle-gastos/`).

## Como gerar o build de produção

```bash
npm run build      # gera em dist/ (roda type-check + build)
npm run preview    # serve o build localmente para conferir antes de publicar
```

## Publicar atualizações no GitHub Pages

O GitHub Pages deste repositório publica a **branch `main`, pasta raiz** (não roda
build automático). Por isso o fluxo de publicação é:

```bash
cd controle-gastos-app
npm run build
rm -rf ../controle-gastos/*
cp -r dist/* ../controle-gastos/
cd ..
git add controle-gastos controle-gastos-app
git commit -m "Atualiza Carteira Everton"
git push
```

O app fica disponível em `https://<usuario>.github.io/rm_contas/controle-gastos/`.

> **Importante:** o `vite.config.ts` define `base: '/rm_contas/controle-gastos/'`.
> Se este projeto for movido para outro caminho/domínio, atualize essa constante
> (`BASE_PATH`) antes de gerar o build, ou os arquivos estáticos (JS/CSS/fontes)
> não serão encontrados.

## Como transformar em aplicativo instalável (PWA)

Não é necessário nenhum passo extra: o app já é um PWA completo (manifest,
service worker com cache offline, ícones, atalhos). No celular:

1. Abra a URL publicada no navegador (Chrome/Safari).
2. Toque em **"Adicionar à tela de início"** (Android) ou **"Adicionar à Tela de
   Início"** no menu de compartilhar (iPhone).
3. O app abre em tela cheia, como um aplicativo nativo, e funciona offline.

## Como gerar um APK / publicar nas lojas

O caminho recomendado é empacotar o PWA com **[PWABuilder](https://www.pwabuilder.com/)**
(gratuito, mantido pela Microsoft) ou **Bubblewrap** (Google, usa Trusted Web Activity):

```bash
npm install -g @bubblewrap/cli
bubblewrap init --manifest https://<usuario>.github.io/rm_contas/controle-gastos/manifest.webmanifest
bubblewrap build
```

Isso gera um `.aab`/`.apk` pronto para a Google Play, usando o próprio PWA como
fonte (sem reescrever o app). Para a App Store, o PWABuilder também gera um
projeto Xcode que empacota o PWA como app iOS.

## Como configurar os ícones

Os ícones ficam em `public/icons/` (`icon-192.svg`, `icon-512.svg`, `maskable-512.svg`)
e são referenciados em `vite.config.ts` (bloco `manifest.icons`). Para trocar a
identidade visual, substitua esses SVGs (mantendo os nomes) e gere um novo build.

## Fontes auto-hospedadas (offline real)

Todas as fontes (Inter, Sora, Material Symbols) ficam em `public/fonts/` e são
carregadas localmente — o app **não depende do Google Fonts em tempo de
execução**, garantindo que funcione mesmo no primeiro carregamento offline.

O ícone (Material Symbols) foi reduzido a um subset contendo **apenas os glifos
usados no app** (via `fonttools`), mapeados por codepoint Unicode em
`src/components/ui/iconCodepoints.ts`. Ao usar um novo nome de ícone que ainda
não exista nesse mapa, gere um novo subset:

```bash
pip install fonttools brotli
# 1. Baixe a fonte completa e o mapa de codepoints do Material Symbols Rounded
# 2. Adicione o(s) novo(s) nome(s) à lista de ícones usados
# 3. Rode:
python3 -m fontTools.subset material-symbols-rounded-full.woff2 \
  --unicodes="U+xxxx,U+yyyy,..." --layout-features='' --flavor=woff2 \
  --output-file=public/fonts/material-symbols-rounded.woff2 \
  --no-hinting --desubroutinize --glyph-names
```

## Segurança — o que este app garante (e o que não garante)

- **PIN local**: nunca armazenado em texto puro — hash PBKDF2-SHA256 (100k
  iterações) com salt aleatório, comparação em tempo constante.
- **Biometria (Face ID / Touch ID / impressão digital)**: via WebAuthn, usando
  o autenticador de plataforma do aparelho como "portão" de desbloqueio local.
  Como o app não tem servidor, este fluxo **não verifica assinatura
  criptográfica remota** — é um gate local, não uma prova de identidade para
  terceiros. O PIN é sempre o mecanismo principal e o fallback garantido.
- **Backup criptografado**: exportações podem ser protegidas com senha
  (AES-256-GCM, chave derivada via PBKDF2). Sem a senha, o arquivo não pode
  ser lido.
- **O que este app NÃO faz**: não criptografa o banco IndexedDB "em repouso"
  campo a campo (isso exigiria uma camada extra de criptografia em cada
  leitura/escrita, com custo de performance, e ainda dependeria de uma chave
  guardada em algum lugar do próprio dispositivo). O modelo de segurança aqui
  é "proteção de sessão local" adequado para um app pessoal sem backend —
  não é um cofre criptográfico de nível bancário.

## Sincronização em nuvem

A estrutura está pronta (`src/services/backup.ts`, interface `CloudSyncProvider`)
mas **nenhum provedor está conectado**. Para ativar sincronização entre
aparelhos no futuro, implemente essa interface para o provedor escolhido
(ex.: Supabase, Firebase) e registre-o em `cloudSyncRegistry`.

## Qualidade de código

- TypeScript estrito (`noUnusedLocals`, `noUnusedParameters`, sem `any` implícito).
- Arquitetura em camadas: `database` → `models` → `services`/`hooks` → `components`/`pages`.
- Code-splitting automático das bibliotecas pesadas de exportação (jsPDF,
  ExcelJS) — só são baixadas quando o usuário exporta um relatório.
- `npx tsc -b --noEmit` para checar tipos sem gerar build.

## Limitações conhecidas

- Sem backend: sincronização em nuvem, notificações push reais e recuperação
  de PIN remota não são possíveis sem conectar um provedor externo (estrutura
  pronta, ver acima).
- Notificações usam a API nativa do navegador (permissão solicitada pelo
  próprio navegador); não há push server.
- WebAuthn/biometria depende do suporte do navegador/aparelho — quando
  indisponível, o app usa apenas PIN automaticamente (detecção de recurso).
