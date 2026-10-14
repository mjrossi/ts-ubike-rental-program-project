library(dplyr)

source(test_path("..", "..", "R", "emission_factors.R"))

survey_path <- test_path(
  "..",
  "..",
  "data",
  "TS_Project_SurveyUBike_final (local).xlsx"
)
copert_small <- test_path("fixtures", "copert_small.csv")

# A one-row COPERT file
write_copert <- function(vehicle, fuel) {
  path <- tempfile(fileext = ".csv")
  write.csv(
    data.frame(
      vehicle = vehicle,
      fuel = fuel,
      fuel_g_km = 50,
      co2 = 160,
      ch4 = 0,
      n2o = 0,
      nox = 0,
      pm = 0
    ),
    path,
    row.names = FALSE
  )
  path
}

test_that("emission_factors.R defines the gas columns", {
  expect_equal(gases, c("co2", "ch4", "n2o", "co2eq", "nox", "pm"))
})

test_that("co2_equivalent() weights CH4 by 29.8 and N2O by 273", {
  expect_equal(co2_equivalent(100, 1, 1), 402.8)
  expect_equal(
    co2_equivalent(c(68, 0), c(0.006, 0), c(0.002, 1)),
    c(68.7248, 273)
  )
})

test_that("read_mode_factors() reads the sheet with Q14 labels", {
  modes <- read_mode_factors(survey_path)

  expect_named(modes, c("mode", "co2", "ch4", "n2o", "nox", "pm", "occupancy"))
  expect_setequal(
    modes$mode,
    c(
      "bus",
      "ferry",
      "rail",
      "metro",
      "shuttle",
      "carpool",
      "taxi",
      "car",
      "motorbike",
      "walk",
      "bike"
    )
  )

  bus <- filter(modes, mode == "bus")
  expect_equal(bus$co2, 68)
  expect_equal(bus$nox, 0.55)
  expect_equal(bus$occupancy, 16)

  # Car rows are left for COPERT
  car <- filter(modes, mode == "car")
  expect_true(is.na(car$co2))
  expect_equal(car$occupancy, 1.6)
})

test_that("copert_factors() adds upstream CO2 and divides by occupancy", {
  occupancy <- tibble(
    mode = c("car", "carpool", "taxi", "motorbike"),
    occupancy = c(1.6, 2.5, 1.4, 1.1)
  )
  vehicles <- copert_factors(copert_small, occupancy)

  expect_named(vehicles, c("mode", "fuel", "co2", "ch4", "n2o", "nox", "pm"))
  # Two car fuels for each of car, carpool and taxi, plus two motorbike fuels
  expect_equal(nrow(vehicles), 8)

  co2 <- function(m, f) filter(vehicles, mode == m, fuel == f)$co2
  expect_equal(co2("car", "Diesel"), 200.7295 / 1.6)
  expect_equal(co2("carpool", "Diesel"), 200.7295 / 2.5)
  expect_equal(co2("taxi", "Petrol"), 210.392 / 1.4)
  expect_equal(co2("motorbike", "Petrol"), 112.032 / 1.1)
  # Electric is all grid emissions: 0.05 kWh/km * 119 g/kWh
  expect_equal(co2("motorbike", "Electric"), 5.95 / 1.1)

  # Other gases only divide by occupancy
  expect_equal(filter(vehicles, mode == "car", fuel == "Diesel")$nox, 0.5 / 1.6)
})

test_that("copert_factors() stops on an unknown vehicle or fuel", {
  occupancy <- tibble(mode = "car", occupancy = 1.6)
  expect_error(copert_factors(write_copert("Car", "Diesel"), occupancy), "Car")
  expect_error(
    copert_factors(write_copert("car", "Hydrogen"), occupancy),
    "Hydrogen"
  )
})

test_that("copert_factors() stops when a vehicle is missing", {
  occupancy <- tibble(mode = "car", occupancy = 1.6)
  expect_error(
    copert_factors(write_copert("car", "Diesel"), occupancy),
    "motorbike"
  )
})

test_that("combine_factors() builds the full table", {
  modes <- read_mode_factors(survey_path)
  vehicles <- copert_factors(copert_small, select(modes, mode, occupancy))
  factors <- combine_factors(modes, vehicles)

  expect_named(factors, c("mode", "fuel", gases))
  # 7 sheet modes + 2 fuels x (car, carpool, taxi) + 2 motorbike fuels
  expect_equal(nrow(factors), 15)
  expect_false(anyNA(select(factors, all_of(gases))))

  # COPERT replaces the sheet's placeholder motorbike row
  expect_setequal(
    filter(factors, mode == "motorbike")$fuel,
    c("Petrol", "Electric")
  )

  # Sheet modes have no fuel, and co2eq is recomputed
  bus <- filter(factors, mode == "bus")
  expect_true(is.na(bus$fuel))
  expect_equal(bus$co2eq, 68.7248)
})

test_that("combine_factors() stops when a mode has no factors", {
  modes <- read_mode_factors(survey_path)
  motorbike_only <- tibble(
    mode = "motorbike",
    fuel = "Petrol",
    co2 = 100,
    ch4 = 0.1,
    n2o = 0.002,
    nox = 0.1,
    pm = 0.01
  )
  expect_error(
    combine_factors(modes, motorbike_only),
    "carpool, taxi, car"
  )
})

test_that("combine_factors() stops on duplicate mode and fuel rows", {
  modes <- read_mode_factors(survey_path)
  vehicles <- copert_factors(copert_small, select(modes, mode, occupancy))
  expect_error(
    combine_factors(modes, bind_rows(vehicles, vehicles[1, ])),
    "Duplicate"
  )
})
