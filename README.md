# Clean Growth Tool Website 2026

This repository now hosts an `R Shiny` rebuild of the Clean Growth Tool that keeps the older interface shell while swapping in the newer public data snapshot from [`bsf-rmi/RMI_Clean_Growth_Tool`](https://github.com/bsf-rmi/RMI_Clean_Growth_Tool).

## Current app

- Main entrypoint: [`app.R`](/Users/jon.ekberg/code/clean-growth-tool-website-2026/app.R)
- Static assets: [`www/`](/Users/jon.ekberg/code/clean-growth-tool-website-2026/www)
- Vendored public data: [`public/data/`](/Users/jon.ekberg/code/clean-growth-tool-website-2026/public/data)

What this Shiny build does:

- Preserves the older `Region View`, `Industry View`, and `About` structure.
- Uses the newer public geography model: `County`, `State`, `CBSA`, `CSA`, and `Commuting Zone`.
- Replaces unsupported legacy workforce and investment panels with public-data-backed metrics:
  - `Economic Complexity Index`
  - `Industrial Diversity`
  - `Strategic Index`
  - `Feasibility`
  - `Strategic Gain`
- Keeps the old `Map / Table` pattern in `Industry View`.
  - Real choropleths are available for `State` and `County`.
  - `CBSA`, `CSA`, and `CZ` currently fall back to a structured ranked panel because matching public geometry is not bundled in the upstream snapshot.

## Run locally

```bash
cd /Users/jon.ekberg/code/clean-growth-tool-website-2026
./start-shiny.sh
```

Then open:

- [http://127.0.0.1:3840](http://127.0.0.1:3840)

You can also run it directly:

```bash
Rscript -e 'shiny::runApp(".", host = "127.0.0.1", port = 3840, launch.browser = FALSE)'
```

## Data refresh

The vendored public snapshot is still refreshed with the existing Node script:

```bash
cd /Users/jon.ekberg/code/clean-growth-tool-website-2026
npm install
npm run sync:data
```

That script refreshes:

- `public/data/meta`
- `public/data/by_geography`
- `public/data/by_industry`
- `public/data/topology`
- `public/data/branding`

## Deployment note

The repository originally shipped with a static `React + Vite` preview for GitHub Pages. The active implementation is now `R Shiny`, so GitHub Pages is no longer the correct deployment target for the main app.

For a live hosted version of the Shiny build, use a Shiny-capable platform such as:

- `shinyapps.io`
- `Posit Connect`
- a container-based host that can run an R process

GitHub Pages can still be used for static documentation or a handoff page, but not for the running Shiny application itself.
