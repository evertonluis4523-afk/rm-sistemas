import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// Publicado em https://<usuario>.github.io/rm_contas/controle-gastos/
// O base precisa bater com o subcaminho real do GitHub Pages.
const BASE_PATH = '/rm_contas/controle-gastos/'

export default defineConfig({
  base: BASE_PATH,
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icons/icon-192.svg', 'icons/icon-512.svg', 'icons/maskable-512.svg'],
      manifest: {
        id: BASE_PATH,
        name: 'Carteira Everton',
        short_name: 'Carteira',
        description: 'Aplicativo financeiro pessoal — controle de gastos, contas, cartões e metas, 100% offline.',
        start_url: BASE_PATH,
        scope: BASE_PATH,
        display: 'standalone',
        orientation: 'portrait',
        background_color: '#0F1115',
        theme_color: '#0F1115',
        lang: 'pt-BR',
        categories: ['finance', 'productivity'],
        icons: [
          { src: 'icons/icon-192.svg', sizes: '192x192', type: 'image/svg+xml', purpose: 'any' },
          { src: 'icons/icon-512.svg', sizes: '512x512', type: 'image/svg+xml', purpose: 'any' },
          { src: 'icons/maskable-512.svg', sizes: '512x512', type: 'image/svg+xml', purpose: 'maskable' },
        ],
        shortcuts: [
          { name: 'Novo gasto', short_name: 'Gasto', url: BASE_PATH + '?new=expense' },
          { name: 'Nova receita', short_name: 'Receita', url: BASE_PATH + '?new=income' },
          { name: 'Relatórios', short_name: 'Relatórios', url: BASE_PATH + 'relatorios' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,png,ico,woff2}'],
        navigateFallback: BASE_PATH + 'index.html',
        cleanupOutdatedCaches: true,
        // Os chunks de exportação (jsPDF/ExcelJS) são maiores que o padrão de 2 MiB;
        // ainda assim devem ser pré-cacheados para exportar relatórios offline.
        maximumFileSizeToCacheInBytes: 6 * 1024 * 1024,
        runtimeCaching: [
          {
            urlPattern: ({ request }) => request.destination === 'font',
            handler: 'CacheFirst',
            options: { cacheName: 'fonts-cache', expiration: { maxEntries: 20, maxAgeSeconds: 60 * 60 * 24 * 365 } },
          },
        ],
      },
      devOptions: { enabled: false },
    }),
  ],
  build: {
    target: 'es2020',
    sourcemap: false,
    chunkSizeWarningLimit: 900,
  },
})
