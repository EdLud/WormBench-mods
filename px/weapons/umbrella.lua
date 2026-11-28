-- Umbrella: WA's parachute with an umbrella's art, blown twice as hard by the wind.

local weapon = {}

weapon.record = {
  parachute = {
    wind_pct = 200,
  },
}

function weapon.definition()
  return require("lib/weapon").merge(weapon.record, {
    copy_from = "stock.parachute",
    name = "Umbrella",
    panel_icon = "sprites/umbrella/icon.png",
    sprites = { "sprites/umbrella/open.png", "sprites/umbrella/hang.png", "sprites/umbrella/pack_away.png" },
    params = {
      gpu_prefix = "sprites/umbrella/",
      worm_art = { "sprites/umbrella/open.png", "sprites/umbrella/hang.png", "sprites/umbrella/pack_away.png" },
    },
  })
end

function weapon.setup()
  local own_time = require("wf-lib/own_time")
  local parachute = require("lib/parachute")
  parachute.setup()

  local ID = "px.umbrella"
  local DEPTH = wa.depth.WORMS
  -- WA's parachute sheets play at 25 frames a second: the opening once
  -- (wparalnk), then the hanging one swinging back and forth (wparacht).
  local STEP = 2 -- game frames per frame
  local OPEN_FRAMES, HANG_FRAMES, PACK_FRAMES = 17, 13, 6
  local LANDING = { jump_falling = true, standing = true }
  local umbrellas = {}

  local function drop_art(worm, u)
    if u.art then u.art:remove(); u.art = nil end
    u.sheet = nil
    worm.body_visible = true
  end

  -- Draws `sheet` in the worm's place, its art facing left as WA's worms do.
  local function show(worm, u, sheet, frame)
    if u.sheet ~= sheet then
      if u.art then u.art:remove() end
      u.art = wa.actors.spawn({
        sprite = sheet, x = worm.x, y = worm.y, owner = worm, visibility = worm, on = function() end,
      })
      u.art:gfx({ glow_of = worm, follow = worm, depth = DEPTH })
      u.sheet = sheet
    end
    u.art.x, u.art.y, u.art.vx, u.art.vy = worm.x, worm.y, 0, 0
    u.art.facing = -worm.facing
    u.art:frame(frame)
    worm.body_visible = false
  end

  local function begin_pack(worm, u)
    u.hanging, u.pack_t, u.pack_x = false, 0, worm.x
    show(worm, u, "sprites/umbrella/pack_away.png", 0)
  end

  local function umbrella_frame(worm)
    local opened = parachute.fired(worm, ID)
    local u = umbrellas[worm.id]
    if not (opened or u) then
      return
    end
    if not u then
      u = {}
      umbrellas[worm.id] = u
    end
    local state = worm.state
    if opened == "open" then
      u.hanging, u.t, u.pack_t = true, 0, nil
    elseif opened == "landed" then
      begin_pack(worm, u)
    end
    if u.hanging then
      if state == "parachuting" then
        local frame = u.t // STEP
        if frame < OPEN_FRAMES then
          show(worm, u, "sprites/umbrella/open.png", frame)
        else
          -- Back and forth: 0, 1, ..., 12, 11, ..., 1.
          local swing = (frame - OPEN_FRAMES) % (2 * HANG_FRAMES - 2)
          if swing >= HANG_FRAMES then swing = 2 * HANG_FRAMES - 2 - swing end
          show(worm, u, "sprites/umbrella/hang.png", swing)
        end
        u.t = u.t + own_time.frames(worm)
        return
      end
      u.hanging = false
      if LANDING[state] then begin_pack(worm, u) else drop_art(worm, u) end
    end
    if u.pack_t then
      local frame = u.pack_t // STEP
      local moving = state == "walking" or state == "jump_prepare" or state == "jumping"
        or math.abs(worm.x - u.pack_x) > 1
      if moving or not LANDING[state] or (frame >= PACK_FRAMES and state ~= "jump_falling") then
        u.pack_t = nil
        drop_art(worm, u)
      else
        show(worm, u, "sprites/umbrella/pack_away.png", math.min(frame, PACK_FRAMES - 1))
        u.pack_t = u.pack_t + own_time.frames(worm)
      end
    end
    if not (u.hanging or u.pack_t) then
      umbrellas[worm.id] = nil
    end
  end

  wa.on.worm_message(function(worm)
    umbrella_frame(worm)
  end, { msgs = { wa.msg.FRAME_FINISH } })
end

return weapon
