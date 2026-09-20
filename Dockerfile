# Pinned analysis environment.
# rocker/verse ships R + tidyverse + Quarto + a LaTeX stack on a fixed R version.
FROM rocker/verse:4.4.1

# Posit Package Manager snapshot: freezes CRAN to a date, so `install.packages`
# resolves the same versions on every build without maintaining a renv.lock.
ENV CRAN_SNAPSHOT=https://packagemanager.posit.co/cran/2026-09-01
RUN echo "options(repos = c(CRAN = '${CRAN_SNAPSHOT}'))" >> /usr/local/lib/R/etc/Rprofile.site

RUN apt-get update && apt-get install -y --no-install-recommends \
      libcurl4-openssl-dev libssl-dev libxml2-dev make \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /project
COPY dependencies.txt /tmp/dependencies.txt
RUN Rscript -e 'pkgs <- readLines("/tmp/dependencies.txt"); \
                pkgs <- pkgs[nzchar(pkgs)]; \
                install.packages(pkgs, Ncpus = parallel::detectCores())' \
 && Rscript -e 'stopifnot(all(readLines("/tmp/dependencies.txt") %in% rownames(installed.packages())))'

CMD ["make", "all"]
