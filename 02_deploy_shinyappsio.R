required_packages <- c("rsconnect", "digest")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Install the following packages before deployment: ",
      paste(missing_packages, collapse = ", ")
    ),
    call. = FALSE
  )
}

deployment_files <- c(
  "app.R",
  file.path("R", "model_engine.R"),
  file.path("data", "20C_modelo_A_artefacto_parametrico_publico_v1.0.rds"),
  file.path("www", "styles.css")
)

missing_files <- deployment_files[!file.exists(deployment_files)]
if (length(missing_files) > 0L) {
  stop(
    paste0("Missing deployment files: ", paste(missing_files, collapse = ", ")),
    call. = FALSE
  )
}

linked_files <- deployment_files[nzchar(Sys.readlink(deployment_files))]
if (length(linked_files) > 0L) {
  stop(
    paste0(
      "Symbolic links are not permitted in the deployment bundle: ",
      paste(linked_files, collapse = ", ")
    ),
    call. = FALSE
  )
}

expected_engine_sha256 <-
  "093060ddebcd0d9d1744d4846e438494a61c47a8660d6e282dfd72628c02d324"
expected_artefact_sha256 <-
  "9dd12aa1a52213f7817bee1e33f20d44bdb19dc834c836d7c57ae30647ac7350"

engine_sha256 <- digest::digest(
  file.path("R", "model_engine.R"),
  algo = "sha256",
  serialize = FALSE
)
artefact_sha256 <- digest::digest(
  file.path("data", "20C_modelo_A_artefacto_parametrico_publico_v1.0.rds"),
  algo = "sha256",
  serialize = FALSE
)

if (!identical(engine_sha256, expected_engine_sha256)) {
  stop("The public prediction engine hash is not certified.", call. = FALSE)
}
if (!identical(artefact_sha256, expected_artefact_sha256)) {
  stop("The public parametric artefact hash is not certified.", call. = FALSE)
}

message("Deployment allowlist verified:")
message(paste0("- ", deployment_files, collapse = "\n"))
message("Patient-level data included: NO")
message("Fitted model object included: NO")

rsconnect::deployApp(
  appDir = getwd(),
  appFiles = deployment_files,
  appName = "model-a-cit-calculator-staging",
  appTitle = "Thrombocytopenia Risk Calculator - Staging",
  appVisibility = "private",
  launch.browser = FALSE,
  forceUpdate = TRUE,
  logLevel = "normal"
)
