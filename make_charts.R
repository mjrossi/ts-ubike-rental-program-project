# UBike survey charts
# Draws the descriptive charts and saves each one to output/ as a PNG. Run it a
# few lines at a time (select, then Cmd+Enter), or all at once.

# Setup ------------------------------------------------------------------------

library(dplyr)
library(forcats)

source("R/survey_codebook.R") # read_survey(), column names and answer labels
source("R/chart_style.R") # colours and theme for the charts
source("R/plots.R") # the plot_*() functions

# Data -------------------------------------------------------------------------

survey <- read_survey()

# Just the students. fct_match() works like == but stops with an error on a
# typo ("Studnet") instead of quietly returning zero rows.
students <- survey |>
  filter(fct_match(role, "Student"))

# Charts -----------------------------------------------------------------------
# These all take any survey table, so plot_modes(students) works too.
# save_chart() also writes each one to output/ as a PNG.

plot_willingness_by(survey, role, "Willingness to use UBike, by role") |>
  save_chart("willingness_by_role")
plot_willingness_by(
  survey,
  urban_cycling,
  "Willingness to use UBike, by urban cycling experience"
) |>
  save_chart("willingness_by_urban_cycling")
plot_willingness_by(
  students,
  urban_cycling,
  "Students' willingness to use UBike, by urban cycling experience"
) |>
  save_chart("willingness_students_urban_cycling")
plot_willingness_by(
  survey,
  bike_parking_home,
  "Willingness to use UBike, by bike parking at home"
) |>
  save_chart("willingness_by_bike_parking")
plot_willingness_by_distance(survey) |> save_chart("willingness_by_distance")
plot_modes(survey) |> save_chart("modes")
plot_mode_combinations(survey) |> save_chart("mode_combinations")
plot_willingness_by(
  survey,
  mode_profile,
  "Willingness to use UBike, by commute type"
) |>
  save_chart("willingness_by_commute_type")
plot_municipalities(survey) |> save_chart("municipalities")

plot_share(survey, willingness, "Willingness to use UBike") |>
  save_chart("willingness")
plot_share(survey, floor_group, "Floor of home") |>
  save_chart("floor")
plot_share(survey, private_vehicle, "Private vehicle", sort = TRUE) |>
  save_chart("private_vehicle")

plot_histogram(survey, age, "Age of respondents", binwidth = 2, "Age") |>
  save_chart("age")
plot_histogram(
  survey,
  travel_time_min,
  "Travel time to campus",
  binwidth = 5,
  "Minutes"
) |>
  save_chart("travel_time")

# The few very long commutes would squash the rest, so the axis stops at 60 km
# and the caption says how many are off the chart. Most Lisboa residents have
# exactly 3.5 km in the data, which is the spike in the 2-4 km bar.
# (The brackets matter: without them, |> would run before the + additions.)
far_away <- sum(survey$distance_km > 60)
(plot_histogram(
  survey,
  distance_km,
  "Home-to-campus distance",
  binwidth = 2,
  "Kilometres"
) +
  coord_cartesian(xlim = c(0, 60)) +
  labs(caption = paste(far_away, "respondents beyond 60 km not shown"))) |>
  save_chart("distance")
