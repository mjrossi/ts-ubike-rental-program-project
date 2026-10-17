# TS: Ubike Rental Program Project

How much commuting CO2 (and CH4, N2O, NOx, PM) would IST's UBike scheme save?
The survey has 1,270 students, faculty and staff. For each person, `main.R`
estimates the chance they switch their commute to cycling and the emissions
that switch would avoid, then adds them up by role and by mode. The brief is
[`docs/project_brief.pdf`](docs/project_brief.pdf).

## Setup in RStudio (once)

1. Install **R 4.6** from [CRAN](https://cran.r-project.org/) and
   [RStudio](https://posit.co/download/rstudio-desktop/), if you don't have
   them yet. An older R can fail to install the packages.
2. Install **Git**:
   - **Windows**: install [Git for Windows](https://git-scm.com/downloads/win)
     with its default options.
   - **Mac**: open the Terminal app, run `git --version`, and click
     **Install** when macOS offers the command line developer tools.

   Then restart RStudio so it finds Git.
3. Clone the project. In RStudio: **File → New Project → Version Control →
   Git**. Paste
   `https://github.com/mjrossi/ts-ubike-rental-program-project.git` as the
   repository URL, pick a folder, and click **Create Project**. RStudio
   downloads the project and opens it, and the Console prints a few lines
   about `renv`. That's expected.
4. In the **Console**, run:

   ```r
   renv::restore()
   ```

   Type `Y` and press Enter when it asks. This installs the exact package
   versions the group uses into this project, so it takes a few minutes the
   first time. Your other R work is not affected.

## Every time

- Open the project by double-clicking
  **`ts-ubike-rental-program-project.Rproj`**, not by opening `main.R` on its
  own. The project tells R where the `data/` and `R/` folders are and which
  packages to use.
- Open `main.R` from RStudio's **Files** pane. Run a line or a selection with
  `Ctrl+Enter` (`Cmd+Enter` on a Mac). Start with the `source()` lines at the
  top, which load the functions from `R/`.
- `make_charts.R` draws the survey charts into `output/`. Open it and click
  **Source**.
- To run the tests, type `testthat::test_dir("tests/testthat")` in the
  Console.

## How it works

`main.R` is four steps. Each one adds columns to the survey table:

```r
survey <- read_survey() |>       # labels the answers, adds grouped columns
  score_shift(model_v1) |>       # tier and p_shift
  add_main_mode(factors) |>      # most polluting mode in Q14
  add_current_emissions(factors) |>
  add_savings()                  # current emissions x p_shift

total_savings(survey, role)
```

1. **Survey.** `read_survey()` turns the sheet's coded answers into labels
   and derives the inputs the decision tree reads (distance bands, bike
   parking, trip chain, ...). A blank answer stays blank, and the model stops
   on it rather than guess.
2. **Probability of shifting.** A decision tree puts each person in one of
   five tiers (Very low to Very high) from their circumstances: distance,
   urban cycling, parking and so on. Modifiers and an optional adjustment
   then move them up or down a tier. `p_shift` is the cell of a probability
   matrix for their tier and their stated willingness (Q23).
3. **Emission factors.** A g/p.km factor for every mode and gas. Bus, ferry,
   rail and metro come from the course workbook. Car, carpool, taxi and
   motorbike come from COPERT plus upstream fuel emissions, divided by
   occupancy.
4. **Savings.** Current emissions are the main mode's factor times the
   commute distance. Expected savings are those emissions times `p_shift`.

`docs/methods.md` has the equations, sources, assumptions and open decisions.

### Shift models

A shift model is a tree, an optional adjustment, a set of modifiers and a
probability matrix. All four are tables in `R/shift_models.R`, so changing a
model means editing a row, not code. There are three models:

- `model_v1`: distance, urban cycling, then a trip-chain gate (escorting
  children, shopping by car) that can cap the tier.
- `model_v2`: distance, urban cycling, then bike parking at home.
- `model_brief`: the brief's Figure 1, for comparison.

`compare_models()` scores several at once. To try a change without editing
the file:

```r
trial <- model_v1
trial$matrix["Moderate", "Unsure"] <- 0.15
compare_models(survey, list(v1 = model_v1, trial = trial))
```

`tree_table(model$tree, survey$path)` counts the people through each gate
and leaf, to check against the diagrams.

## Code

`main.R` and `make_charts.R` are the scripts. The files in `R/` only define
functions and tables:

| File | What's in it |
|---|---|
| `R/survey_codebook.R` | Column names and answer codes (`survey_key`), `read_survey()`, `add_groups()`, `split_modes()` |
| `R/decision_tree.R` | The code that runs a shift model: `shift_model()`, `score_shift()`, `compare_models()`, `tree_table()`, and the checks on each part |
| `R/shift_models.R` | The models themselves: probability matrix, trees, Gate 3, modifiers. Edit this to change a model |
| `R/emission_factors.R` | The factor table, from the workbook and the COPERT export |
| `R/emissions.R` | `add_main_mode()`, `add_current_emissions()`, `add_savings()`, `total_savings()` |
| `R/chart_style.R`, `R/plots.R` | Chart theme and one `plot_*()` function per chart |

The tests in `tests/testthat` cover the tree machinery, the factors and the
emissions maths, and check each model's counts against the group's diagrams.

## Adding a package

Ask the group first, so everyone installs it too. Then:

1. In the Console: `renv::install("packagename")`
2. Add `packagename` to the `Imports:` list in `DESCRIPTION`
3. In the Console: `renv::snapshot()`

The others then run `renv::restore()` to get it. Only add packages that are
on CRAN: a GitHub package would make everyone's `renv::restore()` try to
compile it.

## If something goes wrong

| You see | Try |
|---|---|
| No **Version Control** option in New Project, or no **Git** choice | Git isn't installed, or RStudio hasn't found it. Do step 2, then restart RStudio |
| `cannot open file 'R/survey_codebook.R'` | You opened `main.R` without the project. Close RStudio and double-click the `.Rproj` file |
| `could not find function "..."` | Run the `library()` and `source()` lines at the top of the script first |
| `there is no package called '...'` | Run `renv::restore()` |
| `renv::restore()` tries to compile something and fails | Check that you have R 4.6 (`R.version.string` in the Console) |

---

## VS Code, Neovim, just

Optional. RStudio users can skip this section, and nothing above depends on
it.

```fish
brew install --cask r-app   # R 4.6.1, CRAN build (in ~/dotfiles/Brewfile)
mise install                # just, air, pandoc (mise.toml)
just setup                  # renv.lock packages + editor tooling
just doctor                 # R, packages, pandoc, air
```

Open the folder in VS Code and accept the recommended extensions.

```fish
just run      # main.R
just charts   # make_charts.R, into output/
just test     # tests/testthat
just fmt      # format with air
```

Run `just` for the other recipes.

| What | Where |
|---|---|
| R itself | `r-app` cask. CRAN's prebuilt packages need CRAN's R build, which mise can't provide |
| CLI tooling | `mise.toml` |
| R packages wanted | `DESCRIPTION` (`just add <pkg>` to add one) |
| R packages locked | `renv.lock` (restored by `just setup` or `renv::restore()`) |
| Editor packages (languageserver, vscDebugger, jgd) | `editor_pkgs` in the `justfile`. Kept out of `renv.lock`: vscDebugger is a GitHub package with C code, so it would make every RStudio user's `renv::restore()` try to compile it |

**VS Code**:
- `Cmd+Enter` runs the line or selection in the R terminal.
- The R language server provides hover and completion.
- air formats on save.
- `F5` runs the open script under R Debugger ("Debug R-File" in
  `.vscode/launch.json`) and stops at breakpoints.
- The **R Workspace** view in the sidebar works like RStudio's Environment
  pane, for the R terminal only.
- `View()` and the Workspace view only work at the R terminal's `>` prompt,
  not in the Debug Console or at `Browse[1]>`. To look at data mid-script, run
  the lines up to that point with `Cmd+Enter`, or press `Q` at a `browser()`
  stop first.

**Neovim**, in R buffers only:

| Keys | Action |
|---|---|
| `Enter` | Send line (visual mode: send selection) |
| `\xs` / `\xq` | Start / quit R |
| `\xc` | Send chunk |
| `\xa` | Send file |
| `\xh` | Help for word |
| `\xv` | View data.frame |
