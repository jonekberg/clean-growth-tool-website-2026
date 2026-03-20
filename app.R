library(shiny)
library(bslib)
library(shinyWidgets)
library(readr)
library(dplyr)
library(reactable)
library(plotly)
library(leaflet)
library(htmltools)
library(scales)
library(sf)
library(glue)

data_root <- file.path(getwd(), "public", "data")

geo_level_titles <- c(
  county = "County",
  state = "State",
  cbsa = "Metropolitan Statistical Area",
  csa = "Combined Statistical Area",
  cz = "Commuting Zone"
)

geo_level_choices <- c(
  "Metropolitan Statistical Area" = "cbsa",
  "Combined Statistical Area" = "csa",
  "Commuting Zone" = "cz",
  State = "state",
  County = "county"
)

geo_meta_files <- c(
  county = "meta/county_geography_specific.csv",
  state = "meta/state_geography_specific.csv",
  cbsa = "meta/cbsa_geography_specific.csv",
  csa = "meta/csa_geography_specific.csv",
  cz = "meta/cz_geography_specific.csv"
)

industry_meta_files <- c(
  county = "meta/county_industry_specific.csv",
  state = "meta/state_industry_specific.csv",
  cbsa = "meta/cbsa_industry_specific.csv",
  csa = "meta/csa_industry_specific.csv",
  cz = "meta/cz_industry_specific.csv"
)

region_metric_choices <- c(
  "Feasibility Percentile" = "industry_feasibility_percentile_score",
  "Strategic Gain Percentile" = "strategic_gain_percentile_score",
  "Feasibility Score" = "industry_feasibility",
  "Strategic Gain" = "strategic_gain",
  "Location Quotient" = "location_quotient",
  "Employment Share" = "industry_employment_share"
)

industry_metric_choices <- region_metric_choices

csv_cache <- new.env(parent = emptyenv())
shape_cache <- new.env(parent = emptyenv())

normalize_geoid <- function(level, geoid) {
  values <- gsub("\\.0$", "", trimws(as.character(geoid)))
  values[is.na(values)] <- ""

  if (level == "county") {
    values[values != ""] <- sprintf("%05d", as.integer(values[values != ""]))
  } else if (level == "state") {
    values[values != ""] <- sprintf("%02d", as.integer(values[values != ""]))
  } else if (level == "cbsa") {
    values[values != ""] <- sprintf("%05d", as.integer(values[values != ""]))
  }

  values
}

read_csv_cached <- function(path) {
  cache_key <- normalizePath(path, winslash = "/", mustWork = TRUE)

  if (!exists(cache_key, envir = csv_cache, inherits = FALSE)) {
    assign(cache_key, readr::read_csv(path, show_col_types = FALSE), envir = csv_cache)
  }

  get(cache_key, envir = csv_cache, inherits = FALSE)
}

load_crosswalk <- function() {
  read_csv_cached(file.path(data_root, "meta", "crosswalk.csv")) %>%
    mutate(
      state_fips = normalize_geoid("state", state_fips),
      county_geoid = normalize_geoid("county", county_geoid),
      cbsa_geoid = normalize_geoid("cbsa", cbsa_geoid),
      csa_geoid = normalize_geoid("csa", csa_geoid),
      commuting_zone_geoid = normalize_geoid("cz", commuting_zone_geoid)
    )
}

load_geo_meta <- function(level) {
  read_csv_cached(file.path(data_root, geo_meta_files[[level]])) %>%
    transmute(
      geoid = normalize_geoid(level, geoid),
      name = as.character(name),
      industrial_diversity = as.numeric(industrial_diversity),
      economic_complexity_index = as.numeric(economic_complexity_index),
      economic_complexity_percentile_score = as.numeric(economic_complexity_percentile_score),
      strategic_index = as.numeric(strategic_index),
      strategic_index_percentile = as.numeric(strategic_index_percentile)
    )
}

load_industry_meta <- function(level) {
  read_csv_cached(file.path(data_root, industry_meta_files[[level]])) %>%
    transmute(
      industry_code = as.character(industry_code),
      industry_description = as.character(industry_description),
      industry_ubiquity = as.numeric(industry_ubiquity),
      industry_employment_share_nation = as.numeric(industry_employment_share_nation),
      industry_complexity = as.numeric(industry_complexity),
      industry_complexity_percentile = as.numeric(industry_complexity_percentile)
    )
}

load_region_industries <- function(level, geoid) {
  read_csv_cached(
    file.path(data_root, "by_geography", level, sprintf("%s.csv.gz", normalize_geoid(level, geoid)))
  ) %>%
    transmute(
      geoid = normalize_geoid(level, geoid),
      industry_code = as.character(industry_code),
      industry_employment_share = as.numeric(industry_employment_share),
      location_quotient = as.numeric(location_quotient),
      industry_present = as.numeric(industry_present) > 0,
      industry_comparative_advantage = as.numeric(industry_comparative_advantage) > 0,
      industry_feasibility = as.numeric(industry_feasibility),
      industry_feasibility_percentile_score = as.numeric(industry_feasibility_percentile_score),
      strategic_gain_possible = as.numeric(strategic_gain_possible) > 0,
      strategic_gain = as.numeric(strategic_gain),
      strategic_gain_percentile_score = as.numeric(strategic_gain_percentile_score)
    )
}

load_industry_regions <- function(level, industry_code) {
  read_csv_cached(
    file.path(data_root, "by_industry", level, sprintf("%s.csv.gz", industry_code))
  ) %>%
    transmute(
      geoid = normalize_geoid(level, geoid),
      industry_code = as.character(industry_code),
      industry_employment_share = as.numeric(industry_employment_share),
      location_quotient = as.numeric(location_quotient),
      industry_present = as.numeric(industry_present) > 0,
      industry_comparative_advantage = as.numeric(industry_comparative_advantage) > 0,
      industry_feasibility = as.numeric(industry_feasibility),
      industry_feasibility_percentile_score = as.numeric(industry_feasibility_percentile_score),
      strategic_gain_possible = as.numeric(strategic_gain_possible) > 0,
      strategic_gain = as.numeric(strategic_gain),
      strategic_gain_percentile_score = as.numeric(strategic_gain_percentile_score)
    )
}

decorate_geo_meta <- function(level, geo_meta, crosswalk) {
  if (level == "county") {
    county_lookup <- crosswalk %>%
      distinct(county_geoid, state_abbreviation)

    return(
      geo_meta %>%
        left_join(county_lookup, by = c("geoid" = "county_geoid")) %>%
        mutate(display_name = ifelse(
          is.na(state_abbreviation) | state_abbreviation == "",
          name,
          paste0(name, ", ", state_abbreviation)
        ))
    )
  }

  if (level == "state") {
    state_lookup <- crosswalk %>%
      distinct(state_fips, state_abbreviation)

    return(
      geo_meta %>%
        left_join(state_lookup, by = c("geoid" = "state_fips")) %>%
        mutate(display_name = ifelse(
          is.na(state_abbreviation) | state_abbreviation == "",
          name,
          paste0(name, " (", state_abbreviation, ")")
        ))
    )
  }

  geo_meta %>% mutate(display_name = name)
}

metric_label <- function(metric_key, choices) {
  metric_map <- setNames(names(choices), as.vector(choices))
  label <- metric_map[[metric_key]]

  if (is.null(label) || is.na(label) || label == "") {
    return(metric_key)
  }

  label
}

format_metric_value <- function(value, metric_key) {
  vapply(value, function(single_value) {
    if (is.na(single_value)) {
      return("Not available")
    }

    if (metric_key %in% c("industry_feasibility_percentile_score", "strategic_gain_percentile_score")) {
      return(sprintf("%.1f", single_value))
    }

    if (metric_key == "location_quotient") {
      return(sprintf("%.2f", single_value))
    }

    if (metric_key == "industry_employment_share") {
      return(percent(single_value, accuracy = 0.01))
    }

    sprintf("%.3f", single_value)
  }, character(1))
}

metric_palette_label <- function(metric_key) {
  if (metric_key == "industry_employment_share") {
    return("Employment share")
  }

  metric_label(metric_key, industry_metric_choices)
}

get_shape_data <- function(level) {
  if (!level %in% c("county", "state")) {
    return(NULL)
  }

  if (exists(level, envir = shape_cache, inherits = FALSE)) {
    return(get(level, envir = shape_cache, inherits = FALSE))
  }

  shape <- if (level == "county") {
    st_read(file.path(data_root, "topology", "us-counties-2023.json"), quiet = TRUE) %>%
      transmute(geoid = normalize_geoid("county", GEO_ID), geometry = geometry) %>%
      st_set_crs(4326)
  } else {
    st_read(file.path(data_root, "topology", "states-10m.json"), quiet = TRUE) %>%
      transmute(geoid = normalize_geoid("state", id), geometry = geometry) %>%
      st_set_crs(4326)
  }

  assign(level, shape, envir = shape_cache)
  shape
}

top_entries_card <- function(title, subtitle, rows, metric_key, label_col) {
  if (nrow(rows) == 0) {
    return(
      card(
        class = "cgt-card",
        card_header(title),
        p("No rows match the current filters.")
      )
    )
  }

  items <- lapply(seq_len(min(5, nrow(rows))), function(idx) {
    row <- rows[idx, ]
    tags$li(
      class = "cgt-list-item",
      tags$span(class = "cgt-list-label", row[[label_col]]),
      tags$span(class = "cgt-list-value", format_metric_value(row[[metric_key]], metric_key))
    )
  })

  card(
    class = "cgt-card",
    card_header(title),
    p(class = "cgt-muted", subtitle),
    tags$ol(class = "cgt-list", items)
  )
}

build_region_table <- function(data, selected_metric_label, selected_metric_key) {
  reactable(
    data,
    searchable = FALSE,
    striped = TRUE,
    highlight = TRUE,
    bordered = FALSE,
    compact = TRUE,
    defaultPageSize = 12,
    defaultSorted = list(selected_metric = "desc"),
    columns = list(
      industry_description = colDef(name = "Industry", minWidth = 260),
      industry_code = colDef(name = "NAICS", align = "center", maxWidth = 90),
      selected_metric = colDef(
        name = selected_metric_label,
        align = "right",
        cell = function(value) format_metric_value(value, selected_metric_key)
      ),
      industry_feasibility_percentile_score = colDef(name = "Feas. %ile", align = "right", format = colFormat(digits = 1)),
      strategic_gain_percentile_score = colDef(name = "Strategic %ile", align = "right", format = colFormat(digits = 1)),
      industry_feasibility = colDef(name = "Feasibility", align = "right", format = colFormat(digits = 3)),
      strategic_gain = colDef(name = "Strategic gain", align = "right", format = colFormat(digits = 3)),
      location_quotient = colDef(name = "LQ", align = "right", format = colFormat(digits = 2)),
      industry_employment_share = colDef(name = "Employment share", align = "right", format = colFormat(percent = TRUE, digits = 2)),
      industry_complexity = colDef(name = "Complexity", align = "right", format = colFormat(digits = 2)),
      industry_complexity_percentile = colDef(name = "Complexity %ile", align = "right", format = colFormat(digits = 1))
    )
  )
}

build_industry_table <- function(data, selected_metric_label, selected_metric_key) {
  reactable(
    data,
    searchable = FALSE,
    striped = TRUE,
    highlight = TRUE,
    bordered = FALSE,
    compact = TRUE,
    defaultPageSize = 15,
    defaultSorted = list(selected_metric = "desc"),
    columns = list(
      geo_name = colDef(name = "Geography", minWidth = 280),
      selected_metric = colDef(
        name = selected_metric_label,
        align = "right",
        cell = function(value) format_metric_value(value, selected_metric_key)
      ),
      industry_feasibility_percentile_score = colDef(name = "Feas. %ile", align = "right", format = colFormat(digits = 1)),
      strategic_gain_percentile_score = colDef(name = "Strategic %ile", align = "right", format = colFormat(digits = 1)),
      industry_feasibility = colDef(name = "Feasibility", align = "right", format = colFormat(digits = 3)),
      strategic_gain = colDef(name = "Strategic gain", align = "right", format = colFormat(digits = 3)),
      location_quotient = colDef(name = "LQ", align = "right", format = colFormat(digits = 2)),
      industry_employment_share = colDef(name = "Employment share", align = "right", format = colFormat(percent = TRUE, digits = 2)),
      economic_complexity_index = colDef(name = "ECI", align = "right", format = colFormat(digits = 2)),
      industrial_diversity = colDef(name = "Diversity", align = "right", format = colFormat(separators = TRUE, digits = 0)),
      strategic_index = colDef(name = "Strategic index", align = "right", format = colFormat(digits = 2))
    )
  )
}

region_page <- layout_sidebar(
  fillable = FALSE,
  sidebar = sidebar(
    width = 310,
    tags$p(class = "cgt-sidebar-intro", tags$b("Choose a geography, ranking metric, and industry filter.")),
    selectInput(
      "region_level",
      label = "Geography level",
      choices = geo_level_choices,
      selected = "cbsa",
      width = "100%"
    ),
    selectizeInput(
      "region_geoid",
      label = "Geography",
      choices = NULL,
      width = "100%",
      options = list(placeholder = "Choose a geography")
    ),
    selectInput(
      "region_metric",
      label = "Rank industries by",
      choices = region_metric_choices,
      selected = "industry_feasibility_percentile_score",
      width = "100%"
    ),
    textInput(
      "region_industry_search",
      label = "Filter industries",
      placeholder = "Search by NAICS or industry name"
    ),
    checkboxInput(
      "region_underdeveloped_only",
      label = "Prioritize underdeveloped industries only (LQ < 1)",
      value = TRUE
    ),
    tags$div(
      class = "cgt-sidebar-note",
      tags$strong("Updated data, old UI shell."),
      tags$p(
        "This Shiny build preserves the previous interface rhythm but uses the newer public Clean Growth Tool snapshot."
      )
    )
  ),
  div(
    class = "cgt-page",
    div(
      class = "mi_clase cgt-hero-row",
      fluidRow(
        column(
          3,
          div(
            class = "cgt-title-block",
            uiOutput("region_title_ui")
          )
        ),
        column(
          3,
          value_box(
            title = "Economic Complexity Index",
            value = uiOutput("region_eci_value"),
            uiOutput("region_eci_note"),
            class = "value-box-2 cgt-value-box"
          )
        ),
        column(
          3,
          value_box(
            title = "Industrial Diversity",
            value = uiOutput("region_diversity_value"),
            uiOutput("region_diversity_note"),
            class = "value-box-2 cgt-value-box"
          )
        ),
        column(
          3,
          value_box(
            title = "Strategic Index",
            value = uiOutput("region_strategic_value"),
            uiOutput("region_strategic_note"),
            class = "value-box-3 cgt-value-box"
          )
        )
      )
    ),
    fluidRow(
      column(
        12,
        h3(class = "cgt-section-title", "Filter and select industries to evaluate"),
        tags$p(
          class = "cgt-muted",
          "The table emphasizes the older region-view workflow: identify feasible, underdeveloped, and strategically valuable industries for the selected geography."
        )
      )
    ),
    fluidRow(
      column(
        8,
        reactableOutput("region_table", height = "520px"),
        tags$p(
          class = "cgt-footnote",
          "The region table is built from the public 2026 snapshot. Underdeveloped mode keeps industries with a location quotient below one to stay close to the old planning workflow."
        )
      ),
      column(
        4,
        card(
          class = "cgt-card",
          card_header("Feasibility vs Industry Complexity"),
          plotlyOutput("region_scatter_complexity", height = "250px")
        ),
        br(),
        card(
          class = "cgt-card",
          card_header("Strategic Gain vs Feasibility"),
          plotlyOutput("region_scatter_strategic", height = "250px")
        )
      )
    ),
    br(),
    fluidRow(
      column(6, uiOutput("region_top_feasible")),
      column(6, uiOutput("region_top_strategic"))
    ),
    br(),
    fluidRow(
      column(
        12,
        uiOutput("region_analysis_copy")
      )
    )
  )
)

industry_page <- layout_sidebar(
  fillable = FALSE,
  sidebar = sidebar(
    width = 310,
    tags$p(class = "cgt-sidebar-intro", tags$b("Choose an industry and compare geographies.")),
    selectInput(
      "industry_level",
      label = "Geography level",
      choices = geo_level_choices,
      selected = "cbsa",
      width = "100%"
    ),
    selectizeInput(
      "industry_code",
      label = "Industry",
      choices = NULL,
      width = "100%",
      options = list(placeholder = "Choose an industry")
    ),
    selectInput(
      "industry_metric",
      label = "Rank geographies by",
      choices = industry_metric_choices,
      selected = "industry_feasibility_percentile_score",
      width = "100%"
    ),
    checkboxInput(
      "industry_underdeveloped_only",
      label = "Prioritize underdeveloped geographies only (LQ < 1)",
      value = TRUE
    ),
    tags$div(
      class = "cgt-sidebar-note",
      tags$strong("Map coverage note."),
      tags$p(
        "The public data bundle includes geometry for states and counties. Other geography levels stay in the old map/table layout but fall back to a structured comparison panel."
      )
    )
  ),
  div(
    class = "cgt-page",
    fluidRow(
      column(
        12,
        div(class = "cgt-title-block cgt-title-block-wide", uiOutput("industry_title_ui"))
      )
    ),
    fluidRow(
      column(
        3,
        value_box(
          title = "Industry Complexity",
          value = uiOutput("industry_complexity_value"),
          uiOutput("industry_complexity_note"),
          class = "value-box-2 cgt-value-box"
        )
      ),
      column(
        3,
        value_box(
          title = "Complexity Percentile",
          value = uiOutput("industry_complexity_pct_value"),
          uiOutput("industry_complexity_pct_note"),
          class = "value-box-2 cgt-value-box"
        )
      ),
      column(
        3,
        value_box(
          title = "National Employment Share",
          value = uiOutput("industry_share_value"),
          uiOutput("industry_share_note"),
          class = "value-box-2 cgt-value-box"
        )
      ),
      column(
        3,
        value_box(
          title = "Ubiquity",
          value = uiOutput("industry_ubiquity_value"),
          uiOutput("industry_ubiquity_note"),
          class = "value-box-3 cgt-value-box"
        )
      )
    ),
    br(),
    tabsetPanel(
      tabPanel(
        "Map",
        fluidRow(
          column(9, uiOutput("industry_map_ui")),
          column(3, uiOutput("industry_map_side"))
        )
      ),
      tabPanel(
        "Table",
        br(),
        reactableOutput("industry_table", height = "700px"),
        tags$p(
          class = "cgt-footnote",
          "The table ranks geographies for the selected industry using the current public snapshot and the older comparison-first UI pattern."
        )
      )
    ),
    br(),
    fluidRow(
      column(12, uiOutput("industry_analysis_copy"))
    )
  )
)

about_page <- fluidRow(
  column(
    8,
    h2("The Clean Growth Tool Website 2026"),
    tags$p(
      "This version deliberately keeps the older Shiny experience: a dark RMI header, a left filter rail, and side-by-side comparison panels for Region View and Industry View."
    ),
    tags$p(
      "The data layer, however, has been replaced with the newer public Clean Growth Tool snapshot from the RMI public repository. That means the app now supports county, state, CBSA, CSA, and commuting zone data while preserving the previous planning workflow."
    ),
    h3("What changed"),
    tags$ul(
      tags$li("Legacy workforce and investment panels were replaced with metrics that exist in the current public dataset: Economic Complexity Index, Industrial Diversity, Strategic Index, feasibility, and strategic gain."),
      tags$li("Region View still prioritizes identifying feasible industries for a place, but it now ranks off the 2026 public geography files."),
      tags$li("Industry View still compares where an industry could grow next, but it now uses the 2026 public by-industry files.")
    ),
    h3("Methodology notes"),
    tags$p(
      "Feasibility remains the core organizing idea. It measures how close a target industry is to the capabilities already concentrated in a geography. Strategic gain complements that view by surfacing industries that could improve a geography's long-run economic position."
    ),
    tags$p(
      "Industry complexity and regional economic complexity come from the public RMI snapshot. Higher values generally indicate deeper and more sophisticated capability bases."
    ),
    tags$img(src = "img/feasibility_form.jpg", class = "cgt-about-image"),
    h3("Design intent"),
    tags$p(
      "The goal of this rebuild is not to reproduce every historical panel. It is to preserve the stronger old interface and decision flow while replacing the underlying data contract with the most recent public snapshot."
    ),
    tags$img(src = "img/diagram.jpeg", class = "cgt-about-image"),
    h3("Data source"),
    tags$p(
      "Primary source: public data snapshot from the RMI Clean Growth Tool repository, vendored locally in this project under public/data so the app does not depend on runtime GitHub requests."
    )
  )
)

ui <- page_navbar(
  id = "navbarID",
  selected = "Region-View",
  title = list(
    tags$img(src = "./img/header-logo-white.svg", width = "12px"),
    tags$img(src = "./img/rmi_horizontal_white.svg", width = "50px")
  ),
  header = tags$head(
    tags$meta(name = "description", content = "Clean Growth Tool Website 2026 Shiny rebuild using the older interface shell and the latest public data snapshot."),
    tags$link(rel = "icon", href = "img/b_logo.png", type = "image/png"),
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(rel = "preconnect", href = "https://fonts.gstatic.com", crossorigin = TRUE),
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Roboto:wght@300;400;500;700&display=swap"
    ),
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
    tags$link(rel = "stylesheet", type = "text/css", href = "style_box.css"),
    tags$link(rel = "stylesheet", type = "text/css", href = "cgt2026.css")
  ),
  window_title = "Clean Growth Tool Website 2026",
  theme = bs_theme(
    "navbar-bg" = "#003b63",
    bg = "#ffffff",
    fg = "#10212f",
    info = "#8FE1E2",
    primary = "#003b63",
    secondary = "#55758a"
  ),
  fillable = TRUE,
  nav_item("Clean Growth Tool", class = "custom-nav-item"),
  nav_spacer(),
  nav_item("View data by:", class = "custom-nav-item-2"),
  nav_panel("Industry View", value = "Industry-View", class = "custom-nav-item-4", industry_page),
  nav_panel("Region View", value = "Region-View", class = "custom-nav-item-3", region_page),
  nav_panel("About", about_page),
  nav_spacer(),
  nav_item(tags$a("Public RMI data", href = "https://github.com/bsf-rmi/RMI_Clean_Growth_Tool", target = "_blank"))
)

server <- function(input, output, session) {
  crosswalk <- load_crosswalk()

  region_geo_meta <- reactive({
    decorate_geo_meta(input$region_level, load_geo_meta(input$region_level), crosswalk) %>%
      arrange(display_name)
  })

  industry_geo_meta <- reactive({
    decorate_geo_meta(input$industry_level, load_geo_meta(input$industry_level), crosswalk) %>%
      arrange(display_name)
  })

  region_industry_meta <- reactive({
    load_industry_meta(input$region_level) %>% arrange(industry_description)
  })

  industry_meta_selected_level <- reactive({
    load_industry_meta(input$industry_level) %>% arrange(industry_description)
  })

  observeEvent(region_geo_meta(), {
    choices <- stats::setNames(region_geo_meta()$geoid, region_geo_meta()$display_name)
    selected <- isolate(input$region_geoid)

    if (is.null(selected) || !selected %in% region_geo_meta()$geoid) {
      selected <- region_geo_meta()$geoid[[1]]
    }

    updateSelectizeInput(session, "region_geoid", choices = choices, selected = selected, server = TRUE)
  }, ignoreNULL = FALSE)

  observeEvent(industry_meta_selected_level(), {
    meta <- industry_meta_selected_level()
    choices <- stats::setNames(meta$industry_code, paste0(meta$industry_description, " (", meta$industry_code, ")"))
    selected <- isolate(input$industry_code)

    if (is.null(selected) || !selected %in% meta$industry_code) {
      selected <- meta$industry_code[[1]]
    }

    updateSelectizeInput(session, "industry_code", choices = choices, selected = selected, server = TRUE)
  }, ignoreNULL = FALSE)

  region_selected_meta <- reactive({
    req(input$region_geoid)
    region_geo_meta() %>% filter(geoid == input$region_geoid) %>% slice(1)
  })

  industry_selected_meta <- reactive({
    req(input$industry_code)
    industry_meta_selected_level() %>% filter(industry_code == input$industry_code) %>% slice(1)
  })

  region_industry_data <- reactive({
    req(input$region_geoid)

    joined <- load_region_industries(input$region_level, input$region_geoid) %>%
      left_join(region_industry_meta(), by = "industry_code")

    if (nzchar(trimws(input$region_industry_search))) {
      search_term <- tolower(trimws(input$region_industry_search))
      joined <- joined %>%
        filter(
          grepl(search_term, tolower(coalesce(industry_description, ""))) |
            grepl(search_term, industry_code)
        )
    }

    if (isTRUE(input$region_underdeveloped_only)) {
      joined <- joined %>% filter(location_quotient < 1)
    }

    joined %>%
      arrange(desc(.data[[input$region_metric]]), desc(strategic_gain_percentile_score))
  })

  industry_region_data <- reactive({
    req(input$industry_code)

    joined <- load_industry_regions(input$industry_level, input$industry_code) %>%
      left_join(
        industry_geo_meta() %>%
          select(
            geoid,
            geo_name = name,
            display_name,
            industrial_diversity,
            economic_complexity_index,
            strategic_index
          ),
        by = "geoid"
      ) %>%
      mutate(geo_name = coalesce(display_name, geo_name, geoid))

    if (isTRUE(input$industry_underdeveloped_only)) {
      joined <- joined %>% filter(location_quotient < 1)
    }

    joined %>%
      arrange(desc(.data[[input$industry_metric]]), desc(strategic_gain_percentile_score))
  })

  output$region_title_ui <- renderUI({
    selected <- region_selected_meta()
    div(
      class = "cgt-kicker",
      tags$span(geo_level_titles[[input$region_level]]),
      h2(selected$display_name),
      tags$p(
        class = "cgt-muted",
        "Use the old Region View workflow to identify feasible and strategically valuable industries for this geography."
      )
    )
  })

  output$industry_title_ui <- renderUI({
    selected <- industry_selected_meta()
    div(
      class = "cgt-kicker",
      tags$span(geo_level_titles[[input$industry_level]]),
      h2(selected$industry_description),
      tags$p(
        class = "cgt-muted",
        glue("Compare where NAICS {selected$industry_code} looks most feasible under the current public dataset.")
      )
    )
  })

  output$region_eci_value <- renderUI({
    selected <- region_selected_meta()
    tags$span(sprintf("%.2f", selected$economic_complexity_index))
  })

  output$region_eci_note <- renderUI({
    selected <- region_selected_meta()
    tags$p(class = "cgt-value-note", glue("{sprintf('%.1f', selected$economic_complexity_percentile_score)} percentile nationally."))
  })

  output$region_diversity_value <- renderUI({
    selected <- region_selected_meta()
    tags$span(comma(selected$industrial_diversity))
  })

  output$region_diversity_note <- renderUI({
    tags$p(class = "cgt-value-note", "Count of industries present in the local capability base.")
  })

  output$region_strategic_value <- renderUI({
    selected <- region_selected_meta()
    tags$span(sprintf("%.2f", selected$strategic_index))
  })

  output$region_strategic_note <- renderUI({
    selected <- region_selected_meta()
    tags$p(class = "cgt-value-note", glue("{sprintf('%.1f', selected$strategic_index_percentile)} percentile nationally."))
  })

  output$industry_complexity_value <- renderUI({
    selected <- industry_selected_meta()
    tags$span(sprintf("%.2f", selected$industry_complexity))
  })

  output$industry_complexity_note <- renderUI({
    tags$p(class = "cgt-value-note", "Higher values imply deeper and rarer capability requirements.")
  })

  output$industry_complexity_pct_value <- renderUI({
    selected <- industry_selected_meta()
    tags$span(sprintf("%.1f", selected$industry_complexity_percentile))
  })

  output$industry_complexity_pct_note <- renderUI({
    tags$p(class = "cgt-value-note", "Percentile rank relative to other industries in this public snapshot.")
  })

  output$industry_share_value <- renderUI({
    selected <- industry_selected_meta()
    tags$span(percent(selected$industry_employment_share_nation, accuracy = 0.01))
  })

  output$industry_share_note <- renderUI({
    tags$p(class = "cgt-value-note", "National employment share for the selected industry.")
  })

  output$industry_ubiquity_value <- renderUI({
    selected <- industry_selected_meta()
    tags$span(comma(selected$industry_ubiquity))
  })

  output$industry_ubiquity_note <- renderUI({
    tags$p(class = "cgt-value-note", "Number of geographies where the industry is present.")
  })

  output$region_table <- renderReactable({
    data <- region_industry_data()
    req(nrow(data) > 0)

    metric_key <- input$region_metric
    selected_label <- metric_label(metric_key, region_metric_choices)

    table_data <- data %>%
      mutate(
        selected_metric = .data[[metric_key]]
      ) %>%
      transmute(
        industry_description,
        industry_code,
        selected_metric,
        industry_feasibility_percentile_score,
        strategic_gain_percentile_score,
        industry_feasibility,
        strategic_gain,
        location_quotient,
        industry_employment_share,
        industry_complexity,
        industry_complexity_percentile
      )

    build_region_table(table_data, selected_label, metric_key)
  })

  output$region_scatter_complexity <- renderPlotly({
    data <- region_industry_data()
    req(nrow(data) > 0)

    plot_ly(
      data = data,
      x = ~industry_complexity,
      y = ~industry_feasibility,
      type = "scatter",
      mode = "markers",
      color = ~strategic_gain_percentile_score,
      colors = c("#bedfe5", "#003b63"),
      text = ~paste0(
        industry_description,
        "<br>Complexity: ", sprintf("%.2f", industry_complexity),
        "<br>Feasibility: ", sprintf("%.3f", industry_feasibility),
        "<br>Strategic gain %ile: ", sprintf("%.1f", strategic_gain_percentile_score)
      ),
      hoverinfo = "text"
    ) %>%
      layout(
        xaxis = list(title = "Industry Complexity"),
        yaxis = list(title = "Feasibility"),
        margin = list(l = 50, r = 20, b = 45, t = 10),
        paper_bgcolor = "white",
        plot_bgcolor = "white"
      )
  })

  output$region_scatter_strategic <- renderPlotly({
    data <- region_industry_data()
    req(nrow(data) > 0)

    plot_ly(
      data = data,
      x = ~industry_feasibility,
      y = ~strategic_gain,
      type = "scatter",
      mode = "markers",
      color = ~location_quotient,
      colors = c("#9fdde0", "#003b63"),
      text = ~paste0(
        industry_description,
        "<br>Feasibility: ", sprintf("%.3f", industry_feasibility),
        "<br>Strategic gain: ", sprintf("%.3f", strategic_gain),
        "<br>LQ: ", sprintf("%.2f", location_quotient)
      ),
      hoverinfo = "text"
    ) %>%
      layout(
        xaxis = list(title = "Feasibility"),
        yaxis = list(title = "Strategic Gain"),
        margin = list(l = 50, r = 20, b = 45, t = 10),
        paper_bgcolor = "white",
        plot_bgcolor = "white"
      )
  })

  output$region_top_feasible <- renderUI({
    data <- region_industry_data() %>% arrange(desc(industry_feasibility_percentile_score))
    top_entries_card(
      "Top Feasible Industries",
      "Highest feasibility percentile scores under the current filters.",
      data,
      "industry_feasibility_percentile_score",
      "industry_description"
    )
  })

  output$region_top_strategic <- renderUI({
    data <- region_industry_data() %>% arrange(desc(strategic_gain_percentile_score))
    top_entries_card(
      "Top Strategic Gain Industries",
      "Industries with the strongest strategic upside for the selected geography.",
      data,
      "strategic_gain_percentile_score",
      "industry_description"
    )
  })

  output$region_analysis_copy <- renderUI({
    data <- region_industry_data()
    req(nrow(data) > 0)
    top_feasible <- paste(head(data$industry_description[order(data$industry_feasibility_percentile_score, decreasing = TRUE)], 3), collapse = ", ")
    top_strategic <- paste(head(data$industry_description[order(data$strategic_gain_percentile_score, decreasing = TRUE)], 3), collapse = ", ")

    card(
      class = "cgt-card industries_to_grow_analysis-1",
      card_header("Region View Readout"),
      tags$p(
        glue(
          "For {region_selected_meta()$display_name}, the strongest feasibility signals currently appear in {top_feasible}. The biggest strategic-gain opportunities are {top_strategic}."
        )
      ),
      tags$p(
        "This interpretation uses the public 2026 dataset and is meant to preserve the older region-planning decision flow rather than reproduce every legacy workforce panel."
      )
    )
  })

  output$industry_table <- renderReactable({
    data <- industry_region_data()
    req(nrow(data) > 0)

    metric_key <- input$industry_metric
    selected_label <- metric_label(metric_key, industry_metric_choices)

    table_data <- data %>%
      mutate(
        selected_metric = .data[[metric_key]]
      ) %>%
      transmute(
        geo_name,
        selected_metric,
        industry_feasibility_percentile_score,
        strategic_gain_percentile_score,
        industry_feasibility,
        strategic_gain,
        location_quotient,
        industry_employment_share,
        economic_complexity_index,
        industrial_diversity,
        strategic_index
      )

    build_industry_table(table_data, selected_label, metric_key)
  })

  output$industry_map_ui <- renderUI({
    if (!input$industry_level %in% c("state", "county")) {
      return(
        card(
          class = "cgt-card cgt-map-fallback",
          card_header("Structured Geography Comparison"),
          tags$p(
            class = "cgt-muted",
            "The public bundle does not currently include geometry for this geography level, so the old map slot falls back to a ranked comparison panel."
          ),
          reactableOutput("industry_map_fallback", height = "620px")
        )
      )
    }

    leafletOutput("industry_map", height = "700px")
  })

  output$industry_map_fallback <- renderReactable({
    data <- industry_region_data() %>% slice_head(n = 25)
    req(nrow(data) > 0)

    reactable(
      data %>%
        transmute(
          Geography = geo_name,
          Metric = format_metric_value(.data[[input$industry_metric]], input$industry_metric),
          `Strategic gain %ile` = sprintf("%.1f", strategic_gain_percentile_score),
          `LQ` = sprintf("%.2f", location_quotient),
          `ECI` = sprintf("%.2f", economic_complexity_index)
        ),
      compact = TRUE,
      striped = TRUE,
      bordered = FALSE,
      pagination = FALSE
    )
  })

  output$industry_map <- renderLeaflet({
    req(input$industry_level %in% c("state", "county"))

    data <- industry_region_data()
    req(nrow(data) > 0)

    shape <- get_shape_data(input$industry_level)
    metric_key <- input$industry_metric
    palette_domain <- data[[metric_key]]
    pal <- colorNumeric(
      palette = c("#d9eef1", "#7bcfd4", "#003b63"),
      domain = palette_domain,
      na.color = "#e5ebf0"
    )

    map_data <- shape %>%
      left_join(
        data %>%
          transmute(
            geoid,
            geo_name,
            metric_value = .data[[metric_key]],
            industry_feasibility_percentile_score,
            strategic_gain_percentile_score,
            location_quotient
          ),
        by = "geoid"
      )

    labels <- sprintf(
      "<strong>%s</strong><br/>%s: %s<br/>Feasibility percentile: %s<br/>Strategic gain percentile: %s<br/>Location quotient: %s",
      coalesce(map_data$geo_name, map_data$geoid),
      metric_palette_label(metric_key),
      vapply(map_data$metric_value, format_metric_value, character(1), metric_key = metric_key),
      sprintf("%.1f", map_data$industry_feasibility_percentile_score),
      sprintf("%.1f", map_data$strategic_gain_percentile_score),
      sprintf("%.2f", map_data$location_quotient)
    )

    leaflet(map_data, options = leafletOptions(zoomControl = TRUE, minZoom = 3)) %>%
      addProviderTiles(providers$CartoDB.PositronNoLabels) %>%
      addPolygons(
        fillColor = ~pal(metric_value),
        fillOpacity = 0.85,
        color = "#ffffff",
        weight = 0.4,
        opacity = 1,
        smoothFactor = 0.2,
        label = lapply(labels, HTML),
        highlightOptions = highlightOptions(weight = 1.5, color = "#0f1720", bringToFront = TRUE)
      ) %>%
      addLegend(
        "bottomright",
        pal = pal,
        values = palette_domain,
        opacity = 0.9,
        title = metric_palette_label(metric_key)
      )
  })

  output$industry_map_side <- renderUI({
    data <- industry_region_data()
    req(nrow(data) > 0)

    top_metric <- head(data %>% arrange(desc(.data[[input$industry_metric]])), 5)
    top_entries_card(
      "Leading Geographies",
      glue("Ranked by {metric_label(input$industry_metric, industry_metric_choices)}."),
      top_metric,
      input$industry_metric,
      "geo_name"
    )
  })

  output$industry_analysis_copy <- renderUI({
    data <- industry_region_data()
    req(nrow(data) > 0)

    top_places <- paste(head(data$geo_name, 3), collapse = ", ")

    card(
      class = "cgt-card industries_to_grow_analysis-1",
      card_header("Industry View Readout"),
      tags$p(
        glue(
          "{industry_selected_meta()$industry_description} currently looks strongest in {top_places} under the selected geography level and filters."
        )
      ),
      tags$p(
        "Use the ranking metric to switch between feasibility, strategic upside, and present-day concentration depending on the kind of market-entry question your team is asking."
      )
    )
  })
}

shinyApp(ui, server)
