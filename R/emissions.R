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
    summarise(co2eq = max(co2eq), .by = mode)

  main_modes <- split_modes(data) |>
    mutate(mode = as.character(mode)) |>
    left_join(mode_co2eq, by = "mode") |>
    slice_max(co2eq, n = 1, with_ties = FALSE, by = id) |>
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

  # One row per mode, for people without a fuel
  mode_average <- factors |>
    left_join(fuel_shares, by = "fuel") |>
    mutate(share = if_else(is.na(fuel), 1, coalesce(share, 0))) |>
    summarise(across(all_of(gases), \(x) weighted.mean(x, share)), .by = mode)

  by_fuel <- data |>
    select(id, mode = main_mode, fuel = fuel_type) |>
    mutate(fuel = as.character(fuel)) |>
    inner_join(filter(factors, !is.na(fuel)), by = c("mode", "fuel")) |>
    select(id, all_of(gases))

  # Mode average first, then the fuel factor where there is one
  data <- data |>
    left_join(mode_average, by = c(main_mode = "mode")) |>
    rows_update(by_fuel, by = "id")

  missing <- unique(data$main_mode[is.na(data$co2eq)])
  if (length(missing) > 0) {
    stop("No emission factor for main_mode: ", toString(missing))
  }

  data |>
    mutate(
      commute_km = distance_km * trips_per_day,
      across(all_of(gases), \(x) x * commute_km, .names = "current_{.col}")
    ) |>
    select(-all_of(gases))
}

## add_savings() ---------------------------------------------------------------

# Adds km_shifted and saved_<gas>: commute_km and current_<gas> times p_shift.
add_savings <- function(data) {
  if (!"p_shift" %in% names(data)) {
    stop("p_shift is missing: run the decision tree first")
  }
  data |>
    mutate(
      km_shifted = commute_km * p_shift,
      across(
        all_of(paste0("current_", gases)),
        \(x) x * p_shift,
        .names = "{sub('current_', 'saved_', .col)}"
      )
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
