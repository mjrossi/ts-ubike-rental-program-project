# Emission factors -------------------------------------------------------------
# Well-to-wheel factors in g/p.km (brief, sections 4 and 5), as one table:
#   mode, fuel, co2, ch4, n2o, co2eq, nox, pm
# mode uses the Q14 labels. fuel uses the Q18 labels for the COPERT modes (car,
# carpool, taxi, motorbike) and is NA for the rest.
#
#   modes <- read_mode_factors(path)
#   factors <- combine_factors(
#     modes,
#     copert_factors(copert_path, select(modes, mode, occupancy))
#   )

library(dplyr)
library(readr)
library(readxl)

# Gas columns, in table order
gases <- c("co2", "ch4", "n2o", "co2eq", "nox", "pm")

## read_mode_factors() ---------------------------------------------------------

# Sheet row names -> Q14 labels
sheet_modes <- c(
  "Bus (urban, diesel)" = "bus",
  "Ferry (Transtejo/Soflusa)" = "ferry",
  "Rail (suburban, electric)" = "rail",
  "Metro (Lisboa, electric)" = "metro",
  "IST Shuttle (minibus diesel)" = "shuttle",
  "Carpool (car, 2.5 occ.)" = "carpool",
  "Taxi (car, 1.4 occ.)" = "taxi",
  "Car (1.6 occ.)" = "car",
  "Motorbike / Scooter" = "motorbike",
  "Walking" = "walk",
  "Cycling (target mode)" = "bike"
)

# The workbook's "Emission factors" sheet, already in g/p.km. The car,
# carpool and taxi rows are blank; COPERT replaces them and the motorbike row.
# occupancy is kept for copert_factors().
read_mode_factors <- function(path) {
  sheet <- read_excel(path, sheet = "Emission factors", skip = 2)

  unknown <- setdiff(sheet$Mode, names(sheet_modes))
  if (length(unknown) > 0) {
    stop(
      "Unknown rows in the Emission factors sheet: ",
      toString(unknown),
      call. = FALSE
    )
  }

  sheet |>
    transmute(
      mode = unname(sheet_modes[Mode]),
      co2 = CO2_g_pkm,
      ch4 = CH4_g_pkm,
      n2o = N2O_g_pkm,
      nox = NOx_g_pkm,
      pm = PM_g_pkm,
      occupancy = Occupancy
    )
}

## copert_factors() ------------------------------------------------------------

# Upstream (well-to-tank) emissions: JRC (2021) via L4 slide 69, and lower
# heating values (JEC). LPG isn't on the slide, so it borrows petrol's.
fuel_upstream <- tribble(
  ~fuel    , ~mj_per_kg , ~wtt_g_per_mj ,
  "Diesel" , 43.1       , 18.9          ,
  "Petrol" , 43.2       , 17.0          ,
  "LPG"    , 46.0       , 17.0
)

# Portugal's grid in 2023, in g CO2eq per kWh generated (EEA, greenhouse gas
# emission intensity of electricity generation). Leaves out grid losses and
# the upstream emissions of the fuels burnt.
# https://www.eea.europa.eu/en/analysis/indicators/greenhouse-gas-emission-intensity-of-1-1751032678/greenhouse-gas-emission-intensity-of-electricity-generation-country-level # nolint: line_length_linter.
grid_g_per_kwh <- 119

# Which survey modes each COPERT vehicle covers
vehicle_modes <- tribble(
  ~vehicle    , ~mode       ,
  "car"       , "car"       ,
  "car"       , "carpool"   ,
  "car"       , "taxi"      ,
  "motorbike" , "motorbike"
)

# Car and motorbike rows from a COPERT export: one row per vehicle and fuel,
# with fuel_g_km (kwh_km for Electric), co2, ch4, n2o, nox and pm in g/vkm.
# Adds upstream emissions, then divides by each mode's occupancy to get g/p.km.
# Upstream is only known as CO2eq, so it's added to co2, as the workbook does
# for electric rail and metro.
copert_factors <- function(path, occupancy) {
  copert <- read_csv(path, show_col_types = FALSE)

  unknown <- c(
    setdiff(copert$vehicle, vehicle_modes$vehicle),
    setdiff(copert$fuel, c(fuel_upstream$fuel, "Electric"))
  )
  if (length(unknown) > 0) {
    stop(
      "Unknown vehicles or fuels in the COPERT file: ",
      toString(unknown),
      call. = FALSE
    )
  }

  no_rows <- setdiff(vehicle_modes$vehicle, copert$vehicle)
  if (length(no_rows) > 0) {
    stop("No rows in the COPERT file for: ", toString(no_rows), call. = FALSE)
  }

  copert |>
    left_join(fuel_upstream, by = "fuel") |>
    mutate(
      upstream = if_else(
        fuel == "Electric",
        kwh_km * grid_g_per_kwh,
        fuel_g_km / 1000 * mj_per_kg * wtt_g_per_mj
      ),
      co2 = co2 + upstream
    ) |>
    inner_join(vehicle_modes, by = "vehicle", relationship = "many-to-many") |>
    left_join(occupancy, by = "mode") |>
    mutate(across(c(co2, ch4, n2o, nox, pm), function(x) x / occupancy)) |>
    select(mode, fuel, co2, ch4, n2o, nox, pm)
}

## co2_equivalent() ------------------------------------------------------------

# 100-year GWPs from IPCC AR6 WG1, chapter 7, Table 7.15 (Forster et al.,
# 2021, doi:10.1017/9781009157896.009). Tailpipe CH4 comes from fossil fuel,
# so it uses CH4-fossil (29.8) rather than CH4-non fossil (27.0).
# https://www.ipcc.ch/report/ar6/wg1/chapter/chapter-7/
gwp <- c(ch4 = 29.8, n2o = 273)

co2_equivalent <- function(co2, ch4, n2o) {
  co2 + gwp[["ch4"]] * ch4 + gwp[["n2o"]] * n2o
}

## combine_factors() -----------------------------------------------------------

# Sheet rows plus COPERT rows (which replace the sheet's for the same modes),
# with co2eq computed for every row.
combine_factors <- function(mode_factors, vehicle_factors) {
  factors <- mode_factors |>
    filter(!mode %in% vehicle_factors$mode) |>
    select(-occupancy) |>
    mutate(fuel = NA_character_) |>
    bind_rows(vehicle_factors) |>
    mutate(co2eq = co2_equivalent(co2, ch4, n2o)) |>
    select(mode, fuel, all_of(gases))

  no_factors <- factors |>
    filter(if_any(all_of(gases), is.na)) |>
    pull(mode) |>
    unique()
  if (length(no_factors) > 0) {
    stop("No factors for: ", toString(no_factors), call. = FALSE)
  }

  dupes <- factors |>
    count(mode, fuel) |>
    filter(n > 1)
  if (nrow(dupes) > 0) {
    stop(
      "Duplicate rows for: ",
      toString(paste(dupes$mode, dupes$fuel)),
      call. = FALSE
    )
  }

  factors
}
