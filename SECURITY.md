# Security and disclosure policy

## Intended contents

Only the public application source, static styles, parameter-only model
artefact and synthetic self-test cases may be included in this repository or
deployment bundle.

The following are prohibited:

- patient-level or line-level tables;
- direct or indirect patient identifiers;
- observed clinical cases;
- fitted model objects;
- credentials, deployment tokens or private keys;
- local logs or R session history.

## Deployment controls

The deployment script uses an explicit file allowlist and verifies the
certified SHA-256 hashes of the model engine and public artefact before upload.
Credentials must be configured through the hosting platform or an appropriate
credential store and must never be committed to the repository.

## Reporting

Until a public contact channel is established, security or confidentiality
concerns should be reported directly to the study team through its existing
institutional communication channels. Do not include patient data in a report.
