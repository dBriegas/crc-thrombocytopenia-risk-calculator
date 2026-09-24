###############################################################################
# R/model_engine.R
# Public parameter-only prediction engine for Model A.
###############################################################################

model_a_expected_terms <- c(
  "(Intercept)",
  "ns_cord_c_1",
  "ns_cord_c_2",
  "esquema_nucCAPOXL",
  "esquema_nuc5FUOXL",
  "esquema_nuc5FUIRI",
  "esquema_nucCAPIRI",
  "esquema_nuc5FUOXLIRI",
  "esquema_nucREG",
  "esquema_nucTFT",
  "int_cord_CAPOXL",
  "int_cord_5FUOXL",
  "int_cord_5FUIRI",
  "int_cord_CAPIRI",
  "int_cord_5FUOXLIRI",
  "age",
  "pt0",
  "hb0"
)

model_a_expected_regimens <- c(
  "CAP",
  "CAPOXL",
  "5FUOXL",
  "5FUIRI",
  "CAPIRI",
  "5FUOXLIRI",
  "REG",
  "TFT"
)

model_a_assert <- function(condition, message) {
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
  invisible(TRUE)
}

model_a_sha256 <- function(path) {
  digest::digest(
    path,
    algo = "sha256",
    file = TRUE,
    serialize = FALSE
  )
}

model_a_clip <- function(probability, epsilon) {
  pmin(pmax(as.numeric(probability), epsilon), 1 - epsilon)
}

model_a_load_artefact <- function(path, expected_sha256) {

  model_a_assert(file.exists(path), paste0("Missing public artefact: ", path))

  observed_sha256 <- model_a_sha256(path)

  model_a_assert(
    identical(observed_sha256, expected_sha256),
    paste0(
      "Public artefact identity check failed. Expected ",
      expected_sha256,
      "; observed ",
      observed_sha256,
      "."
    )
  )

  artefact <- readRDS(path)

  model_a_assert(is.list(artefact), "The public artefact is not a list.")
  model_a_assert(
    identical(artefact$metadata$contains_patient_level_data, FALSE) &&
      identical(artefact$metadata$contains_fitted_model_object, FALSE) &&
      identical(artefact$metadata$contains_serialized_functions, FALSE) &&
      identical(artefact$metadata$synthetic_pattern_cases_only, TRUE),
    "Public artefact confidentiality metadata are invalid."
  )
  model_a_assert(
    identical(names(artefact$fixed_effects), model_a_expected_terms),
    "Fixed-effect terms do not match the public specification."
  )
  model_a_assert(
    identical(
      as.character(artefact$factor_encoding$levels),
      model_a_expected_regimens
    ),
    "Regimen levels do not match the public specification."
  )
  model_a_assert(
    isTRUE(artefact$numerical_certification$passed),
    "The public artefact is not numerically certified."
  )

  attr(artefact, "verified_sha256") <- observed_sha256
  artefact
}

model_a_design_matrix <- function(data, artefact) {

  data <- as.data.frame(data)
  required <- artefact$input_specification$names

  model_a_assert(
    all(required %in% names(data)),
    paste0("Missing inputs: ", paste(setdiff(required, names(data)), collapse = ", "))
  )

  cycle <- suppressWarnings(as.numeric(data$cord))
  regimen <- as.character(data$esquema_nuc)
  age <- suppressWarnings(as.numeric(data$age))
  platelets <- suppressWarnings(as.numeric(data$pt0))
  haemoglobin <- suppressWarnings(as.numeric(data$hb0))

  model_a_assert(
    all(is.finite(cycle)) &&
      all(cycle == floor(cycle)) &&
      all(cycle >= 1 & cycle <= 20),
    "Treatment cycle must be an integer between 1 and 20."
  )
  model_a_assert(
    all(regimen %in% artefact$factor_encoding$levels),
    "At least one regimen is unsupported."
  )
  model_a_assert(
    all(is.finite(age)) &&
      all(is.finite(platelets)) &&
      all(is.finite(haemoglobin)),
    "Continuous inputs must be finite numeric values."
  )

  cord_c <- cycle - 1

  spline <- splines::ns(
    cord_c,
    knots = artefact$temporal_spline$internal_knot,
    Boundary.knots = c(
      artefact$temporal_spline$lower_boundary,
      artefact$temporal_spline$upper_boundary
    ),
    intercept = FALSE
  )

  columns <- artefact$design_specification$column_order
  design <- matrix(
    0,
    nrow = nrow(data),
    ncol = length(columns),
    dimnames = list(NULL, columns)
  )

  design[, "(Intercept)"] <- 1
  design[, "ns_cord_c_1"] <- spline[, 1]
  design[, "ns_cord_c_2"] <- spline[, 2]

  for (level in setdiff(artefact$factor_encoding$levels, "CAP")) {
    design[, paste0("esquema_nuc", level)] <- as.numeric(regimen == level)
  }

  for (level in names(
    artefact$design_specification$regimen_time_interactions
  )) {
    column <- artefact$design_specification$regimen_time_interactions[[level]]
    design[, column] <- ifelse(regimen == level, cord_c, 0)
  }

  design[, "age"] <- age
  design[, "pt0"] <- platelets
  design[, "hb0"] <- haemoglobin

  design
}

model_a_central_prediction <- function(design, artefact) {

  beta <- stats::setNames(
    as.numeric(artefact$fixed_effects),
    names(artefact$fixed_effects)
  )

  eta <- as.numeric(design %*% beta)

  shifted_eta <- outer(
    eta,
    sqrt(artefact$marginalisation$total_random_effect_variance) *
      artefact$marginalisation$nodes,
    "+"
  )

  p_marginal <- as.numeric(
    stats::plogis(shifted_eta) %*% artefact$marginalisation$weights
  )

  epsilon <- artefact$recalibration$probability_clip_epsilon
  p_clipped <- model_a_clip(p_marginal, epsilon)

  p_final <- stats::plogis(
    stats::qlogis(p_clipped) + artefact$recalibration$alpha
  )

  data.frame(
    eta_fixed = eta,
    p_marginal = p_marginal,
    p_final = as.numeric(p_final),
    stringsAsFactors = FALSE
  )
}

model_a_generate_beta_draws <- function(artefact) {

  covariance <- as.matrix(artefact$fixed_effect_covariance)
  covariance <- (covariance + t(covariance)) / 2

  decomposition <- eigen(covariance, symmetric = TRUE)

  model_a_assert(
    min(decomposition$values) >= -1e-8,
    "Fixed-effect covariance is not positive semidefinite."
  )

  eigenvalues <- pmax(decomposition$values, 0)
  transform <- decomposition$vectors %*%
    diag(sqrt(eigenvalues), nrow = length(eigenvalues))

  draws <- as.integer(artefact$parametric_uncertainty$recommended_draws)
  seed <- as.integer(artefact$parametric_uncertainty$fixed_seed)

  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }

  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(seed)
  standard_normal <- matrix(
    stats::rnorm(draws * nrow(covariance)),
    nrow = draws,
    ncol = nrow(covariance)
  )

  beta_draws <- standard_normal %*% t(transform)
  beta_draws <- sweep(
    beta_draws,
    2,
    as.numeric(artefact$fixed_effects),
    "+"
  )

  colnames(beta_draws) <- names(artefact$fixed_effects)
  beta_draws
}

model_a_parametric_interval <- function(design, artefact, beta_draws) {

  model_a_assert(
    is.matrix(beta_draws) &&
      identical(colnames(beta_draws), colnames(design)),
    "Parametric beta draws do not match the design matrix."
  )

  variance_total <- artefact$marginalisation$total_random_effect_variance
  nodes <- artefact$marginalisation$nodes
  weights <- artefact$marginalisation$weights
  alpha <- artefact$recalibration$alpha
  epsilon <- artefact$recalibration$probability_clip_epsilon

  interval_matrix <- t(vapply(
    seq_len(nrow(design)),
    function(index) {

      eta_draw <- as.numeric(beta_draws %*% design[index, ])
      shifted_eta <- outer(eta_draw, sqrt(variance_total) * nodes, "+")
      p_marginal <- as.numeric(stats::plogis(shifted_eta) %*% weights)
      p_clipped <- model_a_clip(p_marginal, epsilon)
      p_final <- stats::plogis(stats::qlogis(p_clipped) + alpha)

      stats::quantile(
        p_final,
        probs = c(0.025, 0.975),
        names = FALSE,
        type = 7
      )
    },
    numeric(2)
  ))

  data.frame(
    lower = interval_matrix[, 1],
    upper = interval_matrix[, 2],
    stringsAsFactors = FALSE
  )
}

model_a_predict <- function(
  data,
  artefact,
  beta_draws = NULL,
  interval = FALSE
) {

  design <- model_a_design_matrix(data, artefact)
  central <- model_a_central_prediction(design, artefact)

  if (!isTRUE(interval)) {
    return(central)
  }

  model_a_assert(!is.null(beta_draws), "beta_draws are required for intervals.")
  uncertainty <- model_a_parametric_interval(design, artefact, beta_draws)

  cbind(central, uncertainty)
}

model_a_self_test <- function(artefact, tolerance = 1e-12) {

  cases <- as.data.frame(artefact$synthetic_pattern_cases)
  expected <- as.data.frame(artefact$synthetic_expected_predictions)

  model_a_assert(
    nrow(cases) == 8L &&
      nrow(expected) == 8L &&
      identical(as.character(cases$case_id), as.character(expected$case_id)),
    "Synthetic self-test cases are missing or misaligned."
  )

  predicted <- model_a_predict(cases, artefact, interval = FALSE)
  differences <- abs(predicted$p_final - as.numeric(expected$p_final))
  maximum <- max(differences)

  list(
    passed = is.finite(maximum) && maximum <= tolerance,
    maximum_absolute_difference = maximum,
    tolerance = tolerance,
    case_ids = as.character(cases$case_id),
    predicted = predicted$p_final,
    expected = as.numeric(expected$p_final)
  )
}
