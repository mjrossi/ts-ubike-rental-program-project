# Emissions --------------------------------------------------------------------
# Brief, sections 4 and 5:
#   E_current  = EF_mode * distance
#   E_saved    = E_current * p_shift
#   km_shifted = distance * p_shift
#
#   survey |> add_main_mode(factors) |> add_current_emissions(factors) |>
#     add_savings()
#
# factors and gases come from emission_factors.R, p_shift from decision_tree.R.

library(dplyr)
library(forcats)

## add_main_mode() -------------------------------------------------------------

# Adds main_mode: the person's Q14 mode with the highest co2eq factor. Car and
# motorbike owners (Q12) only list their vehicle in Q14.
add_main_mode <- function(data, factors) {
  # Cars have a row per fuel, so take the highest
  mode_co2eq <- factors |>
    group_by(mode) |>
    summarise(co2eq = max(co2eq))

  main_modes <- split_modes(data) |>
    mutate(mode = as.character(mode)) |>
    left_join(mode_co2eq, by = "mode") |>
    group_by(id) |>
    slice_max(co2eq, n = 1, with_ties = FALSE) |>
    ungroup() |>
    select(id, main_mode = mode)

  data |>
    left_join(main_modes, by = "id")
}

## add_current_emissions() -----------------------------------------------------

# Adds commute_km (distance_km * trips_per_day) and current_<gas> in grams
# (factor * commute_km). Use trips_per_day = 2 for a round trip.
#
# Car, carpool, taxi and motorbike factors depend on fuel. People with a Q18
# fuel get that fuel's row; everyone else gets an average weighted by the car
# drivers' fuel mix.
add_current_emissions <- function(data, factors, trips_per_day = 1) {
  fuel_shares <- data |>
    filter(fct_match(private_vehicle, "car"), !is.na(fuel_type)) |>
    count(fuel = as.character(fuel_type)) |>
    mutate(share = n / sum(n))

  # One row per mode, for people without a fuel. Modes without fuels (bus,
  # walk, ...) keep their only row. A fuel no car owner uses (Electric) gets a
  # weight of 0.
  mode_average <- factors |>
    left_join(fuel_shares, by = "fuel") |>
    mutate(share = if_else(is.na(fuel), 1, coalesce(share, 0))) |>
    group_by(mode) |>
    summarise(across(all_of(gases), function(x) weighted.mean(x, share)))

  by_fuel <- data |>
    select(id, mode = main_mode, fuel = fuel_type) |>
    mutate(fuel = as.character(fuel)) |>
    inner_join(filter(factors, !is.na(fuel)), by = c("mode", "fuel")) |>
    select(id, all_of(gases))

  # Mode average first, then rows_update() swaps in the fuel factor where
  # there is one
  data <- data |>
    left_join(mode_average, by = c(main_mode = "mode")) |>
    rows_update(by_fuel, by = "id")

  no_factor <- unique(data$main_mode[is.na(data$co2eq)])
  if (length(no_factor) > 0) {
    stop(
      "No emission factor for main_mode: ",
      toString(no_factor),
      call. = FALSE
    )
  }

  data |>
    mutate(
      commute_km = distance_km * trips_per_day,
      current_co2 = co2 * commute_km,
      current_ch4 = ch4 * commute_km,
      current_n2o = n2o * commute_km,
      current_co2eq = co2eq * commute_km,
      current_nox = nox * commute_km,
      current_pm = pm * commute_km
    ) |>
    select(-all_of(gases))
}

## add_savings() ---------------------------------------------------------------

# Adds km_shifted and saved_<gas>: commute_km and current_<gas> times p_shift.
add_savings <- function(data) {
  if (!"p_shift" %in% names(data)) {
    stop("p_shift is missing: run the decision tree first", call. = FALSE)
  }
  data |>
    mutate(
      km_shifted = commute_km * p_shift,
      saved_co2 = current_co2 * p_shift,
      saved_ch4 = current_ch4 * p_shift,
      saved_n2o = current_n2o * p_shift,
      saved_co2eq = current_co2eq * p_shift,
      saved_nox = current_nox * p_shift,
      saved_pm = current_pm * p_shift
    )
}

## total_savings() -------------------------------------------------------------

# Sums the km and emission columns by group, with a count of people:
#   total_savings(survey, role)
#   total_savings(survey, role, main_mode)
total_savings <- function(data, ...) {
  data |>
    group_by(...) |>
    summarise(
      people = n(),
      across(
        c(
          commute_km,
          km_shifted,
          starts_with("current_"),
          starts_with("saved_")
        ),
        sum
      ),
      .groups = "drop"
    )
}
