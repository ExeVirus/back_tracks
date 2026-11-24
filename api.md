# Luanti Lua Modding API Reference

* **Namespace**: `core` (since 0.4.10; `minetest` kept as deprecated alias).
* **Execution**: Server-side Lua 5.1 (`double` IEEE-754 numbers). `init.lua` runs at startup in shared env; definitions/media auto-sent to clients.
* **Paths**: `path_share` (read-only engine/games/mods, e.g. `/usr/share/minetest`); `path_user` (user mods/games/worlds/settings, e.g. `~/.minetest`). Local `RUN_IN_PLACE=1` builds share one dir.
* **Numbers & Integer Ranges**: Unqualified "number" = finite Lua number (no NaN/±inf unless noted). "integer"/"int"/"amount"/"count"/"index"/"bitfield" = whole numbers only (assumed `[slua]` if range omitted). Inclusive ranges:
  * `[s16]=[-32768,32767]`, `[s32]=[-2147483648,2147483647]`, `[slua]=[-(2^53-1),2^53-1]`
  * `[u16]=[0,65535]`, `[u32]=[0,4294967295]`, `[u64]=[0,2^64-1]`, `[ulua]=[0,2^53-1]`
  * `[imagesize]=[1,23000]`, `[imageframe]=[0,22999]`

## Games
Paths: `$path_share/games/<gameid>/`, `$path_user/games/<gameid>/`.
* `game.conf`:
  * `title`: Required human-readable title (`name` deprecated).
  * `description`: Short content-tab description (translatable).
  * `first_mod`, `last_mod`: Force mod to load before/after all others.
  * `allowed_mapgens`, `disallowed_mapgens`: Comma-separated mapgens (`allowed` applied before `disallowed`).
  * `default_mapgen`: Default selection for new worlds.
  * `disallowed_mapgen_settings`: Comma-separated mapgen settings hidden in UI (`seed` hides seed input).
  * `disabled_settings`: Comma-separated from `{enable_damage, creative_mode, enable_server}`; hidden in Start tab & initialized `false` (prefix `!` initializes `true`, except `enable_server`).
  * `map_persistent`: Use persistent map backend on new worlds (default `true` = `"sqlite3"`).
  * `author`: ContentDB username. `release`: ContentDB internal ID (do not set).
  * `textdomain`: Translation domain for description (default: `<gameid>`).
  * `aliases`: Comma-separated legacy gameids to auto-load old worlds.
* Files/dirs: `minetest.conf` (default settings), `screenshot.{png,jpg,jpeg}`, `settingtypes.txt` (shown under "Games"), `mods/`, `textures/`, `menu/`.
* `menu/` images: `$identifier.png` or `$identifier.$n.png` (`$n>=1`, random pick) for `overlay`, `background`, `footer`, `header`.
* `menu/` music: `theme.ogg` or `theme.<digit>.ogg` (random pick, Sound group format).

## Mods & Media
* **Load paths**: `games/<gameid>/mods/`, `mods/`, `worlds/<worldname>/worldmods/`. If `<worldname>/game/` exists, ONLY it loads (mods in `<worldname>/game/mods/`).
* **Modpacks**: Subdir whose parent has `modpack.conf` (`name`, `title`, `description`, `author`, `release`, `textdomain`).
* **Mod dir** (`core.get_modpath(modname)`): `mod.conf`, `screenshot.{png,jpg,jpeg}` (3:2, min 300x200), `settingtypes.txt` (under "Mods"), `init.lua`, `models/`, `textures/`, `sounds/`, `fonts/`, `media/`, `locale/`. Deprecated: `depends.txt` (one modname/line, `?` suffix = optional), `description.txt`.
* `mod.conf`: `name`, `title`, `description`, `depends` (comma-sep), `optional_depends` (comma-sep), `author`, `release`, `textdomain` (default: `modname`).
* **Media rules**: Names allow `a-zA-Z0-9_.-`; max ~16MB. Subfolders starting with `_` or `.` ignored. Parent folder file wins over duplicate in subfolder. Dependent mods can overwrite dependency media (discouraged).
  * Images: `.png`, `.jpg`, `.tga`. Sounds: `.ogg` vorbis. Models: `.x`, `.b3d`, `.obj`, (5.10+) `.gltf`, `.glb`. Fonts (5.11+): `.ttf`, `.woff` (preferred).
* **glTF**: `.glb` recommended over `.gltf`. Normalize bone weights. Nodes using matrix transforms must NOT be animated or receive bone overrides. Unsupported: non-`TRIANGLES` primitives, `CUBICSPLINE` interpolation, morph animations, cameras, materials beyond base color (backface culling overridden, double-sided broken), embedded images, external `.bin` URI buffers (embed base64 or use `.glb`). Frame numbers = timestamps in seconds (use animation speed `1.0`). Textures supplied via `textures`/`tiles`/`model[]` in glTF `textures` array order. Do not rely on unsupported features remaining ignored.
* **Custom fonts**: Override default client fonts via stems `regular`, `bold`, `italic`, `bold_italic`, `mono`, `mono_bold`, `mono_italic`, `mono_bold_italic`. Reads `kern` table only, not OpenType `GPOS`.
* **Naming**: Registered names must be `modname:<whatever>` (`[a-zA-Z0-9_]`). Prefix `:` (`:other:name`) to redefine another mod's registration (requires dependency on `other`).

## Aliases
* `core.register_alias(alias, original_name)` / `core.register_alias_force(alias, original_name)`: Maps `alias` -> `original_name`. `register_alias` is a no-op if `alias` already exists; `_force` unregisters existing item first.
* **Non-V6 Mapgen aliases**: Essential: `mapgen_stone`, `mapgen_water_source`, `mapgen_river_water_source` (needs short `liquid_range`, `liquid_renewable=false`). Optional (deprecated; use biome defs): `mapgen_lava_source`, `mapgen_cobble`.
* **V6 Mapgen aliases**: Essential: `mapgen_stone`, `mapgen_water_source`, `mapgen_lava_source`, `mapgen_dirt`, `mapgen_dirt_with_grass`, `mapgen_sand`, `mapgen_tree`, `mapgen_leaves`, `mapgen_apple`, `mapgen_cobble`. Optional (fallbacks): `mapgen_gravel`(stone), `mapgen_desert_stone`(stone), `mapgen_desert_sand`(sand), `mapgen_dirt_with_snow`(dirt_with_grass), `mapgen_snowblock`(dirt_with_grass), `mapgen_snow`(omitted), `mapgen_ice`(water_source), `mapgen_jungletree`(tree), `mapgen_jungleleaves`(leaves), `mapgen_junglegrass`(omitted), `mapgen_pine_tree`(tree), `mapgen_pine_needles`(leaves), `mapgen_stair_cobble`(cobble), `mapgen_mossycobble`(cobble), `mapgen_stair_desert_stone`(desert_stone).
* **Singlenode**: `mapgen_singlenode` overrides default `"air"` fill.

## Textures
* Prefix with `modname_`; refer with or without extension (`foo_bar.png` or `foo_bar`). Textures `<192px` are nearest-neighbor upscaled before optional bilinear/trilinear filtering.
* **Load order** (lowest -> highest): client `$path_share/textures/base/pack` -> server mod `textures/` -> server game `textures/` -> server `$path_share/textures/server` -> server `override.txt` in `texture_path` -> server `override.txt` in `<game>/textures` -> client `texture_path` -> client `override.txt` in `texture_path`.
* **Texture modifiers** (applied in sRGB space without gamma; `TEXMOD_UPSCALE` = lower-res texture upscaled to higher-res):
  * `A^B`: Overlay `B` on `A` (`TEXMOD_UPSCALE`; if both pixels semitransparent, does NOT alpha-blend properly and is non-associative).
  * `(A^B)`: Group modifiers.
  * Escaping inside modifier args (e.g. `[combine`, `[lowpart`, `[mask`): prefix `\^`, `\:`, `\\`.
  * `[crack:<vframes>:<frame>`, `[cracko:<vframes>:<frame>`, `[crack:<grid>:<vframes>:<frame>`, `[cracko:<grid>:<vframes>:<frame>`: Scales & overlays `crack_anylength.png` (`[cracko` only on opaque base pixels). `grid` `[imagesize]` (def 1, creates NxN grid), `vframes` `[imagesize]`, `frame` `[imageframe]` (0-indexed).
  * `[combine:<w>x<h>:<x>,<y>=<tex>:...`: Create `<w>x<h>` (`[imagesize]`) `#00000000` canvas, blit `<tex>` (escaped) at `<x>,<y>` (`[imageframe]`).
  * `[resize:<w>x<h>`: Resize to `[imagesize]`.
  * `[opacity:<ratio>`: Multiply alpha by `ratio/255` rounded (`ratio` `0..255`).
  * `[invert:<mode>`: Invert channels (`255 - v`) for chars in `mode` (`r`,`g`,`b`,`a`).
  * `[brighten`: 50:50 lerp each pixel toward white.
  * `[noalpha`: Set alpha=255 (reveals hidden RGB of transparent pixels).
  * `[makealpha:<r>,<g>,<b>`: Exact RGB match (`0..255`) gets alpha=0 (RGB preserved).
  * `[transform<t>`: Concatenation of `0`/`I` (id), `1`/`R90` (CCW), `2`/`R180`, `3`/`R270`, `4`/`FX`, `5`/`FXR90`, `6`/`FY`, `7`/`FYR90` (case-insensitive).
  * `[inventorycube{<top>{<left>{<right>`: Render inventory cube. No `\`-escaping; replace `^` with `&` in texture names.
  * `[fill:<w>x<h>:<x>,<y>:<ColorString>`: Solid box (`w,h` `[imagesize]`, `x,y` `[u32]`). `x,y` used only when overlaid via `^` (keeps base texture resolution).
  * `[lowpart:<percent>:<tex>`: Blit bottom `<percent>` (`0..100`) of escaped `<tex>` onto base.
  * `[verticalframe:<t>:<n>`: Crop vertical sheet of `t` frames (`[imagesize]`) to 0-based frame `n` (`[imageframe]`).
  * `[mask:<tex>`: Bitwise AND all RGBA channels with escaped `<tex>` (`TEXMOD_UPSCALE`; out-of-bounds base pixels preserved).
  * `[sheet:<w>x<h>:<x>,<y>`: Extract tile at 0-based `x,y` (`[imageframe]`) from `w x h` tile grid (`[imagesize]`).
  * `[colorize:<ColorString>:<ratio>`: Lerp base pixels toward `color` (`ratio` `0..255` or `"alpha"`; omit defaults to color's alpha). Avoid semitransparent pixels, pass explicit `ratio` and opaque `color` (alpha=255) due to bugs.
  * `[colorizehsl:<hue>:<sat>:<light>`: Convert to greyscale & tint like GIMP Colorize. `hue` `[-180,180]` (0=red,60=yel,120=grn,180=cyn,-60=mag,-120=blu), `sat` `[0,100]` (def 50), `light` `[-100,100]` (def 0).
  * `[multiply:<ColorString>`: Per-pixel RGB multiply (alpha ignored).
  * `[screen:<ColorString>`: Inverse of multiply (lightens).
  * `[hsl:<hue>:<sat>:<light>`: Adjust hue (`[-180,180]`), saturation (`[-100,1000]` opt, -100=grey), lightness (`[-100,100]` opt).
  * `[contrast:<contrast>:<brightness>`: Both `[-127,127]` (`brightness` opt).
  * `[overlay:<file>` / `[hardlight:<file>`: GIMP Overlay/Hardlight blends (`TEXMOD_UPSCALE`; `A^[hardlight:B` == `B^[overlay:A`).
  * `[png:<base64>`: Decode embedded PNG from `core.encode_base64(core.encode_png(...))` (`TEXMOD_UPSCALE`). Avoid large images; prefer files or `dynamic_add_media`.
* **Hardware coloring** (multiplies RGB):
  * **Static**: Set `color` (`ColorSpec`) on item/node def; override per `ItemStack` via meta `"color"` (`ColorString`, lost when placed as node). Tile `{name=..., color=...}` overrides all other coloring (set `"white"` to exempt a face).
  * **Palettes**: Texture <=256 px, power-of-2 dims, read L->R T->B; smaller palettes expand via `palette[index / (256 / area)]` (int div).
    * Items: set `palette` field + stack meta `palette_index` (`0..255`). Engine auto-transfers `palette_index` between dug/placed nodes & drops (unless `drop` overrides; use `drop.items[i].inherit_color=true`).
    * Nodes: set `palette` + `paramtype2`: `"color"` (256 colors), `"colorwallmounted"` (32 colors; `param2/8`), `"colorfacedir"` (8 colors; `param2/32`), `"color4dir"` (64 colors; `param2/4`), `"colordegrotate"` (8 colors; `param2/32`).
    * Craft recipes: `core.itemstring_with_palette(item, idx)` / `core.itemstring_with_color(item, cs)`. (Ingredient metadata filtering unsupported).
* **Soft texture overlays**: `inventory_overlay`, `wield_overlay` (items), `overlay_tiles` (nodes; `""` skips face). Drawn separately on top so hardware coloring on base doesn't tint overlay (unless overlay tile sets its own `color`). Slower than merged textures.

## Sounds
* `.ogg` vorbis only; mono required for positional OpenAL playback.
* **Sound group**: `<name>[.<0-9>].ogg`; playing `<name>` picks one at random.
* `SimpleSoundSpec`: String (`""` = none) or `{name="", gain=1.0 (>=0), pitch=1.0 (>0), fade=0.0 (>=0)}`. Final OpenAL gain clamped to `1.0` (setting `gain > 1.0` expands max-volume radius; gain is measured at 3 nodes, constant inside 1 node). Pitch `2.0` = +12 semitones. `fade` = gain/sec fade-in.
* **Sound parameter table**: `{gain=1.0 (scales spec), pitch=1.0 (overrides spec), fade=0.0 (overrides spec), start_time=0.0 (offset in sec, neg = from end; requires feature sound_params_start_time), loop=false, pos=vec, object=ObjectRef (no pos+object), to_player=name, exclude_player=name (no to+exclude), max_hear_distance=32 (requires pos/object)}`.
* **Engine-played special groups**: `player_damage` (gain 0.5), `player_falling_damage` (0.5), `player_jump`, `default_dig_<groupname>` (0.5).

## Nodes & Map Terminology
* Node table (by value): `{name=str, param1=0..255, param2=0..255}`. Definition: `core.registered_nodes[node.name]`.
* `paramtype`: `"none"` (user data) | `"light"` (low 4 bits = sunlight, high 4 bits = artificial light; required for `light_source > 0` and drawtypes `torchlike`, `signlike`, `firelike`, `fencelike`, `raillike`, `nodebox`, `mesh`, `plantlike`, `plantlike_rooted`).
* `paramtype2`:
  * `"none"` (user data).
  * `"flowingliquid"`: bits 0-2 level (`0..7`), bit 3 flowing-downwards flag.
  * `"wallmounted"` (`0..7`): `0=y+, 1=y-, 2=x+, 3=x-, 4=z+, 5=z-`, `6=y+ rot 90°`, `7=y- rot -90°` (6/7 used on placement if `wallmounted_rotate_vertical=true`). Drawtypes: `torchlike`, `signlike`, `plantlike`, `plantlike_rooted`, `normal`, `nodebox`, `mesh`.
  * `"facedir"` (`0..23`): `facedir/4` axis (`0=y+,1=z+,2=z-,3=x+,4=x-,5=y-`), `facedir%4` left-handed 90° step. Connected nodeboxes only rotate textures. Drawtypes: `normal`, `nodebox`, `mesh`.
  * `"4dir"` (`0..3`): Horizontal `facedir`. Drawtypes: `normal`, `nodebox`, `mesh`.
  * `"leveled"`: For `nodebox` `type="leveled"` (`0..127`, height `param2/64`) or `plantlike_rooted` (`0..255`, height `param2/16`).
  * `"degrotate"` (`0..239`): Rotation = `param2 * 1.5` deg (`plantlike`, `mesh`).
  * `"meshoptions"` (`plantlike` bitfield): bits 0-2 shape (`0=x`, `1=+`, `2=*` 3 faces, `3=#` 4 faces, `4=#` leaning out, `5..7` reserved); modifiers `+8` random horizontal offset, `+16` 1.4x scale, `+32` random downward shift (<=1/8), `64,128` reserved.
  * `"color"` (256 palette), `"colorfacedir"` (top 3 bits color / low 5 facedir), `"color4dir"` (top 6 color / low 2 4dir), `"colorwallmounted"` (top 5 color / low 3 wallmounted), `"colordegrotate"` (top 3 color / low 5 degrotate `0..23` in 15° steps).
  * `"glasslikeliquidlevel"` (`glasslike_framed[_optional]` when connected glass enabled): bits 0-5 liquid level `0..63`, `+64` don't connect top/bottom, `+128` don't connect sides; liquid uses `special_tiles[1]`.
* `drawtype`: `"normal"`, `"airlike"`, `"liquid"` (source; set `backface_culling=false` to see from inside; connects to `liquid_alternative_flowing`), `"flowingliquid"` (`special_tiles[1]` top/bot, `special_tiles[2]` sides, `tiles` for inv/wield; must set `liquid_alternative_flowing` to self), `"glasslike"`, `"glasslike_framed"` (frame from outer 1/16th of `tiles[1]`, face detail `tiles[2]`), `"glasslike_framed_optional"`, `"allfaces"`, `"allfaces_optional"` (`special_tiles` used for Simple Leaves), `"torchlike"` (`tiles[1..3]` = top, bottom, side), `"signlike"` (flat against surface), `"plantlike"`, `"firelike"` (2 center + 4 surrounding over flat surface, else clings to side nodes), `"fencelike"`, `"raillike"` (`tiles[1..4]` = straight, curved, T, cross; slopes on steps), `"nodebox"`, `"mesh"` (static meshes only), `"plantlike_rooted"` (base cube `tiles` + `plantlike` extension above using `special_tiles[1]`; `wallmounted` places extension on mounted face & rotates cube).
* **Node boxes** (`box = {x1,y1,z1,x2,y2,z2}`, keep coords in `[-1.45,1.45]` for collision):
  * `{type="regular"}`
  * `{type="fixed", fixed=box|{box,...}}`
  * `{type="leveled", fixed=box|{box,...}}` (top set by `leveled` or `param2`)
  * `{type="wallmounted", wall_top=box, wall_bottom=box, wall_side=box}`
  * `{type="connected", fixed=..., connect_{top,bottom,front,left,back,right}=..., disconnected_{top,bottom,front,left,back,right}=..., disconnected=...(no neighbors), disconnected_sides=...(no side neighbors)}`
* **Map Units**: Node = 1x1x1m. Mapblock = `16x16x16` (`core.MAP_BLOCKSIZE=16`). Mapchunk = `5x5x5` mapblocks (`80x80x80` nodes).
* **Mapblock Status**: `emerged` (loaded from disk or generated) -> `loaded` (in memory; unloaded appears as `"ignore"`, though loaded can also contain `"ignore"`) -> `active` (entities as `ServerActiveObject`/`ObjectRef`/luaentity, ABMs, node timers run; LBMs run on activation). Active does NOT guarantee mapgen finished.
* **Axes & Coords**: +X East, +Y Up, +Z North. `blockpos = math.floor(nodepos / 16)`; block min `blockpos*16`, max `(blockpos+1)*16-1`.

## HUD
* **Common fields**: `position={x,y}` (`0..1` screen %), `name` (unused desc), `direction` (`0=L->R, 1=R->L, 2=T->B, 3=B->T`), `alignment={x,y}` (`-1..1`), `offset={x,y}` (px, scaled by DPI & HUD scaling), `z_index` (`[s16]`, def 0; conventions: -400 vignette, -300 nametags/waypoints, -200 wieldhand, -100 masks, 0 standard HUD, 100 temp msgs, 1000 fullscreen), `hideable` (`bool`, def `true`, >=5.17).
* **Element types** (`type` field; `hud_elem_type` deprecated):
  * `image`: `scale={x,y}` (>0 texture mult, <0 screen %), `text` (texture), `alignment`, `offset`.
  * `text`: `text` (supports `translate`, `colorize` >=proto 44), `number` (`0x[AA]RRGGBB`, alpha >=5.15; alpha `00` becomes `FF`, set `text=""` to hide), `alignment`, `offset`, `size={x=mult}` (float >=5.16), `style` (bitfield: 1=bold, 2=italic, 4=mono). Do not use `scale`.
  * `statbar`: `text` (fg), `text2` (optional bg, same size), `number` (half-images `[u32]`), `item` (off-state half-images `[u32]`), `direction`, `offset`, `size={x,y}` (`[1,2^31-1]`, overrides texture px size).
  * `inventory`: `text` (inv list name), `text2` (slot bg, def hotbar bg), `number` (slot count `[u16]`), `item` (selected index `[u16]`), `direction`, `offset`, `alignment` (def top-left).
  * `hotbar` (>=proto 46): `direction`, `offset`, `alignment`.
  * `waypoint`: `name`, `text` (distance suffix), `precision` (`[u32]`, def 10; 0 hides distance; `floor(dist*p)/p`), `number` (`0xRRGGBB`), `world_pos`, `offset`, `alignment`.
  * `image_waypoint`: Like `image`, positioned by `world_pos` instead of `position`.
  * `compass`: `size={x,y}` (`[s32]`, <0 screen %), `scale={x,y}` (for dir 2,3), `text`, `alignment`, `offset`, `direction` (`0=rot heading, 1=rev rot, 2=translate landscape, 3=rev translate`).
  * `minimap` (>=proto 44): `size={x,y}` (`[s32]`, square; negative = % >=proto 45, e.g. `{0,-25}` -> 25% min(w,h) square), `alignment`, `offset`.

## Simple Representations & Flag Specifiers
* `pointed_thing`: `{type="nothing"}` | `{type="node", under=pos, above=pos}` | `{type="object", ref=ObjectRef}`. `Raycast` adds: `intersection_point` (world pos), `box_id` (1-based), `intersection_normal` (outward unit vec in world space, `vector.zero()` if inside).
* **Flag Specifier Format**: Comma-separated string `"a, nob, c"` or table `{a=true, b=false, c=true}` / `{a=true, nob=true, c=true}`. `"no"` prefix clears flag.

## Items & Groups
* **Item kinds**: `node` (voxel + placeable item sharing same ID), `tool` (unstackable `count<=1`, mutable `wear` `0..65535`), `craftitem` (generic).
* **Special items**: `"unknown"` (unregistered), `"air"`, `"ignore"` (unloaded/ungenerated/out-of-bounds), `""` (empty hand; override globally via `core.override_item("", ...)` or per-player via `"hand"` inv list; cannot be an `ItemStack`).
* **Formats**:
  * Itemstring: `"<name>[ <amount>[ <wear>[ <metadata>]]]"`.
  * Table: `{name=str, count=1..65535, wear=0..65535, metadata=""|{}}`.
  * `ItemStack`: Native C++ object.
* **Groups**: `{group = rating}` (`[-32767,32767]`; `nil` == `0`; boolean flag = `1`). Craft recipe input: `"group:g1,g2"` (must match ALL).
* **Special groups** (`*` = game convention, no engine behavior):
  * Item/Node: `not_in_creative_inventory`(*).
  * Node: `attached_node` (`1`=wallmounted dir or below, `2`=facedir/4dir back face tile 5, `3`=below, `4`=above; drops if unwalkable), `bouncy` (% bounce; <0 uncontrollable), `connect_to_raillike`, `dig_immediate` (`2`=0.5s, `3`=0s, no wear), `disable_jump` (needs `new_move=true`), `disable_descend` (climbs/liquids, needs `new_move=true`), `fall_damage_add_percent` (`dmg = col_speed * ((node+100)/100) * ((player+100)/100) - 14`, clamped >=0), `falling_node` (falls if below non-walkable or `buildable_to`), `float` (won't fall through `liquidtype~="none"`), `level`, `slippery` (>=1, rises with value).
  * Tool: `disable_repair=1` (excludes from `toolrepair`).
  * Entity armor: `immortal` (no damage/breath, hides HUD bars; auto-set when server damage disabled), `fall_damage_add_percent`, `punch_operable` (disables default damage when punched by hand/non-tool).
  * Standard digging/damage: `crumbly` (dirt/sand), `cracky` (stone), `snappy` (leaves/wire), `choppy` (wood), `fleshy` (living), `explody`, `oddly_breakable_by_hand` (`1..3`; higher = faster). Custom conventions: `meat`, `eatable`, `flammable`, `wool`, `metal`, `weapon`, `heavy`.

## Tool Capabilities & Entity Damage
* Missing/incomplete `tool_capabilities` fall back to hand (`""`). Only `tool` items take wear.
* `tool_capabilities = {full_punch_interval=num, max_drop_level=int (unused by engine, for mods), groupcaps={[grp]={uses=u16 (0=inf; actual uses = uses * 3^(maxlevel - node_level); undiggable if node_level > maxlevel), maxlevel=int, times={[rating]=secs}}}, damage_groups={[grp]=s16}, punch_attack_uses=u16}`
  * Dig time 0 adds 0.15s delay while LMB held (0 if clicked); time `0.01` is faster while holding LMB.
* **Entity damage**: `sum_g(cap.damage_groups[g] * clamp(actual_interval / full_punch_interval, 0, 1) * (armor_groups[g] / 100))`. Client predicts damage & shows death smoke. Never call `entity:on_punch` directly; call `object:punch(...)`.

## Metadata
* **Node Metadata** (`NodeMetaRef`): key-value strings + `InvRef`. Special keys: `formspec` (opened on rightclick if no `on_rightclick` callback), `infotext` (hover text, auto-wrapped/truncated).
* **Item Metadata** (`ItemStackMetaRef`): key-value strings (`\1,\2,\3` stripped). Special keys: `description`, `short_description`, `inventory_image`, `inventory_overlay`, `wield_image`, `wield_overlay`, `wield_scale` (`vector.to_string`), `color` (`ColorString`), `palette_index` (int), `count_meta` (replaces displayed count string), `count_alignment` (int: bits 0-1 X, bits 2-3 Y; `0=def, 1=L/U, 2=mid, 3=R/D`), `range` (float, >=5.9).

## Formspec
* Element names: avoid `"quit"` and `"key_*"`; no ASCII control chars. Escape user text with `core.formspec_escape` / `core.hypertext_escape`; colorize with `core.colorize`.
* **Versions**: v1 (pre-5.1), v2 (5.1: real_coordinates forced, `background9`), v3 (5.2: draw in def order, bg before all, `bgcolor` 3 params, `box`/`image` clip by default, `scroll_container`), v4 (5.4: dropdown index events), v5 (5.5: `padding`), v6 (5.6: 9-slice `image`, `animated_image`, `fgimg_middle`), v7 (5.8: `focused` button state, `field_enter_after_edit`), v8 (5.10: `scroll_container` content_padding), v9 (5.12: `allow_close`, area `label`), v10 (5.13: `model` float frames), v11 (5.17: `hypertip`, label/textarea/field alignment), v12 (5.18: `editable` style).
* **Header order**: `formspec_version[<int>]` -> `size[<W>,<H>,<fixed_size>]` (`invsize` deprecated) -> `position[<X>,<Y>]` (`0..1` screen, def `0.5,0.5`) -> `anchor[<X>,<Y>]` (`0..1` form, def `0.5,0.5`) -> `padding[<X>,<Y>]` (screen margin on shrink, def `0.05,0.05`) -> `no_prepend[]` (ignores `set_formspec_prepend`) -> `real_coordinates[<bool>]` (not inherited by prepends).
* **Control/Containers**:
  * `allow_close[<bool>]`: `false` prevents Esc closing (sends `try_quit="true"`; `*_exit[]` and `close_formspec` still work).
  * `container[<X>,<Y>]` ... `container_end[]`: Relative offset (nestable).
  * `scroll_container[<X>,<Y>;<W>,<H>;<scrollbar>;<vertical|horizontal>;<factor=0.1>;<content_padding>]` ... `scroll_container_end[]`: Clips & scrolls children. If `content_padding` given, auto-computes scrollbar `max` and `thumbsize` (negative factor unsupported).
* **Inventory**:
  * `list[<loc>;<list>;<X>,<Y>;<W>,<H>;<start_idx=0>]`: Shows slots.
  * `listring[<loc>;<list>]` / `listring[]` (adds last two `list[]`s): Shift-click transfer ring.
  * `listcolors[<bg>;<hover>[;<border>[;<tt_bg>;<tt_fg>]]]` (`ColorString`s).
  * `listimages[<bg_img>;<hover_img>]` (empty keeps `listcolors`).
* **Tooltips & Media**:
  * `tooltip[<name|X,Y;W,H>;<text>[;<bg>;<fg>]]` (must follow target element).
  * `hypertip[<name|X,Y;W,H>;<staticPos>;<width_em>;<name>;<markup>]` (`staticPos` = `x,y` or empty to follow cursor).
  * `image[<X>,<Y>;<W>,<H>;<tex>[;<middle>]]` (`middle` 9-slice, v6+).
  * `animated_image[<X>,<Y>;<W>,<H>;<name>;<tex>;<frames>;<dur_ms>;<start=1>[;<middle>]]` (`dur_ms=0` pauses; event sends current frame).
  * `model[<X>,<Y>;<W>,<H>;<name>;<mesh>;<tex1,tex2...>[;<rot_x,y>[;<continuous=false>[;<mouse=true>[;<begin,end>[;<fps=0>]]]]]]`.
  * `item_image[<X>,<Y>;<W>,<H>;<item>]`.
  * `bgcolor[<bg>;<false|true|both|neither>;<fbg>]`.
  * `background[<X>,<Y>;<W>,<H>;<tex>[;<auto_clip>]]`, `background9[<X>,<Y>;<W>,<H>;<tex>;<auto_clip>;<x|x,y|x,y,x2,y2>]` (negative x2/y2 = from far edge; `auto_clip=true` uses X,Y as offset & ignores W,H).
  * `box[<X>,<Y>;<W>,<H>;<ColorString>]` (omit color to allow `style` props).
* **Inputs & Widgets**:
  * `pwdfield[<X>,<Y>;<W>,<H>;<name>;<label>]`, `field[<X>,<Y>;<W>,<H>;<name>;<label>;<default>]` (empty name shows label only; `${meta_key}` substitutes single meta field), `field[<name>;<label>;<default>]` (no `size[]`, auto Proceed button). Enter sets `fields.key_enter_field=name`.
  * `field_enter_after_edit[<name>;<bool>]` (Android, exp), `field_close_on_enter[<name>;<bool=true>]`.
  * `textarea[<X>,<Y>;<W>,<H>;<name>;<label>;<default>]` (empty name = transparent read-only wrapped text with scrollbar).
  * `label[<X>,<Y>;<label>]` (real_coords centers vertically; `\n` spaced 0.5), `label[<X>,<Y>;<W>,<H>;<label>]` (wrapped area label, real_coords only, truncates overflow).
  * `vertlabel[<X>,<Y>;<label>]`, `hypertext[<X>,<Y>;<W>,<H>;<name>;<markup>]`.
  * `button[...]` / `button_exit[...]`, `button_url[...;<http(s)://url>]` / `button_url_exit[...]`, `image_button[<X>,<Y>;<W>,<H>;<tex>;<name>;<label>[;<noclip>;<drawborder>;<pressed_tex>]]` / `image_button_exit[...]`, `item_image_button[<X>,<Y>;<W>,<H>;<item>;<name>;<label>]` (unique `name` required for tooltips).
  * `textlist[<X>,<Y>;<W>,<H>;<name>;<e1,e2...>[;<sel_idx>;<transparent>]]` (`#RRGGBB` prefix colors row, `##` for `#`; parse via `core.explode_textlist_event`).
  * `tabheader[<X>,<Y>[;<H>|<W>,<H>];<name>;<c1,c2...>;<cur_tab>[;<transparent>;<draw_border>]]` (1-indexed; sends index on change).
  * `dropdown[<X>,<Y>;<W>[;<H>];<name>;<i1,i2...>;<sel_idx>[;<index_event>]]` (`index_event=true` sends index instead of text, v4+).
  * `checkbox[<X>,<Y>;<name>;<label>[;<selected>]]` (sends `"true"`/`"false"`).
  * `scrollbar[<X>,<Y>;<W>,<H>;<vertical|horizontal>;<name>;<val>]` + `scrollbaroptions[min=0;max=1000;smallstep=10;largestep=100;thumbsize=1;arrows=default|show|hide]` (`max==min` disables; parse via `core.explode_scrollbar_event`).
  * `table[<X>,<Y>;<W>,<H>;<name>;<c1,c2...>;<sel_idx>]` + `tableoptions[color=#FFF;background=#000;border=true;highlight=#466432;highlight_text=#FFF;opendepth=0]` + `tablecolumns[<type>,<opt>...;...]` (types: `text`, `image` (`0=tex,...`), `color` (`span=N`), `indent`, `tree`; opts: `align=left|center|right|inline`, `width=N`, `padding=N`, `tooltip=str`; parse via `core.explode_table_event`).
  * `set_focus[<name>[;<force=false>]]` (must precede element; works on checkbox, buttons, table, textlist, dropdown, fields, textarea, scrollbar).
* **Real Coords Migration**: `pos = (oldpos+1)*1.25 + 0.375`, `size = (oldsize-1)*1.25 + 0.75 + 1`.
* **Styling**: `style[<name|*>[:s1+s2],...;prop=val;...]` (by name) / `style_type[...]` (by type; `button_exit`->`button`, `pwdfield`->`field`, `vertlabel`->`label`, `animated_image`->`image`). Applies to following elements; empty value resets.
  * States: `default` (all), `focused`, `hovered`, `pressed` (buttons).
  * Props: `noclip` (most elements), `bgcolor`/`bgcolor_hovered`/`bgcolor_pressed`, `bgimg`/`bgimg_hovered`/`bgimg_pressed`/`bgimg_middle`, `fgimg`/`fgimg_hovered`/`fgimg_pressed`/`fgimg_middle` (`image_button`), `alpha`, `border` (button, field/textarea, hypertip), `content_offset`, `padding` (button), `sound` (button, checkbox, dropdown, hypertext, tabheader), `textcolor`, `font` (`normal|mono[,bold][,italic]`), `font_size` (`N|+N|-N|*N`), `colors`/`bordercolors`/`borderwidths` (1/2/4 CSS-style values for `box`), `halign`/`valign` (`field`/`textarea`/`label`), `editable` (checkbox, dropdown, field, pwdfield, textarea; v12), `size`/`spacing` (`list` 2D vectors).
* **Markup Language** (`hypertext`/`hypertip`; escape `\<`, `\>`, `\\`, `\"`):
  * `<style color=... font=mono|normal size=...>...</style>`
  * `<global background=... margin=... valign=top|middle|bottom color=... hovercolor=... size=... font=... halign=left|right|center|justify>`
  * `<tag name=... color=... hovercolor=... font=... size=...>` (define/override tag style)
  * Builtin tags: `<normal>`, `<big>`, `<bigger>`, `<center>`, `<left>`, `<right>`, `<justify>`, `<mono>`, `<b>`, `<i>`, `<u>`.
  * `<action name=... [url=...]>` (sends `"action:"..name`; non-clickable in `hypertip`).
  * `<img name=... [float=left|right] [width=...] [height=...]>` (preserves aspect if 1 dim given).
  * `<item name=... [float=...] [width=...] [height=...] [rotate=yes|X,Y,Z] [angle=X,Y,Z]>` (`rotate`/`angle` require `inventory_items_animations`).

## Inventory, Colors, Escapes & Coordinate System
* **Inventory locations**: `"context"` (`"current_name"` deprecated), `"current_player"`, `"player:<name>"`, `"nodemeta:<X>,<Y>,<Z>"`, `"detached:<name>"`.
* **Player inv lists**: `main`, `craft`, `craftpreview`, `craftresult`, `hand` (create via `set_size`; slot 1 overrides empty hand).
* **Swap transaction order**: `allow_take` & `allow_put` (src & dst) -> exchange stacks -> `on_take` (src & dst) -> `on_put` (src & dst).
* `ColorString`: `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, CSS Color Level 4 names optionally suffixed `#A` or `#AA`.
* `ColorSpec`: `{a=255,r=0..255,g=0..255,b=0..255}`, `0xAARRGGBB`, or `ColorString`.
* **Escapes**: `core.get_color_escape_sequence(cs)`, `core.colorize(cs, msg)` (unsupported in tabheaders/dropdowns), `core.get_background_escape_sequence(cs)` (item desc/tooltips only), `core.strip_foreground_colors(s)`, `core.strip_background_colors(s)`, `core.strip_colors(s)`, `core.strip_escapes(s)` (strips all escapes incl. translations).
* **Coordinate & Rotation System**:
  * **Left-handed** world: +X right, +Y up, +Z forward.
  * Bones & attachments: **left-handed extrinsic X-Y-Z** (`Z*Y*X`).
  * **Exception**: Objects (`ObjectRef:set_rotation`, `get_rotation`, `automatic_rotate`) use **right-handed extrinsic Z-X-Y** (roll Z, pitch X, yaw Y).

## Math Classes: `vector`, `vector2`, `Rotation`, `Matrix4`
* `vector` (3D) & `vector2` (2D): `{x,y[,z]}` with metatable (`v[1..3]`, `v:fn(...)`, `tostring`, `==`, `-v`, `+`, `-`, `*s`, `/s`). Plain `{x=,y=,z=}` tables accepted by functions. Do not modify `.metatable`.
  * **Common**: `copy(v)`, `zero()`, `random_direction()` (unit len), `from_string(s[,init]) -> v, next_pos`, `to_string(v)` (lossy), `direction(p1,p2)` (unit or 0), `distance(p1,p2)`, `length(v)`, `normalize(v)`, `floor(v)`, `ceil(v)`, `round(v)` (half away from 0), `sign(v,tol)`, `abs(v)`, `apply(v,fn,...)`, `combine(v,w,fn)`, `equals(v1,v2)`, `dot(v1,v2)`, `check(v)` (true only if metatable vector), `in_area(pos,min,max)` (inclusive), `add(v,vec|num)`, `subtract(v,vec|num)`, `multiply(v,s)` (`vector` Schur deprecated), `divide(v,s)` (`vector` Schur deprecated).
  * `vector`-only: `new(x,y,z)`, `unpack(v)`, `sort(v1,v2) -> minp,maxp`, `cross(v1,v2)` (`+X x +Y = +Z`), `angle(v1,v2)` (`[0,pi]`), `offset(v,x,y,z)`, `random_in_area(min,max)` (inclusive int); deprecated: `rotate(v,r)`, `rotate_around_axis(v1,v2,a)`, `dir_to_rotation(dir[,up])`.
  * `vector2`-only: `new(x,y)`, `unpack(v)`, `from_angle(rad)`, `to_angle(v)` (`(-pi,pi]`, `(0,0)->0`), `sort(v1,v2) -> minp,maxp`, `angle(v1,v2)` (unsigned), `rotate(v,rad)` (CCW), `offset(v,x,y)`.
* `Rotation` (5.19+, left-handed, 32-bit float quaternions):
  * Constructors: `identity()`, `quaternion(x,y,z,w)`, `axis_angle(axis,rad)`, `x(pitch)`, `y(yaw)`, `z(roll)`, `euler_xyz(p,y,r)`, `euler_zxy(p,y,r)` (entity convert: `Rotation.euler_zxy((-rot):unpack())`), `maps_to(from,to)`, `compose(...)` (right-to-left: `compose(second, first)` applies `first` then `second`).
  * Methods: `to_quaternion() -> x,y,z,w`, `to_axis_angle() -> axis,rad`, `to_euler_xyz() -> p,y,r`, `to_euler_zxy() -> p,y,r` (entity rot: `-vector.new(r:to_euler_zxy())`), `compose(...)`, `apply(vec)`, `invert()`, `slerp(to,t)`, `angle_to(other)`, `__tostring`.
* `Matrix4` (5.19+, column-major 4x4, 32-bit floats):
  * Constructors: `new(16 row-major nums)`, `identity()`, `full(num)`, `translation(vec)`, `rotation(rot)`, `scale(vec|num)`, `trs([t],[r],[s])`, `reflection(normal)`, `compose(...)` (right-to-left).
  * Methods: `get/set(r,c[,n])` (1..4), `get_row/set_row(r,...)`, `get_col/set_col(c,...)`, `copy()`, `unpack()` (16 row-major), `transform_4d(x,y,z,w) -> x,y,z,w`, `transform_pos(pos)` (`w=1`), `transform_dir(dir)` (`w=0`), `compose(...)`, `determinant()`, `invert()` (or `nil`), `transpose()`, `equals(other[,tol=0])`, `is_affine_transform([tol=0])`, `get_translation()`, `set_translation(vec)`, `get_rotation_scale() -> rot, scale` (no shear/reflect).
  * Operators: `+`, `-`, `-m`, `*s` (scales ALL entries incl. col 4), `==`, `__tostring`.

## Helper Functions
* `dump2(obj, name="_", dumped={})` -> `name[k] = v` lines; `dump(val, indent="\t")` -> Lua table string (handles loops; `""` = compact).
* `math.hypot(x,y)`, `math.sign(x, tol=0)` -> `-1|0|1` (NaN -> `0`), `math.factorial(x)` (`[ulua]`, `>=171` -> `inf`), `math.round(x)` (half away from 0), `math.isfinite(x)`.
* `string.split(str, sep=",", include_empty=false, max_splits=-1, sep_is_pattern=false)` -> list; `string:trim()`; `string.pack(fmt,...)`, `string.unpack(fmt,s[,pos])`, `string.packsize(fmt)` (Lua 5.4).
* `core.wrap_text(str, limit_bytes, as_table=false)` -> word-wrapped string/lines (normalizes newlines/spaces if wrapped).
* `core.pos_to_string(pos, decimals)`, `core.string_to_pos(s)` -> `pos|nil`, `core.string_to_area(s, relative_to)` -> `p1,p2|nil` (supports `~`, `~num`).
* `core.is_yes(arg)` -> bool (`y`,`yes`,`true`, nonzero num), `core.is_nan(x)`, `core.get_us_time()` -> elapsed microseconds.
* `table.copy(t)` (deep copy, strips metatables), `table.copy_with_metatables(t)` (5.12+, preserves metatables), `table.indexof(list, val)` (`-1` if missing, stops at nil), `table.keyof(t, val)` -> `key|nil`, `table.insert_all(t, other)` -> `t`, `table.key_value_swap(t)`, `table.shuffle(t, from=1, to=#t, rand=math.random)`.
* `core.pointed_thing_to_face_pos(placer, pt)` -> exact hit pos on node face.
* `core.get_tool_wear_after_use(uses, initial_wear=0)` -> added wear (`0` if `uses==0`).
* `core.get_dig_params(groups, tool_caps, wear=0)` -> `{diggable, time, wear}`.
* `core.get_hit_params(groups, tool_caps, time_from_last_punch, wear=0)` -> `{hp [-65535..65535], wear}`.

## Translations
* `core.get_translator(textdomain)` -> `S(str,...)`, `PS(str, plural, n, ...)`.
* `core.translate(textdomain, str, ...)`, `core.translate_n(textdomain, str, plural, n, ...)` (`n` nonnegative int; plurals `.po`/`.mo` only). Arguments are not translated; output contains escape sequences (don't slice/length-check; concatenation & `colorize` work).
* `core.get_translated_string(lang_code, str)`: Server-side translation for sorting/filtering (`lang_code` from `get_player_information`).
* Files in `locale/`:
  * `.tr` (`<domain>.<lang>.tr`): `# textdomain: <dom>`, `orig=trans` (no extra spaces). Escapes: `@@`, `@1..@9` (must be sequential in orig), `@=`, `@\n`, `@n`.
  * Gettext `.po`/`.mo`: `msgctxt` = textdomain (defaults to filename).
  * Monolingual (5.18+): `X-Source-Language: <lang>` in English file header (`.po`/`.mo`) or `# X-Source-Language: <lang>` after textdomain (`.tr`). English acts as client fallback.
* Content meta: `title`/`description` in `.conf` translated via mod/game `locale/` using `textdomain` (games/modpacks search all contained mods).

## Fractal Value Noise, Ores, Decorations, Schematics
* `NoiseParams`: `{offset=0, scale=1, spread={x,y,z} (required, >0), seed=12345 ([s32]), octaves=3 ([1,65535]; error if any octave wavelength <1), persistence=0.6 (alias persist), lacunarity=2.0 (>=1.0), flags="" ("defaults, eased, absvalue", "noeased")}`. Value = `offset + scale * sum_i(oct_i * persist^(i-1))`. 2D ignores `spread.z`; default eased for 2D, non-eased for 3D.
* **Ore types**:
  * `scatter`: random clusters; optional `noise_params` + `noise_threshold`.
  * `sheet`: 2D noise blob columns (`column_height_min=1`, `column_height_max` def `clust_size`, `column_midpoint_factor=0.5` `0..1` growth direction). Ignores `clust_scarcity`, `clust_num_ores`.
  * `puff`: 2D noise cloud; `np_puff_top`, `np_puff_bottom`. Flags: `puff_cliffs` (no edge taper), `puff_additive_composition`.
  * `blob`: 3D noise deformed sphere (`clust_size`, `clust_scarcity`).
  * `vein`: 2 intersecting 3D noises (~200x slower!); `random_factor=1`. Ignores `clust_*`.
  * `stratum`: Continuous horizontal/undulating layer; 2D `noise_params` (Y midpoint, omit for flat `y_min..y_max`) + 2D `np_stratum_thickness` or constant `stratum_thickness`; `clust_scarcity` = 1-in-N chance per node. Ignores `clust_num_ores`, `clust_size`, `noise_threshold`, `random_factor`.
* **Decorations**: `simple` (1xHx1 column), `schematic`, `lsystem` (`treedef`).
* **Schematics**: `.mts` file or `{size=vec, yslice_prob={{ypos=0..H-1, prob=0..255}}, data={{name, prob|param1=255, param2=0, force_place=false}, ...}}` in `[z [y [x]]]` order. `prob`: `0..1`=0%, `254..255`=100%, else `p/256`. Flags: `place_center_x`, `place_center_y`, `place_center_z`, `force_placement`.

## Lua Voxel Manipulator & Mapgen Objects
* `VoxelManip([p1, p2])` / `core.get_voxel_manip([p1, p2])`: Fast bulk read/write (no node callbacks or rollback; `core.set_node` faster for <=3x3x3).
  * Flat index (1-based): `(z-p1.z)*Ny*Nx + (y-p1.y)*Nx + (x-p1.x) + 1`.
  * Content IDs: `core.get_content_id(name)`, `core.get_name_from_content_id(id)`, `core.CONTENT_UNKNOWN`, `core.CONTENT_AIR`, `core.CONTENT_IGNORE`.
  * Methods:
    * `read_from_map(p1,p2) -> emin,emax`: Loads blocks (mapblock-aligned), *adds* to VM area.
    * `initialize(p1,p2[,node]) -> emin,emax` (5.13+): Resizes/clears VM without reading map (optionally fills with `node`).
    * `write_to_map([light=true])`: Commits VM to map (if `light=false`, call `core.fix_light` later).
    * `get_node_at(pos) -> MapNode`, `set_node_at(pos, node)`: Slow single-node access.
    * `get_data([buf]) -> ids`, `set_data(ids)`, `get_light_data([buf]) -> param1s` (`day + night*16`), `set_light_data(data)`, `get_param2_data([buf]) -> param2s`, `set_param2_data(data)`: Bulk flat-array snapshots (reuse `buf` for speed).
    * `set_lighting({day,night}[,p1,p2])`, `calc_lighting([p1,p2][,propagate_shadow=true])`: Mapgen VM only.
    * `update_liquids()`: Queues liquid flow for placed liquids.
    * `get_emerged_area() -> emin,emax`.
    * `close()` (5.13+): Frees C++ memory immediately.
    * `update_map()` (no-op), `was_modified()` (broken/deprecated, avoid).
* `VoxelArea(pmin, pmax)` / `VoxelArea:new({MinEdge=pmin, MaxEdge=pmax})` (`[s16]`): `.ystride`, `.zstride`, `getExtent() -> vec`, `getVolume() -> int`, `index(x,y,z)`, `indexp(p)`, `position(i) -> vec`, `contains(x,y,z)`, `containsp(p)`, `containsi(i)`, `iter(x1,y1,z1,x2,y2,z2)`, `iterp(p1,p2)`.
* `core.get_mapgen_object(name)` (inside `on_generated` only):
  * `"voxelmanip"` -> `vm, emin, emax` (note: VM area > `minp..maxp`; `set_node` updates mapgen VM).
  * `"heightmap"`, `"biomemap"`, `"heatmap"`, `"humiditymap"` -> flat chunk arrays.
  * `"gennotify"` -> `{dungeon={pos...}, temple={pos...}, cave_begin, cave_end, large_cave_begin, large_cave_end, custom={[id]=val}, ["decoration#"..id]={surface_pos...}}` (requires prior `core.set_gen_notify`).

## Registered Entities, L-System Trees, Privileges
* **Entity `self`**: `.name`, `.object` (`ObjectRef`), entity definition as metatable.
  * `on_activate(self, staticdata, dtime_s)`: Spawn/load (`dtime_s` = time unloaded).
  * `on_deactivate(self, removal)`: Before unload (`removal=false`) or `object:remove()` (`removal=true`). Not called on `clear_objects({mode="full"})` or if never activated.
  * `on_step(self, dtime, moveresult)`: Per tick after physics. `moveresult` (when `physical=true`): `{touching_ground, collides, standing_on_object, collisions={{type="node"|"object", axis="x"|"y"|"z", node_pos, object, new_pos (moveresult_new_pos), old_velocity, new_velocity}}}`.
  * `on_punch(self, puncher, time_from_last_punch, tool_caps, dir, damage)`: Return `true` cancels default damage.
  * `on_death(self, killer)`, `on_rightclick(self, clicker)`, `on_attach_child(self, child)`, `on_detach_child(self, child)`, `on_detach(self, parent)` (also on removal), `get_staticdata(self) -> str`.
* **L-system `treedef`**: `{axiom, rules_a, rules_b, rules_c, rules_d, trunk, leaves, leaves2, leaves2_chance (0..100), angle (s16 deg), iterations (2..32767), random_level (0..32767), trunk_type ("single"|"double"|"crossed"), thin_branches (bool), fruit, fruit_chance (0..100), seed (s32)}`. Symbols: `G` move pen up, `F` trunk/branch, `f` leaves, `T` trunk only, `R` fruit, `A..D` rules, `a..d` rules w/ 90/80/70/60% chance, `+`/`-` yaw R/L, `&`/`^` pitch D/U, `/`/`*` roll R/L, `[`/`]` push/pop.
* **Builtin privileges**: `shout`, `interact`, `fast`, `fly`, `noclip`, `teleport`, `bring`, `give`, `settime`, `debug` (wireframe), `privs`, `basic_privs`, `kick`, `ban`, `password`, `protection_bypass` (convention only), `server`, `rollback`.

## `core` Namespace Reference

### Utilities, Features & Logging
* `core.get_current_modname()` (load-time), `core.get_modpath(modname)` -> `path|nil`, `core.get_modnames([load_order=false])` (5.16+), `core.get_game_info()` -> `{id, title, author, path}`, `core.get_worldpath()`, `core.get_mod_data_path()` (load-time, world-independent dir), `core.is_singleplayer()`.
* `core.features` & `core.has_feature(str|{[feat]=true}) -> bool, missing`: Feature flags: `glasslike_framed`, `nodebox_as_selectionbox`, `get_all_craft_recipes_works`, `use_texture_alpha`, `no_legacy_abms`, `texture_names_parens`, `area_store_custom_ids`, `add_entity_with_staticdata`, `no_chat_message_prediction`, `object_use_texture_alpha`, `object_independent_selectionbox`, `httpfetch_binary_data`, `formspec_version_element`, `area_store_persistent_ids`, `pathfinder_works`, `object_step_has_moveresult`, `direct_velocity_on_players`, `use_texture_alpha_string_modes`, `degrotate_240_steps`, `abm_min_max_y`, `dynamic_add_media_table`, `particlespawner_tweenable`, `get_sky_as_table`, `get_light_data_buffer`, `mod_storage_on_disk`, `compress_zstd`, `sound_params_start_time`, `physics_overrides_v2`, `hud_def_type_field`, `random_state_restore`, `after_order_expiry_registration`, `wallmounted_rotate`, `item_specific_pointabilities`, `blocking_pointability_type`, `dynamic_add_media_startup`, `dynamic_add_media_filepath`, `lsystem_decoration_type`, `item_meta_range`, `node_interaction_actor`, `moveresult_new_pos`, `override_item_remove_fields`, `hotbar_hud_element`, `bulk_lbms`, `abm_without_neighbors`, `biome_weights`, `particle_blend_clip`, `remove_item_match_meta`, `httpfetch_additional_methods`, `object_guids`, `on_timer_four_args`, `particlespawner_exclude_player`, `generate_decorations_biomes`, `chunksize_vector`, `item_image_animation`, `get_modnames_load_order`, `set_camera_resettable`, `hud_hideable_field`, `compress_raw_deflate`, `get_all_craft_recipes_fuel`, `get_all_craft_recipes_replacements`.
* `core.get_player_information(name)` -> `{address, ip_version, connection_uptime, protocol_version, formspec_version, lang_code, min/max/avg_rtt, min/max/avg_jitter, version_string}`. Use `protocol_version >= core.protocol_versions["5.8.0"]` (5.11+) for client checks.
* `core.get_player_window_information(name)` (5.7+) -> `{size={x,y}, max_formspec_size={x,y}, real_gui_scaling, real_hud_scaling, touch_controls (5.9+)}`.
* FS/Hashing/Colors/PNG: `path_exists(p)`, `mkdir(p)`, `rmdir(p, recursive)`, `cpdir(src, dst)`, `mvdir(src, dst)`, `get_dir_list(p[, is_dir])`, `safe_file_write(p, data)`, `get_version()` -> `{project, string, proto_min, proto_max, hash, is_dev}`, `sha1(data, raw=false)`, `sha256(data, raw=false)`, `colorspec_to_colorstring(cs)`, `colorspec_to_bytes(cs)` -> 4 RGBA bytes, `colorspec_to_table(cs)`, `time_to_day_night_ratio(tod)`, `encode_png(w, h, data, [comp=0..9])` (ColorSpec array or raw RGBA string), `urlencode(s)`.
* Logging: `core.debug(...)`, `core.log([level="none"|"error"|"warning"|"action"|"info"|"verbose",] text)`.

### Registration & Global Callbacks (Load-time only)
* Registration (pass fresh tables to item regs): `register_node(name, def)`, `register_craftitem(name, def)`, `register_tool(name, def)`, `override_item(name, redef, del_fields)`, `unregister_item(name)`, `register_entity(name, def)`, `register_abm(def)`, `register_lbm(def)`, `register_alias(a, orig)`, `register_alias_force(a, orig)`, `register_ore(def) -> handle`, `register_biome(def) -> handle`, `unregister_biome(name)` (shifts IDs!), `register_decoration(def) -> handle`, `register_schematic(def) -> handle`, `clear_registered_{biomes,decorations,ores,schematics}()`, `register_craft(recipe)`, `clear_craft(recipe)` (output OR input, not both), `register_chatcommand(cmd, def)`, `override_chatcommand(name, redef)`, `unregister_chatcommand(name)`, `register_privilege(name, desc|def)`, `register_authentication_handler(def)` (once only).
* Global callbacks (registered into `core.registered_*`):
  * `register_globalstep(fn(dtime))`: Every server step (~0.1s).
  * `register_on_mods_loaded(fn())`: After all `init.lua`s, before media/aliases.
  * `register_on_shutdown(fn())`: Normal shutdown (won't run on crash).
  * `register_on_placenode(fn(pos, newnode, placer, oldnode, itemstack, pointed_thing))` -> `true` keeps item (prefer `on_construct`/`after_place_node`).
  * `register_on_dignode(fn(pos, oldnode, digger))` (prefer `on_destruct`/`after_dig_node`).
  * `register_on_punchnode(fn(pos, node, puncher, pointed_thing))`.
  * `register_on_generated(fn(minp, maxp, blockseed))`: Blocks main thread (prefer mapgen env).
  * `register_on_newplayer(fn(player))`, `register_on_joinplayer(fn(player, last_login))`, `register_on_leaveplayer(fn(player, timed_out))` (not called on shutdown).
  * `register_on_prejoinplayer(fn(name, ip))` -> string disconnects client.
  * `register_on_authplayer(fn(name, ip, is_success))` (`register_on_auth_fail` deprecated).
  * `register_on_punchplayer(fn(player, hitter, time_from_last_punch, tool_caps, dir, damage))` -> `true` cancels damage (runs even if dead).
  * `register_on_rightclickplayer(fn(player, clicker))`.
  * `register_on_player_hpchange(fn(player, hp_change, reason), modifier)`: Modifier returns `new_hp_change[, stop_bool]`. Not called for damage when `hp==0`.
  * `register_on_dieplayer(fn(player, reason))`, `register_on_respawnplayer(fn(player))` (`true` disables default respawn pos).
  * `register_on_cheat(fn(player, cheat))` (`cheat.type`: `moved_too_fast`, `interacted_too_far`, `interacted_with_self`, `interacted_while_dead`, `finished_unknown_dig`, `dug_unbreakable`, `dug_too_fast`).
  * `register_on_chat_message(fn(name, msg))` -> `true` suppresses broadcast.
  * `register_on_chatcommand(fn(name, cmd, params))` -> `true` handles before default.
  * `register_on_player_receive_fields(fn(player, formname, fields))`: Newest first; `true` stops chain. Not called for nodemeta formspecs. `formname=""` = player inventory. `fields` has `quit="true"`, `try_quit="true"`, `key_enter="true"`, `key_enter_field`.
  * `register_on_craft(fn(stack, player, old_grid, craft_inv))` -> `ItemStack|nil`; `register_craft_predict(...)` (read-only prediction).
  * `register_allow_player_inventory_action(fn(player, action, inv, info))` -> max count (`-1` no-modify); `register_on_player_inventory_action(...)` (`action="move"` `{from_list,to_list,from_index,to_index,count}`, `"put"`/`"take"` `{listname,index,stack}`).
  * `register_on_protection_violation(fn(pos, name))`.
  * `register_on_item_eat(fn(hp_change, replace_with, stack, user, pt))` -> `ItemStack` cancels default eat & later callbacks.
  * `register_on_item_pickup(fn(stack, picker, pt, time_from_last_punch, ...))` -> `ItemStack` cancels default pickup.
  * `register_on_priv_grant(fn(name, granter, priv))`, `register_on_priv_revoke(fn(name, revoker, priv))` (called twice if done by player: once with playername, once with nil).
  * `register_can_bypass_userlimit(fn(name, ip))` -> `true` bypasses.
  * `register_on_modchannel_message(fn(channel, sender, msg))` (`sender=""` if server mod).
  * `register_on_liquid_transformed(fn(pos_list, old_node_list))`.
  * `register_on_mapblocks_changed(fn(modified_blocks_hashset, count))`: Once/step max; keys are `hash_node_position` of blockpos.

### Settings, Auth & Chat
* `core.settings` (`Settings`); `core.setting_get_pos(name)` (deprecated).
* Auth: `string_to_privs(str, delim=",")`, `privs_to_string(privs, delim=",")`, `get_player_privs(name)`, `check_player_privs(player_or_name, ...) -> bool, missing`, `check_password_entry(name, entry, pass) -> bool`, `get_password_hash(name, pass)` (salted, non-deterministic), `get_player_ip(name)`, `get_auth_handler()` (after load time), `notify_authentication_modified([name])`, `set_player_password(name, hash)`, `set_player_privs(name, privs)`, `change_player_privs(name, changes)` (`{[p]=true|false}`), `auth_reload()`.
* Chat: `chat_send_all(text)`, `chat_send_player(name, text)`, `format_chat_message(name, msg)` (overridable).

### Environment, Mapgen, Pathfinding
* Nodes: `set_node(pos, node)` (alias `add_node`, clears meta), `bulk_set_node(pos_list, node)`, `swap_node(pos, node)` (keeps meta, no callbacks), `bulk_swap_node(pos_list, node)`, `remove_node(pos)` (faster air), `get_node(pos)` (returns `ignore` if unloaded), `get_node_or_nil(pos)`, `get_node_raw(x,y,z) -> id, p1, p2, pos_ok`.
* Light: `get_node_light(pos[, tod]) -> 0..15|nil`, `get_natural_light(pos[, tod]) -> 0..15|nil`, `get_artificial_light(param1) -> 0..15`.
* Node Actions: `place_node(pos, node[, placer]) -> bool` (calls `on_place`), `dig_node(pos[, digger]) -> bool`, `punch_node(pos[, puncher]) -> bool`, `spawn_falling_node(pos) -> bool, ObjectRef`.
* Meta/Timers: `find_nodes_with_meta(p1, p2) -> {pos...}`, `get_meta(pos) -> NodeMetaRef`, `get_node_timer(pos) -> NodeTimerRef`.
* Objects: `add_entity(pos, name[, staticdata]) -> ObjectRef|nil`, `add_item(pos, item) -> ObjectRef|nil`, `get_player_by_name(name) -> ObjectRef|nil`, `get_objects_inside_radius(center, r)` (list; unsafe if world mutated during loop), `objects_inside_radius(center, r)` (safe iterator), `get_objects_in_area(minp, maxp)`, `objects_in_area(minp, maxp)` (safe iterator).
* Time: `set_timeofday(0..1)`, `get_timeofday()`, `get_gametime() -> [u32]|nil` (`nil` before 1st step), `get_day_count() -> [u32]`.
* Area search: `find_node_near(pos, r, names[, search_center=false]) -> pos|nil`, `find_nodes_in_area(p1, p2, names[, grouped=false])` (vol<=150M; returns `pos_list, counts` or `{[name]={pos...}}`), `find_nodes_in_area_under_air(p1, p2, names) -> {pos...}`.
* Noise & Mapgen: `get_value_noise(np)` (`get_perlin` deprecated), `get_value_noise_map(np, size)` (`get_perlin_map` deprecated), `get_voxel_manip([p1, p2])`, `set_gen_notify(flags[, deco_ids, custom_ids])`, `get_gen_notify() -> flags, deco_ids, custom_ids`, `get_decoration_id(name)`, `get_mapgen_object(name)`, `get_heat(pos)`, `get_humidity(pos)`, `get_biome_data(pos) -> {biome, heat, humidity}|nil`, `get_biome_id(name)`, `get_biome_name(id)`, `get_mapgen_edges([limit[, chunksize]]) -> minp, maxp`, `get_mapgen_chunksize() -> vec`, `get_mapgen_setting(name)` (`"seed"` is `[u64]` string!), `get_mapgen_setting_noiseparams(name)`, `set_mapgen_setting(name, val, override_meta=false)`, `set_mapgen_setting_noiseparams(name, np, override_meta=false)`, `set_noiseparams(name, np, set_default=true)`, `get_noiseparams(name)`, `generate_ores(vm[, p1, p2])`, `generate_decorations(vm[, p1, p2[, use_mapgen_biomes=false]])`. (`get_mapgen_params`/`set_mapgen_params` deprecated).
* Blocks: `clear_objects([opts])` (`mode="full"|"quick"`), `load_area(p1[, p2])` (no mapgen), `emerge_area(p1, p2[, cb(blockpos, action, calls_remaining, param), param])` (actions: `EMERGE_GENERATED`, `EMERGE_FROM_MEMORY`, `EMERGE_FROM_DISK`, `EMERGE_CANCELLED`, `EMERGE_ERRORED`), `delete_area(p1, p2) -> bool`.
* Raycast/Path/Trees/Levels/Falling:
  * `line_of_sight(p1, p2) -> bool, block_pos` (checks non-air).
  * `raycast(p1, p2, objects=true, liquids=false, pointabilities=nil) -> Raycast`.
  * `find_path(p1, p2, searchdist [u16], max_jump [u16], max_drop [u16], algo="A*_noprefetch"|"A*"|"Dijkstra") -> {pos...}|nil`.
  * `spawn_tree(pos, treedef)`, `spawn_tree_on_vmanip(vm, pos, treedef)`.
  * `transforming_liquid_add(pos)` (queue liquid flow).
  * `get_node_max_level(pos)`, `get_node_level(pos)`, `set_node_level(pos, lvl=1 [0..63]) -> rest`, `add_node_level(pos, lvl=1 [-127..127]) -> rest`.
  * `get_node_boxes("node_box"|"collision_box"|"selection_box", pos[, node]) -> {{x1,y1,z1,x2,y2,z2}, ...}` (relative to `pos`).
  * `fix_light(p1, p2) -> bool` (mapblock-aligned), `check_single_for_falling(pos)`, `check_for_falling(pos)` (cascades), `get_spawn_level(x, z) -> y|nil`.

### Mod Channels, Inventory, Formspec, Item Handling, Rollback, Defaults, Sounds, Timing
* `mod_channel_join(name) -> ModChannel`.
* `get_inventory(loc)` (`{type="player"|"node"|"detached", ...}`), `create_detached_inventory(name, cbs[, player_name]) -> InvRef`, `remove_detached_inventory(name) -> bool`.
* `do_item_eat(hp_change, replace_with, stack, user, pt) -> stack|nil`.
* `show_formspec(player, formname, formspec)` (`""` shows temp inv formspec if server&client >=5.13), `close_formspec(player, formname)` (`""` closes any), `formspec_escape(s)`, `hypertext_escape(s)`, `explode_table_event(s) -> {type="INV"|"CHG"|"DCL", row, column}`, `explode_textlist_event(s) -> {type, index}`, `explode_scrollbar_event(s) -> {type="INV"|"CHG"|"VAL", value}`, `show_death_screen(player, reason)` (overridable).
* `inventorycube(t, l, r)`, `get_pointed_thing_position(pt, above)`, `dir_to_facedir(dir[, is6d])`, `facedir_to_dir(f)`, `dir_to_fourdir(dir)`, `fourdir_to_dir(f)`, `dir_to_wallmounted(dir)`, `wallmounted_to_dir(w)`, `dir_to_yaw(dir)`, `yaw_to_dir(yaw)`, `is_colored_paramtype(pt)`, `strip_param2_color(p2, pt)`, `get_node_drops(node[, toolname, tool, digger, pos]) -> {itemstr...}` (extra args 5.12+), `get_craft_result(input) -> output, decremented_input` (`input={method="normal"|"cooking"|"fuel", width, items}`; `output={item, time, replacements}`), `get_craft_recipe(output)`, `get_all_craft_recipes(output) -> {{method, width, items, output, time (5.17+), replacements (5.17+)}}|nil`, `handle_node_drops(pos, drops, digger)` (overridable), `itemstring_with_palette(item, idx)`, `itemstring_with_color(item, cs)`.
* `rollback_get_node_actions(pos, range, secs, limit) -> {{actor, pos, time, oldnode, newnode}, ...}|nil`, `rollback_revert_actions_by(actor, secs) -> bool, msgs`.
* Default callbacks: `item_place_node(stack, placer, pt[, p2, prevent_after_place]) -> stack, pos`, `item_place(stack, placer, pt[, p2]) -> stack, pos` (calls `on_rightclick` if defined), `item_pickup(...)`, `item_secondary_use(...)`, `item_drop(stack, dropper, pos) -> stack, obj (5.12+)`, `item_eat(hp[, replace]) -> fn`, `node_punch(...)`, `node_dig(...)`.
* `sound_play(spec, params[, ephemeral=false]) -> handle`, `sound_stop(handle)`, `sound_fade(handle, step_per_sec, target_gain)` (`0` deletes).
* `after(secs, fn, ...) -> job` (`job:cancel()`). Ordered by expiry, then registration.

### Async & Mapgen Envs, IPC, Server, Bans, Particles, Schematics, HTTP, Storage, Misc
* **Async**: `handle_async(fn, cb, ...) -> AsyncJob`, `register_async_dofile(path)`. Available: `AreaStore`, `ItemStack`, `ValueNoise`, `ValueNoiseMap`, `PseudoRandom`, `PcgRandom`, `SecureRandom`, `VoxelArea`, `VoxelManip` (transferred only), `Settings`, `core.settings`, `core.registered_{items,nodes,tools,craftitems,aliases}` (funcs/userdata = `true`), `register_portable_metatable`, IPC, standalone helpers. Transferable userdata: `ItemStack`, `ValueNoise`, `ValueNoiseMap`, `VoxelManip`.
* **Mapgen env**: `register_mapgen_script(path)`. Exclusive: `register_on_generated(fn(vm, minp, maxp, blockseed))` (no `read_from_map`/`write_to_map`), `save_gen_notify(id, data) -> bool` (no userdata). Available: same as async + `registered_{biomes,ores,decorations}`, biome/mapgen queries, node ops on current chunk only (no node meta).
* **IPC** (serializes/copies on access, no userdata): `ipc_get(key)`, `ipc_set(key, val)`, `ipc_cas(key, old, new) -> bool`, `ipc_poll(key, timeout_ms) -> bool` (blocking, avoid on main thread).
* **Server**: `request_shutdown([msg, reconnect=false, delay=0])` (delay<0 cancels), `cancel_shutdown_requests()`, `get_server_status(name, joined)` (overridable), `get_server_uptime()`, `get_server_max_lag()`, `remove_player(name) -> 0|1|2` (`0=ok, 1=missing, 2=online`), `remove_player_auth(name) -> bool`, `dynamic_add_media({filename, filepath|filedata, to_player, ephemeral=false, client_cache=!ephemeral (5.14+)}, cb(name)) -> bool` (if `cb=nil`, startup only without `ephemeral`/`to_player`).
* **Bans**: `get_ban_list()`, `get_ban_description(ip_or_name)`, `ban_player(name) -> bool`, `unban_player_or_ip(ip_or_name)`, `kick_player(name[, reason, reconnect]) -> bool`, `disconnect_player(name[, reason, reconnect]) -> bool` (no `"Kicked: "` prefix).
* **Particles**: `add_particle(def)`, `add_particlespawner(def) -> id (-1 fail)`, `delete_particlespawner(id[, playername])`.
* **Schematics**: `create_schematic(p1, p2, prob_list, filename, slice_prob_list)` (`prob` `0..127` + `128` force_place), `place_schematic(pos, schem, rot, replacements, force, flags)` (files cached forever!), `place_schematic_on_vmanip(vm, pos, schem, rot, replacements, force, flags) -> bool|nil`, `serialize_schematic(schem, "mts"|"lua", {lua_use_comments, lua_num_indent_spaces})`, `read_schematic(schem, {write_yslice_prob="all"|"low"|"none"})`.
* **HTTP** (init time, main scope only, mod must be in `secure.http_mods`/`trusted_mods`): `request_http_api() -> {fetch(req, cb(res)), fetch_async(req) -> h, fetch_async_get(h) -> res}|nil`.
* **Storage**: `get_mod_storage() -> StorageRef` (load-time; JSON-backed, no raw binary).
* **Misc**: `get_connected_players()`, `is_player(obj)`, `player_exists(name)`, `is_valid_player_name(name)`, `hud_replace_builtin("breath"|"health"|"minimap"|"hotbar", def)`, `parse_relative_number(arg, rel)`, `send_join_message(name)`, `send_leave_message(name, timed_out)`, `hash_node_position(pos)` (`[0,2^48-1]`), `get_position_from_hash(hash)`, `get_item_group(name, grp)` (`get_node_group` deprecated), `raillike_group(name)`, `get_content_id(name)`, `get_name_from_content_id(id)`, `parse_json(s[, nullval, ret_err])`, `write_json(data[, styled])` (empty tables -> `null`, no mixed keys), `serialize(val)`, `deserialize(s[, safe])` (UNSAFE on untrusted input), `compress(data, "deflate"|"raw_deflate"|"zstd", [level])`, `decompress(data, method)`, `rgba(r,g,b[,a])`, `encode_base64(s)`, `decode_base64(s)`, `is_protected(pos, name)` (overridable; chain old!), `record_protection_violation(pos, name)`, `is_creative_enabled(name)` (overridable), `is_area_protected(p1, p2, name, interval=4) -> pos|false`, `rotate_and_place(stack, placer, pt[, inf, orient_flags, prevent_after])`, `rotate_node(...)`, `calculate_knockback(...)` (overridable), `forceload_block(pos[, transient=false[, limit]]) -> bool`, `forceload_free_block(pos[, transient=false])`, `get_loaded_blocks()`, `get_loadable_blocks()` (expensive), `get_active_blocks()`, `compare_block_status(pos, "unknown"|"emerging"|"loaded"|"active") -> bool|nil`, `request_insecure_environment()` (`init.lua` main scope only), `global_exists(name)`, `register_portable_metatable(name, mt)` (register in both main & async envs).
* **Global objects/tables**: `core.env` (deprecated), `core.registered_{items,nodes,craftitems,tools,entities,abms,lbms,aliases,ores,biomes,decorations,chatcommands,privileges}`, `core.objects_by_guid`, `core.object_refs` (obsolete), `core.luaentities`.

## Class Reference
* `AreaStore([type="LibSpatial"])`: `get_area(id, corners, data)` -> `nil|true|{min,max,data}`, `get_areas_for_pos(pos, corners, data)`, `get_areas_in_area(c1, c2, overlap, corners, data)`, `insert_area(c1, c2, data[, id])` (`[0,2^32-2]`), `reserve(n)`, `remove_area(id) -> bool`, `set_cache_params({enabled=true, block_radius=64 (>=16), limit=1000 (>=20)})`, `to_string()`, `to_file(fn)`, `from_string(s)`, `from_file(fn)` (experimental).
* `AsyncJob`: `cancel() -> bool` (only if not yet started).
* `InvRef`: `is_empty(l)`, `get_size(l)`, `set_size(l, sz [0..32767])` (`0` deletes), `get_width(l)`, `set_width(l, w [0..32767])`, `get_stack(l, i)`, `set_stack(l, i, stack)`, `get_list(l)`, `set_list(l, list)`, `get_lists()`, `set_lists(lists)`, `add_item(l, stack) -> leftover`, `room_for_item(l, stack)`, `contains_item(l, stack[, match_meta=false])` (ignores wear), `remove_item(l, stack[, match_meta=false]) -> taken` (reverse order, ignores wear, 5.12+), `get_location()`.
* `ItemStack([x])`: `is_empty()`, `get_name()`, `set_name(n)`, `get_count()`, `set_count(c [u16])`, `get_wear()`, `set_wear(w [u16])`, `get_meta() -> ItemStackMetaRef`, `get_metadata()`/`set_metadata()` (deprecated), `get_description()` (meta -> def -> name), `get_short_description()` (meta short -> def short -> 1st line desc -> name), `clear()`, `replace(item)`, `to_string()`, `to_table() -> tbl|nil`, `get_stack_max()`, `get_free_space()`, `is_known()`, `get_definition()`, `get_tool_capabilities()`, `add_wear(amt)`, `add_wear_by_uses(max_uses)`, `get_wear_bar_params()`, `add_item(item) -> leftover`, `item_fits(item)`, `take_item(n=1)`, `peek_item(n=1)`, `equals(other)` / `==` (false if compared to string/table).
* `MetaDataRef` (base for `StorageRef`, `NodeMetaRef`, `ItemStackMetaRef`, `PlayerMetaRef`): `contains(k)`, `get(k) -> str|nil`, `set_string(k, v)` (`""` deletes), `get_string(k)` (`""` if missing), `set_int(k, v [s32])`, `get_int(k)` (`0` if missing), `set_float(k, v)`, `get_float(k)`, `get_keys()`, `to_table() -> {fields={}, inventory={}}`, `from_table(t)`, `equals(other)`.
  * `ItemStackMetaRef` adds: `set_tool_capabilities([caps])`, `set_wear_bar_params([params])`.
  * `NodeMetaRef` adds: `get_inventory() -> InvRef`, `mark_as_private(name|names)` (requires existing key-value).
* `ModChannel`: `leave()`, `is_writeable()`, `send_all(msg)` (max 65535 chars).
* `NodeTimerRef`: `set(timeout, elapsed)`, `start(timeout)`, `stop()`, `get_timeout()` (`0` = inactive), `get_elapsed()`, `is_started()`.
* `ObjectRef` (don't store across ticks; check `is_valid()`):
  * Common: `is_valid()`, `get_pos()`, `set_pos(p)`, `add_pos(p)`, `get_velocity()`, `add_velocity(v)` (for players: not in `free_move`; horizontal normalized), `move_to(p, continuous=false)`, `punch(puncher, time_from_last_punch, tool_caps, dir)`, `right_click(clicker)`, `get_hp()`, `set_hp(hp [u16][, reason])`, `get_inventory()` (players only), `get_wield_list()`, `get_wield_index()`, `get_wielded_item()`, `set_wielded_item(item[, skip_anim=false])`, `get_armor_groups()`, `set_armor_groups(t)`, `set_attach(parent[, bone="", pos={0,0,0} (10x node scale!), rot_deg={0,0,0}, forced_visible=false])`, `get_attach() -> parent, bone, pos, rot, forced_visible`, `get_children()`, `set_detach()`, `set_bone_override(bone, {position/rotation/scale={vec, interpolation=0, absolute=false}}|nil)` (rot in **radians**; `set_bone_position`/`get_bone_position` deprecated, deg), `get_bone_override(bone)`, `get_bone_overrides()`, `set_properties(t)`, `get_properties()`, `set_observers({[name]=true}|nil)` (attached sounds broken), `get_observers()`, `get_effective_observers()`, `is_player()`, `get_nametag_attributes()`, `set_nametag_attributes({text, color, bgcolor})`, `get_guid()` (5.13+; player name or `@...`).
  * Animations (old): `set_animation(range={x=1,y=1}, speed=15 (use 1 for glTF), blend=0, loop=true)`, `get_animation()`, `set_animation_frame_speed(speed)`.
  * Animations (new, >=5.17, don't mix track names & 1-based numbers): `play_animation(track, {min_frame=0, max_frame=inf, start_frame, speed=1, loop=true, blend=0, priority=0})`, `update_animation(track, {speed})`, `stop_animation([track])`, `get_animations()`.
  * LuaEntity-only: `remove()` (instantly invalidates ref), `set_velocity(v)`, `set_acceleration(a)`, `get_acceleration()`, `set_rotation(rad_vec[, interpolate=true])` (right-handed Z-X-Y), `get_rotation()`, `set_yaw(rad)` (zeros pitch/roll), `get_yaw()`, `set_texture_mod(mod)`, `get_texture_mod()`, `set_sprite(start={x=0,y=0}, num=1, len=0.2, select_x_by_camera=false)`, `get_luaentity()`, `get_entity_name()` (deprecated).
  * Player-only: `get_player_name()`, `get_look_dir()`, `get_look_vertical()`, `get_look_horizontal()`, `set_look_vertical(rad)`, `set_look_horizontal(rad)` (`pitch`/`yaw` variants deprecated), `get_breath()`, `set_breath(u16)`, `set_fov(fov, is_mult=false, transition=0)` (`0` clears), `get_fov() -> fov, is_mult, trans`, `get_meta() -> PlayerMetaRef` (`set_attribute`/`get_attribute` deprecated), `set_inventory_formspec(fs)` (`""` disables; updates live), `get_inventory_formspec()`, `set_formspec_prepend(fs)`, `get_formspec_prepend()`, `get_player_control() -> {up,down,left,right,jump,aux1,sneak,dig,place,LMB,RMB,zoom,movement_x,movement_y}`, `get_player_control_bits()`, `set_physics_override({speed, speed_walk, speed_climb, speed_crouch, speed_fast, jump, gravity, liquid_fluidity (>=1), liquid_fluidity_smooth, liquid_sink, acceleration_default, acceleration_air, acceleration_fast, sneak, sneak_glitch, new_move})`, `get_physics_override()`, `hud_add(def) -> id|nil`, `hud_remove(id) -> bool|nil`, `hud_change(id, stat, val) -> bool|nil`, `hud_get(id)`, `hud_get_all()`, `hud_set_flags({hotbar,healthbar,crosshair,wielditem,breathbar,minimap,minimap_radar,basic_debug,chat})`, `hud_get_flags()`, `hud_set_hotbar_itemcount(1..32)`, `hud_get_hotbar_itemcount()`, `hud_set_hotbar_image(tex)`, `hud_get_hotbar_image()`, `hud_set_hotbar_selected_image(tex)`, `hud_get_hotbar_selected_image()`, `set_minimap_modes(modes, sel_idx)` (`type="off"|"surface"|"radar"|"texture"`, `label`, `size`, `texture` <=512px, `scale`), `set_sky(params)` (`base_color`, `body_orbit_tilt [-60..60]`, `type="regular"|"skybox"|"plain"`, `textures[1..6]` Y+,Y-,X+,X-,Z-,Z+, `clouds`, `sky_color={day_sky,day_horizon,dawn_sky,dawn_horizon,night_sky,night_horizon,indoors,fog_sun_tint,fog_moon_tint,fog_tint_type}`, `fog={fog_distance, fog_start, fog_color}`, `auto_dim_skybox` >=5.16), `get_sky(as_table)`, `set_sun({visible, texture, tonemap, sunrise, sunrise_visible, scale})` (`scale` ~1.57x larger than moon), `get_sun()`, `set_moon({visible, texture, tonemap, scale})` (rot 180° relative to sun), `get_moon()`, `set_stars({visible, day_opacity, count [0..16384], star_color, scale, star_seed [u32]})`, `get_stars()`, `set_clouds({density, color, ambient, height, thickness, speed, shadow})`, `get_clouds()`, `override_day_night_ratio(0..1|nil)`, `get_day_night_ratio()`, `set_local_animation(idle, walk, dig, walk_dig, speed=30)` (track 1), `get_local_animation()`, `set_eye_offset([fp, tp_back, tp_front])` (`tp` clamped `[-10,-10,-5]..[10,15,5]`), `get_eye_offset()`, `set_camera({mode="any"|"first"|"third"|"third_front"}|nil)` (>=5.12; nil >=5.16), `get_camera()`, `send_mapblock(blockpos) -> bool`, `set_lighting({saturation=1, shadows={intensity,tint,direction}, exposure={luminance_min=-3,luminance_max=-3,exposure_correction=0,speed_dark_bright=1000,speed_bright_dark=1000,center_weight_power=1}, bloom={intensity=0.05,strength_factor=1,radius=1}, volumetric_light={strength=0}, static={light_curve[1..16], ao_gamma=1.8}}|nil)`, `get_lighting()`, `respawn()`, `get_flags()`, `set_flags({breathing, drowning, node_damage})`.
* `PcgRandom(seed[, seq])` (`[ulua]`): `next([min, max])`, `rand_normal_dist(min, max, trials=6)`, `get_state()`, `set_state(s)`.
* `PseudoRandom(seed [s32])`: `next([min, max])` (`max-min == 32767` or `<= 6553`), `get_state() -> num`.
* `SecureRandom()`: `next_bytes(count=1 [<=2048]) -> str`.
* `Raycast(p1, p2, objects=true, liquids=false, pointabilities=nil)`: `next() -> pointed_thing|nil` (iterable; unreliable for attached objects & `automatic_rotate` boxes).
* `Settings([filename])`: `get(k)`, `get_bool(k[, def])`, `get_np_group(k)`, `get_flags(k)` (`mg_flags`/`mg*_spflags`), `get_pos(k)`, `set(k, v)`, `set_bool(k, v)`, `set_np_group(k, v)`, `set_pos(k, v)`, `remove(k)`, `get_names()`, `has(k)` (ignores defaults), `write()`, `to_table()`.
* `ValueNoise(np)` & `ValueNoiseMap(np, size)` (5.12+, formerly `PerlinNoise*`; requires initialized mapgen env): `get_2d(pos)`, `get_3d(pos)` / `get_2d_map(pos)`, `get_3d_map(pos)`, `get_2d_map_flat(pos, buf)`, `get_3d_map_flat(pos, buf)`, `calc_2d_map(pos)`, `calc_3d_map(pos)`, `get_map_slice(offset, size, buf)` (1-based).

## Definition Tables
* **Object properties** (initial values set via entity `initial_properties`; player properties non-persistent):
  `hp_max=10` (player def `20`; entity >0; `[u16]`), `breath_max=0` (player def `10`; `[u16]`), `zoom_fov=0` (creative 15, survival 0), `eye_height=1.625`, `physical=false`, `collide_with_objects=true`, `collisionbox={-0.5,-0.5,-0.5,0.5,0.5,0.5}` (never rotates), `selectionbox={..., rotate=false}` (<=5 units for server raycasts; obeys entity+attachment rot), `pointable=true|false|"blocking"`, `visual="sprite"|"upright_sprite"|"cube"|"mesh"|"wielditem"|"item"|"node"` (5.12+; player def `"upright_sprite"`; use `wield_item=name` for wielditem, `visual_size=0.667` for 1-node scale), `visual_size={x=1,y=1,z=1}` (player `{1,2,1}`), `mesh` (10 units = 1 node), `textures={}` (`cube`:6, `sprite`:1, `upright_sprite`:2, `mesh`:per material), `node={name,p1,p2}`, `use_texture_alpha=false`, `spritediv={x=1,y=1}`, `initial_sprite_basepos={x=0,y=0}`, `is_visible=true`, `makes_footstep_sound=false`, `automatic_rotate=0` (rad/s right-handed Y), `stepheight=0`, `automatic_face_movement_dir=0.0|false`, `automatic_face_movement_max_rotation_per_sec=-1`, `backface_culling=true`, `glow=0` (<0 unshaded), `nametag=""`, `nametag_color`, `nametag_bgcolor=false`, `nametag_fontsize=false`, `nametag_scale_z=false`, `infotext=""`, `static_save=true`, `damage_texture_modifier="^[brighten"`, `shaded=true`, `show_on_minimap=false` (player `true`), `step_up_mode="legacy"|"floaty"|"rigid"` (>=5.16).
* **ABM**: `{label, nodenames, neighbors, without_neighbors (5.10+), interval=10, chance=50 ([u32], 0->1), min_y=-32768, max_y=32767, catch_up=true, action(pos, node, active_obj_cnt, active_obj_cnt_wider)}`.
* **LBM**: `{label, name, nodenames, run_at_every_load=false, action(pos, node, dtime_s) | bulk_action(pos_list, dtime_s)}`. (Runs on block activation, not load/mapgen).
* **Tile**: `"img.png"` | `{name, animation, backface_culling=true, align_style="node"|"world"|"user", scale=int (divides 16), color=ColorSpec}` (`image` deprecated).
* **Tile animation**: `{type="vertical_frames", aspect_w, aspect_h, length}` | `{type="sheet_2d", frames_w, frames_h, frame_length}`.
* **Item def**: `description`, `short_description`, `groups`, `inventory_image`, `inventory_overlay`, `wield_image`, `wield_overlay`, `wield_scale={1,1,1}`, `palette`, `color="#ffffffff"`, `stack_max=99 [1..65535]`, `range=4.0`, `liquids_pointable=false`, `pointabilities={nodes={[name|grp]=bool|"blocking"}, objects={[name|grp]=bool|"blocking"}}` (priority: exact name -> grp `true` -> grp `false` -> grp `"blocking"` -> `liquids_pointable` -> node/obj `pointable`), `light_source=0 (0..LIGHT_MAX=14)`, `tool_capabilities`, `wear_color={blend="constant"|"linear", color_stops={[0..1]=ColorSpec}}|ColorSpec`, `node_placement_prediction`, `node_dig_prediction="air"`, `touch_interaction` (`"user"|"long_dig_short_place"|"short_dig_long_place"` or `{pointed_nothing, pointed_node, pointed_object}`), `sound={breaks, eat, punch_use, punch_use_air}`, `on_place(stack, placer, pt)`, `on_secondary_use(stack, user, pt)`, `on_drop(stack, dropper, pos)` (only returned count matters), `on_pickup(stack, picker, pt, ...)`, `on_use(stack, user, pt)` (disables client dig/punch), `after_use(stack, user, node, digparams)`, `_custom`.
* **Node def**: all Item fields + `drawtype`, `visual_scale=1.0`, `tiles[1..6]` (`+Y,-Y,+X,-X,+Z,-Z`), `overlay_tiles[1..6]`, `special_tiles[1..2]`, `color`, `use_texture_alpha="opaque"|"clip"|"blend"`, `palette`, `post_effect_color`, `post_effect_color_shaded=false`, `paramtype`, `paramtype2`, `place_param2=0`, `wallmounted_rotate_vertical=false`, `is_ground_content=true` (carved by caves/dungeons), `sunlight_propagates=false`, `walkable=true`, `pointable=true|false|"blocking"`, `diggable=true`, `climbable=false`, `move_resistance=0 [0..7]` (defaults to `liquid_viscosity`), `buildable_to=false`, `floodable=false` (never on liquids), `liquidtype="none"|"source"|"flowing"`, `liquid_alternative_{flowing,source}`, `liquid_viscosity=0 [0..7]`, `liquid_renewable=true`, `liquid_move_physics=nil`, `leveled=0`, `leveled_max=127` (>124 collision issues), `liquid_range=8 [0..8]`, `drowning=0`, `damage_per_second=0`, `node_box`, `connects_to`, `connect_sides`, `mesh` (glTF: 10u=1n, obj: 1u=1n, b3d/x static: 1u=1n else 10u=1n), `selection_box`, `collision_box`, `legacy_facedir_simple`, `legacy_wallmounted`, `waving=0..3` (1=plant, 2=leaves, 3=liquid), `sounds={footstep (0.6x pos gain), dig="__group"|spec, dug, place, place_failed, fall}`, `drop=str|{max_items=1, items={{rarity=1, tools, tool_groups, items, inherit_color=false}}}`, `on_construct(pos)`, `on_destruct(pos)`, `after_destruct(pos, oldnode)`, `on_flood(pos, oldnode, newnode)` (`true` cancels), `preserve_metadata(pos, oldnode, oldmeta, drops)`, `after_place_node(pos, placer, stack, pt)`, `after_dig_node(pos, oldnode, oldmeta, digger)`, `can_dig(pos[, player])`, `on_punch(pos, node, puncher, pt)`, `on_rightclick(pos, node, clicker, stack, pt) -> stack`, `on_dig(pos, node, digger) -> bool`, `on_timer(pos, elapsed, node (5.14+), timeout (5.14+))` (`true` restarts), `on_receive_fields(pos, formname, fields, sender)`, `allow_metadata_inventory_{move,put,take}` (`-1` allows without modifying), `on_metadata_inventory_{move,put,take}`, `on_blast(pos, intensity)`, `mod_origin`.
* **Crafting**: `type="shaped"` (default; 2D `recipe` rows, `""` empty, `replacements={{old,new},...}`), `"shapeless"` (1D `recipe`), `"toolrepair"` (`additional_wear=-0.02`; `65536*(1-((1-w1)+(1-w2)-add))`), `"cooking"` (`recipe` str, `cooktime=3.0`, `replacements`), `"fuel"` (`recipe` str, `burntime=1.0`, `replacements`). Priority: shaped > shapeless > toolrepair; no-groups > groups; earlier > later.
* **Ore**: `{name, ore_type, ore, ore_param2=0, wherein, clust_scarcity=512 [u32>0], clust_num_ores=8, clust_size=3, y_min, y_max, flags, noise_threshold, noise_params, biomes, column_height_min, column_height_max, column_midpoint_factor, np_puff_top, np_puff_bottom, random_factor, np_stratum_thickness, stratum_thickness}`.
* **Biome**: `{name, node_dust, node_top, depth_top, node_filler, depth_filler, node_stone, node_water_top, depth_water_top, node_water, node_river_water, node_riverbed, depth_riverbed, node_cave_liquid, node_dungeon, node_dungeon_alt, node_dungeon_stair, y_max, y_min, max_pos, min_pos, vertical_blend=0, heat_point, humidity_point, weight=1.0 (5.11+)}`. Max 65535 biomes.
* **Decoration**: `{name, deco_type="simple"|"schematic"|"lsystem", place_on, sidelen=8, fill_ratio=0.02 (>=10 complete), noise_params, biomes, y_min, y_max, spawn_by, check_offset=-1 (-1|0|1), num_spawn_by=-1, flags="liquid_surface, force_placement, all_floors, all_ceilings", decoration, height=1, height_max=0, param2=0, param2_max=0, place_offset_y=0, schematic, replacements, rotation, treedef}`.
* **PlayerHPChangeReason**: `{type="set_hp"|"punch"|"fall"|"node_damage"|"drown"|"respawn", object, node, node_pos, custom_type, from="engine"|"mod"}`.
* **Chatcommand**: `{params="", description="", privs={}, func(name, param) -> bool[, msg]}`.
* **Privilege**: `{description="", give_to_singleplayer=true, give_to_admin, on_grant(name, granter), on_revoke(name, revoker)}` (`true` stops global callbacks).
* **Detached inv**: `{allow_{move,put,take}(inv, ...), on_{move,put,take}(inv, ...)}`.
* **Particle / ParticleSpawner**:
  * Particle: `{pos, velocity, acceleration, expirationtime=1, size=1 (0+node=random), collisiondetection=false, collision_removal=false, object_collision=false, vertical=false, texture, playername, animation, glow=0..14, node, node_tile=0..6, drag=vec, jitter={min,max,bias}, bounce={min,max,bias}}`.
  * ParticleSpawner: `{amount=1 [u16], time=1 (0=inf), size=1, collisiondetection, collision_removal, object_collision, attached=ObjectRef, vertical, texture, texpool, playername, exclude_player (5.14+), animation (length<0 syncs to particle exptime), glow, node, node_tile, legacy min*/max* fields}` + modern range/tween fields (5.6+): `pos`, `vel`, `acc`, `size`, `jitter`, `drag`, `bounce`, `exptime`, `radius`, `attract={kind="none"|"point"|"line"|"plane", strength, origin, direction, origin_attached, direction_attached, die_on_contact=true}`, and `<prop>_tween={style="fwd"|"rev"|"pulse"|"flicker", reps=1..65535, start=0..1, frame1, frameN}`.
  * Texture table (5.6+): `{name, alpha=1, alpha_tween, scale=1|{x,y}, scale_tween, blend="alpha"|"clip"|"add"|"screen"|"sub", animation}`.
* **HTTPRequest / Result**: `{url, timeout, method="GET"|"HEAD"|"POST"|"PUT"|"PATCH"|"DELETE", data (str|table), user_agent, extra_headers, multipart=false, quiet=false}` -> `{completed, succeeded, timeout, code, data, error (if not succeeded, 5.19+)}`.
* **Auth handler**: `{get_auth(name) -> {password, privileges, last_login}|nil, create_auth(name, pass), delete_auth(name) -> bool, set_password(name, pass), set_privileges(name, privs), reload() -> bool, record_login(name), iterate()}`.

## Bit Library, Tracy, Error Handling
* `bit.{tobit, tohex, bnot, band, bor, bxor, lshift, rshift, arshift, rol, ror, bswap}` (LuaJIT BitOp).
* `tracy` global (when built with Tracy; unstable dev feature).
* `core.error_handler(err, stack_level) -> str` (overridable; default uses `debug.traceback`; tables use `__tostring`).