# UBike survey charts
# Draws the descriptive charts and saves each one to output/ as a PNG. Run it a
# few lines at a time (select, then Cmd+Enter), or all at once.

# Setup ------------------------------------------------------------------------

library(dplyr)
library(forcats)

source("survey_codebook.R") # read_survey(), column names and answer labels
source("chart_style.R") # colours and theme for the charts
source("plots.R") # the plot_*() functions

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
plot_municipalities(survey) |> save_chart("municipalities")
