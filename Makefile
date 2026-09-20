SHELL := /bin/bash
R     := Rscript
DOCKER_IMAGE := wa-education-roi:latest

.PHONY: all data data-refresh test render publish clean docker-build docker-run help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

all: data test render ## Fetch, validate, and render

data: ## Pull NAEP, finance, and deflator data into data/
	$(R) R/01_fetch_naep.R
	$(R) R/02_fetch_finance.R
	$(R) R/04_build_panel.R

data-refresh: ## Force re-fetch, ignoring the RDS cache
	$(R) -e 'source("R/04_build_panel.R"); build_analysis_panel(refresh = TRUE)'

test: ## Validate API pulls against hand-verified published figures
	$(R) -e 'testthat::test_file("tests/test_anchors.R", stop_on_failure = TRUE)'

render: ## Render the Quarto site to _site/
	quarto render

publish: render ## Render, then hand _site/ to publish-web.sh
	@bash scripts/publish.sh

clean: ## Remove rendered output and derived data (keeps raw cache)
	rm -rf _site .quarto data/processed/* figures/*
	@touch data/processed/.gitkeep figures/.gitkeep

docker-build: ## Build the pinned analysis image
	docker build -t $(DOCKER_IMAGE) .

docker-run: ## Run the full pipeline inside the container
	docker run --rm -v "$$PWD":/project $(DOCKER_IMAGE) make all

docker-shell: ## Interactive R session in the container
	docker run --rm -it -v "$$PWD":/project $(DOCKER_IMAGE) bash
