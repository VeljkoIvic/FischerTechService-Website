// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  base: '/FischerTechService/',
  vite: {
    css: {
      preprocessorOptions: {
        scss: {
          api: 'legacy',
          // Enable SCSS minification in production builds
          // Development: 'expanded' for readability
          // Production: 'compressed' for minimal file size
          outputStyle: 'compressed',
        },
      },
    },
  },
});
