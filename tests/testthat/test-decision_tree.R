# Two gates: colour, then (for red) size. Blue and green share a leaf.
graph <- list(
  start = "colour",
  gates = tribble(
    ~node    , ~column  , ~label    , ~reason ,
    "colour" , "colour" , "Colour?" , ""      ,
    "size"   , "size"   , "Size?"   , ""
  ),
  branches = tribble(
    ~node    , ~value  , ~to         ,
    "colour" , "red"   , "size"      ,
    "colour" , "blue"  , "cool"      ,
    "colour" , "green" , "cool"      ,
    "size"   , "big"   , "big red"   ,
    "size"   , "small" , "small red"
  ),
  leaves = tribble(
    ~leaf       , ~tier       , ~reason ,
    "cool"      , "Low"       , ""      ,
    "big red"   , "Very high" , ""      ,
    "small red" , "Moderate"  , ""
  )
)

# The adjustment reads `chain`, the modifiers read `m1` and `m2`
chain <- list(
  column = "chain",
  effects = tribble(
    ~value      , ~steps , ~max_tier , ~reason ,
    "none"      ,      0 , NA        , ""      ,
    "step"      ,     -1 , NA        , ""      ,
    "cap"       ,      0 , "Low"     , ""      ,
    "step, cap" ,     -1 , "Low"     , ""
  )
)

nudges <- tribble(
  ~modifier , ~column , ~value , ~steps , ~reason ,
  "M1"      , "m1"    , "down" ,     -1 , ""      ,
  "M2"      , "m2"    , "down" ,     -1 , ""      ,
  "Up"      , "m1"    , "up"   ,      1 , ""
)

people <- tibble(
  id = 1:4,
  colour = c("red", "red", "blue", "green"),
  size = c("big", "small", NA, NA)
)

## walk_tree() and check_tree() ------------------------------------------------

test_that("walk_tree() routes each person to a leaf", {
  route <- walk_tree(people, graph)
  expect_equal(route$leaf, c("big red", "small red", "cool", "cool"))
  expect_equal(
    route$path,
    c(
      "colour > size > big red",
      "colour > size > small red",
      "colour > cool",
      "colour > cool"
    )
  )
})

test_that("walk_tree() stops on an answer with no branch", {
  purple <- mutate(people, colour = replace(colour, 2, "purple"))
  expect_error(walk_tree(purple, graph), "colour = purple \\(ids 2\\)")
  no_size <- mutate(people, size = replace(size, 1, NA))
  expect_error(walk_tree(no_size, graph), "size = NA \\(ids 1\\)")
  # Row numbers stand in for ids
  expect_error(walk_tree(select(purple, -id), graph), "\\(ids 2\\)")
})

test_that("walk_tree() stops when a gate column is missing", {
  expect_error(walk_tree(select(people, -size), graph), "no column size")
})

test_that("check_tree() names dangling, repeated and unreachable nodes", {
  broken <- graph
  broken$branches$to[5] <- "tiny red"
  expect_error(check_tree(broken), "Branches to nowhere: tiny red")
  expect_error(check_tree(broken), "reached from start: small red")

  broken <- graph
  broken$branches <- bind_rows(graph$branches, graph$branches[1, ])
  expect_error(check_tree(broken), "Repeated branches: colour red")

  broken <- graph
  broken$leaves$tier[1] <- "Medium"
  expect_error(check_tree(broken), "tier not in tier_levels: Medium")

  broken <- graph
  broken$start <- c("colour", "size")
  expect_error(check_tree(broken), "More than one start: colour, size")
})

test_that("check_tree() finds loops", {
  loop <- graph
  loop$branches$to[4] <- "colour"
  expect_error(check_tree(loop), "Gates in a loop: colour, size")
})

test_that("tree_table() checks the tree first", {
  repeated <- graph
  repeated$gates <- bind_rows(graph$gates, graph$gates[1, ])
  expect_error(tree_table(repeated), "Repeated gates: colour")
})

## adjust_tier() ---------------------------------------------------------------

# One person, Very high unless base says otherwise
adjusted <- function(chain_value, m1 = "No", m2 = "No", base = "Very high") {
  tibble(
    id = 1,
    chain = chain_value,
    m1 = m1,
    m2 = m2,
    base_tier = factor(base, levels = tier_levels)
  ) |>
    adjust_tier(chain, nudges)
}

tier_of <- function(...) as.character(adjusted(...)$tier)

test_that("adjust_tier() applies steps, then modifiers, then caps", {
  expect_equal(tier_of("none"), "Very high")
  expect_equal(tier_of("step"), "High")
  # Gate 3's step doesn't count toward the modifiers' limit
  expect_equal(tier_of("step", m1 = "down"), "Moderate")
  # The cap comes last
  expect_equal(tier_of("cap", m1 = "down"), "Low")
  expect_equal(tier_of("step, cap"), "Low")
})

test_that("adjust_tier() limits the modifiers to one step", {
  out <- adjusted("none", m1 = "down", m2 = "down")
  expect_equal(as.character(out$tier), "High")
  expect_equal(out$modifiers, "M1, M2")
  # Up and down cancel out
  expect_equal(tier_of("none", "up", "down"), "Very high")
  # Unless the model allows more
  two <- tibble(
    base_tier = "Very high",
    chain = "none",
    m1 = "down",
    m2 = "down"
  ) |>
    adjust_tier(chain, nudges, max_modifier_steps = 2)
  expect_equal(as.character(two$tier), "Moderate")
  # Or none
  none <- adjust_tier(two, chain, nudges, max_modifier_steps = 0)
  expect_equal(as.character(none$tier), "Very high")
})

test_that("max_modifier_steps must be one whole number, 0 or more", {
  person <- tibble(base_tier = "Very high", m1 = "No", m2 = "No")
  for (bad in list(-1, 0.5, NA, c(1, 2), "1")) {
    expect_error(
      adjust_tier(person, modifiers = nudges, max_modifier_steps = bad),
      "max_modifier_steps must be one whole number, 0 or more"
    )
  }
  expect_error(
    shift_model(graph, matrix = shift_probabilities, max_modifier_steps = -1),
    "max_modifier_steps must be"
  )
})

test_that("adjust_tier() stays within Very low to Very high at each step", {
  expect_equal(tier_of("step", m1 = "down", base = "Low"), "Very low")
  expect_equal(tier_of("none", m1 = "up"), "Very high")
  # The step can't push below Very low and swallow a later +1
  expect_equal(tier_of("step", m1 = "up", base = "Very low"), "Low")
})

test_that("adjust_tier() reads base_tier by label", {
  out <- tibble(base_tier = factor(c("Very high", "Very low"))) |>
    adjust_tier()
  expect_equal(as.character(out$tier), c("Very high", "Very low"))
  out <- tibble(base_tier = c("Low", "High")) |> adjust_tier()
  expect_equal(as.character(out$tier), c("Low", "High"))
  expect_error(
    tibble(id = 7, base_tier = NA) |> adjust_tier(),
    "base_tier not in tier_levels: NA \\(ids 7\\)"
  )
})

test_that("adjust_tier() stops on a blank answer", {
  blank_chain <- tibble(id = 3, chain = NA, base_tier = "Very high")
  expect_error(adjust_tier(blank_chain, chain), "No answer for chain")
  blank_m2 <- tibble(id = 5, m1 = "No", m2 = NA, base_tier = "Very high")
  expect_error(
    adjust_tier(blank_m2, modifiers = nudges),
    "No answer for m2, read by M2 \\(ids 5\\)"
  )
})

test_that("adjust_tier() stops on an unknown value or a bad table", {
  expect_error(adjusted("other"), "No adjustment for chain = other")

  bad <- chain
  bad$effects$max_tier[3] <- "Medium"
  expect_error(check_adjustment(bad), "max_tier not in tier_levels: Medium")
  bad <- chain
  bad$effects$value[2] <- "none"
  expect_error(check_adjustment(bad), "Repeated values: none")
  bad <- chain
  bad$effects$steps[2] <- 0.5
  expect_error(check_adjustment(bad), "aren't whole numbers: 0.5")

  expect_error(
    check_modifiers(bind_rows(nudges, nudges[1, ])),
    "Repeated modifiers: M1"
  )
  expect_error(check_modifiers(select(nudges, -steps)), "no column steps")
  expect_error(
    check_modifiers(mutate(nudges, steps = c(-1, 0, 1))),
    "Steps of 0: M2"
  )
})

test_that("adjust_tier() works without adjustments or modifiers", {
  out <- tibble(id = 1, base_tier = factor("Low", levels = tier_levels)) |>
    adjust_tier()
  expect_equal(as.character(out$tier), "Low")
  expect_equal(out$modifiers, "")
})

test_that("pick_modifiers() picks by name, in order", {
  picked <- pick_modifiers(nudges, c("Up", "M1"))
  expect_equal(picked$modifier, c("Up", "M1"))
  expect_error(pick_modifiers(nudges, "M3"), "No modifier called M3")
})

## The probability matrix ------------------------------------------------------

test_that("shift_matrix() multiplies tier and willingness", {
  expect_equal(dim(shift_probabilities), c(5, 4))
  expect_equal(shift_probabilities["Very high", "Unsure"], 0.30)
  expect_equal(shift_probabilities["Very low", "Not Interested"], 0.0025)
  # Names in any order
  expect_equal(
    shift_matrix(rev(tier_probabilities), rev(willingness_weights)),
    shift_probabilities
  )
  expect_error(
    shift_matrix(tier_probabilities[-1], willingness_weights),
    "tier must be named"
  )
})

test_that("check_matrix() stops on bad cells and warns on falls", {
  m <- shift_probabilities
  m["Very high", "Unsure"] <- 1.2
  expect_error(check_matrix(m), "between 0 and 1")
  m["Very high", "Unsure"] <- NA
  expect_error(check_matrix(m), "no blanks")
  expect_error(check_matrix(m[-1, ]), "matrix rows must be named")

  m <- shift_probabilities
  m["Low", "Unsure"] <- 0.01
  expect_warning(check_matrix(m), "falls as the tier rises")
  m <- shift_probabilities
  m["Very high", "Yes_all bikes"] <- 0.5
  expect_warning(check_matrix(m), "as willingness rises")
})

test_that("add_shift_probability() reads the matrix cell", {
  people <- tibble(
    id = 1:3,
    tier = factor(
      c("Very high", "Very low", "Very high"),
      levels = tier_levels
    ),
    willingness = factor(
      c("Yes_all bikes", "Not Interested", "Unsure"),
      levels = willingness_levels
    )
  )
  out <- add_shift_probability(people, shift_probabilities)
  expect_equal(out$p_shift, c(1, 0.0025, 0.3))

  # A cell set by hand
  m <- shift_probabilities
  m["Very high", "Unsure"] <- 0.35
  expect_equal(add_shift_probability(people, m)$p_shift[3], 0.35)

  # Without Q23, rather than reading the wrong cells
  expect_error(
    add_shift_probability(select(people, -willingness), shift_probabilities),
    "no column willingness"
  )

  expect_error(
    people |>
      mutate(willingness = c("Maybe", NA, "Unsure")) |>
      add_shift_probability(shift_probabilities),
    "Very high / Maybe, Very low / NA \\(ids 1, 2\\)"
  )
})

## The models on the survey ----------------------------------------------------

survey <- read_survey(workbook_path)
models <- list(v1 = model_v1, v2 = model_v2, brief = model_brief)
scored <- lapply(models, \(model) score_shift(survey, model))

# People per value of column, named by value
counts <- function(data, column) {
  n <- count(data, .data[[column]])
  setNames(n$n, n[[column]])
}

applies <- function(data, modifier) {
  sum(vapply(
    strsplit(data$modifiers, ", ", fixed = TRUE),
    \(names) modifier %in% names,
    logical(1)
  ))
}

# The n in each box of the group's diagrams
test_that("model_v1 matches its diagram", {
  leaves <- c(
    A1 = 222,
    A2 = 252,
    A3 = 215,
    B1 = 83,
    B2 = 153,
    C1 = 156,
    C2 = 109,
    C3 = 80
  )
  expect_equal(counts(scored$v1, "leaf")[names(leaves)], leaves)

  gate3 <- c(
    "2+ children under 11" = 29,
    "1 child under 11" = 42,
    "Only children 11+" = 25,
    "Escorts older adults" = 6,
    "Shopping by car or motorbike" = 43,
    "Everything else" = 1125
  )
  expect_equal(counts(scored$v1, "trip_chain")[names(gate3)], gate3)
  expect_equal(applies(scored$v1, "no parking"), 244)
  expect_equal(applies(scored$v1, "age 50+"), 95)
})

test_that("model_v2 matches its diagram", {
  leaves <- c(
    A1 = 155,
    A2 = 67,
    A3 = 187,
    A4 = 28,
    A5 = 198,
    A6 = 54,
    B1 = 83,
    B2 = 128,
    B3 = 25,
    C1 = 156,
    C2 = 109,
    C3 = 80
  )
  expect_equal(counts(scored$v2, "leaf")[names(leaves)], leaves)
  expect_equal(applies(scored$v2, "escort stop"), 102)
})

test_that("every model gives everyone a p_shift", {
  for (out in scored) {
    expect_false(anyNA(out$p_shift))
    expect_true(all(out$p_shift >= 0.0025 & out$p_shift <= 1))
  }
})

test_that("score_shift() is the three steps in a row", {
  by_hand <- survey |>
    add_tier(tree_v1) |>
    adjust_tier(trip_chain_v1, model_v1$modifiers) |>
    add_shift_probability(shift_probabilities)
  expect_identical(scored$v1, by_hand)
})

test_that("a part can be swapped on a model", {
  trial <- model_v1
  trial$modifiers <- pick_modifiers(modifier_library, "escort stop")
  out <- score_shift(survey, trial)
  expect_equal(applies(out, "escort stop"), 102)
  expect_equal(applies(out, "no parking"), 0)

  # score_shift() checks the swapped part
  trial$matrix["Very high", "Unsure"] <- 2
  expect_error(score_shift(survey, trial), "between 0 and 1")
})

test_that("score_shift() rescores data that's already scored", {
  # Its path, leaf, modifiers, tier and p_shift columns are replaced, not read
  expect_identical(score_shift(scored$v1, model_v2), scored$v2)
  m <- shift_probabilities
  m[] <- 0.5
  expect_true(all(add_shift_probability(scored$v1, m)$p_shift == 0.5))
})

test_that("score_shift() warns about a modifier that applies to nobody", {
  typo <- model_v1
  typo$modifiers$value[2] <- "50 or Older"
  expect_warning(score_shift(survey, typo), "apply to nobody: age 50\\+")
})

test_that("score_shift() warns once about a matrix that falls", {
  falls <- model_v1
  falls$matrix["Moderate", "Unsure"] <- 0.01
  warnings <- character()
  withCallingHandlers(
    score_shift(survey, falls),
    warning = \(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(grep("p_shift falls", warnings), 1)
})

test_that("compare_models() gives a row per model", {
  out <- compare_models(survey, models)
  expect_equal(out$model, names(models))
  expect_equal(rowSums(out[tier_levels]), rep(nrow(survey), 3))
  expect_equal(out$mean_p_shift[1], mean(scored$v1$p_shift))
  expect_error(compare_models(survey, list(model_v1)), "Name every model")
})

test_that("tree_table() counts the people through each node", {
  nodes <- tree_table(tree_v1, scored$v1$path)
  expect_equal(nodes$n[nodes$node == "gate1"], 1270)
  expect_equal(nodes$n[nodes$node == "gate2d"], 189)
  expect_equal(nrow(nodes), nrow(tree_v1$gates) + nrow(tree_v1$leaves))
})
