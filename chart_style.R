# Chart style ------------------------------------------------------------------
# Colours, sizes and the theme shared by every chart in plots.R.

library(ggplot2)

## Colours ---------------------------------------------------------------------

text_dark <- "#0b0b0b" # titles
text_grey <- "#52514e" # axis labels, legend, values on bars
text_light <- "#898781" # axis titles, captions

background_colour <- "#fcfcfb"
grid_colour <- "#e1e0d9"
bar_colour <- "#2a78d6" # for charts with a single colour

# Q23 answers, going from light to dark blue as the answer gets more positive.
# The names have to match the labels in survey_codebook.R.
willingness_colours <- c(
  "Not Interested" = "#86b6ef",
  "Unsure" = "#3987e5",
  "Yes_electric" = "#256abf",
  "Yes_all bikes" = "#104281"
)

# The same answers, reworded for the legend
willingness_legend <- c(
  "Not interested",
  "Unsure",
  "Yes, e-bikes",
  "Yes, all bikes"
)

## Text ------------------------------------------------------------------------

label_size <- 3.3 # values on bars, in mm

# 0.315 becomes "32%". Shares too small to round to 1% show as "<1%".
# (scales::percent() borrows percent() from the scales package without
# loading the whole thing with library().)
percent_label <- function(x) {
  ifelse(x > 0 & x < 0.01, "<1%", scales::percent(x, accuracy = 1))
}

## Theme -----------------------------------------------------------------------

# grid says which gridlines to keep: "x", "y" or "both". Horizontal bar charts
# want "x", vertical ones "y".
theme_ubike <- function(grid = "both") {
  ubike_theme <- theme_minimal(base_size = 12) +
    theme(
      plot.background = element_rect(fill = background_colour, colour = NA),
      plot.title = element_text(colour = text_dark, face = "bold"),
      plot.subtitle = element_text(colour = text_grey),
      plot.caption = element_text(colour = text_light, hjust = 0),
      # line the title and caption up with the chart's left edge, not the axis
      plot.title.position = "plot",
      plot.caption.position = "plot",
      axis.text = element_text(colour = text_grey),
      axis.title = element_text(colour = text_light),
      panel.grid.major = element_line(colour = grid_colour, linewidth = 0.3),
      panel.grid.minor = element_blank(),
      legend.position = "top",
      legend.justification = "left",
      legend.text = element_text(colour = text_grey),
      legend.title = element_blank(),
      # extra room on the right so the last axis label ("100%") isn't cut off
      plot.margin = margin(8, 16, 8, 8)
    )

  if (grid == "x") {
    ubike_theme <- ubike_theme + theme(panel.grid.major.y = element_blank())
  }
  if (grid == "y") {
    ubike_theme <- ubike_theme + theme(panel.grid.major.x = element_blank())
  }

  ubike_theme
}

## Saving ----------------------------------------------------------------------

# Saves a chart to output/<name>.png and hands the chart back unchanged, so it
# still shows up when you run the line in the console:
#   plot_modes(survey) |> save_chart("modes")
# A fixed size keeps the PNGs identical however the script is run.
save_chart <- function(plot, name, width = 8, height = 5) {
  dir.create("output", showWarnings = FALSE)
  ggsave(
    file.path("output", paste0(name, ".png")),
    plot,
    width = width,
    height = height, # inches
    dpi = 300
  )
  plot
}
