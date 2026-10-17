# Labelled but not yet grouped, so add_groups() can run on edited answers
labelled <- read_excel(workbook_path) |> label_survey()

# The first n people, with columns replaced
grouped <- function(n, ...) {
  labelled |>
    slice_head(n = n) |>
    mutate(...) |>
    add_groups()
}

answers <- function(column, values) {
  factor(values, levels = levels(labelled[[column]]))
}

test_that("add_groups() bands distance at 5 and 15 km (Figure 1: 10 km)", {
  out <- grouped(6, distance_km = c(4.99, 5, 10, 10.01, 14.99, 15))
  expect_equal(
    out$distance_band,
    c(
      "Under 5 km",
      "5 to 15 km",
      "5 to 15 km",
      "5 to 15 km",
      "5 to 15 km",
      "15 km or more"
    )
  )
  expect_equal(
    out$distance_band_brief,
    c(
      "Under 5 km",
      "5 to 10 km",
      "5 to 10 km",
      "Over 10 km",
      "Over 10 km",
      "Over 10 km"
    )
  )
})

test_that("add_groups() sorts trip chains as tree_v1's Gate 3 does", {
  no_children <- 0
  out <- grouped(
    6,
    intermediate_stop = answers(
      "intermediate_stop",
      c("Children", "Children", "Children", "Shopping", "Shopping", "No")
    ),
    children_under1 = no_children,
    children_1to5 = c(0, 2, 0, 0, 0, 0),
    children_6to10 = no_children,
    children_11to15 = c(0, 0, 1, 0, 0, 0),
    children_over15 = no_children,
    private_vehicle = answers(
      "private_vehicle",
      c("no", "no", "no", "car", "no", "car")
    )
  )
  expect_equal(
    out$trip_chain,
    c(
      # Escorts children but lists none
      "1 child under 11",
      "2+ children under 11",
      "Only children 11+",
      "Shopping by car or motorbike",
      # Shopping on foot or by transit
      "Everything else",
      "Everything else"
    )
  )
})

test_that("add_groups() counts a blank Q20 as No", {
  out <- grouped(1, urban_cycling = replace(urban_cycling, 1, NA))
  expect_equal(out$cycling, "No")
})

test_that("add_groups() keeps other blank answers blank", {
  out <- grouped(
    1,
    across(
      c(distance_km, bike_parking_home, age, intermediate_stop),
      \(x) replace(x, 1, NA)
    )
  )
  gates <- c(
    "distance_band",
    "distance_band_brief",
    "parking_home",
    "age_band",
    "escort_stop",
    "trip_chain",
    "confident_with_parking"
  )
  for (column in gates) {
    expect_true(is.na(out[[column]]), label = column)
  }

  # A blank number of children, for someone escorting children
  out <- grouped(
    1,
    intermediate_stop = answers("intermediate_stop", "Children"),
    children_6to10 = NA
  )
  expect_true(is.na(out$trip_chain))
})

test_that("a blank answer stops the model", {
  out <- grouped(3, distance_km = c(1, NA, 2))
  expect_error(score_shift(out, model_v1), "distance_band = NA")
})
