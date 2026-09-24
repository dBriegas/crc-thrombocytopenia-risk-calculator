###############################################################################
# app.R
# Model A Public Shinylive Clinical Calculator v1.4
###############################################################################

options(stringsAsFactors = FALSE)

required_packages <- c("shiny", "bslib", "ggplot2", "digest", "splines")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    paste0(
      "Missing required packages: ",
      paste(missing_packages, collapse = ", "),
      ". Install the packages listed in README.md first."
    ),
    call. = FALSE
  )
}

source(file.path("R", "model_engine.R"), local = TRUE)

public_artefact_file <- file.path(
  "data",
  "20C_modelo_A_artefacto_parametrico_publico_v1.0.rds"
)

expected_public_sha256 <-
  "9dd12aa1a52213f7817bee1e33f20d44bdb19dc834c836d7c57ae30647ac7350"

model_artefact <- model_a_load_artefact(
  public_artefact_file,
  expected_public_sha256
)

model_self_test <- model_a_self_test(model_artefact, tolerance = 1e-12)

if (!isTRUE(model_self_test$passed)) {
  stop(
    paste0(
      "Synthetic self-test failed. Maximum absolute difference = ",
      format(model_self_test$maximum_absolute_difference, scientific = TRUE)
    ),
    call. = FALSE
  )
}

model_beta_draws <- model_a_generate_beta_draws(model_artefact)
model_regimens <- as.character(model_artefact$factor_encoding$levels)
model_domain <- as.data.frame(model_artefact$operational_domain)
model_horizons <- as.data.frame(model_artefact$prediction_horizons)
default_case <- as.data.frame(model_artefact$synthetic_pattern_cases)[1, ]

regimen_labels <- c(
  CAP = "Capecitabine (CAP)",
  CAPOXL = "Capecitabine + oxaliplatin (CAPOXL)",
  `5FUOXL` = "5-FU + oxaliplatin (5FUOXL)",
  `5FUIRI` = "5-FU + irinotecan (5FUIRI)",
  CAPIRI = "Capecitabine + irinotecan (CAPIRI)",
  `5FUOXLIRI` = "5-FU + oxaliplatin + irinotecan (5FUOXLIRI)",
  REG = "Regorafenib (REG)",
  TFT = "Trifluridine/tipiracil (TFT)"
)

regimen_choices <- stats::setNames(
  model_regimens,
  unname(regimen_labels[model_regimens])
)

maximum_cycle <- function(regimen) {
  value <- model_horizons$maximum_supported_cycle[
    match(as.character(regimen), model_horizons$regimen)
  ]
  as.integer(value)
}

validate_case <- function(regimen, cycle, age, platelets, haemoglobin) {

  errors <- character(0)

  if (!(regimen %in% model_regimens)) {
    errors <- c(errors, "Unsupported regimen.")
  }

  if (!is.finite(cycle) || cycle != floor(cycle) || cycle < 1) {
    errors <- c(errors, "Treatment cycle must be a positive integer.")
  }

  if (
    regimen %in% model_regimens &&
      is.finite(cycle) &&
      cycle > maximum_cycle(regimen)
  ) {
    errors <- c(
      errors,
      paste0(
        "This regimen is supported only through cycle ",
        maximum_cycle(regimen),
        "."
      )
    )
  }

  if (!is.finite(age) || age <= 0) {
    errors <- c(errors, "Age must be a valid positive number.")
  }
  if (!is.finite(platelets) || platelets <= 0) {
    errors <- c(errors, "Baseline platelet count must be a valid positive number.")
  }
  if (!is.finite(haemoglobin) || haemoglobin <= 0) {
    errors <- c(errors, "Baseline haemoglobin must be a valid positive number.")
  }

  errors
}

cycle_support <- function(regimen, cycle) {

  regimen <- as.character(regimen)
  cycle <- as.integer(cycle)

  if (regimen %in% c("REG", "TFT")) {
    return(list(
      level = "reduced",
      title = "Reduced support",
      message = paste0(
        regimen_labels[[regimen]],
        " is a structurally short category with reduced support throughout ",
        "its permitted horizon."
      )
    ))
  }

  if (identical(regimen, "5FUOXLIRI")) {
    return(list(
      level = "limited",
      title = "Limited support",
      message = paste0(
        "The triplet regimen has limited support throughout cycles 1-20 ",
        "because of its small development sample."
      )
    ))
  }

  if (cycle >= 15L) {
    return(list(
      level = "limited",
      title = "Limited temporal support",
      message = paste0(
        "Cycle ", cycle,
        " lies in the limited-support temporal tail (cycles 15-20)."
      )
    ))
  }

  list(
    level = "robust",
    title = "Main temporal support",
    message = "The selected cycle lies within the main temporal support."
  )
}

continuous_support <- function(age, platelets, haemoglobin) {

  values <- c(age = age, pt0 = platelets, hb0 = haemoglobin)
  labels <- c(
    age = "Age",
    pt0 = "Baseline platelet count",
    hb0 = "Baseline haemoglobin"
  )

  limited <- character(0)
  extrapolation <- character(0)

  for (index in seq_len(nrow(model_domain))) {
    row <- model_domain[index, ]
    value <- values[[as.character(row$variable)]]
    label <- labels[[as.character(row$variable)]]

    if (value < row$observed_min || value > row$observed_max) {
      extrapolation <- c(
        extrapolation,
        paste0(
          label,
          " is outside the observed range (",
          format(row$observed_min, trim = TRUE),
          " to ",
          format(row$observed_max, trim = TRUE),
          ")."
        )
      )
    } else if (value < row$p1 || value > row$p99) {
      limited <- c(
        limited,
        paste0(
          label,
          " is outside the P1-P99 main-support interval (",
          format(row$p1, digits = 6, trim = TRUE),
          " to ",
          format(row$p99, digits = 6, trim = TRUE),
          ")."
        )
      )
    }
  }

  platelet_caution <- if (platelets < 150) {
    paste0(
      "Baseline platelets are below 150 x10^3/uL. This does not block ",
      "prediction, but interpretation requires particular caution if the ",
      "evaluated episode is first line."
    )
  } else {
    character(0)
  }

  list(
    limited = limited,
    extrapolation = extrapolation,
    platelet_caution = platelet_caution
  )
}

app_theme <- bslib::bs_theme(
  version = 5,
  bg = "#FFFEF6",
  fg = "#40403E",
  primary = "#D78F3B",
  secondary = "#B2A44A",
  success = "#B2A44A",
  warning = "#F7E3A0",
  danger = "#B94F45",
  base_font = bslib::font_collection(
    "Inter",
    "Aptos",
    "-apple-system",
    "BlinkMacSystemFont",
    "Segoe UI",
    "sans-serif"
  )
)

ui <- shiny::fluidPage(
  theme = app_theme,
  shiny::tags$head(
    shiny::tags$title("Model A Public Clinical Calculator"),
    shiny::tags$meta(name = "theme-color", content = "#FFFEF6"),
    shiny::tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")
  ),
  shiny::div(
    class = "app-shell",
    shiny::div(
      class = "hero",
      shiny::div(class = "hero-kicker", "Colorectal cancer · Public Model A"),
      shiny::h1("Chemotherapy-induced thrombocytopenia risk"),
      shiny::p(
        paste0(
          "Estimated continuous probability of any thrombocytopenia ",
          "(CTCAE grade 1-4 vs 0) during an individual treatment cycle."
        )
      ),
      shiny::div(
        class = "model-badge",
        "Internally validated · External/prospective validation pending"
      )
    ),
    shiny::fluidRow(
      shiny::column(
        width = 4,
        shiny::div(
          class = "panel-card",
          shiny::div(class = "panel-title", "Patient and treatment inputs"),
          shiny::selectInput(
            inputId = "regimen",
            label = "Regimen",
            choices = regimen_choices,
            selected = as.character(default_case$esquema_nuc)
          ),
          shiny::numericInput(
            inputId = "cycle",
            label = "Treatment cycle",
            value = as.integer(default_case$cord),
            min = 1,
            max = 20,
            step = 1
          ),
          shiny::numericInput(
            inputId = "age",
            label = "Age (years)",
            value = as.numeric(default_case$age),
            min = 0.1,
            step = 0.1
          ),
          shiny::numericInput(
            inputId = "platelets",
            label = "Baseline platelet count (x10^3/uL)",
            value = as.numeric(default_case$pt0),
            min = 0.1,
            step = 0.1
          ),
          shiny::numericInput(
            inputId = "haemoglobin",
            label = "Baseline haemoglobin (g/dL)",
            value = as.numeric(default_case$hb0),
            min = 0.1,
            step = 0.1
          ),
          shiny::div(
            class = "small-note",
            shiny::HTML(
              paste0(
                "<strong>Baseline values</strong> refer to measurements ",
                "before the start of the current treatment line. ",
                "Treatment-line number is not requested."
              )
            )
          ),
          shiny::actionButton(
            inputId = "calculate",
            label = "Calculate risk",
            class = "btn-primary"
          )
        ),
        shiny::div(
          class = "panel-card",
          shiny::div(class = "panel-title", "Clinical-use note"),
          shiny::div(
            class = "footer-note",
            shiny::HTML(
              paste0(
                "This model provides <strong>informational predictive ",
                "support</strong>. It does not prescribe treatment, replace ",
                "laboratory monitoring or professional judgement, or establish ",
                "causal differences between regimens. In the published GitHub ",
                "Pages edition, entered values are processed locally in the browser, ",
                "are not sent to a remote R server, and are not retained by the application."
              )
            )
          )
        )
      ),
      shiny::column(
        width = 8,
        shiny::uiOutput("result_ui"),
        shiny::div(
          class = "panel-card",
          shiny::div(class = "chart-title", "Risk trajectory for the entered profile"),
          shiny::div(
            class = "chart-subtitle",
            paste0(
              "Age and baseline laboratory values are held constant. The ribbon ",
              "shows the 95% parametric interval from fixed-effect covariance only."
            )
          ),
          shiny::plotOutput("trajectory_plot", height = "370px")
        ),
        shiny::uiOutput("domain_ui")
      )
    )
  )
)

server <- function(input, output, session) {

  shiny::observeEvent(
    input$regimen,
    {
      horizon <- maximum_cycle(input$regimen)
      current_cycle <- suppressWarnings(as.numeric(input$cycle))
      if (!is.finite(current_cycle)) {
        current_cycle <- 1
      }
      shiny::updateNumericInput(
        session,
        "cycle",
        max = horizon,
        value = min(max(1, floor(current_cycle)), horizon)
      )
    },
    ignoreInit = FALSE
  )

  submitted <- shiny::eventReactive(
    input$calculate,
    {
      regimen <- as.character(input$regimen)
      cycle <- suppressWarnings(as.numeric(input$cycle))
      age <- suppressWarnings(as.numeric(input$age))
      platelets <- suppressWarnings(as.numeric(input$platelets))
      haemoglobin <- suppressWarnings(as.numeric(input$haemoglobin))

      errors <- validate_case(
        regimen,
        cycle,
        age,
        platelets,
        haemoglobin
      )

      if (length(errors) > 0L) {
        return(list(ok = FALSE, errors = errors))
      }

      new_data <- data.frame(
        cord = as.integer(cycle),
        esquema_nuc = regimen,
        age = age,
        pt0 = platelets,
        hb0 = haemoglobin,
        stringsAsFactors = FALSE
      )

      prediction <- model_a_predict(
        new_data,
        model_artefact,
        beta_draws = model_beta_draws,
        interval = TRUE
      )

      list(
        ok = TRUE,
        regimen = regimen,
        cycle = as.integer(cycle),
        age = age,
        platelets = platelets,
        haemoglobin = haemoglobin,
        prediction = prediction[1, ],
        cycle_support = cycle_support(regimen, cycle),
        continuous_support = continuous_support(age, platelets, haemoglobin)
      )
    },
    ignoreInit = FALSE
  )

  output$result_ui <- shiny::renderUI({

    result <- submitted()

    if (!isTRUE(result$ok)) {
      return(shiny::div(
        class = "panel-card",
        shiny::div(
          class = "support-box support-error",
          shiny::div(class = "support-title", "Prediction unavailable"),
          shiny::tags$ul(lapply(result$errors, shiny::tags$li))
        )
      ))
    }

    support_class <- switch(
      result$cycle_support$level,
      robust = "support-robust",
      limited = "support-limited",
      reduced = "support-reduced",
      "support-neutral"
    )

    shiny::div(
      class = "panel-card",
      shiny::fluidRow(
        shiny::column(
          width = 5,
          shiny::div(
            class = "risk-card",
            shiny::div(class = "risk-label", "Predicted probability"),
            shiny::div(
              class = "risk-value",
              sprintf("%.1f%%", 100 * result$prediction$p_final)
            ),
            shiny::div(
              class = "risk-interval",
              sprintf(
                "95%% parametric interval: %.1f%% to %.1f%%",
                100 * result$prediction$lower,
                100 * result$prediction$upper
              )
            ),
            shiny::div(
              class = "risk-caption",
              paste0(regimen_labels[[result$regimen]], " · cycle ", result$cycle)
            )
          )
        ),
        shiny::column(
          width = 7,
          shiny::div(
            class = paste("support-box", support_class),
            shiny::div(class = "support-title", result$cycle_support$title),
            result$cycle_support$message
          ),
          shiny::div(
            class = "support-box support-neutral",
            shiny::div(class = "support-title", "Uncertainty scope"),
            paste0(
              "The interval propagates fixed-effect covariance only. It does ",
              "not include uncertainty from random-effect variances, the ",
              "recalibration intercept, model selection, validation or external ",
              "transportability."
            )
          )
        )
      )
    )
  })

  output$domain_ui <- shiny::renderUI({

    result <- submitted()
    if (!isTRUE(result$ok)) {
      return(NULL)
    }

    support <- result$continuous_support
    items <- character(0)

    if (length(support$platelet_caution) > 0L) {
      items <- c(items, paste0("<strong>Caution:</strong> ", support$platelet_caution))
    }
    if (length(support$limited) > 0L) {
      items <- c(items, paste0("<strong>Limited support:</strong> ", support$limited))
    }
    if (length(support$extrapolation) > 0L) {
      items <- c(items, paste0("<strong>Extrapolation:</strong> ", support$extrapolation))
    }

    if (length(items) == 0L) {
      return(shiny::div(
        class = "panel-card",
        shiny::div(
          class = "support-box support-robust",
          shiny::div(class = "support-title", "Continuous-variable support"),
          paste0(
            "Age, baseline platelets and baseline haemoglobin are within ",
            "their P1-P99 main-support intervals."
          )
        )
      ))
    }

    shiny::div(
      class = "panel-card",
      shiny::div(
        class = "support-box support-limited",
        shiny::div(class = "support-title", "Domain warning"),
        shiny::tags$ul(lapply(items, function(item) shiny::tags$li(shiny::HTML(item))))
      )
    )
  })

  output$trajectory_plot <- shiny::renderPlot({

    result <- submitted()
    shiny::validate(
      shiny::need(isTRUE(result$ok), "Enter a supported case to display the trajectory.")
    )

    cycles <- seq_len(maximum_cycle(result$regimen))
    trajectory_data <- data.frame(
      cord = cycles,
      esquema_nuc = rep(result$regimen, length(cycles)),
      age = rep(result$age, length(cycles)),
      pt0 = rep(result$platelets, length(cycles)),
      hb0 = rep(result$haemoglobin, length(cycles)),
      stringsAsFactors = FALSE
    )

    trajectory_prediction <- model_a_predict(
      trajectory_data,
      model_artefact,
      beta_draws = model_beta_draws,
      interval = TRUE
    )

    plot_data <- data.frame(
      cycle = cycles,
      risk = 100 * trajectory_prediction$p_final,
      lower = 100 * trajectory_prediction$lower,
      upper = 100 * trajectory_prediction$upper
    )

    selected_data <- plot_data[
      plot_data$cycle == result$cycle,
      ,
      drop = FALSE
    ]

    plot <- ggplot2::ggplot(
      plot_data,
      ggplot2::aes(x = cycle, y = risk)
    ) +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = lower, ymax = upper),
        fill = "#FCBC72",
        alpha = 0.30
      ) +
      ggplot2::geom_line(colour = "#625A29", linewidth = 1.05) +
      ggplot2::geom_point(
        data = selected_data,
        colour = "#D78F3B",
        size = 3.2
      ) +
      ggplot2::scale_x_continuous(breaks = cycles) +
      ggplot2::scale_y_continuous(
        labels = function(value) paste0(value, "%"),
        limits = c(0, 100),
        expand = ggplot2::expansion(mult = c(0, 0.03))
      ) +
      ggplot2::labs(
        x = "Treatment cycle",
        y = "Predicted probability"
      ) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        panel.grid.minor = ggplot2::element_blank(),
        plot.margin = ggplot2::margin(10, 10, 5, 5)
      )

    if (result$regimen %in% c("CAP", "CAPOXL", "5FUOXL", "5FUIRI", "CAPIRI")) {
      plot <- plot +
        ggplot2::annotate(
          "rect",
          xmin = 14.5,
          xmax = 20.5,
          ymin = -Inf,
          ymax = Inf,
          alpha = 0.055,
          fill = "#F7E3A0"
        ) +
        ggplot2::annotate(
          "text",
          x = 17.5,
          y = 98,
          label = "LIMITED TEMPORAL TAIL",
          size = 3,
          fontface = "bold",
          colour = "#635B40"
        )
    }

    plot
  })
}

message(
  paste0(
    "Model A public Shiny calculator ready.\n",
    "Public artefact SHA-256: ", attr(model_artefact, "verified_sha256"), "\n",
    "Synthetic self-test maximum absolute difference: ",
    format(model_self_test$maximum_absolute_difference, scientific = TRUE), "\n",
    "Patient-level data included: NO\n",
    "Submitted-value persistence: NO"
  )
)

shiny::shinyApp(ui = ui, server = server)
