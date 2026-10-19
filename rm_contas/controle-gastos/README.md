# ⚠️ Pasta gerada automaticamente — não edite aqui

Este diretório contém o **build de produção** do app **Carteira Everton**,
publicado pelo GitHub Pages em:
`https://<usuario>.github.io/rm_contas/controle-gastos/`

O **código-fonte** (React + TypeScript) vive em [`../controle-gastos-app/`](../controle-gastos-app/).

Para atualizar este app:

```bash
cd ../controle-gastos-app
npm install
npm run build
rm -rf ../controle-gastos/*
cp -r dist/* ../controle-gastos/
```

Veja o README completo em `../controle-gastos-app/README.md` para instruções de
desenvolvimento, publicação, geração de APK e demais detalhes.
