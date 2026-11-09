-- Generates a hidden "1 item -> 1 junk shell" recipe for every item from
-- every mod. Runs in final-fixes so items added by other mods are included.
local CRAFT_TIME = settings.startup["wp-junk-cannon-craft-time"].value

-- All item subtypes the engine knows about, with a fallback list.
local item_types = {}
if defines and defines.prototypes and defines.prototypes.item then
  for kind in pairs(defines.prototypes.item) do item_types[#item_types + 1] = kind end
else
  item_types = {
    "item", "ammo", "capsule", "gun", "armor", "module", "tool", "repair-tool",
    "item-with-entity-data", "item-with-inventory", "item-with-label", "item-with-tags",
    "blueprint", "blueprint-book", "deconstruction-item", "upgrade-item",
    "selection-tool", "copy-paste-tool", "rail-planner", "space-platform-starter-pack",
  }
end

-- Never make shell-recycling loops.
local excluded = {["wp-junk-shell"] = true, ["weplay-junk-shell"] = true}

-- By default, anything the cannon's burner can burn is fuel only, so
-- inserters never put coal or wood in the junk slot.
local FUEL_AS_JUNK = settings.startup["wp-junk-cannon-fuel-as-junk"].value
local burner_categories = {}
do
  local cannon = data.raw.furnace["wp-junk-cannon"]
  local source = cannon and cannon.energy_source or {}
  for _, cat in pairs(source.fuel_categories or {source.fuel_category or "chemical"}) do
    burner_categories[cat] = true
  end
end

local function is_burner_fuel(prototype)
  if not prototype.fuel_value then return false end
  local cats = prototype.fuel_categories or {prototype.fuel_category or "chemical"}
  for _, cat in pairs(cats) do
    if burner_categories[cat] then return true end
  end
  return false
end

local recipes = {}
for _, kind in ipairs(item_types) do
  for name, prototype in pairs(data.raw[kind] or {}) do
    local recipe_name = "wp-junk-process-" .. name
    if not excluded[name] and not prototype.parameter and not data.raw.recipe[recipe_name]
       and (FUEL_AS_JUNK or not is_burner_fuel(prototype)) then
      recipes[#recipes + 1] = {
        type = "recipe", name = recipe_name, categories = {"wp-junk-processing"},
        enabled = true, hidden = true, energy_required = CRAFT_TIME,
        ingredients = {{type = "item", name = name, amount = 1}},
        results = {{type = "item", name = "wp-junk-shell", amount = 1}},
        can_set_quality = false, allow_quality = false,
        allow_productivity = false, auto_recycle = false,
        hide_from_stats = true, hide_from_signal_gui = true,
        allow_inserter_overload = false,
        localised_name = {"recipe-name.wp-junk-processing"}
      }
    end
  end
end

-- Extend in chunks to stay friendly with very large modpacks.
for i = 1, #recipes, 256 do
  local batch = {}
  for j = i, math.min(i + 255, #recipes) do batch[#batch + 1] = recipes[j] end
  data:extend(batch)
end
