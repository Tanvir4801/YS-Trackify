---
name: Admin Panel esbuild / lucide-react fix
description: How to fix Vite 4 failing to resolve lucide-react in Trackify_Admin, and how to run the dev server without .bin symlinks.
---

## Problem
`lucide-react@1.11.0` ships `"module": "dist/esm/lucide-react.mjs"` in its package.json, but that `.mjs` bundle file is missing from the installed package (only helper files like `context.mjs` exist in `dist/esm/`). Vite 4's esbuild dep-scanner tries to resolve that module field and fails with "Failed to resolve entry for package lucide-react".

## Fix
In `Trackify_Admin/vite.config.js`, alias lucide-react to the CJS bundle and add it to `optimizeDeps.include`:

```js
resolve: {
  alias: {
    "lucide-react": path.resolve(__dirname, "node_modules/lucide-react/dist/cjs/lucide-react.js"),
  },
},
optimizeDeps: {
  include: ['lucide-react'],
  esbuildOptions: { mainFields: ['main'] },
},
```

**Why:** The CJS bundle at `dist/cjs/lucide-react.js` (932KB) is intact. The `main` field in package.json points to it correctly. Only the ESM bundle is missing.

## Running Vite without .bin symlinks
`node_modules/.bin` has 0 symlinks (npm install doesn't create them in this Replit env). Run vite directly:
```
cd Trackify_Admin && node node_modules/vite/dist/node/cli.js
```

## Workflow
The "Start Admin Panel" workflow is configured with:
- command: `cd Trackify_Admin && node node_modules/vite/dist/node/cli.js`
- port: 3000, outputType: console (webview requires port 5000 only)
