-- WePlay: Junk Cannon (Factorio 2.1)
-- A native burner furnace (wp-junk-cannon) with a hidden ammo turret
-- (wp-junk-cannon-gun) sitting on top. control.lua moves shells between them.
-- The "weplay-*" prototypes are kept only so 0.1.1 saves can migrate.

local gfx = "__WePlayJunkCannon__/graphics/"
local startup = settings.startup
local DAMAGE   = startup["wp-junk-cannon-shell-damage"].value
local COOLDOWN = startup["wp-junk-cannon-fire-cooldown"].value
local RANGE    = startup["wp-junk-cannon-range"].value

---------------------------------------------------------------- graphics
-- Sizes and shifts come from graphics/sprites.lua, written by pack_sheets.py.
local sprites = require("graphics.sprites")

-- Shrinks the renders in game. 1 = full render size (about 3 tiles wide).
local SIZE = 0.6
-- Moves every layer down (in tiles) so the base sits on the ground like
-- the stone furnace.
local OFFSET_Y = 0.6

local function layer(entry)
  local l = table.deepcopy(entry)
  l.scale = sprites.scale * SIZE
  l.shift = {entry.shift[1] * SIZE, entry.shift[2] * SIZE + OFFSET_Y}
  return l
end

local blank = {filename = gfx .. "transparent.png", width = 8, height = 8}
-- Head: 64 directions, frame 0 = north, clockwise, plus its shadow.
local cannon = {layers = {layer(sprites.head), layer(sprites.head_shadow)}}

---------------------------------------------------------------- hidden gun
local gun = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
gun.name = "wp-junk-cannon-gun"
gun.localised_name = {"entity-name.wp-junk-cannon"}
gun.icon = gfx .. "junk-cannon-icon.png"
gun.icon_size = 64
gun.icons = nil
gun.hidden = true
-- Inserters must never feed or empty the gun directly; script owns its ammo.
gun.flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
  "no-automated-item-insertion", "no-automated-item-removal", "not-flammable"}
gun.minable = nil
gun.collision_mask = {layers = {}}
gun.collision_box = {{0, 0}, {0, 0}}
gun.selection_box = {{0, 0}, {0, 0}}
-- Huge health: control.lua forwards every hit to the furnace and refills this.
gun.max_health = 1000000
gun.healing_per_tick = 0
gun.corpse = nil
gun.dying_explosion = nil
gun.inventory_size = 1
gun.automated_ammo_count = 0
gun.rotation_speed = 0.015
gun.preparing_speed = 1
gun.folding_speed = 1
gun.attacking_speed = 1
gun.folded_animation = cannon
gun.preparing_animation = cannon
gun.prepared_animation = cannon
gun.attacking_animation = cannon
gun.folding_animation = cannon
gun.graphics_set = {base_visualisation = {animation = blank}}
gun.attack_parameters = {
  type = "projectile", ammo_category = "wp-junk-shell",
  cooldown = COOLDOWN, range = RANGE, min_range = 0,
  -- Shot effects (the smoke puff) start where the barrel meets the cannon
  -- body: about 3.5 tiles up the full-size render, at the pivot.
  projectile_center = {0, -3.55 * SIZE + OFFSET_Y},
  projectile_creation_distance = 0,
  sound = {
    filename = "__WePlayJunkCannon__/sound/junk-cannon-fire.ogg",
    volume = 0.3,
    -- A whole row firing at once plays at most 3 booms.
    aggregation = {max_count = 3, remove = true, count_already_playing = true},
  }
}
gun.circuit_connector = nil
gun.circuit_wire_max_distance = nil
gun.water_reflection = nil
-- The cannon is tall: keep drawing it when its base is just off-screen.
gun.drawing_box_vertical_extension = 5
-- No alt-mode ammo icon drawn over the furnace window.
gun.icon_draw_specification = {scale = 0}

---------------------------------------------------------------- furnace base
-- Copying stone-furnace keeps working 2.1 burner, smoke, sound and the
-- glowing fire window until custom sprites replace graphics_set.
local furnace = table.deepcopy(data.raw["furnace"]["stone-furnace"])
furnace.name = "wp-junk-cannon"
furnace.localised_name = {"entity-name.wp-junk-cannon"}
furnace.localised_description = {"entity-description.wp-junk-cannon"}
furnace.icon = gfx .. "junk-cannon-icon.png"
furnace.icon_size = 64
furnace.icons = nil
furnace.minable = {mining_time = 0.5, result = "wp-junk-cannon"}
furnace.max_health = 200
furnace.crafting_categories = {"wp-junk-processing"}
furnace.crafting_speed = 1
furnace.source_inventory_size = 1
-- One 10-stack output slot: the furnace stops by itself ("Output full")
-- once 10 shells are waiting, plus the one chambered in the gun.
furnace.result_inventory_size = 1
furnace.energy_usage = "90kW"
furnace.allowed_effects = {}
furnace.module_slots = 0
furnace.fast_replaceable_group = nil
furnace.next_upgrade = nil
furnace.collision_box = {{-0.8, -0.8}, {0.8, 0.8}}
furnace.selection_box = {{-1, -1}, {1, 1}}
-- Shells never leave the cannon: inserters and loaders can't take them out.
furnace.flags = {"placeable-neutral", "placeable-player", "player-creation",
  "no-automated-item-removal"}

-- Base and its shadow come from sprites.lua. The window glow is an additive
-- layer cut to the same size and shift as the base, flickering only while
-- baking. Everything draws on "lower-object" so the cannon head (hidden
-- turret, normal "object" layer, same position) always draws on top.
local glow = layer(sprites.base)
glow.filename = gfx .. "junk-cannon-window-glow.png"
glow.draw_as_glow = true
glow.blend_mode = "additive"

-- Looping flames (16 frames), cut to the window shape, same box as the base.
local fire = layer(sprites.base)
fire.filename = gfx .. "junk-cannon-fire.png"
fire.frame_count = 16
fire.line_length = 8
fire.animation_speed = 0.3
fire.draw_as_glow = true

furnace.graphics_set = {
  working_visualisations = {
    {
      always_draw = true,
      render_layer = "lower-object",
      animation = {layers = {layer(sprites.base), layer(sprites.base_shadow)}},
    },
    {
      fadeout = true,
      effect = "flicker",
      render_layer = "lower-object",
      animation = glow,
      light = {intensity = 0.4, size = 3, shift = {0, 0.03 + OFFSET_Y}, color = {1, 0.55, 0.2}},
    },
    {
      fadeout = true,
      render_layer = "lower-object",
      animation = fire,
    },
  },
}
furnace.drawing_box_vertical_extension = 2
-- No alt-mode shell icon drawn over the furnace window.
furnace.show_recipe_icon = false

-- The head belongs to the hidden turret, which only exists once the cannon is
-- built. control.lua draws this one frame of it (barrel to the upper left)
-- on Junk Cannon ghosts, so blueprints show the whole cannon.
local ghost_head = layer(sprites.head)
local GHOST_FRAME = 56
ghost_head.type = "sprite"
ghost_head.name = "wp-junk-cannon-ghost-head"
ghost_head.x = (GHOST_FRAME % ghost_head.line_length) * ghost_head.width
ghost_head.y = math.floor(GHOST_FRAME / ghost_head.line_length) * ghost_head.height
ghost_head.direction_count = nil
ghost_head.line_length = nil
furnace.water_reflection = nil

---------------------------------------------------------------- ammo
local function junk_ammo(name, category, order)
  return {
    type = "ammo", name = name, hidden = true,
    icon = gfx .. "junk-shell-icon.png", icon_size = 64,
    stack_size = 10, magazine_size = 1, ammo_category = category,
    subgroup = "ammo", order = order,
    ammo_type = {
      target_type = "entity",
      action = {
        type = "direct",
        action_delivery = {
          type = "instant",
          -- A puff of smoke at the cannon instead of the gun turret's muzzle flash.
          source_effects = {
            type = "create-trivial-smoke", smoke_name = "artillery-smoke",
            initial_height = 0, max_radius = 0.4, repeat_count = 6,
            speed_from_center = 0.02, speed_from_center_deviation = 0.01,
            offset_deviation = {{-0.2, -0.2}, {0.2, 0.2}},
          },
          target_effects = {
            {type = "create-entity", entity_name = "explosion-hit", offsets = {{0, 1}},
              offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}}},
            {type = "damage", damage = {amount = DAMAGE, type = "physical"}}
          }
        }
      }
    }
  }
end

---------------------------------------------------------------- legacy (0.1.1 saves)
local legacy = table.deepcopy(data.raw["container"]["wooden-chest"])
legacy.name = "weplay-junk-cannon"
legacy.localised_name = {"entity-name.weplay-junk-cannon"}
legacy.icon = gfx .. "junk-cannon-icon.png"
legacy.icon_size = 64
legacy.icons = nil
legacy.hidden = true
legacy.flags = {"placeable-player", "player-creation", "not-on-map"}
legacy.minable = {mining_time = 0.5, result = "wp-junk-cannon"}
legacy.inventory_size = 16
legacy.collision_box = {{-0.8, -0.8}, {0.8, 0.8}}
legacy.selection_box = {{-1, -1}, {1, 1}}
legacy.picture = {filename = gfx .. "furnace-base.png", width = 192, height = 192,
  scale = 0.5, shift = {0, -0.15}}

local legacy_gun = table.deepcopy(gun)
legacy_gun.name = "weplay-junk-cannon-gun"
legacy_gun.attack_parameters.ammo_category = "weplay-junk-shell"

local recipe_ingredients = {
  {type = "item", name = "iron-plate", amount = 8},
  {type = "item", name = "stone-furnace", amount = 1},
  {type = "item", name = "iron-gear-wheel", amount = 4},
}

data:extend({
  {type = "recipe-category", name = "wp-junk-processing"},
  {type = "ammo-category", name = "wp-junk-shell"},
  {type = "ammo-category", name = "weplay-junk-shell", hidden = true},
  junk_ammo("wp-junk-shell", "wp-junk-shell", "z[wp-junk-shell]"),
  junk_ammo("weplay-junk-shell", "weplay-junk-shell", "z[weplay-junk-shell]"),
  {type = "item", name = "wp-junk-cannon", icon = gfx .. "junk-cannon-icon.png", icon_size = 64,
    subgroup = "defensive-structure", order = "a[wp-junk-cannon]",
    place_result = "wp-junk-cannon", stack_size = 50},
  {type = "item", name = "weplay-junk-cannon", icon = gfx .. "junk-cannon-icon.png", icon_size = 64,
    hidden = true, subgroup = "defensive-structure", order = "z[legacy-junk-cannon]",
    place_result = "wp-junk-cannon", stack_size = 50},
  {type = "recipe", name = "wp-junk-cannon", enabled = true, energy_required = 3,
    ingredients = recipe_ingredients,
    results = {{type = "item", name = "wp-junk-cannon", amount = 1}}},
  furnace, gun, legacy, legacy_gun, ghost_head
})
