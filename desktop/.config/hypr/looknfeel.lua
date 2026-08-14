-- Personal appearance overrides migrated from looknfeel.conf.
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 2,
    border_size = 1,
  },

  decoration = {
    rounding = 3,
  },
})

hl.animation({
  leaf = "workspaces",
  enabled = true,
  speed = 2,
  bezier = "easeOutQuint",
  style = "slide",
})
