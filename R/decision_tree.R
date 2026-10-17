# Decision tree ----------------------------------------------------------------
# Runs a shift model to give each person's p_shift (brief, section 4 and
# Figure 1). The models themselves are in R/shift_models.R.
#
#   survey |> score_shift(model_v1)
#
# is add_tier() |> adjust_tier() |> add_shift_probability(). A model's parts,
# and the columns of each table:
#   tree        start, plus tables
#                 gates     node, column, label, reason
#                 branches  node, value, to
#                 leaves    leaf, tier, reason
#   adjustment  optional. column, plus effects: value, steps, max_tier, reason
#   modifiers   optional. modifier, column, value, steps, reason
#   matrix      p_shift for each tier (rows) and Q23 answer (columns)
# A person at a gate follows the branch whose value matches their answer in
# the gate's column, until they reach a leaf. Those columns come from
# add_groups() (R/survey_codebook.R).

library(dplyr)

## Tiers and answers -----------------------------------------------------------

# Least to most likely to shift
tier_levels <- c("Very low", "Low", "Moderate", "High", "Very high")

# Q23, least to most willing (the labels in survey_key)
willingness_levels <- c(
  "Not Interested",
  "Unsure",
  "Yes_electric",
  "Yes_all bikes"
)

## shift_model() ---------------------------------------------------------------

# A model from its parts, after checking each one. score_shift() checks them
# again, so a part can be swapped on a model directly:
#   model$modifiers <- pick_modifiers(modifier_library, "age 50+")
shift_model <- function(
  tree,
  adjustment = NULL,
  modifiers = NULL,
  matrix,
  max_modifier_steps = 1
) {
  model <- list(
    tree = tree,
    adjustment = adjustment,
    modifiers = modifiers,
    matrix = matrix,
    max_modifier_steps = max_modifier_steps
  )
  check_model(model)
}

check_model <- function(model) {
  check_tree(model$tree)
  check_adjustment(model$adjustment)
  check_modifiers(model$modifiers)
  check_matrix(model$matrix)
  check_max_modifier_steps(model$max_modifier_steps)
  invisible(model)
}

# The modifiers in `names`, in that order, from a table of modifiers
pick_modifiers <- function(modifiers, names) {
  unknown <- setdiff(names, modifiers$modifier)
  if (length(unknown) > 0) {
    stop(
      "No modifier called ",
      toString(unknown),
      ". There are: ",
      toString(modifiers$modifier),
      call. = FALSE
    )
  }
  modifiers[match(names, modifiers$modifier), ]
}

## shift_matrix() --------------------------------------------------------------

# p_shift for each tier and Q23 answer: the tier's probability times the
# answer's weight. Both are named vectors.
shift_matrix <- function(tier, willingness) {
  stop_unless_names(tier, tier_levels, "tier")
  stop_unless_names(willingness, willingness_levels, "willingness")
  outer(tier[tier_levels], willingness[willingness_levels])
}

# Stops unless the matrix has a probability between 0 and 1 for every tier and
# Q23 answer. Warns if a probability falls as the tier or willingness rises.
check_matrix <- function(matrix) {
  if (!is.matrix(matrix) || !is.numeric(matrix)) {
    stop("The probability matrix must be a numeric matrix", call. = FALSE)
  }
  stop_unless_names(matrix[, 1], tier_levels, "matrix rows")
  stop_unless_names(matrix[1, ], willingness_levels, "matrix columns")
  if (anyNA(matrix) || any(matrix < 0 | matrix > 1)) {
    stop(
      "The probability matrix must be between 0 and 1, with no blanks",
      call. = FALSE
    )
  }

  in_order <- matrix[tier_levels, willingness_levels]
  falls <- c(
    if (any(diff(in_order) < 0)) "as the tier rises",
    if (any(diff(t(in_order)) < 0)) "as willingness rises"
  )
  if (length(falls) > 0) {
    warning("p_shift falls ", paste(falls, collapse = " and "), call. = FALSE)
  }
  invisible(matrix)
}

# Stops unless x is named with exactly `levels`, in any order
stop_unless_names <- function(x, levels, what) {
  if (!setequal(names(x), levels) || anyDuplicated(names(x))) {
    stop(
      "The ",
      what,
      " must be named ",
      toString(levels),
      " (got ",
      toString(names(x)),
      ")",
      call. = FALSE
    )
  }
}

## check_tree() ----------------------------------------------------------------

# Stops, listing every problem, unless the tree is well formed: every branch
# leads somewhere, every gate and leaf can be reached, and there are no loops.
check_tree <- function(tree) {
  stop_if_missing(tree$gates, c("node", "column", "label", "reason"), "gates")
  stop_if_missing(tree$branches, c("node", "value", "to"), "branches")
  stop_if_missing(tree$leaves, c("leaf", "tier", "reason"), "leaves")

  gates <- tree$gates$node
  leaves <- tree$leaves$leaf
  branches <- tree$branches

  repeated <- duplicated(select(branches, node, value))
  stop_if_problems(
    "The tree",
    list(
      "Not a gate: start = " = setdiff(
        if (is.null(tree$start)) "(none)" else tree$start,
        gates
      ),
      "More than one start: " = if (length(tree$start) > 1) tree$start,
      "Repeated gates: " = gates[duplicated(gates)],
      "Repeated leaves: " = leaves[duplicated(leaves)],
      "Both a gate and a leaf: " = intersect(gates, leaves),
      # walk_tree() joins routes with " > "
      "Names with \" > \": " = grep(" > ", c(gates, leaves), value = TRUE),
      "Branches from a node that isn't a gate: " = setdiff(
        branches$node,
        gates
      ),
      "Branches to nowhere: " = setdiff(branches$to, c(gates, leaves)),
      "Gates with no branches: " = setdiff(gates, branches$node),
      "Repeated branches: " = paste(
        branches$node[repeated],
        branches$value[repeated]
      ),
      "Leaf tier not in tier_levels: " = setdiff(tree$leaves$tier, tier_levels),
      "Can't be reached from start: " = setdiff(
        c(gates, leaves),
        reachable_from(tree$start, branches)
      ),
      "Gates in a loop: " = gates_in_loops(gates, leaves, branches)
    )
  )
  invisible(tree)
}

# Every node the branches lead to from `start`, and start itself
reachable_from <- function(start, branches) {
  reached <- start
  repeat {
    more <- setdiff(branches$to[branches$node %in% reached], reached)
    if (length(more) == 0) {
      return(reached)
    }
    reached <- c(reached, more)
  }
}

# Peels off gates whose branches all end at leaves or peeled gates. Whatever
# is left goes round in a loop.
gates_in_loops <- function(gates, leaves, branches) {
  done <- leaves
  repeat {
    ready <- setdiff(gates, c(done, branches$node[!branches$to %in% done]))
    if (length(ready) == 0) {
      return(setdiff(gates, done))
    }
    done <- c(done, ready)
  }
}

## check_adjustment() and check_modifiers() ------------------------------------

# Stops unless the adjustment (or NULL) is one column with one row of effects
# per value
check_adjustment <- function(adjustment) {
  if (is.null(adjustment)) {
    return(invisible(adjustment))
  }
  if (!is.character(adjustment$column) || length(adjustment$column) != 1) {
    stop("The adjustment needs one column name", call. = FALSE)
  }
  effect_rows <- adjustment$effects
  stop_if_missing(
    effect_rows,
    c("value", "steps", "max_tier", "reason"),
    "adjustment effects"
  )
  stop_if_problems(
    "The adjustment",
    list(
      "Repeated values: " = effect_rows$value[duplicated(effect_rows$value)],
      "Steps that aren't whole numbers: " = bad_steps(effect_rows$steps),
      "Adjustment max_tier not in tier_levels: " = setdiff(
        na.omit(effect_rows$max_tier),
        tier_levels
      )
    )
  )
  invisible(adjustment)
}

# Stops unless the modifiers (or NULL) have unique names and whole, non-zero
# steps
check_modifiers <- function(modifiers) {
  if (is.null(modifiers)) {
    return(invisible(modifiers))
  }
  stop_if_missing(
    modifiers,
    c("modifier", "column", "value", "steps", "reason"),
    "modifiers"
  )
  stop_if_problems(
    "The modifiers",
    list(
      "Repeated modifiers: " = modifiers$modifier[
        duplicated(modifiers$modifier)
      ],
      "Steps that aren't whole numbers: " = bad_steps(modifiers$steps),
      "Steps of 0: " = modifiers$modifier[modifiers$steps %in% 0]
    )
  )
  invisible(modifiers)
}

bad_steps <- function(steps) {
  steps[is.na(steps) | steps != round(steps)]
}

# Stops unless the modifiers' limit is one whole number, 0 or more. A negative
# one would move everyone down, whatever their modifiers.
check_max_modifier_steps <- function(steps) {
  if (
    !is.numeric(steps) ||
      length(steps) != 1 ||
      length(bad_steps(steps)) > 0 ||
      steps < 0
  ) {
    stop(
      "max_modifier_steps must be one whole number, 0 or more (got ",
      toString(steps),
      ")",
      call. = FALSE
    )
  }
}

## Errors ----------------------------------------------------------------------

# Stops unless the table has every column in `columns`
stop_if_missing <- function(table, columns, what) {
  absent <- setdiff(columns, names(table))
  if (length(absent) > 0) {
    stop("The ", what, " table has no column ", toString(absent), call. = FALSE)
  }
}

# Stops with every problem (a named list of what's wrong) that isn't empty
stop_if_problems <- function(what, problems) {
  problems <- problems[lengths(problems) > 0]
  if (length(problems) > 0) {
    stop(
      what,
      " isn't valid:\n",
      paste0(
        names(problems),
        sapply(problems, function(x) toString(unique(x))),
        collapse = "\n"
      ),
      call. = FALSE
    )
  }
}

# The first ten ids (or row numbers, without an id column) where `rows` is TRUE
ids_where <- function(data, rows) {
  ids <- if ("id" %in% names(data)) data$id else seq_len(nrow(data))
  paste0("(ids ", toString(head(ids[rows], 10)), ")")
}

# Stops if anyone has no answer in `column`
stop_if_blank <- function(data, column, what) {
  blank <- is.na(data[[column]])
  if (any(blank)) {
    stop(
      "No answer for ",
      column,
      ", read by ",
      what,
      " ",
      ids_where(data, blank),
      call. = FALSE
    )
  }
}

## walk_tree() -----------------------------------------------------------------

# Each person's leaf, and their route to it (path, like "gate1 > gate2a > A1").
# Stops if an answer has no branch.
walk_tree <- function(data, tree) {
  check_tree(tree)
  stop_if_missing(data, tree$gates$column, "data")

  at <- rep(tree$start, nrow(data))
  path <- at
  # check_tree() ruled out loops, so everyone reaches a leaf
  while (any(at %in% tree$gates$node)) {
    for (node in intersect(tree$gates$node, at)) {
      here <- at == node
      column <- tree$gates$column[tree$gates$node == node]
      branches <- tree$branches[tree$branches$node == node, ]
      values <- as.character(data[[column]][here])
      to <- branches$to[match(values, branches$value)]

      if (anyNA(to)) {
        stop(
          "No branch at ",
          node,
          " for ",
          column,
          " = ",
          toString(unique(values[is.na(to)])),
          " ",
          ids_where(data[here, ], is.na(to)),
          call. = FALSE
        )
      }
      at[here] <- to
      path[here] <- paste(path[here], to, sep = " > ")
    }
  }
  list(leaf = at, path = path)
}

## score_shift() ---------------------------------------------------------------

# Adds path, leaf, base_tier, modifiers, tier and p_shift from a shift_model().
# Warns about modifiers that apply to nobody (a typo in value, say). Each step
# checks its own part; checking the whole model here too would repeat
# check_matrix()'s warning.
score_shift <- function(data, model) {
  scored <- data |>
    add_tier(model$tree) |>
    adjust_tier(
      model$adjustment,
      model$modifiers,
      model$max_modifier_steps
    ) |>
    add_shift_probability(model$matrix)

  applied <- unlist(strsplit(scored$modifiers, ", "))
  unused <- setdiff(model$modifiers$modifier, applied)
  if (length(unused) > 0) {
    warning(
      "These modifiers apply to nobody: ",
      toString(unused),
      call. = FALSE
    )
  }
  scored
}

# One row per model (a named list of shift_model()s): the mean and total
# p_shift, and the people in each tier
compare_models <- function(data, models) {
  if (is.null(names(models)) || any(names(models) == "")) {
    stop(
      "Name every model, e.g. list(v1 = model_v1, v2 = model_v2)",
      call. = FALSE
    )
  }
  rows <- lapply(models, function(model) {
    score_shift(data, model) |>
      summarise(
        mean_p_shift = mean(p_shift),
        expected_shifters = sum(p_shift),
        `Very low` = sum(tier == "Very low"),
        Low = sum(tier == "Low"),
        Moderate = sum(tier == "Moderate"),
        High = sum(tier == "High"),
        `Very high` = sum(tier == "Very high")
      )
  })
  bind_rows(rows, .id = "model")
}

## add_tier() ------------------------------------------------------------------

# Adds path, leaf and base_tier (a factor with tier_levels).
add_tier <- function(data, tree) {
  route <- walk_tree(data, tree)
  leaf_tier <- tree$leaves$tier[match(route$leaf, tree$leaves$leaf)]

  data$path <- route$path
  data$leaf <- route$leaf
  data$base_tier <- factor(leaf_tier, levels = tier_levels)
  data
}

## adjust_tier() ---------------------------------------------------------------

# Adds modifiers (the ones that apply, comma-separated) and tier. From
# base_tier, in this order, staying within Very low to Very high at each step:
#   1. the adjustment's steps (one row per value of its column)
#   2. the modifiers' steps, net, within +-max_modifier_steps
#   3. the adjustment's max_tier
adjust_tier <- function(
  data,
  adjustment = NULL,
  modifiers = NULL,
  max_modifier_steps = 1
) {
  if (!"base_tier" %in% names(data)) {
    stop("base_tier is missing: run add_tier() first", call. = FALSE)
  }
  check_max_modifier_steps(max_modifier_steps)

  # By label, so the factor's level order doesn't matter
  tiers <- as.character(data$base_tier)
  position <- match(tiers, tier_levels)
  if (anyNA(position)) {
    stop(
      "base_tier not in tier_levels: ",
      toString(unique(tiers[is.na(position)])),
      " ",
      ids_where(data, is.na(position)),
      call. = FALSE
    )
  }
  top <- length(tier_levels)
  within_tiers <- function(x) pmin(pmax(x, 1), top)
  cap <- rep(top, nrow(data))

  if (!is.null(adjustment)) {
    effect <- match_adjustment(data, adjustment)
    position <- within_tiers(position + effect$steps)
    cap <- coalesce(match(effect$max_tier, tier_levels), top)
  }

  matched <- match_modifiers(data, modifiers)
  net <- pmin(pmax(matched$steps, -max_modifier_steps), max_modifier_steps)
  position <- within_tiers(position + net)
  position <- pmin(position, cap)

  data$modifiers <- matched$names
  data$tier <- factor(tier_levels[position], levels = tier_levels)
  data
}

# Each person's row of adjustment$effects. Stops on a blank answer or a value
# with no row.
match_adjustment <- function(data, adjustment) {
  check_adjustment(adjustment)
  column <- adjustment$column
  stop_if_missing(data, column, "data")
  stop_if_blank(data, column, "the adjustment")

  values <- as.character(data[[column]])
  effect <- adjustment$effects[match(values, adjustment$effects$value), ]
  if (anyNA(effect$value)) {
    stop(
      "No adjustment for ",
      column,
      " = ",
      toString(unique(values[is.na(effect$value)])),
      call. = FALSE
    )
  }
  effect
}

# For each person, the modifiers that apply (names, comma-separated) and the
# sum of their steps. Each modifier is one row: it applies when the person's
# answer in column equals value. Stops on a blank answer.
match_modifiers <- function(data, modifiers) {
  check_modifiers(modifiers)
  modifier_names <- rep("", nrow(data))
  steps <- rep(0, nrow(data))
  if (is.null(modifiers)) {
    return(list(names = modifier_names, steps = steps))
  }
  stop_if_missing(data, modifiers$column, "data")

  for (i in seq_len(nrow(modifiers))) {
    modifier <- modifiers$modifier[i]
    column <- modifiers$column[i]
    stop_if_blank(data, column, modifier)

    applies <- data[[column]] == modifiers$value[i]
    steps[applies] <- steps[applies] + modifiers$steps[i]
    modifier_names[applies] <- if_else(
      modifier_names[applies] == "",
      modifier,
      paste(modifier_names[applies], modifier, sep = ", ")
    )
  }
  list(names = modifier_names, steps = steps)
}

## add_shift_probability() -----------------------------------------------------

# Adds p_shift: the matrix cell for the person's tier and Q23 answer.
add_shift_probability <- function(data, matrix) {
  if (!"tier" %in% names(data)) {
    stop("tier is missing: run adjust_tier() first", call. = FALSE)
  }
  # Without it, cbind() below drops the column and the matrix is read by
  # position
  stop_if_missing(data, "willingness", "data")
  check_matrix(matrix)

  # One cell per person: matrix[cbind(rows, columns)] reads the cell at each
  # (row, column) pair
  tier <- as.character(data$tier)
  willingness <- as.character(data$willingness)
  cell <- cbind(
    match(tier, rownames(matrix)),
    match(willingness, colnames(matrix))
  )
  p_shift <- matrix[cell]

  if (anyNA(p_shift)) {
    no_cell <- unique(paste(tier, willingness, sep = " / ")[is.na(p_shift)])
    stop(
      "No probability for: ",
      toString(no_cell),
      " ",
      ids_where(data, is.na(p_shift)),
      call. = FALSE
    )
  }
  data$p_shift <- p_shift
  data
}

## tree_table() ----------------------------------------------------------------

# One row per gate and leaf, with its label (the tier, for a leaf) and
# reason, plus the number of people through it when given add_tier()'s paths:
#   tree_table(model$tree, survey$path)
tree_table <- function(tree, paths = NULL) {
  check_tree(tree)
  rows <- bind_rows(
    tibble(
      node = tree$gates$node,
      kind = "gate",
      label = tree$gates$label,
      reason = tree$gates$reason
    ),
    tibble(
      node = tree$leaves$leaf,
      kind = "leaf",
      label = tree$leaves$tier,
      reason = tree$leaves$reason
    )
  )

  if (!is.null(paths)) {
    nodes <- unlist(strsplit(paths, " > ", fixed = TRUE))
    rows$n <- as.integer(table(factor(nodes, levels = rows$node)))
  }
  rows
}
