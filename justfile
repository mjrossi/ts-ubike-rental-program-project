# ts-ubike-rental-program-project -- common commands.
# Run `just` (no args) to list recipes, organized by group.
#
# `just` itself is pinned in mise.toml; a single `mise install` provisions it
# alongside air and pandoc. R comes from the r-app cask (see mise.toml).
#
# Recipes go through `mise exec --` so the pinned air and pandoc are on PATH
# even where mise isn't shell-activated -- rmarkdown::render finds pandoc via
# PATH. R's own startup sources .Rprofile, which activates renv, so every
# Rscript below sees the project library rather than the user one.

set shell := ["bash", "-euo", "pipefail", "-c"]

# ── default ───────────────────────────────────────────

[private]
default:
    @just --list --unsorted

# ── setup ─────────────────────────────────────────────

# install the exact package versions in renv.lock
[group('setup')]
setup:
    mise exec -- Rscript -e 'renv::restore(prompt = FALSE)'

# install everything DESCRIPTION lists and record it in renv.lock
[group('setup')]
sync:
    mise exec -- Rscript -e 'renv::install(prompt = FALSE); renv::snapshot(prompt = FALSE)'

# add a package (CRAN name, or user/repo for GitHub) to DESCRIPTION and renv.lock
[group('setup')]
add pkg:
    mise exec -- Rscript -e 'renv::install("{{pkg}}", prompt = FALSE); desc::desc_set_dep(basename("{{pkg}}"), "Imports"); if (grepl("/", "{{pkg}}")) desc::desc_add_remotes("{{pkg}}"); renv::snapshot(prompt = FALSE)'

# check that R, the spatial stack, pandoc and air are all wired up
[group('setup')]
doctor:
    mise exec -- Rscript -e 'cat(R.version.string, "\n"); cat("library:", .libPaths()[1], "\n"); pkgs <- desc::desc_get_deps()$package; pkgs <- setdiff(pkgs, "R"); ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE); print(ok); print(sf::sf_extSoftVersion()); cat("pandoc:", as.character(rmarkdown::pandoc_version()), "\n"); stopifnot(all(ok))'
    mise exec -- air --version

# ── dev ───────────────────────────────────────────────

# R console in the project (renv active)
[group('dev')]
console:
    mise exec -- R --quiet --no-save

# render an R Markdown file to its default output format
[group('dev')]
render file:
    mise exec -- Rscript -e 'rmarkdown::render("{{file}}")'

# ── check ─────────────────────────────────────────────

# format R code with air
[group('check')]
fmt:
    mise exec -- air format .

# fail if any R file isn't air-formatted
[group('check')]
fmt-check:
    mise exec -- air format --check .
