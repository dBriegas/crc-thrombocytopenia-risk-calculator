required_packages <- c("shiny", "bslib", "ggplot2", "digest", "splines")

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) == 0L) {
  message("All required packages are already installed.")
} else {
  message("Installing: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, dependencies = TRUE)
  still_missing <- missing_packages[
    !vapply(missing_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(still_missing) > 0L) {
    stop(
      paste0("Could not install: ", paste(still_missing, collapse = ", ")),
      call. = FALSE
    )
  }
}
