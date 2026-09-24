required_packages <- c("shiny", "bslib", "ggplot2", "digest", "splines")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Missing packages: ", paste(missing_packages, collapse = ", "),
      ". Run 00_install_packages.R first."
    ),
    call. = FALSE
  )
}
options(shiny.autoreload = TRUE)
shiny::runApp(
  appDir = getwd(),
  host = "127.0.0.1",
  port = 8787,
  launch.browser = TRUE
)
