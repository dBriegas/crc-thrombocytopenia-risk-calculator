# GitHub Pages deployment

The repository is deliberately kept private during development. In GitHub Free,
the planned GitHub Pages site requires a public repository.

Before replacing a public release:

1. Replace the repository contents with the audited v1.5 source set.
2. Commit and push the certified files to `main`.
3. Make the repository public only after the confidentiality audit is confirmed.
4. In Settings > Pages, select GitHub Actions as the build and deployment source.
5. Run the workflow; deployment occurs only after its real browser test passes.
6. Record the deployed commit, URL, final hashes and browser verification output.

The workflow follows the GitHub Pages architecture used by Posit's official
Shinylive example. Before export it creates a temporary runtime directory from
the exact four-file runtime allowlist certified by Script 25D. Documentation,
the browser test and build
files therefore never enter the browser's virtual filesystem. The deployed
application remains static: visitors do not connect to a remote R process.
