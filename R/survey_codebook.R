# Survey codebook --------------------------------------------------------------
# The sheet stores answers as codes, explained in each header, e.g.
# "Q2_Role (Student-1; Faculty/Researcher-2; Staff-3)". read_survey() renames
# the columns and swaps the codes for labels.

library(dplyr)
library(readxl)
library(tidyr)

## survey_key ------------------------------------------------------------------

# One entry per sheet column, in order: the exact header, plus its codes if it
# has any. label_survey() errors if the sheet stops matching.
survey_key <- list(
  id = list(header = "ID"),
  role = list(
    header = "Q2_Role (Student-1; Faculty/Researcher-2; Staff-3)",
    codes = c("Student" = 1, "Faculty/Researcher" = 2, "Staff" = 3)
  ),
  campus = list(
    header = "Q3_Campus (CTN-0; Alameda-1; TagusPark-2)",
    codes = c("CTN" = 0, "Alameda" = 1, "TagusPark" = 2)
  ),
  age = list(header = "Q4_Age"),
  gender = list(
    header = "Q5_Gender (Female-1; Other-0)",
    codes = c("Female" = 1, "Other" = 0)
  ),
  municipality = list(header = "Q6_Municipality"),
  children_under1 = list(header = "Q7_Children_under1"),
  children_1to5 = list(header = "Q8_Children_1to5"),
  children_6to10 = list(header = "Q9_Children_6to10"),
  children_11to15 = list(header = "Q10_Children_11to15"),
  children_over15 = list(header = "Q11_Children_over15"),
  private_vehicle = list(
    header = "Q12_PrivateVehicle (no-1; car-2; motorbike-3)",
    codes = c("no" = 1, "car" = 2, "motorbike" = 3)
  ),
  travel_time_min = list(header = "Q13_TravelTime_min"),
  # Several modes per person, like "1;4;8". Left as text for split_modes().
  modes = list(
    header = "Q14_Modes (combinations use \";\": 1-walk; 2-car;3-carpool;4-bus;5-ferry;6-bike;7-rail;8-metro;9-motorbike;10-shuttle;11-taxi;12-other)", # nolint: line_length_linter.
    codes = c(
      "walk" = 1,
      "car" = 2,
      "carpool" = 3,
      "bus" = 4,
      "ferry" = 5,
      "bike" = 6,
      "rail" = 7,
      "metro" = 8,
      "motorbike" = 9,
      "shuttle" = 10,
      "taxi" = 11,
      "other" = 12
    )
  ),
  intermediate_stop = list(
    header = "Q15_IntermediateStop (No-0; Children-1; OlderAdults-2; Shopping-3; Gym/Sports-4; Work-5; Other-6)", # nolint: line_length_linter.
    codes = c(
      "No" = 0,
      "Children" = 1,
      "OlderAdults" = 2,
      "Shopping" = 3,
      "Gym/Sports" = 4,
      "Work" = 5,
      "Other" = 6
    )
  ),
  transit_card = list(
    header = "Q16_TransitCard (Yes-1; No-0)",
    codes = c("Yes" = 1, "No" = 0)
  ),
  distance_km = list(header = "Q17_Distance_km"),
  fuel_type = list(
    header = "Q18_FuelType (Diesel-1; Petrol-2; LPG-3; Electric-4)",
    codes = c("Diesel" = 1, "Petrol" = 2, "LPG" = 3, "Electric" = 4)
  ),
  vehicle_type = list(
    header = "Q19_VehicleType (Citycar-1; Utilitarian-2; Estate-3; MPV-4; SUV-5; Big>3L-6; Scooter-7; Motorbike-8)", # nolint: line_length_linter.
    codes = c(
      "Citycar" = 1,
      "Utilitarian" = 2,
      "Estate" = 3,
      "MPV" = 4,
      "SUV" = 5,
      "Big>3L" = 6,
      "Scooter" = 7,
      "Motorbike" = 8
    )
  ),
  urban_cycling = list(
    header = "Q20_UrbanCycling (No-0; Yes-1; ABit-2)",
    codes = c("No" = 0, "Yes" = 1, "ABit" = 2)
  ),
  bike_parking_home = list(
    header = "Q21_BikeParkingHome (No-0; InsideFlat-1; Building/Garage-2; Sheltered-3; Unsheltered-4)", # nolint: line_length_linter.
    codes = c(
      "No" = 0,
      "InsideFlat" = 1,
      "Building/Garage" = 2,
      "Sheltered" = 3,
      "Unsheltered" = 4
    )
  ),
  # Kept as a number: -2 to 4, with 5 meaning above the 4th floor
  floor = list(header = "Q22_Floor (ground-0; basement -1/-2; >4th floor-5)"),
  willingness = list(
    header = "Q23_Willingness (Not Interested - 1; Unsure - 2; Yes_electric - 3; Yes_all bikes - 4)", # nolint: line_length_linter.
    codes = c(
      "Not Interested" = 1,
      "Unsure" = 2,
      "Yes_electric" = 3,
      "Yes_all bikes" = 4
    )
  ),
  # distance_km / travel_time_min * 60, from the sheet. IDs 643 and 846 don't
  # match it.
  speed_kmh = list(header = "Speed (km/h)")
)

## read_survey() ---------------------------------------------------------------

# The workbook with the survey and the "Emission factors" sheet
survey_path <- "./data/TS_Project_SurveyUBike_final (local).xlsx"

# Reads, labels and groups the survey. Every script starts with this.
read_survey <- function(path = survey_path) {
  read_excel(path) |>
    label_survey() |>
    add_groups()
}

## label_survey() --------------------------------------------------------------

# Short column names and labelled answers.
label_survey <- function(data) {
  # Otherwise the names would land on the wrong columns
  headers <- vapply(
    survey_key,
    \(key) key$header,
    character(1),
    USE.NAMES = FALSE
  )
  if (!identical(names(data), headers)) {
    stop("The Excel headers differ from survey_key. Update survey_key.")
  }

  names(data) <- names(survey_key)

  # modes stays as text (see split_modes())
  for (name in names(survey_key)) {
    codes <- survey_key[[name]]$codes
    if (!is.null(codes) && name != "modes") {
      data[[name]] <- factor(
        data[[name]],
        levels = codes,
        labels = names(codes)
      )
    }
  }

  data
}

## add_groups() ----------------------------------------------------------------

# Grouped columns for the decision tree and charts.
add_groups <- function(data) {
  # One commute type per person: car beats transit, transit beats walk/bike
  profiles <- split_modes(data) |>
    group_by(id) |>
    summarise(
      car = any(mode %in% c("car", "carpool", "motorbike", "taxi")),
      transit = any(mode %in% c("bus", "metro", "rail", "ferry", "shuttle")),
      active = any(mode %in% c("walk", "bike"))
    ) |>
    mutate(
      mode_profile = factor(
        case_when(
          car & transit ~ "Car + transit",
          car ~ "Car",
          transit ~ "Transit",
          active ~ "Walk or bike only",
          TRUE ~ "Other"
        ),
        levels = c(
          "Car",
          "Car + transit",
          "Transit",
          "Walk or bike only",
          "Other"
        )
      )
    ) |>
    select(id, mode_profile)

  data |>
    left_join(profiles, by = "id") |>
    mutate(
      # Gate 3 bands
      distance_group = cut(
        distance_km,
        breaks = c(-Inf, 5, 10, Inf),
        labels = c("Under 5 km", "5 to 10 km", "Over 10 km"),
        right = FALSE # 5 km goes into "5 to 10 km"
      ),
      # Under-11s often need a school run (modifier)
      young_children = if_else(
        children_under1 + children_1to5 + children_6to10 > 0,
        "Yes",
        "No"
      ),
      # Gates 2a and 3b
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
      # Gate 1: "A bit" counts as can ride
      can_ride = if_else(urban_cycling == "No", "Cannot ride", "Can ride")
    )
}

## split_modes() ---------------------------------------------------------------

# One row per person per mode ("1;4;8" -> walk, bus, metro), without repeats.
split_modes <- function(data) {
  codes <- survey_key$modes$codes

  data |>
    select(id, modes) |>
    separate_longer_delim(modes, delim = ";") |>
    mutate(
      mode = factor(as.numeric(modes), levels = codes, labels = names(codes))
    ) |>
    select(id, mode) |>
    distinct()
}
