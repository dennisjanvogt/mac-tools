import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'node:path'

// Self-contained build — single HTML with inlined assets where possible.
// Output goes to dist/ which Swift copies into Canwa.app/Contents/Resources/web/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
  base: './',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    target: 'safari16',
    assetsInlineLimit: 4096,
    rollupOptions: {
      output: {
        manualChunks: undefined,
      },
    },
  },
})
