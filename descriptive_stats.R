# UBike survey: descriptive statistics (Task 1)
# Run it a few lines at a time (select, then Cmd+Enter), or all at once with
# Cmd+Option+R. Each section prepares a later step of the project.

# Setup ------------------------------------------------------------------------

# Load the packages (add-ons) we need
library(dplyr) # count(), mutate(), summarise() and the |> pipelines
library(tidyr) # pivot_wider() to turn long tables into wide ones
library(forcats) # helpers for categories (factors)
library(readxl) # read_excel() to open the Excel file

# Load his helpers: short column names, labels and split_modes()
source("survey_codebook.R")

# Data -------------------------------------------------------------------------

# Read the survey and turn number codes into words (1 becomes "Student")
survey <- read_excel("./data/TS_Project_SurveyUBike_final (local).xlsx") |>
  label_survey()

# Two helper functions ---------------------------------------------------------
# We repeat the same calculation for many columns, so we write it once here.
# {{ column }} means "the column you give me", written without quotes.

# For categories: how many people gave each answer, and what %
count_pct <- function(data, column) {
  data |>
    count(value = {{ column }}) |>
    mutate(
      pct = round(100 * n / sum(n), 1),
      value = replace_na(as.character(value), "(no answer)")
    )
}

# For numbers: the usual summary statistics in one row
num_summary <- function(data, column) {
  data |>
    summarise(
      n = sum(!is.na({{ column }})),
      mean = round(mean({{ column }}, na.rm = TRUE), 1),
      sd = round(sd({{ column }}, na.rm = TRUE), 1),
      min = min({{ column }}, na.rm = TRUE),
      q1 = quantile({{ column }}, 0.25, na.rm = TRUE), # 25% are below this
      median = median({{ column }}, na.rm = TRUE), # 50% are below this
      q3 = quantile({{ column }}, 0.75, na.rm = TRUE), # 75% are below this
      max = max({{ column }}, na.rm = TRUE)
    )
}

# For willingness (Q23) split by a group: % of each answer within the group
cross_pct <- function(data, group) {
  data |>
    filter(!is.na({{ group }})) |>
    count({{ group }}, willingness) |>
    group_by({{ group }}) |>
    mutate(
      group_n = sum(n), # people in this group
      pct = round(100 * n / group_n, 1)
    ) |>
    ungroup() |>
    select(-n) |>
    pivot_wider(names_from = willingness, values_from = pct, values_fill = 0)
}

# New helper columns -----------------------------------------------------------
# Groups that match the decision tree, made once so every table can use them.

survey <- survey |>
  mutate(
    # Distance bands of the scaffold tree (Gate 3)
    distance_group = cut(
      distance_km,
      breaks = c(-Inf, 5, 10, Inf),
      labels = c("Under 5 km", "5 to 10 km", "Over 10 km"),
      right = FALSE # 5 km goes into "5 to 10 km"
    ),
    # Children under 11 often need to be taken to school (modifier)
    young_children = if_else(
      children_under1 + children_1to5 + children_6to10 > 0,
      "Yes",
      "No"
    ),
    # Floor in fewer groups (Gate 2a and 3b)
    floor_group = factor(
      case_when(
        floor <= 0 ~ "Ground or basement",
        floor <= 2 ~ "1st or 2nd floor",
        floor <= 4 ~ "3rd or 4th floor",
        TRUE ~ "Above 4th floor"
      ),
      levels = c(
        "Ground or basement",
        "1st or 2nd floor",
        "3rd or 4th floor",
        "Above 4th floor"
      )
    ),
    # Can the person ride in the city? (Gate 1: "No" versus "Yes" or "A bit")
    can_ride = if_else(urban_cycling == "No", "Cannot ride", "Can ride")
  )

# 1. Who answered --------------------------------------------------------------
# Results are summed by role later, so we need the sample make-up.

role_table <- count_pct(survey, role)
campus_table <- count_pct(survey, campus)
gender_table <- count_pct(survey, gender)
age_summary <- num_summary(survey, age)

role_table
campus_table
gender_table
age_summary

# Age differs a lot by role, so also show it per role
survey |>
  group_by(role) |>
  num_summary(age)

# Top 10 home municipalities
survey |>
  count_pct(municipality) |>
  arrange(desc(n)) |>
  head(10)

# 2. Decision tree gates -------------------------------------------------------
# How many people fall into each branch of the tree.

urban_cycling_table <- count_pct(survey, urban_cycling) # Gate 1
distance_summary <- num_summary(survey, distance_km) # Gate 2 and 3
distance_group_table <- count_pct(survey, distance_group)
parking_table <- count_pct(survey, bike_parking_home) # Gate 2a and 3a
floor_table <- count_pct(survey, floor_group) # Gate 2a and 3b
transit_card_table <- count_pct(survey, transit_card) # Gate 3c
private_vehicle_table <- count_pct(survey, private_vehicle) # Gate 3b and 3c

urban_cycling_table
distance_summary
distance_group_table
parking_table
floor_table
transit_card_table
private_vehicle_table

# The two first splits of the tree together: who lands in which branch
survey |>
  count(can_ride, distance_group) |>
  mutate(pct = round(100 * n / sum(n), 1))

# 3. Possible modifiers --------------------------------------------------------
# We must pick at least two. A modifier only matters if it applies to many.

young_children_table <- count_pct(survey, young_children)
stop_table <- count_pct(survey, intermediate_stop)
travel_time_summary <- num_summary(survey, travel_time_min)

young_children_table
stop_table
travel_time_summary

# 4. Inputs for the emissions step ---------------------------------------------
# Which modes and car types need emission factors later.

# Q14: one person can use several modes, so % is "share of people using it"
mode_table <- split_modes(survey) |>
  count(value = mode) |>
  mutate(
    pct = round(100 * n / nrow(survey), 1),
    value = as.character(value)
  ) |>
  arrange(desc(n))

mode_table

# Fuel and vehicle type, only for people who drive a car or motorbike
drivers <- survey |>
  filter(private_vehicle %in% c("car", "motorbike"))

fuel_table <- count_pct(drivers, fuel_type)
vehicle_table <- count_pct(drivers, vehicle_type)

fuel_table
vehicle_table

# 5. Stated willingness (Q23) --------------------------------------------------
# Overall answers, then split by the tree gates (row % add up to 100).

willingness_table <- count_pct(survey, willingness)
willingness_table

cross_pct(survey, role)
cross_pct(survey, can_ride)
cross_pct(survey, distance_group)
cross_pct(survey, bike_parking_home)
cross_pct(survey, floor_group)
cross_pct(survey, private_vehicle)

# 6. Data checks ---------------------------------------------------------------
# Odd values to discuss with the team before building the tree.

# Commutes of 0 km or very long ones
survey |>
  filter(distance_km == 0 | distance_km > 60) |>
  select(id, role, distance_km, travel_time_min, modes)

# People who drive but gave no fuel type, or the other way round
survey |>
  count(private_vehicle, has_fuel_type = !is.na(fuel_type))

# Final overview ---------------------------------------------------------------
# All category tables stacked into one long table, plus one table for numbers.

overview_categories <- bind_rows(
  list(
    "Role (Q2)" = role_table,
    "Campus (Q3)" = campus_table,
    "Gender (Q5)" = gender_table,
    "Private vehicle (Q12)" = private_vehicle_table,
    "Commute modes (Q14)" = mode_table,
    "Intermediate stop (Q15)" = stop_table,
    "Transit card (Q16)" = transit_card_table,
    "Distance group (Q17)" = distance_group_table,
    "Fuel type, drivers (Q18)" = fuel_table,
    "Vehicle type, drivers (Q19)" = vehicle_table,
    "Urban cycling (Q20)" = urban_cycling_table,
    "Bike parking at home (Q21)" = parking_table,
    "Floor (Q22)" = floor_table,
    "Children under 11 (Q7-Q9)" = young_children_table,
    "Willingness (Q23)" = willingness_table
  ),
  .id = "variable" # the list names become this column
)

overview_numbers <- bind_rows(
  list(
    "Age (Q4)" = age_summary,
    "Travel time, min (Q13)" = travel_time_summary,
    "Distance, km (Q17)" = distance_summary
  ),
  .id = "variable"
)

# Look at them in the console, then as spreadsheets
print(overview_categories, n = Inf)
overview_numbers

View(overview_categories)
View(overview_numbers)

# Save both as CSV in output/ (open in Excel, or paste into the slides)
dir.create("output", showWarnings = FALSE)
write.csv(overview_categories, "output/overview_categories.csv", row.names = FALSE)
write.csv(overview_numbers, "output/overview_numbers.csv", row.names = FALSE)
