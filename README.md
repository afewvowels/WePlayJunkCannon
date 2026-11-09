# WePlay: Junk Cannon

A cozy early-game turret for Factorio 2.1. The Junk Cannon is a burner furnace with a big cannon bolted on top. Feed it fuel and *anything else*, from any mod, and it bakes the junk into shells and shoots them at enemies.

## How it works

- Unlocked from the start. Recipe: 8 iron plates, 4 iron gears, 1 stone furnace.
- Fuel goes in the burner slot. Any other item goes in the input slot and becomes one Junk Shell (2 seconds each by default).
- Holds 10 shells in its output plus 1 in the cannon. When it's full, the furnace stops with "Output full".
- Shells that are already baked still fire when the fuel runs out.
- Damage, fire rate, range and bake time are startup settings.

## Known issues and limits

- Fuel (coal, wood, solid fuel...) only goes in the burner slot, so a mixed chest or belt feeds fuel and junk correctly. Turn on the "Fuel can be used as junk" startup setting to bake fuel into shells too.
- The input slot holds one item type at a time.
- Quality is ignored, so a legendary item makes a normal shell. Valuable items are not protected.
- Area damage (spitter acid, explosions) can hit the furnace twice: once directly and once through the hidden cannon.

## Replacing the art

Render the head (64 directions, north first, clockwise), the base, and a shadow pass for each, then run `pack_sheets.py`. It writes the packed sheets plus `graphics/sprites.lua`, which `data.lua` reads for every size and shift, so no Lua editing is needed.

## Upgrading from 0.1.x (weplay-junk-cannon)

Back up your save first. Old chest-style cannons become furnaces. Extra stacks they held are spilled on the ground, never deleted. The `weplay-*` legacy prototypes exist only for this migration.
