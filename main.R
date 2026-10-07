# UBike emission savings
# The project's main script: from the survey to the emissions a shift to
# cycling would save. Run it a few lines at a time (select, then Cmd+Enter).
# The other .R files just define the functions used here; the charts are in
# make_charts.R.

# Setup ------------------------------------------------------------------------

library(dplyr)

source("survey_codebook.R") # read_survey(), column names and answer labels

# Data -------------------------------------------------------------------------

survey <- read_survey()
