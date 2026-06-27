// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  // Produktions-Domain (für korrekte Canonical-URLs / Sitemap).
  site: 'https://www.fishertechservice.ch',
  redirects: {
    '/about': '/#services',
  },
  vite: {
    css: {
      preprocessorOptions: {
        scss: {
          // Moderne Sass-API (sass-embedded) statt der veralteten Legacy-JS-API.
          api: 'modern-compiler',
          // Bulma nutzt intern noch veraltetes if()-Syntax; quietDeps blendet
          // Deprecation-Warnungen aus node_modules aus, ohne eigene Styles
          // stummzuschalten. Die finale CSS-Minifizierung übernimmt Astro.
          quietDeps: true,
        },
      },
    },
  },
});
