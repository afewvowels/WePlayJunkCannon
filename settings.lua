-- Startup settings so alpha testers can tune balance without editing code.
data:extend({
  {
    type = "double-setting", name = "wp-junk-cannon-shell-damage",
    setting_type = "startup", default_value = 5, minimum_value = 1, maximum_value = 1000,
    order = "a"
  },
  {
    type = "int-setting", name = "wp-junk-cannon-fire-cooldown",
    setting_type = "startup", default_value = 120, minimum_value = 10, maximum_value = 600,
    order = "b"
  },
  {
    type = "int-setting", name = "wp-junk-cannon-range",
    setting_type = "startup", default_value = 13, minimum_value = 5, maximum_value = 30,
    order = "c"
  },
  {
    type = "double-setting", name = "wp-junk-cannon-craft-time",
    setting_type = "startup", default_value = 2, minimum_value = 0.25, maximum_value = 30,
    order = "d"
  },
  {
    type = "bool-setting", name = "wp-junk-cannon-fuel-as-junk",
    setting_type = "startup", default_value = false,
    order = "e"
  },
})
