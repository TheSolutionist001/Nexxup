import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  test: {
    include: ['tests/unit/**/*.test.ts', 'tests/db/**/*.test.ts'],
    // Die Datenbank-Tests laden alle Migrationen in ein lokales Postgres
    testTimeout: 30_000,
    environment: 'node',
  },
});
