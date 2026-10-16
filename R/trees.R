# Shift models -----------------------------------------------------------------
# The parts of each shift model, as tables, and the models built from them.
# R/decision_tree.R runs them. Edit this file to change a model:
#   survey |> score_shift(model_v1)
#
# The parts, each of which can be swapped on its own:
#   - Probabilities: tier_probabilities and willingness_weights make
#     shift_probabilities, the matrix with p_shift for each tier and Q23
#     answer. Set a cell by hand to break from the product.
#   - Trees: gates, branches and leaves.
#       New question: a row in gates. Its column must be in the survey or made
#       by add_groups() in R/survey_codebook.R (add it there if it needs a
#       threshold or combines questions).
#       New answer route: a row in branches. Several values can lead to the
#       same node ("Yes or a bit" is two rows).
#       New outcome: a row in leaves, with a tier from tier_levels.
#   - Adjustment: trip_chain_v1, tree_v1's Gate 3. One row per value.
#   - Modifiers: one row each in modifier_library, picked by name for each
#     model. New modifier: a row with steps -1 or +1.
#   - Models: shift_model() puts the parts together and checks them.
#
# To try a change without editing this file, copy a model and swap a part
# (score_shift() checks the parts again):
#   trial <- model_v1
#   trial$modifiers <- pick_modifiers(modifier_library, "escort stop")
#   trial$matrix["Moderate", "Unsure"] <- 0.15
#   compare_models(survey, list(v1 = model_v1, trial = trial))
#
# reason holds the justification the brief asks for (against the Hierarchy of
# Cycling Needs). TODO: fill them in.
#
# The tables stay one row per line, aligned by air, so lintr skips this file's
# line lengths and comma spacing.
# nolint start: line_length_linter, commas_linter.

library(dplyr)

## Probabilities ---------------------------------------------------------------

# Each tier's probability, starting from Figure 1
tier_probabilities <- c(
  "Very low" = 0.05,
  "Low" = 0.20,
  "Moderate" = 0.40,
  "High" = 0.60,
  "Very high" = 1.00
)

# Each Q23 answer's weight, from the group's diagrams
willingness_weights <- c(
  "Not Interested" = 0.05,
  "Unsure" = 0.30,
  "Yes_electric" = 0.70,
  "Yes_all bikes" = 1.00
)

# p_shift for each tier (rows) and Q23 answer (columns): the product of the
# two above. To set a cell by hand, after this line:
#   shift_probabilities["Very high", "Unsure"] <- 0.35
shift_probabilities <- shift_matrix(tier_probabilities, willingness_weights)

## Trees -----------------------------------------------------------------------

### tree_v1: trip chain --------------------------------------------------------

# Distance, then urban cycling, then (far and able to cycle) rail, metro or
# ferry. model_v1 adds Gate 3 (trip_chain_v1) after it.
tree_v1 <- list(
  start = "gate1",
  gates = tribble(
    ~node    , ~column            , ~label                              , ~reason ,
    "gate1"  , "distance_band"    , "How far is your commute? (Q17)"    , "TODO"  ,
    "gate2a" , "cycling"          , "Can you cycle in the city? (Q20)"  , "TODO"  ,
    "gate2b" , "cycling"          , "Can you cycle in the city? (Q20)"  , "TODO"  ,
    "gate2c" , "cycling"          , "Can you cycle in the city? (Q20)"  , "TODO"  ,
    "gate2d" , "rail_metro_ferry" , "Uses train, metro or ferry? (Q14)" , "TODO"
  ),
  branches = tribble(
    ~node    , ~value          , ~to      ,
    "gate1"  , "Under 5 km"    , "gate2a" ,
    "gate1"  , "5 to 15 km"    , "gate2b" ,
    "gate1"  , "15 km or more" , "gate2c" ,
    "gate2a" , "No"            , "A1"     ,
    "gate2a" , "ABit"          , "A2"     ,
    "gate2a" , "Yes"           , "A3"     ,
    "gate2b" , "No"            , "B1"     ,
    "gate2b" , "ABit"          , "B2"     ,
    "gate2b" , "Yes"           , "B2"     ,
    "gate2c" , "No"            , "C1"     ,
    "gate2c" , "ABit"          , "gate2d" ,
    "gate2c" , "Yes"           , "gate2d" ,
    "gate2d" , "Yes"           , "C2"     ,
    "gate2d" , "No"            , "C3"
  ),
  leaves = tribble(
    ~leaf , ~tier       , ~reason ,
    "A1"  , "Low"       , "TODO"  ,
    "A2"  , "High"      , "TODO"  ,
    "A3"  , "Very high" , "TODO"  ,
    "B1"  , "Very low"  , "TODO"  ,
    "B2"  , "Moderate"  , "TODO"  ,
    "C1"  , "Very low"  , "TODO"  ,
    "C2"  , "Low"       , "TODO"  ,
    "C3"  , "Very low"  , "TODO"
  )
)

### tree_v2: bike parking ------------------------------------------------------

# Distance, then urban cycling, then bike parking at home (everyone under
# 5 km, and those who cycle at 5 to 15 km) or rail, metro or ferry (those who
# cycle at 15 km or more).
tree_v2 <- list(
  start = "gate1",
  gates = tribble(
    ~node         , ~column            , ~label                              , ~reason ,
    "gate1"       , "distance_band"    , "Commute distance? (Q17)"           , "TODO"  ,
    "gate2a"      , "cycling"          , "Can you cycle in the city? (Q20)"  , "TODO"  ,
    "gate2b"      , "cycling"          , "Can you cycle in the city? (Q20)"  , "TODO"  ,
    "gate2c"      , "cycling"          , "Can you cycle in the city? (Q20)"  , "TODO"  ,
    "gate3a_no"   , "parking_home"     , "Bike parking at home? (Q21)"       , "TODO"  ,
    "gate3a_abit" , "parking_home"     , "Bike parking at home? (Q21)"       , "TODO"  ,
    "gate3a_yes"  , "parking_home"     , "Bike parking at home? (Q21)"       , "TODO"  ,
    "gate3b"      , "parking_home"     , "Bike parking at home? (Q21)"       , "TODO"  ,
    "gate3c"      , "rail_metro_ferry" , "Uses train, metro or ferry? (Q14)" , "TODO"
  ),
  branches = tribble(
    ~node         , ~value          , ~to           ,
    "gate1"       , "Under 5 km"    , "gate2a"      ,
    "gate1"       , "5 to 15 km"    , "gate2b"      ,
    "gate1"       , "15 km or more" , "gate2c"      ,
    "gate2a"      , "No"            , "gate3a_no"   ,
    "gate2a"      , "ABit"          , "gate3a_abit" ,
    "gate2a"      , "Yes"           , "gate3a_yes"  ,
    "gate3a_no"   , "Yes"           , "A1"          ,
    "gate3a_no"   , "No"            , "A2"          ,
    "gate3a_abit" , "Yes"           , "A5"          ,
    "gate3a_abit" , "No"            , "A6"          ,
    "gate3a_yes"  , "Yes"           , "A3"          ,
    "gate3a_yes"  , "No"            , "A4"          ,
    "gate2b"      , "No"            , "B1"          ,
    "gate2b"      , "ABit"          , "gate3b"      ,
    "gate2b"      , "Yes"           , "gate3b"      ,
    "gate3b"      , "Yes"           , "B2"          ,
    "gate3b"      , "No"            , "B3"          ,
    "gate2c"      , "No"            , "C1"          ,
    "gate2c"      , "ABit"          , "gate3c"      ,
    "gate2c"      , "Yes"           , "gate3c"      ,
    "gate3c"      , "Yes"           , "C2"          ,
    "gate3c"      , "No"            , "C3"
  ),
  leaves = tribble(
    ~leaf , ~tier       , ~reason ,
    "A1"  , "Low"       , "TODO"  ,
    "A2"  , "Very low"  , "TODO"  ,
    "A3"  , "Very high" , "TODO"  ,
    "A4"  , "Moderate"  , "TODO"  ,
    "A5"  , "High"      , "TODO"  ,
    "A6"  , "Low"       , "TODO"  ,
    "B1"  , "Very low"  , "TODO"  ,
    "B2"  , "Moderate"  , "TODO"  ,
    "B3"  , "Low"       , "TODO"  ,
    "C1"  , "Very low"  , "TODO"  ,
    "C2"  , "Low"       , "TODO"  ,
    "C3"  , "Very low"  , "TODO"
  )
)

### tree_brief: the brief's Figure 1 ------------------------------------------

# The scaffold as given, for comparison (the brief scores it 3/20 on its own).
# Where Figure 1 leaves a threshold open, add_groups() picks one: a low
# floor is the 2nd or below, and car-light means not commuting only by car.
tree_brief <- list(
  start = "gate1",
  gates = tribble(
    ~node    , ~column                  , ~label                               , ~reason                                  ,
    "gate1"  , "cycling"                , "Can the respondent ride? (Q20 > 0)" , "Figure 1"                               ,
    "gate2"  , "distance_band_brief"    , "Is distance < 5 km? (Q17)"          , "Figure 1"                               ,
    "gate2a" , "parking_floor_ok"       , "Q21 parking & Q22 floor OK?"        , "Figure 1"                               ,
    "gate3"  , "distance_band_brief"    , "What is the distance? (Q17)"        , "Figure 1"                               ,
    "gate3a" , "confident_with_parking" , "Q20 confident & Q21 parking?"       , "Figure 1, with High for one of the two" ,
    "gate3b" , "low_floor_not_car_only" , "Q22 low floor & not car-only?"      , "Figure 1"                               ,
    "gate3c" , "transit_card_car_light" , "Q16 transit card & car-light?"      , "Figure 1"
  ),
  branches = tribble(
    ~node    , ~value           , ~to                                         ,
    "gate1"  , "No"             , "gate2"                                     ,
    "gate1"  , "ABit"           , "gate3"                                     ,
    "gate1"  , "Yes"            , "gate3"                                     ,
    "gate2"  , "Under 5 km"     , "gate2a"                                    ,
    "gate2"  , "5 to 10 km"     , "Can't ride, 5 km+"                         ,
    "gate2"  , "Over 10 km"     , "Can't ride, 5 km+"                         ,
    "gate2a" , "No"             , "Can't ride, short, no parking or floor"    ,
    "gate2a" , "Yes"            , "Can't ride, short, parking and floor"      ,
    "gate3"  , "Under 5 km"     , "gate3a"                                    ,
    "gate3"  , "5 to 10 km"     , "gate3b"                                    ,
    "gate3"  , "Over 10 km"     , "gate3c"                                    ,
    "gate3a" , "Neither"        , "Rides, under 5 km, neither"                ,
    "gate3a" , "One of the two" , "Rides, under 5 km, one of the two"         ,
    "gate3a" , "Both"           , "Rides, under 5 km, confident with parking" ,
    "gate3b" , "No"             , "Rides, 5 to 10 km, no"                     ,
    "gate3b" , "Yes"            , "Rides, 5 to 10 km, yes"                    ,
    "gate3c" , "No"             , "Rides, over 10 km, no"                     ,
    "gate3c" , "Yes"            , "Rides, over 10 km, yes"
  ),
  leaves = tribble(
    ~leaf                                       , ~tier       , ~reason    ,
    "Can't ride, 5 km+"                         , "Very low"  , "Figure 1" ,
    "Can't ride, short, no parking or floor"    , "Low"       , "Figure 1" ,
    "Can't ride, short, parking and floor"      , "Moderate"  , "Figure 1" ,
    "Rides, under 5 km, neither"                , "Moderate"  , "Figure 1" ,
    "Rides, under 5 km, one of the two"         , "High"      , "Figure 1" ,
    "Rides, under 5 km, confident with parking" , "Very high" , "Figure 1" ,
    "Rides, 5 to 10 km, no"                     , "Low"       , "Figure 1" ,
    "Rides, 5 to 10 km, yes"                    , "Moderate"  , "Figure 1" ,
    "Rides, over 10 km, no"                     , "Very low"  , "Figure 1" ,
    "Rides, over 10 km, yes"                    , "Low"       , "Figure 1"
  )
)

## Adjustments -----------------------------------------------------------------

# tree_v1's Gate 3, for every branch: what does your daily trip chain look
# like? One row per trip_chain value (Q15, with Q7 to Q11 and Q12). Caps
# (max_tier) go past the brief's +-1 tier, so they need a reason on the slides.
trip_chain_v1 <- list(
  column = "trip_chain",
  effects = tribble(
    ~value                         , ~steps , ~max_tier  , ~reason                                                ,
    "2+ children under 11"         ,      0 , "Very low" , "TODO"                                                 ,
    "1 child under 11"             ,      0 , "Low"      , "TODO"                                                 ,
    "Only children 11+"            ,     -1 , NA         , "TODO"                                                 ,
    "Escorts older adults"         ,      0 , "Very low" , "TODO"                                                 ,
    "Shopping by car or motorbike" ,     -1 , NA         , "TODO"                                                 ,
    "Everything else"              ,      0 , NA         , "No stop, gym, work, other, or shopping without a car"
  )
)

## Modifiers -------------------------------------------------------------------

# Every modifier a model can pick. Each applies when the person's answer in
# column is value.
modifier_library <- tribble(
  ~modifier     , ~column        , ~value        , ~steps , ~reason ,
  # Q21
  "no parking"  , "parking_home" , "No"          ,     -1 , "TODO"  ,
  # Q4
  "age 50+"     , "age_band"     , "50 or older" ,     -1 , "TODO"  ,
  # Q15: escorts children or older adults
  "escort stop" , "escort_stop"  , "Yes"         ,     -1 , "TODO"
)

## Models ----------------------------------------------------------------------

# Trip chain: tree_v1, then Gate 3, then the modifiers lower the tier by at
# most one more
model_v1 <- shift_model(
  tree_v1,
  adjustment = trip_chain_v1,
  modifiers = pick_modifiers(modifier_library, c("no parking", "age 50+")),
  matrix = shift_probabilities
)

# Bike parking: tree_v2, then the modifiers lower the tier by at most one
model_v2 <- shift_model(
  tree_v2,
  modifiers = pick_modifiers(modifier_library, c("escort stop", "age 50+")),
  matrix = shift_probabilities
)

# The brief's scaffold, for comparison
model_brief <- shift_model(tree_brief, matrix = shift_probabilities)

# nolint end
