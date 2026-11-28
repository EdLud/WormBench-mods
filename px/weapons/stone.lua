-- Stone: a slingshot whose pebble hurts by how fast it hits and then stays where it rests.

local weapon = {}
local ART = "sprites/stone/"

weapon.record = {
  handling = {
    ends_turn = true,
  },
}

function weapon.definition()
  return require("lib/weapon").merge(weapon.record, {
    wep = "weps/stone.wep",
    name = "Stone",
    panel_icon = ART .. "icon.png",
    worm_sprites = {
      weaponlnk = ART .. "aim.png", weaponlnku = ART .. "aimu.png", weaponlnkd = ART .. "aimd.png",
      wthrow = ART .. "draw.png", wthrowu = ART .. "drawu.png", wthrowd = ART .. "drawd.png",
    },
    sprites = { ART .. "stone.png" },
    params = { gpu_prefix = ART },
    on_fire = function(fire) require("lib/shared").fires.stone(fire) end,
  })
end

function weapon.setup()
  local shared = require("lib/shared")

  local FORCE = 17 -- ForceInit: pixels/frame at full power
  local BOUNCE = 0.3 -- DumpingA, DumpingB: speed kept off what it hits
  local SLIDE = 0.96 -- DumpingC: speed kept along it
  local PUSH_X, PUSH_Y = 1 / 2, 1 / 3
  local NAP = 3000 -- frames
  local PLANTER_GRACE = 13 -- frames
  local SEA_DRAG, SEA_SINK = 0.8, 0.3 -- a missile's sea step
  local SUNK = 200 -- pixels below the surface
  local SINK_TINT = 0x5A5AF0
  local SOUND_SPLASH = 57
  local STONE = ART .. "stone.png"

  local stones = {} -- actor id -> state

  local function trunc(v) return v >= 0 and math.floor(v) or -math.floor(-v) end

  local function turn_worm()
    for _, w in ipairs(wa.worms.all()) do
      if w.turn then return w end
    end
  end

  -- What it hits takes a hit of the Prod's kind: the speed it hit with as
  -- damage, half its sideways and a third of its vertical speed as the push.
  -- The worm whose turn it is never takes one, and no worm does between turns.
  local function strike(other, vx, vy)
    local damage = trunc(math.abs(vx) + math.abs(vy))
    local px, py = vx * PUSH_X, vy * PUSH_Y
    if damage == 0 and px == 0 and py == 0 then return end
    if other.kind == "worm" then
      local current = turn_worm()
      if current and current.id ~= other.id then
        other:hit { amount = damage, vx = px, vy = py }
      end
    elseif other.kind == "oil" or other.kind == "crate" or other.kind == "mine" then
      other:hit(damage, px, py)
    end
  end

  local function contact(a, ev)
    if ev.nx ~= 0 then
      a.vx, a.vy = -BOUNCE * ev.vx, SLIDE * ev.vy
    elseif ev.ny ~= 0 then
      a.vx, a.vy = SLIDE * ev.vx, -BOUNCE * ev.vy
    end
    if ev.first and ev.other ~= "land" then strike(ev.other, ev.vx, ev.vy) end
  end

  local function overlaps(a, worm)
    return a.x >= worm.x - 10 and a.x <= worm.x + 10 and a.y >= worm.y - 20 and a.y <= worm.y + 6
  end

  -- Its thrower lets it through until it has flown clear.
  local function planter_grace(s, a)
    if not s.planter then return end
    local planter
    for _, w in ipairs(wa.worms.all()) do
      if w.id == s.planter_id and w.hp > 0 then planter = w; break end
    end
    if not planter or (s.age >= PLANTER_GRACE and not overlaps(a, planter)) then
      a:collision_ignore(s.planter, false)
      s.planter, s.planter_id = nil, nil
    end
  end

  local function sink(s, a)
    if not s.sinking then
      s.sinking, s.x, s.y, s.vx, s.vy = true, a.x, a.y, a.vx, a.vy
      a.hits = {}
      a:gfx { tint = SINK_TINT }
      wa.sound.play(a, SOUND_SPLASH)
    end
    s.vx, s.vy = s.vx * SEA_DRAG, s.vy * SEA_DRAG + SEA_SINK
    s.x, s.y = s.x + s.vx, s.y + s.vy
    if s.y >= wa.world.water() + SUNK then
      stones[a.id] = nil
      a:remove()
      return
    end
    a:warp { x = s.x, y = s.y, vx = 0, vy = 0 }
  end

  local function frame(a)
    local s = stones[a.id]
    if not s then return end
    s.age = s.age + 1
    if s.sinking or a.y >= wa.world.water() then
      sink(s, a)
      return
    end
    planter_grace(s, a)
    -- Asleep, WA still moves it and the water still wakes it.
    if not s.planter then a:sleep(NAP) end
  end

  shared.fires.stone = function(fire)
    local worm = fire.worm
    local angle = math.rad(worm.aim_target)
    local speed = (fire.power or 1) * FORCE
    local a = wa.actors.spawn {
      sprite = STONE, owner = worm, x = worm.x, y = worm.y,
      vx = worm.vx + wa.math.cos(angle) * worm.facing * speed,
      vy = worm.vy - wa.math.sin(angle) * speed,
      body = { physics = "mine", hits = { land = true, worms = true, mines = true, crates = true, objects = true } },
      on = { frame = frame, contact = contact },
    }
    a:gfx { depth = wa.depth.OBJECTS }
    local s = { age = 0 }
    if a:collision_ignore(worm, true) then s.planter, s.planter_id = worm, worm.id end
    stones[a.id] = s
  end
end

return weapon
