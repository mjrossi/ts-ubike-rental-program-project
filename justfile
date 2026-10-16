# Recipes use `mise exec --` so the pinned air and pandoc are on PATH.

set shell := ["bash", "-euo", "pipefail", "-c"]

[private]
default:
    @just --list --unsorted

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

# run main.R: survey, decision tree, emission savings
[group('dev')]
run:
    mise exec -- Rscript main.R

# R console in the project (renv active)
[group('dev')]
console:
    mise exec -- R --quiet --no-save

# render an R Markdown file to its default output format
[group('dev')]
render file:
    mise exec -- Rscript -e 'rmarkdown::render("{{file}}")'

# format R code with air
[group('check')]
fmt:
    mise exec -- air format .

# fail if any R file isn't air-formatted
[group('check')]
fmt-check:
    mise exec -- air format --check .

# run the tests in tests/testthat
[group('check')]
test:
    mise exec -- Rscript -e 'testthat::test_dir("tests/testthat")'
