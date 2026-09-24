# Security and disclosure policy

## Permitted repository contents

Only public application source, static styles, the parameter-only model artefact,
synthetic self-test cases and publication documentation may be committed.

The following are prohibited:

- patient-level or treatment-line-level tables;
- direct or indirect patient identifiers;
- observed clinical cases;
- fitted model objects;
- credentials, deployment tokens or private keys;
- local logs, R history or environment files.

## Deployment controls

The source candidate is built from an explicit allowlist. The model engine and
public artefact are checked against certified SHA-256 signatures. Deployment is
performed by GitHub Actions using the repository token supplied automatically by
GitHub; no personal token is stored in the repository.

The prediction engine runs in the browser. The application code contains no
analytics, cookies, external database connection or facility for persisting
submitted values.

## Reporting

Until a public contact channel is established, security or confidentiality
concerns should be reported to the study team through existing institutional
channels. Do not include patient data in a report.
