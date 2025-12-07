import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  // This ensures the compiler supports import.meta
  esbuild: {
    target: "es2020"
  },
  // This ensures the build output supports import.meta
  build: {
    target: "es2020"
  }
})