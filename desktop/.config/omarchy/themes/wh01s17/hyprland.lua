local active_border_color = {
  colors = { "rgba(84c959ee)", "rgba(45d9eaee)" },
  angle = 45,
}
local inactive_border_color = "rgba(243038aa)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    rounding = 6,
    rounding_power = 2,
    shadow = {
      enabled = true,
      range = 8,
      render_power = 3,
      color = "rgba(84c95926)",
      color_inactive = "rgba(04060766)",
    },
  },
})
