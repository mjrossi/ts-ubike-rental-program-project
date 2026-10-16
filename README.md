# TS: Ubike Rental Program Project

## Setup

```fish
brew install --cask r-app   # R 4.6.1, CRAN build (in ~/dotfiles/Brewfile)
mise install                # just, air, pandoc (mise.toml)
just setup                  # course packages, pinned in renv.lock
just doctor                 # R, sf's GDAL/GEOS/PROJ, pandoc, air
```

Open the folder in VS Code and accept the recommended extensions.

## Where things live

| What | Where |
|---|---|
| R itself | `r-app` cask. CRAN's prebuilt packages (sf!) need CRAN's R build, which mise can't provide |
| CLI tooling | `mise.toml` |
| R packages wanted | `DESCRIPTION` (`just add <pkg>` to add one) |
| R packages locked | `renv.lock` (restored by `just setup`) |
| openrouteservice key | macOS Keychain: run `openrouteservice::ors_api_key("<key>")` once. An `ORS_API_KEY` env var overrides it |

## Code

`main.R` is the project's script: survey, decision tree, emission savings.
`make_charts.R` draws the descriptive charts into `output/`. Both source the
files in `R/`, which only define things:

| File | Defines |
|---|---|
| `R/survey_codebook.R` | The survey's columns and answer labels (`survey_key`), `read_survey()`, `label_survey()`, `add_groups()` and `split_modes()` |
| `R/decision_tree.R` | Tiers and their probabilities, `add_tier()`, `adjust_tier()` and `add_shift_probability()` (adds `p_shift`) |
| `R/emission_factors.R` | The g/p.km factor table for every mode, from the course Excel file and COPERT |
| `R/emissions.R` | `add_main_mode()`, `add_current_emissions()`, `add_savings()` and `total_savings()` |
| `R/chart_style.R` | Chart colours, legend wording, `theme_ubike()` and `save_chart()` (writes a chart to `output/` as a PNG) |
| `R/plots.R` | One `plot_*()` function per chart; each takes any survey table |

The project brief is `docs/project_brief.pdf`. `docs/methods.md` has the
equations, sources and assumptions behind `main.R`, for the slides.

## Editors

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

Run `just` to list the other recipes.
