# Runs before the tests: loads the code under test, from the project root.
library(dplyr)
library(readxl)

r_file <- function(name) test_path("..", "..", "R", name)
source(r_file("survey_codebook.R"))
source(r_file("decision_tree.R"))
source(r_file("shift_models.R"))
source(r_file("emission_factors.R"))
source(r_file("emissions.R"))

# The course workbook, from the test directory. Not called survey_path, which
# R/survey_codebook.R sets relative to the project root.
workbook_path <- test_path("..", "..", "data", "ubike_survey.xlsx")
