-- lua mods/tests/px/test_stone.lua
-- Stone: the slingshot's throw, PX's bounce, its speed-scaled hits and the
-- stone sinking in the water.
local root = HIGHLANDER_ROOT or ((arg[0]:match("^(.*[/\\])") or "") .. "../../px/")
package.path = root .. "?.lua;" .. package.path

local function check(what, ok, detail)
  if not ok then error("FAIL: " .. what .. (detail and ("   [" .. tostring(detail) .. "]") or ""), 2) end
  print("  ok   " .. what)
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

local worms, spawned, sounds

local function new_worm(id, turn)
  local w = { kind = "worm", id = id, turn = turn, hp = 100, x = 100, y = 50, vx = 0, vy = 0,
    facing = 1, aim_target = 0, hits = {} }
  function w:hit(h) self.hits[#self.hits + 1] = h end
  return w
end

local function new_object(kind)
  local o = { kind = kind, hits = {} }
  function o:hit(damage, vx, vy) self.hits[#self.hits + 1] = { damage = damage, vx = vx, vy = vy } end
  return o
end

local function new_match()
  worms, spawned, sounds = {}, {}, {}
  local next_id = 300
  package.loaded["lib/shared"] = { fires = {} }
  wa = {
    depth = { OBJECTS = 0x90000 },
    math = { sin = math.sin, cos = math.cos },
    sound = { play = function(_, id) sounds[#sounds + 1] = id end },
    world = { water = function() return 1000 end },
    worms = { all = function() return worms end },
    actors = {
      spawn = function(spec)
        next_id = next_id + 1
        local a = { id = next_id, spec = spec, x = spec.x, y = spec.y, vx = spec.vx, vy = spec.vy,
          ignored = {}, slept = 0 }
        function a:gfx(g) for k, v in pairs(g) do self[k] = v end end
        function a:collision_ignore(w, on) self.ignored[w.id] = on or nil; return true end
        function a:sleep(n) self.slept = n end
        function a:warp(p) self.x, self.y, self.vx, self.vy = p.x, p.y, p.vx, p.vy end
        function a:remove() self.dead = true end
        spawned[#spawned + 1] = a
        return a
      end,
    },
  }
  dofile(root .. "weapons/stone.lua").setup()
  return package.loaded["lib/shared"].fires.stone
end

print("stone: the record")
do
  local d = dofile(root .. "weapons/stone.lua").definition()
  check("PX's record, ending the turn", d.wep == "weps/stone.wep" and d.handling.ends_turn == true)
  check("the slingshot poses: aim and draw on every slope",
    d.worm_sprites.weaponlnku == "sprites/stone/aimu.png" and d.worm_sprites.wthrowd == "sprites/stone/drawd.png")
end

print("stone: the throw")
do
  local fire = new_match()
  local thrower = new_worm(17, true)
  thrower.vx, thrower.aim_target = 0.5, 0
  worms = { thrower }
  fire({ worm = thrower, power = 1 })
  local a = spawned[1]
  check("from the worm, at 17 a frame along the aim plus the worm's own speed",
    a.x == 100 and a.y == 50 and near(a.vx, 17.5) and near(a.vy, 0), a.vx .. "," .. a.vy)
  check("WA's mine motion, and its thrower lets it through", a.spec.body.physics == "mine" and a.ignored[17])
  check("it runs into mines as well as land, worms, crates and drums", a.spec.body.hits.mines and a.spec.body.hits.objects)

  fire({ worm = thrower, power = 0.5 })
  thrower.facing, thrower.aim_target = -1, 90
  fire({ worm = thrower, power = 1 })
  check("half power, half the speed", near(spawned[2].vx, 0.5 + 8.5))
  check("aimed straight up", near(spawned[3].vx, 0.5) and near(spawned[3].vy, -17), spawned[3].vy)
end

print("stone: the bounce")
do
  local fire = new_match()
  local thrower = new_worm(17, true)
  worms = { thrower }
  fire({ worm = thrower, power = 1 })
  local a = spawned[1]
  local contact = a.spec.on.contact
  contact(a, { other = "land", nx = 0, ny = -1, vx = 5, vy = 10, first = true })
  check("off a floor: 0.3 of its fall back up, 0.96 of its slide kept", near(a.vx, 4.8) and near(a.vy, -3))
  contact(a, { other = "land", nx = 1, ny = 0, vx = -10, vy = 2, first = true })
  check("off a wall the same, on the other axis", near(a.vx, 3) and near(a.vy, 1.92))
end

print("stone: what it hits")
do
  local fire = new_match()
  local thrower, enemy = new_worm(17, true), new_worm(33, false)
  worms = { thrower, enemy }
  fire({ worm = thrower, power = 1 })
  local a = spawned[1]
  local contact = a.spec.on.contact
  contact(a, { other = enemy, nx = 1, ny = 0, vx = -6.5, vy = 3.9, first = true })
  local h = enemy.hits[1]
  check("a worm takes its speed as damage, half and a third of it as the push",
    h and h.amount == 10 and near(h.vx, -3.25) and near(h.vy, 1.3), h and h.amount)
  check("WA's own hit kind, the Prod's", h and h.kind == nil)
  contact(a, { other = enemy, nx = 1, ny = 0, vx = -6.5, vy = 3.9, first = false })
  check("once per touch", #enemy.hits == 1)

  contact(a, { other = thrower, nx = 1, ny = 0, vx = 9, vy = 0, first = true })
  check("the worm whose turn it is is spared", #thrower.hits == 0)
  thrower.turn = false
  contact(a, { other = enemy, nx = 1, ny = 0, vx = 9, vy = 0, first = true })
  check("between turns no worm is hit", #enemy.hits == 1)

  local drum, crate, mine = new_object("oil"), new_object("crate"), new_object("mine")
  contact(a, { other = drum, nx = 0, ny = -1, vx = 2.5, vy = 4, first = true })
  contact(a, { other = crate, nx = 0, ny = -1, vx = 0, vy = 3, first = true })
  contact(a, { other = mine, nx = 0, ny = -1, vx = 0, vy = 3, first = true })
  check("oil drums, crates and mines take the hit too, between turns as well",
    drum.hits[1] and drum.hits[1].damage == 6 and crate.hits[1] and crate.hits[1].damage == 3
      and mine.hits[1] and mine.hits[1].damage == 3)
end

print("stone: resting and sinking")
do
  local fire = new_match()
  local thrower = new_worm(17, true)
  worms = { thrower }
  fire({ worm = thrower, power = 1 })
  local a = spawned[1]
  local frame = a.spec.on.frame
  frame(a)
  check("still in its thrower's grace, it stays awake", a.slept == 0 and a.ignored[17])
  a.x = 300
  for _ = 1, 13 do frame(a) end
  check("clear of its thrower: collides with it again and sleeps", not a.ignored[17] and a.slept == 3000)

  a.y, a.vx, a.vy = 1000, 2, 5
  frame(a)
  check("into the water: tinted, splashing, sinking as a missile does",
    a.tint == 0x5A5AF0 and sounds[1] == 57 and near(a.y, 1000 + 4.3) and a.vx == 0, a.y)
  for _ = 1, 400 do if not a.dead then frame(a) end end
  check("gone once well below the surface", a.dead)
end

print("all stone checks passed")
