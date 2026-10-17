# Survey charts ----------------------------------------------------------------
# Each function takes survey data (or a subset) and returns a ggplot:
#   plot_modes(students) + labs(title = "Students' commute modes")
# Needs survey_codebook.R and chart_style.R sourced first.
#
# A column passed in by name, like plot_share(survey, floor_group), is written
# {{ column }} inside the function. That passes the bare name on to dplyr and
# ggplot, as if it had been typed there.

library(dplyr)
library(forcats)
library(ggplot2)

## Share bars ------------------------------------------------------------------

# The layers for a horizontal bar chart of a share column, labelled with
# percentages. Add title and subtitle with labs():
#   ggplot(shares, aes(x = share, y = answer)) + share_bars()
share_bars <- function() {
  list(
    geom_col(width = 0.7, fill = bar_colour),
    geom_text(
      aes(label = percent_label(share)),
      hjust = -0.2,
      colour = text_grey,
      size = label_size
    ),
    scale_x_continuous(
      labels = scales::percent,
      expand = expansion(mult = c(0, 0.1))
    ),
    theme_ubike(grid = "x")
  )
}

## Share of each answer --------------------------------------------------------

# Share giving each answer, in codebook order (or by size with sort = TRUE).
# Missing answers get a "(no answer)" bar.
#   plot_share(survey, floor_group, "Floor of home")
plot_share <- function(data, column, title, sort = FALSE) {
  shares <- data |>
    count(answer = {{ column }}) |>
    mutate(
      share = n / sum(n),
      answer = fct_na_value_to_level(factor(answer), "(no answer)")
    )

  if (sort) {
    shares <- shares |> mutate(answer = fct_reorder(answer, share))
  } else {
    # First answer on top
    shares <- shares |> mutate(answer = fct_rev(answer))
  }

  ggplot(shares, aes(x = share, y = answer)) +
    share_bars() +
    labs(
      title = title,
      subtitle = paste0("Share of respondents (n = ", sum(shares$n), ")"),
      x = NULL,
      y = NULL
    )
}

## Histogram -------------------------------------------------------------------

# Spread of a numeric answer like age or distance_km.
#   plot_histogram(survey, age, "Age of respondents", binwidth = 2, "Age")
plot_histogram <- function(data, column, title, binwidth, x_label = NULL) {
  values <- data |> filter(!is.na({{ column }}))

  ggplot(values, aes(x = {{ column }})) +
    geom_histogram(
      binwidth = binwidth,
      boundary = 0,
      fill = bar_colour,
      colour = background_colour,
      linewidth = 0.3
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    labs(
      title = title,
      subtitle = paste0("n = ", nrow(values)),
      x = x_label,
      y = "Respondents"
    ) +
    theme_ubike(grid = "y")
}

## Willingness by group --------------------------------------------------------

# Q23 answers as a 100% bar per group, labelled with the group size.
#   plot_willingness_by(survey, campus, "Title")
plot_willingness_by <- function(data, group, title) {
  shares <- data |>
    filter(!is.na({{ group }})) |>
    count({{ group }}, willingness) |>
    group_by({{ group }}) |>
    mutate(
      share = n / sum(n),
      label = paste0({{ group }}, "\n(n = ", sum(n), ")")
    ) |>
    ungroup() |>
    mutate(
      # First group on top
      label = fct_rev(fct_inorder(label)),
      # "Not Interested" on the left
      willingness = fct_rev(willingness),
      # Too thin to label under 6%
      percent_text = if_else(share >= 0.06, percent_label(share), "")
    )

  ggplot(shares, aes(x = share, y = label, fill = willingness)) +
    geom_col(width = 0.7, colour = background_colour, linewidth = 0.5) +
    geom_text(
      aes(label = percent_text),
      position = position_stack(vjust = 0.5),
      colour = "white",
      size = label_size
    ) +
    scale_x_continuous(labels = scales::percent, expand = c(0, 0)) +
    scale_fill_manual(
      values = willingness_colours,
      breaks = names(willingness_colours),
      labels = willingness_legend
    ) +
    labs(title = title, x = NULL, y = NULL) +
    theme_ubike(grid = "x")
}

## Willingness by distance -----------------------------------------------------

# Share answering yes to Q23 in each distance band.
plot_willingness_by_distance <- function(data) {
  shares <- data |>
    filter(!is.na(distance_km)) |>
    mutate(
      band = cut(
        distance_km,
        breaks = c(0, 2, 5, 10, 20, Inf),
        labels = c("0-2 km", "2-5 km", "5-10 km", "10-20 km", "20+ km"),
        include.lowest = TRUE
      ),
      willing = fct_match(willingness, c("Yes_electric", "Yes_all bikes"))
    ) |>
    group_by(band) |>
    summarise(share = mean(willing), n = n()) |>
    mutate(label = fct_inorder(paste0(band, "\nn = ", n)))

  ggplot(shares, aes(x = label, y = share)) +
    geom_col(width = 0.7, fill = bar_colour) +
    geom_text(
      aes(label = percent_label(share)),
      vjust = -0.6,
      colour = text_grey,
      size = label_size
    ) +
    scale_y_continuous(
      labels = scales::percent,
      expand = expansion(mult = c(0, 0.12))
    ) +
    labs(
      title = "Willingness to use UBike, by commute distance",
      subtitle = "Share answering yes (e-bikes or all bikes)",
      x = "Home-to-campus distance",
      y = NULL
    ) +
    theme_ubike(grid = "y")
}

## Commute modes ---------------------------------------------------------------

# Share of people using each Q14 mode. People can pick several, so the bars
# add up to more than 100%.
plot_modes <- function(data) {
  shares <- split_modes(data) |>
    count(mode) |>
    mutate(
      share = n / nrow(data), # out of people, not answers
      mode = fct_reorder(mode, share)
    )

  ggplot(shares, aes(x = share, y = mode)) +
    share_bars() +
    labs(
      title = "Modes used to commute to campus",
      subtitle = "Share of respondents using each mode; many use several",
      x = NULL,
      y = NULL
    )
}

## Mode combinations -----------------------------------------------------------

# Most common full Q14 answers, like "bus + metro". Unlike plot_modes(), each
# person counts once.
plot_mode_combinations <- function(data, top = 10) {
  combos <- split_modes(data) |>
    arrange(id, mode) |>
    group_by(id) |>
    summarise(combination = paste(mode, collapse = " + ")) |>
    count(combination) |>
    mutate(share = n / sum(n))

  shown <- combos |>
    slice_max(n, n = top, with_ties = FALSE) |>
    mutate(combination = fct_reorder(combination, n))

  ggplot(shown, aes(x = share, y = combination)) +
    share_bars() +
    labs(
      title = "Most common combinations of commute modes",
      subtitle = paste0(
        "Top ",
        nrow(shown),
        " of ",
        nrow(combos),
        " combinations; share of respondents (n = ",
        sum(combos$n),
        ")"
      ),
      x = NULL,
      y = NULL
    )
}

## Municipalities --------------------------------------------------------------

# Respondents per municipality, with the rest lumped into "Other". Ties can add
# a few bars past top.
plot_municipalities <- function(data, top = 10) {
  counts <- data |>
    mutate(municipality = fct_lump_n(municipality, top)) |>
    count(municipality) |>
    mutate(
      municipality = fct_reorder(municipality, n),
      municipality = fct_relevel(municipality, "Other") # Other at the bottom
    )

  ggplot(counts, aes(x = n, y = municipality)) +
    geom_col(width = 0.7, fill = bar_colour) +
    geom_text(
      aes(label = n),
      hjust = -0.3,
      colour = text_grey,
      size = label_size
    ) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.08))) +
    labs(
      title = "Where respondents live",
      subtitle = paste("Top", top, "municipalities by respondents"),
      x = NULL,
      y = NULL
    ) +
    theme_ubike(grid = "x")
}
