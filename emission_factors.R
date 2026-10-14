# Emission factors -------------------------------------------------------------
# Grams emitted per passenger-km (g/p.km) for each commute mode, over the energy
# lifecycle (well-to-wheel). Brief, section 4 and the notes in section 5.
#
# Every function here works towards one table, with a row per mode (and per
# fuel for cars) and a column per gas:
#   mode, fuel, co2, ch4, n2o, co2eq, nox, pm
# mode uses the Q14 labels from survey_codebook.R ("car", "bus", ...). fuel is
# NA except for cars, where it uses the Q18 labels ("Diesel", "Petrol", ...).

library(dplyr)

## read_mode_factors() ---------------------------------------------------------

# Bus, rail, metro, ferry and the IST shuttle, from the course Excel file. Its
# factors are per vehicle-km, so each is divided by the mode's average
# occupancy (also in that file) to get g/p.km.
read_mode_factors <- function(path) {
  stop("read_mode_factors() is not written yet")
}

## copert_factors() ------------------------------------------------------------

# Cars (one row per Q18 fuel type) and motorbikes, from a COPERT 5.3 run.
# COPERT gives g/vehicle-km at the exhaust, so this adds the fuel's upstream
# (well-to-tank) share and divides by occupancy. Carpool and taxi reuse the
# car rows with their own occupancy.
copert_factors <- function(path, occupancy) {
  stop("copert_factors() is not written yet")
}

## co2_equivalent() ------------------------------------------------------------

# CO2eq from the three greenhouse gases, weighting CH4 and N2O by their 100-year
# global warming potential. Still to decide: which IPCC report's values.
co2_equivalent <- function(co2, ch4, n2o) {
  stop("co2_equivalent() is not written yet")
}

## combine_factors() -----------------------------------------------------------

# Stacks the two tables above into the one described at the top, fills in
# co2eq, and adds walk and bike with zero for every gas.
combine_factors <- function(mode_factors, vehicle_factors) {
  stop("combine_factors() is not written yet")
}
