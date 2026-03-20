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
library(sp)
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
  if (!level %in% c("cbsa", "state")) {
    return(NULL)
  }

  if (exists(level, envir = shape_cache, inherits = FALSE)) {
    return(get(level, envir = shape_cache, inherits = FALSE))
  }

  shape <- if (level == "cbsa") {
    readRDS(file.path(getwd(), "geometry", "msa_2023.rds")) %>%
      mutate(geoid = normalize_geoid("cbsa", geoid))
  } else {
    readRDS(file.path(getwd(), "geometry", "states_2023.rds")) %>%
      mutate(geoid = normalize_geoid("state", geoid))
  }

  assign(level, shape, envir = shape_cache)
  shape
}

geo_mode_to_level <- function(mode) {
  if (identical(mode, "MSA")) {
    return("cbsa")
  }

  "state"
}

load_msa_meta <- function() {
  load_geo_meta("cbsa") %>%
    filter(grepl("Metro Area$", name)) %>%
    mutate(
      short_name = sub(" Metro Area$", "", name),
      display_name = paste0(sub(" Metro Area$", "", name), " (MSA)")
    )
}

load_state_meta_display <- function(crosswalk) {
  decorate_geo_meta("state", load_geo_meta("state"), crosswalk) %>%
    mutate(short_name = name, display_name = name)
}

build_msa_state_lookup <- function(crosswalk, msa_meta) {
  crosswalk %>%
    filter(!is.na(cbsa_geoid), cbsa_geoid != "", county_in_cbsa) %>%
    distinct(state_fips, state_name, state_abbreviation, cbsa_geoid) %>%
    left_join(
      msa_meta %>% select(geoid, short_name, display_name),
      by = c("cbsa_geoid" = "geoid")
    ) %>%
    filter(!is.na(display_name)) %>%
    mutate(state_label = paste0(state_name, " (", state_abbreviation, ")"))
}

build_percentile_legend <- function(title) {
  tags$div(
    class = "cgt-legend-card",
    tags$span(class = "legend-title", title),
    tags$div(class = "cgt-legend-bar"),
    tags$div(
      class = "cgt-legend-labels",
      tags$span("0%"),
      tags$span("100%")
    )
  )
}

# Work around leaflet's Shiny bounds/label helpers, which error on this geometry set.
add_polygons_direct <- function(map, lng = NULL, lat = NULL, layerId = NULL, group = NULL,
                                stroke = TRUE, color = "#03F", weight = 5, opacity = 0.5,
                                fill = TRUE, fillColor = color, fillOpacity = 0.2, dashArray = NULL,
                                smoothFactor = 1, noClip = FALSE, popup = NULL, popupOptions = NULL,
                                label = NULL, labelOptions = NULL, options = pathOptions(),
                                highlightOptions = NULL, data = getMapData(map)) {
  if (missing(labelOptions)) {
    labelOptions <- labelOptions()
  }

  options <- c(
    options,
    leaflet:::filterNULL(list(
      stroke = stroke,
      color = color,
      weight = weight,
      opacity = opacity,
      fill = fill,
      fillColor = fillColor,
      fillOpacity = fillOpacity,
      dashArray = dashArray,
      smoothFactor = smoothFactor,
      noClip = noClip
    ))
  )

  polygons <- leaflet:::derivePolygons(data, lng, lat, missing(lng), missing(lat), "addPolygons")

  if (!is.null(label)) {
    label <- htmltools::htmlEscape(as.character(label))
  }

  leaflet:::invokeMethod(
    map,
    data,
    "addPolygons",
    polygons,
    layerId,
    group,
    options,
    popup,
    popupOptions,
    label,
    labelOptions,
    highlightOptions
  )
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
    HTML("<b>Choose a state, region, and ranking metric</b>"),
    selectInput(
      "state_selected",
      label = "State:",
      choices = c("Loading..." = ""),
      selected = "",
      width = "100%"
    ),
    uiOutput("msa_selected_ui"),
    selectInput(
      "region_metric",
      label = "Rank industries by:",
      choices = region_metric_choices,
      selected = "industry_feasibility_percentile_score",
      width = "100%"
    ),
    textInput(
      "region_industry_search",
      label = "Filter industries:",
      placeholder = "Search by NAICS or industry name"
    ),
    checkboxInput(
      "region_underdeveloped_only",
      label = "Show underdeveloped industries only (LQ < 1)",
      value = TRUE
    ),
    tags$div(
      class = "cgt-sidebar-note",
      tags$strong("MSA and State only."),
      tags$p("This rebuild follows the old app pattern, but the public 2026 snapshot only supports state and metro-area data in this UI.")
    )
  ),
  div(
    class = "cgt-page",
    page_fillable(
      fluidRow(
        class = "mi_clase cgt-hero-row",
        column(3, uiOutput("title_ui")),
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
      column(12, h3(class = "cgt-section-title", "Filter and select industries to evaluate"))
    ),
    fluidRow(
      column(
        8,
        reactableOutput("feasibility_table", height = "520px")
      ),
      column(
        4,
        card(
          class = "cgt-card",
          card_header("Feasible & Complex"),
          plotlyOutput("scatter_complexity", height = "250px")
        ),
        br(),
        card(
          class = "cgt-card",
          card_header("Strategic Gain vs Feasibility"),
          plotlyOutput("scatter_good_jobs", height = "250px")
        )
      )
    ),
    tags$p(
      class = "cgt-footnote",
      "The table presents public-snapshot industries for the selected metro area or state. Underdeveloped mode keeps industries with a location quotient below one, preserving the older planning workflow."
    ),
    br(),
    fluidRow(
      column(6, uiOutput("region_top_feasible")),
      column(6, uiOutput("region_top_strategic"))
    ),
    br(),
    uiOutput("industries_to_grow_analysis")
  )
)

industry_page <- layout_sidebar(
  fillable = FALSE,
  sidebar = sidebar(
    width = 310,
    HTML("<b>Choose an industry and compare where it is most feasible to grow</b>"),
    selectizeInput(
      "industry_code",
      label = "Industry:",
      choices = NULL,
      width = "100%",
      options = list(placeholder = "Choose an industry")
    ),
    selectInput(
      "industry_metric",
      label = "Selection criteria:",
      choices = industry_metric_choices,
      selected = "industry_feasibility_percentile_score",
      width = "100%"
    ),
    checkboxInput(
      "industry_underdeveloped_only",
      label = "Show underdeveloped regions only (LQ < 1)",
      value = TRUE
    ),
    tags$div(
      class = "cgt-sidebar-note",
      tags$strong("Map-first layout."),
      tags$p("The top navigation toggle switches the full US choropleth between metro areas and states, matching the older app's overall behavior.")
    )
  ),
  div(
    class = "cgt-page",
    tabsetPanel(
      tabPanel(
        "Map",
        div(
          class = "cgt-map-stage",
          leafletOutput("Maps", height = 700),
          absolutePanel(
            id = "controls2",
            class = "panel panel-default cgt-overlay-panel",
            fixed = FALSE,
            draggable = TRUE,
            top = 200,
            right = "auto",
            left = 32,
            bottom = "auto",
            width = 320,
            height = "auto",
            uiOutput("title_ui_Business")
          ),
          absolutePanel(
            top = 86,
            right = 36,
            left = "auto",
            width = 225,
            fixed = FALSE,
            uiOutput("map_legend")
          ),
          absolutePanel(
            id = "controls",
            class = "panel panel-default cgt-overlay-panel cgt-click-panel",
            fixed = FALSE,
            draggable = TRUE,
            top = 160,
            right = 36,
            left = "auto",
            bottom = "auto",
            width = 280,
            height = "auto",
            uiOutput("ver")
          )
        ),
        tags$p(
          class = "cgt-footnote",
          "This map shows where the selected industry is most feasible across US states or metro areas, using a percentile choropleth like the original application."
        )
      ),
      tabPanel(
        "Table",
        br(),
        uiOutput("title_ui_Business_table"),
        reactableOutput("Table_Map", height = "700px"),
        tags$p(
          class = "cgt-footnote",
          "The table provides the same state or metro ranking behind the choropleth, using the selected metric from the current public snapshot."
        )
      )
    ),
    br(),
    uiOutput("Region_to_grow_analysis")
  )
)

about_page <- fluidRow(
  column(
    8,
    h2("The Clean Growth Tool Website 2026"),
    tags$p(
      "This version intentionally returns to the older Shiny UI pattern: a dark RMI navigation bar, a left filter rail, and a map-first Industry View."
    ),
    tags$p(
      "It uses the latest public snapshot where possible, but this old-UI rebuild is intentionally scoped to State and Metro Area views because the public 2026 data does not expose Economic Area files."
    ),
    h3("What changed"),
    tags$ul(
      tags$li("Industry View uses a full US choropleth again, with draggable summary panels modeled on the old app."),
      tags$li("Region View uses the older state-and-city flow, adapted to current public state/MSA data."),
      tags$li("Legacy workforce-specific panels remain out of scope because matching public 2026 datasets are not available.")
    ),
    h3("Data source"),
    tags$p(
      "Primary source: public Clean Growth Tool snapshot vendored locally under public/data. Metro geometries are sourced from Census TIGER/Line boundaries and stored locally in this repository."
    ),
    tags$img(src = "img/feasibility_form.jpg", class = "cgt-about-image"),
    tags$img(src = "img/diagram.jpeg", class = "cgt-about-image")
  )
)

ui <- page_navbar(
  id = "navbarID",
  selected = "Industry-View",
  title = list(
    tags$img(src = "./img/header-logo-white.svg", width = "12px"),
    tags$img(src = "./img/rmi_horizontal_white.svg", width = "50px")
  ),
  header = tags$head(
    tags$meta(name = "description", content = "Clean Growth Tool Website 2026 Shiny rebuild using the old app UI with current public state and metro data."),
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
  nav_spacer(),
  nav_item(
    radioGroupButtons(
      inputId = "Region_select",
      choices = c("Metro Areas" = "MSA", "State" = "STATE"),
      selected = "MSA",
      size = "sm",
      justified = FALSE,
      checkIcon = list(yes = icon("check"))
    )
  ),
  nav_panel("About", about_page),
  nav_item(tags$a("Public RMI data", href = "https://github.com/bsf-rmi/RMI_Clean_Growth_Tool", target = "_blank"))
)

server <- function(input, output, session) {
  crosswalk <- load_crosswalk()
  msa_meta <- load_msa_meta() %>% arrange(display_name)
  state_meta <- load_state_meta_display(crosswalk) %>% arrange(display_name)
  msa_state_lookup <- build_msa_state_lookup(crosswalk, msa_meta)

  active_level <- reactive({
    geo_mode_to_level(if (is.null(input$Region_select)) "MSA" else input$Region_select)
  })

  active_geo_meta <- reactive({
    if (identical(input$Region_select, "MSA")) {
      msa_meta
    } else {
      state_meta
    }
  })

  active_industry_meta <- reactive({
    load_industry_meta(active_level()) %>% arrange(industry_description)
  })

  observe({
    if (identical(input$Region_select, "MSA")) {
      state_choices_df <- msa_state_lookup %>%
        distinct(state_fips, state_label) %>%
        arrange(state_label)
      choices <- c("All states" = "ALL", stats::setNames(state_choices_df$state_fips, state_choices_df$state_label))
      selected <- isolate(input$state_selected)
      if (is.null(selected) || !selected %in% unname(choices)) {
        selected <- "ALL"
      }
    } else {
      choices <- stats::setNames(state_meta$geoid, state_meta$display_name)
      selected <- isolate(input$state_selected)
      if (is.null(selected) || !selected %in% state_meta$geoid) {
        selected <- state_meta$geoid[[1]]
      }
    }

    updateSelectInput(session, "state_selected", choices = choices, selected = selected)
  })

  available_msas <- reactive({
    req(identical(input$Region_select, "MSA"))

    if (is.null(input$state_selected) || identical(input$state_selected, "ALL")) {
      return(msa_meta)
    }

    msa_ids <- msa_state_lookup %>%
      filter(state_fips == input$state_selected) %>%
      distinct(cbsa_geoid) %>%
      pull(cbsa_geoid)

    msa_meta %>%
      filter(geoid %in% msa_ids) %>%
      arrange(display_name)
  })

  output$msa_selected_ui <- renderUI({
    if (!identical(input$Region_select, "MSA")) {
      return(NULL)
    }

    choices_df <- available_msas()
    req(nrow(choices_df) > 0)
    selected <- isolate(input$msa_selected)
    if (is.null(selected) || !selected %in% choices_df$geoid) {
      selected <- choices_df$geoid[[1]]
    }

    selectizeInput(
      "msa_selected",
      label = "Metro Area:",
      choices = stats::setNames(choices_df$geoid, choices_df$display_name),
      selected = selected,
      width = "100%",
      options = list(placeholder = "Choose a metro area")
    )
  })

  observeEvent(active_industry_meta(), {
    meta <- active_industry_meta()
    choices <- stats::setNames(meta$industry_code, paste0(meta$industry_description, " (", meta$industry_code, ")"))
    selected <- isolate(input$industry_code)

    if (is.null(selected) || !selected %in% meta$industry_code) {
      selected <- meta$industry_code[[1]]
    }

    updateSelectizeInput(session, "industry_code", choices = choices, selected = selected, server = TRUE)
  }, ignoreNULL = FALSE)

  region_selected_geoid <- reactive({
    if (identical(input$Region_select, "MSA")) {
      req(input$msa_selected)
      input$msa_selected
    } else {
      req(input$state_selected)
      input$state_selected
    }
  })

  region_selected_meta <- reactive({
    active_geo_meta() %>%
      filter(geoid == region_selected_geoid()) %>%
      slice(1)
  })

  industry_selected_meta <- reactive({
    req(input$industry_code)
    active_industry_meta() %>%
      filter(industry_code == input$industry_code) %>%
      slice(1)
  })

  industry_region_data <- reactive({
    req(input$industry_code)

    joined <- load_industry_regions(active_level(), input$industry_code) %>%
      filter(geoid %in% active_geo_meta()$geoid) %>%
      left_join(
        active_geo_meta() %>%
          select(
            geoid,
            geo_name = short_name,
            display_name,
            industrial_diversity,
            economic_complexity_index,
            strategic_index
          ),
        by = "geoid"
      ) %>%
      mutate(
        geo_name = coalesce(geo_name, display_name, geoid)
      )

    if (isTRUE(input$industry_underdeveloped_only)) {
      joined <- joined %>% filter(location_quotient < 1)
    }

    joined %>%
      arrange(desc(.data[[input$industry_metric]]), desc(strategic_gain_percentile_score))
  })

  industry_region_map_data <- reactive({
    metric_key <- input$industry_metric

    industry_region_data() %>%
      mutate(
        metric_value = .data[[metric_key]],
        metric_percentile = percent_rank(metric_value),
        metric_rank = rank(desc(metric_value), ties.method = "first")
      )
  })

  region_industry_data <- reactive({
    joined <- load_region_industries(active_level(), region_selected_geoid()) %>%
      left_join(active_industry_meta(), by = "industry_code")

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

  output$title_ui <- renderUI({
    selected <- region_selected_meta()
    level_label <- if (identical(input$Region_select, "MSA")) "Metro Area" else "State"

    div(
      class = "cgt-title-block",
      tags$div(class = "cgt-kicker", tags$span(level_label)),
      h2(class = "cgt-region-heading", selected$display_name),
      tags$p(class = "cgt-muted", "Use the old Region View workflow to identify feasible and strategically valuable industries.")
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

  output$feasibility_table <- renderReactable({
    data <- region_industry_data()
    req(nrow(data) > 0)

    metric_key <- input$region_metric
    selected_label <- metric_label(metric_key, region_metric_choices)

    build_region_table(
      data %>%
        mutate(selected_metric = .data[[metric_key]]) %>%
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
        ),
      selected_label,
      metric_key
    )
  })

  output$scatter_complexity <- renderPlotly({
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

  output$scatter_good_jobs <- renderPlotly({
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
    top_entries_card(
      "Top Feasible Industries",
      "Highest feasibility percentile scores under the current filters.",
      region_industry_data() %>% arrange(desc(industry_feasibility_percentile_score)),
      "industry_feasibility_percentile_score",
      "industry_description"
    )
  })

  output$region_top_strategic <- renderUI({
    top_entries_card(
      "Top Strategic Gain Industries",
      "Industries with the strongest strategic upside for the selected region.",
      region_industry_data() %>% arrange(desc(strategic_gain_percentile_score)),
      "strategic_gain_percentile_score",
      "industry_description"
    )
  })

  output$industries_to_grow_analysis <- renderUI({
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
      )
    )
  })

  output$title_ui_Business <- renderUI({
    selected <- industry_selected_meta()

    tags$div(
      class = "cgt-map-summary",
      tags$h5(selected$industry_description),
      tags$p(class = "cgt-overlay-subtitle", paste0("NAICS ", selected$industry_code, " · ", if (identical(input$Region_select, "MSA")) "Metro Areas" else "States")),
      tags$div(
        class = "cgt-mini-stat-grid",
        tags$div(class = "cgt-mini-stat", tags$span("Complexity"), tags$strong(sprintf("%.2f", selected$industry_complexity))),
        tags$div(class = "cgt-mini-stat", tags$span("Complexity %ile"), tags$strong(sprintf("%.1f", selected$industry_complexity_percentile))),
        tags$div(class = "cgt-mini-stat", tags$span("Nat. emp. share"), tags$strong(percent(selected$industry_employment_share_nation, accuracy = 0.01))),
        tags$div(class = "cgt-mini-stat", tags$span("Ubiquity"), tags$strong(comma(selected$industry_ubiquity)))
      )
    )
  })

  output$title_ui_Business_table <- renderUI({
    selected <- industry_selected_meta()
    tags$div(
      class = "cgt-table-title",
      tags$h5(selected$industry_description),
      tags$p(class = "cgt-muted", paste0("NAICS ", selected$industry_code, " ranked across ", if (identical(input$Region_select, "MSA")) "metro areas" else "states", "."))
    )
  })

  output$map_legend <- renderUI({
    build_percentile_legend(paste("Percentile", metric_label(input$industry_metric, industry_metric_choices)))
  })

  output$Maps <- renderLeaflet({
    map_data <- industry_region_map_data()
    req(nrow(map_data) > 0)

    pal <- colorNumeric(
      palette = c("#8c510a", "#e8cd94", "#f5f7ea", "#93cfc8", "#01665e"),
      domain = seq(0, 1, by = 0.1),
      reverse = FALSE,
      na.color = "#dfe7ec"
    )

    shape <- get_shape_data(active_level()) %>%
      inner_join(
        map_data %>%
          transmute(
            geoid,
            geo_name,
            metric_value,
            metric_percentile,
            metric_rank,
            industry_feasibility_percentile_score,
            strategic_gain_percentile_score,
          location_quotient
          ),
        by = "geoid"
      ) %>%
      sf::st_transform(4326)
    shape_sp <- methods::as(shape, "Spatial")

    labels <- sprintf(
      "%s\n%s percentile: %s\n%s: %s",
      shape$geo_name,
      metric_label(input$industry_metric, industry_metric_choices),
      round(shape$metric_percentile * 100, 0),
      metric_label(input$industry_metric, industry_metric_choices),
      format_metric_value(shape$metric_value, input$industry_metric)
    )

    leaflet(options = leafletOptions(zoomControl = TRUE)) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      add_polygons_direct(
        data = shape_sp,
        stroke = TRUE,
        fillOpacity = 0.8,
        smoothFactor = 0.9,
        color = "#5e9fb0",
        opacity = 0.15,
        fillColor = pal(shape_sp@data$metric_percentile),
        layerId = shape_sp@data$geoid,
        label = labels,
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "15px",
          direction = "auto"
        )
      ) %>%
      setView(lng = -98.583333, lat = 39.833333, zoom = 5)
  })

  observeEvent(list(input$industry_code, input$industry_metric, input$Region_select), {
    output$ver <- renderUI({ NULL })
  }, ignoreInit = FALSE)

  observeEvent(input$Maps_shape_click, {
    selected_row <- industry_region_map_data() %>%
      filter(geoid == input$Maps_shape_click$id) %>%
      slice(1)

    req(nrow(selected_row) == 1)

    output$ver <- renderUI({
      card(
        class = "cgt-card",
        card_header("Zoom-in"),
        h5(selected_row$geo_name),
        h6(
          paste0(
            "Placed at rank ",
            selected_row$metric_rank,
            " out of ",
            nrow(industry_region_map_data()),
            " by ",
            metric_label(input$industry_metric, industry_metric_choices),
            " for ",
            industry_selected_meta()$industry_description
          )
        ),
        reactableOutput("selected_city_stats_map"),
        actionLink("Close", "Close")
      )
    })

    output$selected_city_stats_map <- renderReactable({
      reactable(
        tibble::tibble(
          Metric = c(
            metric_label(input$industry_metric, industry_metric_choices),
            "Feasibility percentile",
            "Strategic gain percentile",
            "Location quotient"
          ),
          Value = c(
            format_metric_value(selected_row$metric_value, input$industry_metric),
            sprintf("%.1f", selected_row$industry_feasibility_percentile_score),
            sprintf("%.1f", selected_row$strategic_gain_percentile_score),
            sprintf("%.2f", selected_row$location_quotient)
          )
        ),
        pagination = FALSE,
        bordered = FALSE,
        compact = TRUE
      )
    })
  })

  observeEvent(input$Close, {
    output$ver <- renderUI({ NULL })
  })

  output$Table_Map <- renderReactable({
    data <- industry_region_map_data()
    req(nrow(data) > 0)

    metric_key <- input$industry_metric
    selected_label <- metric_label(metric_key, industry_metric_choices)

    build_industry_table(
      data %>%
        transmute(
          geo_name,
          selected_metric = metric_value,
          industry_feasibility_percentile_score,
          strategic_gain_percentile_score,
          industry_feasibility,
          strategic_gain,
          location_quotient,
          industry_employment_share,
          economic_complexity_index,
          industrial_diversity,
          strategic_index
        ),
      selected_label,
      metric_key
    )
  })

  output$Region_to_grow_analysis <- renderUI({
    data <- industry_region_map_data()
    req(nrow(data) > 0)

    top_places <- paste(head(data$geo_name[order(data$metric_rank)], 3), collapse = ", ")

    card(
      class = "cgt-card industries_to_grow_analysis-1",
      card_header("Industry View Readout"),
      tags$p(
        glue(
          "{industry_selected_meta()$industry_description} currently looks strongest in {top_places} under the {if (identical(input$Region_select, 'MSA')) 'metro-area' else 'state'} view."
        )
      )
    )
  })
}

shinyApp(ui, server)
