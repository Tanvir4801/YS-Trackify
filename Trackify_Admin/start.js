#!/usr/bin/env node
// Starts the Vite dev server without needing .bin/vite symlink
import { fileURLToPath } from 'url';
import { createRequire } from 'module';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

// Set working directory to admin panel root
process.chdir(__dirname);

// Load and run the Vite CLI
const viteCli = path.join(__dirname, 'node_modules/vite/dist/node/cli.js');
await import(viteCli);
