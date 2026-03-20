# Clean Growth Tool Website 2026

This repository rebuilds the Clean Growth Tool as a static `React + Vite` site that preserves the older two-pane browsing experience while using the latest public 2026 data published in [`bsf-rmi/RMI_Clean_Growth_Tool`](https://github.com/bsf-rmi/RMI_Clean_Growth_Tool).

## What this build does

- Keeps the classic `Region View` and `Industry View` reading flow.
- Uses vendored public snapshot data under [`public/data`](/Users/jon.ekberg/code/clean-growth-tool-website-2026/public/data).
- Replaces unsupported legacy workforce panels with modern metric panels that are backed by the public 2026 files.
- Deploys as a static site to GitHub Pages.

## Local development

```bash
cd /Users/jon.ekberg/code/clean-growth-tool-website-2026
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Refresh the vendored public data

```bash
npm run sync:data
```

That script pulls a sparse snapshot of the public upstream repo and refreshes:

- `public/data/meta`
- `public/data/by_geography`
- `public/data/by_industry`
- `public/data/topology`
- `public/data/branding`

## Deployment

GitHub Pages deployment is handled through [`.github/workflows/deploy.yml`](/Users/jon.ekberg/code/clean-growth-tool-website-2026/.github/workflows/deploy.yml).
