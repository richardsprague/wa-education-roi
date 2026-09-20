## 06_plots.R -- shared chart theme and the figures used in index.qmd.
##
## Palette: two categorical slots (blue, orange) validated for colorblind
## separation against both light and dark surfaces. Donor/placebo units are
## deliberately NOT categorical colors -- they are an undifferentiated gray
## backdrop, because their identity carries no meaning in a placebo plot.

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(scales)
})

PAL <- list(
  series_1  = "#2a78d6",  # blue   -- Washington (the treated unit)
  series_2  = "#eb6834",  # orange -- synthetic Washington
  backdrop  = "#b8b7b1",  # donor/placebo units
  rule      = "#52514e",  # reference lines
  surface   = "#fcfcfb",
  ink       = "#0b0b0b",
  ink_muted = "#52514e"
)

theme_roi <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.background   = element_rect(fill = PAL$surface, colour = NA),
      panel.background  = element_rect(fill = PAL$surface, colour = NA),
      panel.grid.minor  = element_blank(),
      panel.grid.major  = element_line(colour = "#e6e5e1", linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      axis.title        = element_text(colour = PAL$ink_muted, size = rel(0.9)),
      axis.text         = element_text(colour = PAL$ink_muted),
      plot.title        = element_text(colour = PAL$ink, face = "bold",
                                       size = rel(1.15), margin = margin(b = 4)),
      plot.subtitle     = element_text(colour = PAL$ink_muted, size = rel(0.92),
                                       margin = margin(b = 12)),
      plot.caption      = element_text(colour = PAL$ink_muted, size = rel(0.8),
                                       hjust = 0, margin = margin(t = 12)),
      legend.position   = "top",
      legend.justification = "left",
      legend.title      = element_blank(),
      legend.text       = element_text(colour = PAL$ink_muted),
      plot.title.position = "plot",
      plot.caption.position = "plot"
    )
}

#' Vertical rule marking treatment onset, with an in-panel label.
treatment_rule <- function(year = TREAT_YEAR, label = "McCleary response begins") {
  list(
    geom_vline(xintercept = year, colour = PAL$rule,
               linetype = "dashed", linewidth = 0.4),
    annotate("text", x = year, y = Inf, label = label,
             hjust = -0.04, vjust = 1.8, size = 3.1, colour = PAL$ink_muted)
  )
}

#' Figure 1: treated vs synthetic outcome path.
plot_trends <- function(sc, title, subtitle = NULL, y_lab = "NAEP scale score") {
  d <- sc |>
    tidysynth::grab_synthetic_control() |>
    tidyr::pivot_longer(c(real_y, synth_y), names_to = "series", values_to = "value") |>
    dplyr::mutate(series = dplyr::recode(series,
      real_y  = "Washington (observed)",
      synth_y = "Synthetic Washington"
    ))

  labs_last <- d |> dplyr::group_by(series) |> dplyr::slice_max(time_unit, n = 1)

  ggplot(d, aes(time_unit, value, colour = series)) +
    treatment_rule() +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2.2) +
    ggrepel::geom_text_repel(
      data = labs_last, aes(label = series),
      hjust = 0, direction = "y", nudge_x = 0.6, size = 3.2,
      segment.colour = NA, show.legend = FALSE
    ) +
    scale_colour_manual(values = c(
      "Washington (observed)" = PAL$series_1,
      "Synthetic Washington"  = PAL$series_2
    )) +
    scale_x_continuous(breaks = NAEP_YEARS, expand = expansion(mult = c(0.02, 0.18))) +
    labs(title = title, subtitle = subtitle, x = NULL, y = y_lab,
         caption = "Source: NAEP Data Service (NCES); Census F-33 via Urban Institute Education Data Portal.") +
    theme_roi()
}

#' Figure 2: gap between treated and synthetic, centred on zero.
plot_gap <- function(sc, title, subtitle = NULL, y_lab = "Observed minus synthetic") {
  d <- sc |>
    tidysynth::grab_synthetic_control() |>
    dplyr::mutate(gap = real_y - synth_y)

  ggplot(d, aes(time_unit, gap)) +
    geom_hline(yintercept = 0, colour = PAL$rule, linewidth = 0.4) +
    treatment_rule() +
    geom_line(colour = PAL$series_1, linewidth = 0.8) +
    geom_point(colour = PAL$series_1, size = 2.2) +
    scale_x_continuous(breaks = NAEP_YEARS) +
    labs(title = title, subtitle = subtitle, x = NULL, y = y_lab,
         caption = "A flat line at zero after treatment means the reform moved nothing detectable.") +
    theme_roi()
}

#' Figure 3: placebo distribution. Every donor re-estimated as if treated.
plot_placebos <- function(sc, title, subtitle = NULL,
                          prune_ratio = 5,
                          y_lab = "Observed minus synthetic") {
  d <- tidysynth::grab_synthetic_control(sc, placebo = TRUE) |>
    dplyr::mutate(gap = real_y - synth_y)

  ## Drop placebos whose pre-period fit is far worse than WA's -- a unit the
  ## donor pool cannot reproduce before treatment tells us nothing after it.
  pre_rmspe <- d |>
    dplyr::filter(time_unit < TREAT_YEAR) |>
    dplyr::group_by(.id) |>
    dplyr::summarise(rmspe = sqrt(mean(gap^2, na.rm = TRUE)), .groups = "drop")

  wa_rmspe <- pre_rmspe$rmspe[pre_rmspe$.id == TREAT_UNIT]
  keep <- pre_rmspe$.id[pre_rmspe$rmspe <= prune_ratio * wa_rmspe]

  d <- dplyr::filter(d, .id %in% keep) |>
    dplyr::mutate(is_wa = .id == TREAT_UNIT)

  ggplot() +
    geom_hline(yintercept = 0, colour = PAL$rule, linewidth = 0.4) +
    treatment_rule() +
    geom_line(data = dplyr::filter(d, !is_wa),
              aes(time_unit, gap, group = .id),
              colour = PAL$backdrop, linewidth = 0.4, alpha = 0.8) +
    geom_line(data = dplyr::filter(d, is_wa),
              aes(time_unit, gap), colour = PAL$series_1, linewidth = 1) +
    annotate("text", x = max(d$time_unit), y = dplyr::last(d$gap[d$is_wa]),
             label = "Washington", hjust = 1, vjust = -0.9,
             colour = PAL$series_1, size = 3.4, fontface = "bold") +
    scale_x_continuous(breaks = NAEP_YEARS) +
    labs(title = title, subtitle = subtitle, x = NULL, y = y_lab,
         caption = sprintf(
           "Gray: each donor state re-estimated as if it had been treated (pre-period fit within %dx Washington's). n = %d placebos.",
           prune_ratio, length(keep) - 1L)) +
    theme_roi()
}

#' Figure 4: per-pupil revenue paths, nominal vs real cost-adjusted.
plot_spending <- function(panel, states = c("WA"), value_cols = c("rev_pp", "rev_pp_real")) {
  d <- panel |>
    dplyr::filter(state %in% states) |>
    tidyr::pivot_longer(dplyr::all_of(value_cols),
                        names_to = "measure", values_to = "value") |>
    dplyr::mutate(measure = dplyr::recode(measure,
      rev_pp      = "Nominal dollars",
      rev_pp_real = "Real, cost-of-living adjusted"
    ))

  labs_last <- d |> dplyr::group_by(measure) |> dplyr::slice_max(year, n = 1)

  ggplot(d, aes(year, value, colour = measure)) +
    treatment_rule() +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2.2) +
    ggrepel::geom_text_repel(
      data = labs_last, aes(label = measure),
      hjust = 0, direction = "y", nudge_x = 0.6, size = 3.2,
      segment.colour = NA, show.legend = FALSE
    ) +
    scale_colour_manual(values = c(
      "Nominal dollars" = PAL$series_1,
      "Real, cost-of-living adjusted" = PAL$series_2
    )) +
    scale_y_continuous(labels = scales::dollar_format(accuracy = 1)) +
    scale_x_continuous(breaks = NAEP_YEARS, expand = expansion(mult = c(0.02, 0.22))) +
    labs(
      title = "What the per-pupil increase looks like after deflating it",
      subtitle = "Washington total revenue per pupil. The nominal series is the one quoted in public debate.",
      x = NULL, y = "Revenue per pupil",
      caption = "Deflated by CPI-U to constant dollars, then by BEA Regional Price Parities for state cost differences."
    ) +
    theme_roi()
}
