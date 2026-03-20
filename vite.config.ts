import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  base: '/clean-growth-tool-website-2026/',
  plugins: [react()],
  build: {
    sourcemap: false,
  },
});
