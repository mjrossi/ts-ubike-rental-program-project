# Every gas gets the same value, so co2 and co2eq can be checked by hand
factors <- tibble(
  mode = c("walk", "bus", "car", "car", "motorbike"),
  fuel = c(NA, NA, "Diesel", "Petrol", "Petrol")
)
for (gas in gases) {
  factors[[gas]] <- c(0, 50, 100, 200, 80)
}

vehicles <- names(survey_key$private_vehicle$codes)
fuels <- names(survey_key$fuel_type$codes)

# Two Diesel and one Petrol car driver, so the fuel mix is 2/3 Diesel
people <- tibble(
  id = 1:6,
  modes = c("2", "2", "2", "2", "9", "1;4"),
  private_vehicle = factor(
    c("car", "car", "car", "no", "motorbike", "no"),
    levels = vehicles
  ),
  fuel_type = factor(
    c("Diesel", "Diesel", "Petrol", NA, "Diesel", NA),
    levels = fuels
  ),
  distance_km = c(10, 10, 10, 3, 10, 2),
  p_shift = 0.5
)

test_that("add_main_mode() picks the mode with the highest co2eq", {
  out <- add_main_mode(people, factors)
  expect_equal(
    out$main_mode,
    c("car", "car", "car", "car", "motorbike", "bus")
  )
})

test_that("add_current_emissions() uses the fuel row or the fuel mix", {
  out <- people |>
    add_main_mode(factors) |>
    add_current_emissions(factors)

  # Diesel and Petrol drivers get their own fuel's row
  expect_equal(out$current_co2[1:3], c(1000, 1000, 2000))
  # A car user without a fuel gets 100 * 2/3 + 200 * 1/3 per km
  expect_equal(out$current_co2[4], 400)
  # No Diesel motorbike row, so the rider gets the motorbike average (Petrol)
  expect_equal(out$current_co2[5], 800)
  # walk;bus counts as bus
  expect_equal(out$current_co2[6], 100)
  expect_equal(out$current_co2eq, out$current_co2)
  expect_false(any(c("co2", "co2eq") %in% names(out)))
})

test_that("add_current_emissions() multiplies by trips_per_day", {
  out <- people |>
    add_main_mode(factors) |>
    add_current_emissions(factors, trips_per_day = 2)
  expect_equal(out$commute_km, people$distance_km * 2)
  expect_equal(out$current_co2[1], 2000)
})

test_that("add_current_emissions() stops when a main_mode has no factor", {
  other <- people[6, ] |> mutate(id = 7L, modes = "12")
  expect_error(
    bind_rows(people, other) |>
      add_main_mode(factors) |>
      add_current_emissions(factors),
    "No emission factor for main_mode: other"
  )
})

test_that("add_savings() scales km and emissions by p_shift", {
  out <- people |>
    add_main_mode(factors) |>
    add_current_emissions(factors) |>
    add_savings()
  expect_equal(out$km_shifted, out$commute_km * 0.5)
  expect_equal(out$saved_co2, out$current_co2 * 0.5)
  expect_equal(out$saved_pm, out$current_pm * 0.5)
})

test_that("add_savings() stops when p_shift is missing", {
  out <- people |>
    select(-p_shift) |>
    add_main_mode(factors) |>
    add_current_emissions(factors)
  expect_error(add_savings(out), "p_shift is missing")
})
