# TS: Ubike Rental Program Project

## Setup

```fish
brew install --cask r-app   # R 4.6.1, CRAN build (in ~/dotfiles/Brewfile)
mise install                # just, air, pandoc -- pinned in mise.toml
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

## Editors

**VS Code**:
- `Cmd+Enter` runs the line or selection in the R terminal.
- The R language server provides hover and completion.
- air formats on save.
- `F5` runs the open script under R Debugger ("Debug R-File" in
  `.vscode/launch.json`) and stops at breakpoints. Its `vscDebugger` package
  is in renv.lock. When paused, inspect data with `dplyr::glimpse()` in the
  Debug Console.
- The **R Workspace** view in the sidebar is RStudio's Environment pane for
  the R terminal: each data frame's view icon opens it in the data viewer.
  It shows the terminal's objects, never the debugger's.
- `View()` and the Workspace view work only at the R terminal's top-level `>`
  prompt. They fail in the Debug Console and at a `Browse[1]>` prompt, because
  the viewer's callbacks only run at the top level. To browse data mid-script,
  select the lines up to that point and press `Cmd+Enter`. At a `browser()`
  stop, press `Q` first: the objects created so far stay in the workspace.

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
