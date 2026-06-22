import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5002,
    strictPort: false,
    allowedHosts: true,
  },
  build: {
    chunkSizeWarningLimit: 3000,
  },
  preview: {
    host: '0.0.0.0',
    port: 5002,
    allowedHosts: true,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
