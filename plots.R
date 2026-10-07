# Survey charts ----------------------------------------------------------------
# One function per chart. Each takes survey data (all of it, or a subset like
# students) and returns a ggplot you can keep adding to:
#   plot_modes(students) + labs(title = "Students' commute modes")
#
# Needs survey_codebook.R and chart_style.R sourced first (main.R does this).

library(dplyr)
library(forcats) # the fct_*() functions for working with factors
library(ggplot2)

## Willingness by group --------------------------------------------------------

# Q23 answers as one 100% bar per group, with the group size in its label.
# Pass the column without quotes: plot_willingness_by(survey, campus, "Title")
plot_willingness_by <- function(data, group, title) {
  # {{ group }} passes the column you gave the function on to dplyr. Without
  # the braces, dplyr would look for a column actually called "group".
  shares <- data |>
    filter(!is.na({{ group }})) |>
    count({{ group }}, willingness) |> # adds n, the number of people
    group_by({{ group }}) |>
    mutate(
      share = n / sum(n),
      label = paste0({{ group }}, "\n(n = ", sum(n), ")")
    ) |>
    ungroup() |>
    mutate(
      # ggplot draws the first level at the bottom, so flip the order to get
      # the first group on top
      label = fct_rev(fct_inorder(label)),
      # flipped so every bar starts with "Not Interested" on the left
      willingness = fct_rev(willingness),
      # segments under 6% are too thin to fit a label
      percent_text = if_else(share >= 0.06, percent_label(share), "")
    )

  ggplot(shares, aes(x = share, y = label, fill = willingness)) +
    geom_col(width = 0.7, colour = background_colour, linewidth = 0.5) +
    geom_text(
      aes(label = percent_text),
      position = position_stack(vjust = 0.5), # middle of each segment
      colour = "white",
      size = label_size
    ) +
    scale_x_continuous(labels = scales::percent, expand = c(0, 0)) +
    scale_fill_manual(
      values = willingness_colours,
      breaks = names(willingness_colours), # legend in the original order
      labels = willingness_legend
    ) +
    labs(title = title, x = NULL, y = NULL) +
    theme_ubike(grid = "x")
}

## Willingness by distance -----------------------------------------------------

# Share answering yes to Q23 (e-bikes or all bikes) in each distance band.
plot_willingness_by_distance <- function(data) {
  shares <- data |>
    filter(!is.na(distance_km)) |>
    mutate(
      band = cut(
        distance_km,
        breaks = c(0, 2, 5, 10, 20, Inf),
        labels = c("0–2 km", "2–5 km", "5–10 km", "10–20 km", "20+ km"),
        include.lowest = TRUE
      ),
      willing = fct_match(willingness, c("Yes_electric", "Yes_all bikes"))
    ) |>
    group_by(band) |>
    # the mean of TRUE/FALSE values is the proportion that are TRUE
    summarise(share = mean(willing), n = n()) |>
    mutate(label = fct_inorder(paste0(band, "\nn = ", n)))

  ggplot(shares, aes(x = label, y = share)) +
    geom_col(width = 0.7, fill = bar_colour) +
    geom_text(
      aes(label = percent_label(share)),
      vjust = -0.6, # just above the bar
      colour = text_grey,
      size = label_size
    ) +
    scale_y_continuous(
      labels = scales::percent,
      expand = expansion(mult = c(0, 0.12)) # headroom for the labels
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

# Share of people using each commute mode (Q14). People could pick more than
# one, so the bars add up to more than 100%.
plot_modes <- function(data) {
  shares <- split_modes(data) |>
    count(mode) |>
    mutate(
      share = n / nrow(data), # out of people, not answers
      mode = fct_reorder(mode, share)
    )

  ggplot(shares, aes(x = share, y = mode)) +
    geom_col(width = 0.7, fill = bar_colour) +
    geom_text(
      aes(label = percent_label(share)),
      hjust = -0.2, # just past the end of the bar
      colour = text_grey,
      size = label_size
    ) +
    scale_x_continuous(
      labels = scales::percent,
      expand = expansion(mult = c(0, 0.1))
    ) +
    labs(
      title = "Modes used to commute to campus",
      subtitle = "Share of respondents using each mode; many use several",
      x = NULL,
      y = NULL
    ) +
    theme_ubike(grid = "x")
}

## Municipalities --------------------------------------------------------------

# Respondents per municipality. The top ones get their own bar and the rest
# are lumped into "Other". Ties for last place are all kept, so you can end up
# with a few more bars than top.
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
