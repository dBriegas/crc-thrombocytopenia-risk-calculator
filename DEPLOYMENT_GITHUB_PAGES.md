# GitHub Pages deployment

The repository remained private throughout development. The source candidate
passed Script 26C and is approved for publication through GitHub Pages.

Certified deployment sequence:

1. Replace the candidate repository contents with the audited v1.4 source set.
2. Commit and push the certified files to `main`.
3. Make the repository public only after the confidentiality audit is confirmed.
4. In Settings > Pages, select GitHub Actions as the build and deployment source.
5. Run the workflow and verify the published URL in a clean browser session.
6. Record the deployed commit, URL, final hashes and browser verification output.

Steps 1-3 may be performed only after the Script 26C status is
`CERTIFIED_FOR_GITHUB_PAGES_DEPLOYMENT`. Step 6 closes the chain as Script 26D.

The workflow follows the GitHub Pages architecture used by Posit's official
Shinylive example. Before export it creates a temporary runtime directory from
the exact four-file allowlist certified by Script 25C. Documentation and build
files therefore never enter the browser's virtual filesystem. The deployed
application remains static: visitors do not connect to a remote R process.
