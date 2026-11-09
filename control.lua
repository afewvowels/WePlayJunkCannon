-- WePlay: Junk Cannon (Factorio 2.1)
-- The furnace bakes junk into shells natively. This script:
--   * pairs each furnace with a hidden gun,
--   * chambers one shell at a time from the furnace output into the gun,
--   * forwards any damage the gun takes to the furnace (so biters can't
--     get stuck chewing on an invulnerable turret),
--   * migrates old 0.1.x saves.

local BASE, OLD_BASE   = "wp-junk-cannon", "weplay-junk-cannon"
local GUN, OLD_GUN     = "wp-junk-cannon-gun", "weplay-junk-cannon-gun"
local SHELL, OLD_SHELL = "wp-junk-shell", "weplay-junk-shell"
local TICK_INTERVAL    = 5
local GUN_HEALTH       = 1000000 -- must match max_health in data.lua

---------------------------------------------------------------- storage
-- storage.wp_junk_cannons[base_unit] = {base=LuaEntity, gun=LuaEntity, gun_unit=uint}
-- storage.wp_junk_gun_owner[gun_unit] = base_unit
local function cannons()
  storage.wp_junk_cannons = storage.wp_junk_cannons or {}
  return storage.wp_junk_cannons
end

local function owners()
  storage.wp_junk_gun_owner = storage.wp_junk_gun_owner or {}
  return storage.wp_junk_gun_owner
end

---------------------------------------------------------------- pairing
local function register(base)
  if not (base and base.valid and base.name == BASE) then return end
  -- 0.1.x paused full furnaces with disabled_by_script; clear it on old saves.
  base.disabled_by_script = false
  local id = base.unit_number
  local rec = cannons()[id]
  if rec and rec.gun and rec.gun.valid then return end
  local gun = base.surface.create_entity{
    name = GUN, position = base.position, force = base.force,
    create_build_effect_smoke = false, raise_built = false
  }
  if not gun then return end
  cannons()[id] = {base = base, gun = gun, gun_unit = gun.unit_number}
  owners()[gun.unit_number] = id
end

local function unregister(id)
  local rec = cannons()[id]
  if not rec then return end
  if rec.gun_unit then owners()[rec.gun_unit] = nil end
  if rec.gun and rec.gun.valid then rec.gun.destroy() end
  cannons()[id] = nil
end

---------------------------------------------------------------- shells stay put
-- Junk Shells only ever live inside a Junk Cannon. Any that end up anywhere
-- else (taken out by hand, or returned when a cannon is mined) go back to the
-- cannon the player has open, or are deleted.
local function opened_cannon_output(player)
  local opened = player.opened
  if opened and type(opened) ~= "number" and opened.object_name == "LuaEntity"
     and opened.valid and opened.name == BASE then
    return opened.get_inventory(defines.inventory.crafter_output)
  end
end

local function take_back(player, inv)
  if not (inv and inv.valid) then return end
  for _, name in pairs{SHELL, OLD_SHELL} do
    local count = inv.get_item_count(name)
    if count > 0 then
      inv.remove{name = name, count = count}
      local output = name == SHELL and opened_cannon_output(player)
      if output then output.insert{name = SHELL, count = count} end
    end
  end
end

local function clean_player(player)
  if not (player and player.valid) then return end
  local cursor = player.cursor_stack
  if cursor and cursor.valid_for_read and (cursor.name == SHELL or cursor.name == OLD_SHELL) then
    local count, name = cursor.count, cursor.name
    cursor.clear()
    local output = name == SHELL and opened_cannon_output(player)
    if output then output.insert{name = SHELL, count = count} end
  end
  take_back(player, player.get_main_inventory())
  take_back(player, player.get_inventory(defines.inventory.character_ammo))
  take_back(player, player.get_inventory(defines.inventory.character_trash))
end

---------------------------------------------------------------- ghosts
-- Ghosts only show the furnace, so draw the cannon head on top of them. The
-- drawing is tied to the ghost and disappears with it when it's built or
-- removed.
local GHOST_TINT = {r = 0.45, g = 0.6, b = 0.85, a = 0.55}

local function draw_ghost_head(ghost)
  if not (ghost and ghost.valid and ghost.type == "entity-ghost" and ghost.ghost_name == BASE) then
    return
  end
  rendering.draw_sprite{sprite = "wp-junk-cannon-ghost-head", target = ghost,
    surface = ghost.surface, tint = GHOST_TINT, render_layer = "object"}
end

---------------------------------------------------------------- 0.1.x migration
-- Old chest-based cannons become furnaces. A furnace has one input slot, so
-- extra stacks are spilled on the ground, never silently deleted.
local function migrate_chest(chest)
  local surface, position, force = chest.surface, chest.position, chest.force
  local old_inv = chest.get_inventory(defines.inventory.chest)
  local items = {}
  if old_inv then
    for i = 1, #old_inv do
      local stack = old_inv[i]
      if stack.valid_for_read then
        items[#items + 1] = {name = stack.name, count = stack.count, quality = stack.quality.name}
      end
    end
    old_inv.clear()
  end
  chest.destroy{raise_destroy = false}
  local base = surface.create_entity{name = BASE, position = position, force = force,
    create_build_effect_smoke = false, raise_built = false}
  local function spill(item)
    surface.spill_item_stack{position = position, stack = item, enable_looted = true, force = force}
  end
  if not base then
    for _, item in ipairs(items) do spill(item) end
    return
  end
  local input = base.get_inventory(defines.inventory.crafter_input)
  local fuel = base.get_fuel_inventory()
  for _, item in ipairs(items) do
    local remaining = item.count
    local proto = prototypes.item[item.name]
    if fuel and proto and proto.fuel_value > 0 then
      remaining = remaining - fuel.insert(item)
    end
    if remaining > 0 and input then
      remaining = remaining - input.insert{name = item.name, count = remaining, quality = item.quality}
    end
    if remaining > 0 then
      spill{name = item.name, count = remaining, quality = item.quality}
    end
  end
end

-- Rebuilds every pairing. Runs on init and on any mod change. Current guns
-- are kept and re-paired with their furnace, so a loaded shell stays in the
-- cannon (full cannons used to spill it on every mod update). Only 0.1.x guns
-- are replaced, and their shells are handed back to the furnace.
local function rebuild()
  storage.wp_junk_cannons = {}
  storage.wp_junk_gun_owner = {}
  rendering.clear(script.mod_name)
  for _, player in pairs(game.players) do clean_player(player) end
  for _, surface in pairs(game.surfaces) do
    local recovered = {}
    for _, oldgun in pairs(surface.find_entities_filtered{name = OLD_GUN}) do
      local inv = oldgun.get_inventory(defines.inventory.turret_ammo)
      local count = inv and (inv.get_item_count(SHELL) + inv.get_item_count(OLD_SHELL)) or 0
      local key = oldgun.position.x .. ":" .. oldgun.position.y
      recovered[key] = (recovered[key] or 0) + count
      oldgun.destroy()
    end
    local guns = {}
    for _, gun in pairs(surface.find_entities_filtered{name = GUN}) do
      local key = gun.position.x .. ":" .. gun.position.y
      if guns[key] then gun.destroy() else guns[key] = gun end -- never two per spot
    end
    for _, chest in pairs(surface.find_entities_filtered{name = OLD_BASE}) do
      migrate_chest(chest)
    end
    for _, base in pairs(surface.find_entities_filtered{name = BASE}) do
      local key = base.position.x .. ":" .. base.position.y
      local gun = guns[key]
      if gun then
        guns[key] = nil
        base.disabled_by_script = false
        cannons()[base.unit_number] = {base = base, gun = gun, gun_unit = gun.unit_number}
        owners()[gun.unit_number] = base.unit_number
      else
        register(base)
      end
      local count = recovered[key] or 0
      if count > 0 then
        local output = base.get_inventory(defines.inventory.crafter_output)
        if output then count = count - output.insert{name = SHELL, count = count} end
        if count > 0 then
          surface.spill_item_stack{position = base.position, stack = {name = SHELL, count = count},
            enable_looted = true, force = base.force}
        end
      end
    end
    -- Shells older versions dropped on the ground.
    for _, item in pairs(surface.find_entities_filtered{name = "item-on-ground"}) do
      local stack = item.stack
      if stack and stack.valid_for_read and (stack.name == SHELL or stack.name == OLD_SHELL) then
        item.destroy()
      end
    end
    for _, ghost in pairs(surface.find_entities_filtered{ghost_name = BASE}) do
      draw_ghost_head(ghost)
    end
    -- Guns whose furnace is gone: give back their shell and remove them.
    for _, gun in pairs(guns) do
      local inv = gun.get_inventory(defines.inventory.turret_ammo)
      local count = inv and inv.get_item_count(SHELL) or 0
      if count > 0 then
        surface.spill_item_stack{position = gun.position, stack = {name = SHELL, count = count},
          enable_looted = true}
      end
      gun.destroy()
    end
  end
end

---------------------------------------------------------------- events
local function on_built(event)
  local entity = event.entity or event.destination
  if entity and entity.valid and entity.type == "entity-ghost" then
    draw_ghost_head(entity)
  else
    register(entity)
  end
end

-- Runs only once the cannon is really mined (not when mining fails because
-- the inventory is full). Its shells are deleted from the mined items, and
-- the hidden gun goes with it.
local function on_mined(event)
  local base = event.entity
  if not (base and base.valid) then return end
  local buffer = event.buffer
  if buffer and buffer.valid then
    for _, name in pairs{SHELL, OLD_SHELL} do
      local count = buffer.get_item_count(name)
      if count > 0 then buffer.remove{name = name, count = count} end
    end
  end
  unregister(base.unit_number)
end

local function on_died(event)
  local base = event.entity
  if base and base.valid then unregister(base.unit_number) end
end

-- Hits on the hidden gun land on the furnace instead, using the furnace's
-- own resistances. The gun is topped back up to full health every hit.
local function on_gun_damaged(event)
  local gun = event.entity
  if not (gun and gun.valid) then return end
  gun.health = GUN_HEALTH
  local id = owners()[gun.unit_number]
  local rec = id and cannons()[id]
  local base = rec and rec.base
  if not (base and base.valid) then return end
  base.damage(event.original_damage_amount, event.force or "enemy",
    event.damage_type.name, event.source, event.cause)
end

local base_filter = {{filter = "name", name = BASE}}
local built_filter = {{filter = "name", name = BASE}, {filter = "ghost_name", name = BASE}}
local e = defines.events

script.on_init(rebuild)
script.on_configuration_changed(rebuild)

for _, ev in pairs{e.on_built_entity, e.on_robot_built_entity, e.on_space_platform_built_entity,
                   e.script_raised_built, e.script_raised_revive, e.on_entity_cloned} do
  if ev then script.on_event(ev, on_built, built_filter) end
end
for _, ev in pairs{e.on_player_mined_entity, e.on_robot_mined_entity, e.on_space_platform_mined_entity,
                   e.script_raised_destroy} do
  if ev then script.on_event(ev, on_mined, base_filter) end
end

local function on_player_items_changed(event)
  clean_player(game.get_player(event.player_index))
end
for _, ev in pairs{e.on_player_cursor_stack_changed, e.on_player_main_inventory_changed,
                   e.on_player_ammo_inventory_changed, e.on_player_trash_inventory_changed} do
  if ev then script.on_event(ev, on_player_items_changed) end
end
script.on_event(e.on_entity_died, on_died, base_filter)
script.on_event(e.on_entity_damaged, on_gun_damaged, {{filter = "name", name = GUN}})

-- Chamber a shell whenever the gun is empty. The furnace stops on its own
-- when its 10-shell output slot is full.
script.on_nth_tick(TICK_INTERVAL, function()
  local broken
  for id, rec in pairs(cannons()) do
    local base, gun = rec.base, rec.gun
    if not (base.valid and gun and gun.valid) then
      broken = broken or {}
      broken[#broken + 1] = id
    else
      local ammo = gun.get_inventory(defines.inventory.turret_ammo)
      if ammo and ammo.is_empty() then
        local output = base.get_inventory(defines.inventory.crafter_output)
        if output and output.get_item_count(SHELL) > 0
           and ammo.insert{name = SHELL, count = 1} == 1 then
          output.remove{name = SHELL, count = 1}
        end
      end
    end
  end
  -- Clean up outside the loop (Lua forbids adding keys mid-traversal).
  if broken then
    for _, id in ipairs(broken) do
      local base = cannons()[id].base
      unregister(id)
      if base.valid then register(base) end -- gun lost somehow: recreate it
    end
  end
end)
