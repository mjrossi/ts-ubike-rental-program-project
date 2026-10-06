# Codebook for the UBike survey spreadsheet (TS_Project_SurveyUBike_final),
# "Raw data" sheet: one row per respondent, one column per question.
#
# In the sheet, answers are numeric codes and each column header lists its
# codes, e.g. "Q2_Role (Student-1; Faculty/Researcher-2; Staff-3)". This file
# gives every column a short name (role) and turns coded answers into factors
# with readable labels ("Student"), so you can write role == "Student".
#
# Usage (needs R 4.1 or later): source() this file, read the sheet with
# readxl::read_excel(), and pass the result to label_survey(), which returns
# the relabelled data.
#
# label_survey() stops with "Excel headers differ from survey_key" if the
# sheet's columns aren't exactly the ones below, e.g. after someone renames,
# adds or reorders a column. Update survey_key to match the new sheet.
#
# survey_key has one entry per column, in sheet order, named by its short
# name, with
# - header: the column's exact name in the Excel file
# - codes:  answer label = code, copied from that header
# - multi:  TRUE when a cell can hold several codes joined by ";" (Q14 only;
#           it stays as text, e.g. "1;4;8")
# Columns without codes (ID, age, counts, minutes, km, municipality) keep the
# values read from the sheet.

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
    ),
    multi = TRUE
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
  # Kept as a number, since floors are ordered: 0 is ground, -1 and -2 are
  # basement levels, 1-4 are floors and 5 means above the 4th floor.
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
  # Precomputed in the sheet as distance_km / travel_time_min * 60. IDs 643
  # and 846 don't match that formula.
  speed_kmh = list(header = "Speed (km/h)")
)

# Renames the survey columns to the short names above and turns each
# single-answer coded column into a factor with the header's labels. Q14
# (modes) stays as text, since one cell can hold several codes.
label_survey <- function(data, key = survey_key) {
  headers <- vapply(key, \(entry) entry$header, "", USE.NAMES = FALSE)
  stopifnot(
    "Excel headers differ from survey_key" = identical(names(data), headers)
  )
  names(data) <- names(key)

  for (name in names(key)) {
    codes <- key[[name]]$codes
    if (!is.null(codes) && !isTRUE(key[[name]]$multi)) {
      data[[name]] <- factor(data[[name]], codes, names(codes))
    }
  }
  data
}
