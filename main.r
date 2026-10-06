# imports
library(dplyr)
library(readxl)

# codebook: survey_key and label_survey()
source("survey_codebook.r")

# read the excel file
data <- read_excel("./data/TS_Project_SurveyUBike_final (local).xlsx")

# short column names and labelled answers
survey <- label_survey(data)

# filter students
students <- survey |>
  filter(role == "Student")

# view students
View(students)
