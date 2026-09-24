# Thrombocytopenia Risk Calculator for Colorectal Cancer Chemotherapy

Research-use Shiny application implementing Model A, a longitudinal prediction
model for the per-cycle probability of any chemotherapy-induced
thrombocytopenia (CTCAE grade 1-4 versus grade 0) in patients treated for
colorectal cancer.

## Status

This repository is a **private publication candidate**. The parameter-only
prediction engine and its synthetic pattern cases were previously certified.
The redesigned Shiny package must undergo final packaging and cross-tool
certification before it is described as the definitive public release.

The model has been internally validated. External and prospective validation
remain pending.

## Inputs

1. Chemotherapy regimen.
2. Treatment cycle.
3. Age at the start of the current treatment line.
4. Baseline platelet count before the current treatment line.
5. Baseline haemoglobin before the current treatment line.

Treatment-line number is not requested and is not a fixed-effect predictor.

## Output

The application returns a continuous predicted probability and a 95%
parametric interval based on fixed-effect covariance. It also displays the risk
trajectory over the regimen-specific supported horizon and issues explicit
warnings for limited support or extrapolation.

The interval does not incorporate uncertainty from random-effect variances,
the recalibration intercept, model selection, internal validation or external
transportability.

## Domain rules

- Baseline platelets below 150 x10^3/uL do not block prediction but trigger a
  first-line caution.
- CAP, CAPOXL, 5FUOXL, 5FUIRI and CAPIRI support cycles 1-20; cycles 15-20 form
  a limited-support temporal tail.
- 5FUOXLIRI supports cycles 1-20 with limited support throughout.
- REG supports cycles 1-4 with reduced support.
- TFT supports cycles 1-3 with reduced support.
- Values outside P1-P99 trigger limited-support warnings.
- Values outside the observed range are explicitly identified as
  extrapolations.

## Confidentiality architecture

The repository contains only a parameter-level public artefact and synthetic
self-test cases. It contains no individual observations, patient identifiers,
observed clinical cases or fitted `glmmTMB` object. The application code does
not write or retain values submitted through the interface.

See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

## Run locally

Set the working directory to this repository and run:

```r
source("00_install_packages.R") # first time only
source("01_run_local.R")
```

The local development server uses `http://127.0.0.1:8787`.

## Private staging deployment

After configuring an eligible shinyapps.io account and installing `rsconnect`:

```r
source("02_deploy_shinyappsio.R")
```

The deployment script uses an explicit four-file allowlist and verifies the
SHA-256 hashes of the public prediction engine and parametric artefact before
uploading. Private application authentication depends on the selected hosting
plan.

## Clinical-use statement

This application provides informational predictive support. It does not
prescribe treatment, replace laboratory monitoring or professional judgement,
or establish causal differences between regimens. Predicted probabilities
must not be interpreted as externally validated estimates until such
validation has been completed.

## Certified computational components

- Public engine SHA-256:
  `093060ddebcd0d9d1744d4846e438494a61c47a8660d6e282dfd72628c02d324`
- Public parametric artefact SHA-256:
  `9dd12aa1a52213f7817bee1e33f20d44bdb19dc834c836d7c57ae30647ac7350`

## Citation and licence

Citation metadata and the software licence will be added after confirmation of
the definitive author list, institutional attribution and licensing decision.
