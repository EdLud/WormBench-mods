-- lua mods/tests/px/test_umbrella.lua
-- Umbrella: WA's parachute, twice the wind, PX's umbrella drawn in the
-- worm's place from the opening to the pack-away.
local root = HIGHLANDER_ROOT or ((arg[0]:match("^(.*[/\\])") or "") .. "../../px/")
package.path = root .. "?.lua;" .. package.path

local handlers, spawned
package.loaded["wf-lib/own_time"] = { frames = function() return 1 end }

local function check(what, ok, detail)
  if not ok then error("FAIL: " .. what .. (detail and ("   [" .. tostring(detail) .. "]") or ""), 2) end
  print("  ok   " .. what)
end

local function new_match()
  handlers, spawned = {}, {}
  wa = {
    depth = { WORMS = 0xD0000 },
    msg = { FRAME_FINISH = 2, WEAPON_RELEASED = 0x49 },
    on = {
      worm_message = function(f, filter)
        local wants = {}
        for _, m in ipairs(filter.msgs) do wants[m] = true end
        handlers[#handlers + 1] = { f = f, wants = wants }
      end,
    },
    actors = {
      spawn = function(spec)
        local a = { sprite = spec.sprite, x = spec.x, y = spec.y }
        function a:gfx(g) for k, v in pairs(g) do self[k] = v end end
        function a:frame(i) self.shown = i end
        function a:remove() self.dead = true end
        spawned[#spawned + 1] = a
        return a
      end,
    },
  }
  package.loaded["lib/parachute"] = nil
  dofile(root .. "weapons/umbrella.lua").setup()
  return { id = 17, x = 100, y = 50, facing = 1, state = "jumping", weapon = "px.umbrella", body_visible = true }
end

local function message(w, msg)
  for _, h in ipairs(handlers) do
    if h.wants[msg] then h.f(w, msg) end
  end
end

local function wa_fires(w, state_after)
  w.state = "parachuting"
  message(w, wa.msg.WEAPON_RELEASED)
  w.state = state_after or "parachuting"
  message(w, wa.msg.FRAME_FINISH)
end

print("umbrella: the record")
do
  local d = dofile(root .. "weapons/umbrella.lua").definition()
  check("WA's parachute, blown twice as hard as the stock one",
    d.copy_from == "stock.parachute" and d.parachute.wind_pct == 200)
end

print("umbrella: opened, hanging, packed away")
do
  local w = new_match()
  message(w, wa.msg.FRAME_FINISH)
  check("nothing before WA fires it", #spawned == 0 and w.body_visible)
  wa_fires(w)
  local open = spawned[1]
  check("opened: the umbrella opens in the worm's place", open.sprite == "sprites/umbrella/open.png"
    and open.shown == 0 and open.glow_of == w and open.follow == w and w.body_visible == false)
  w.facing = -1
  for _ = 1, 33 do message(w, wa.msg.FRAME_FINISH) end
  check("its 17 frames at 25 a second, mirrored with the worm", open.shown == 16 and open.facing == 1
    and not open.dead, open.shown)
  local shown = {}
  for _ = 1, 52 do
    message(w, wa.msg.FRAME_FINISH)
    shown[#shown + 1] = spawned[2].shown
  end
  check("then it hangs, swinging back and forth", open.dead and spawned[2].sprite == "sprites/umbrella/hang.png"
    and shown[1] == 0 and shown[25] == 12 and shown[27] == 11 and shown[47] == 1 and shown[49] == 0,
    table.concat(shown, ","))
  w.state = "jump_falling"
  message(w, wa.msg.FRAME_FINISH)
  local pack = spawned[3]
  check("landed: packed away over WA's pack-away", spawned[2].dead
    and pack.sprite == "sprites/umbrella/pack_away.png" and pack.shown == 0 and w.body_visible == false)
  for _ = 1, 11 do message(w, wa.msg.FRAME_FINISH) end
  check("6 frames, the last held", pack.shown == 5 and not pack.dead, pack.shown)
  w.state = "standing"
  message(w, wa.msg.FRAME_FINISH)
  message(w, wa.msg.FRAME_FINISH)
  check("standing after it: the worm shown again", pack.dead and w.body_visible == true)
  message(w, wa.msg.FRAME_FINISH)
  check("and nothing more drawn", #spawned == 3)
end

print("umbrella: a hard landing, closed in the air, another parachute")
do
  local w = new_match()
  wa_fires(w, "jump_falling")
  check("opened and landed at once: only the pack-away", #spawned == 1
    and spawned[1].sprite == "sprites/umbrella/pack_away.png")

  w = new_match()
  wa_fires(w)
  w.state = "falling" -- the jump key closed WA's parachute
  message(w, wa.msg.FRAME_FINISH)
  check("closed in the air: no pack-away, the worm shown", spawned[1].dead and #spawned == 1
    and w.body_visible == true)
  wa_fires(w)
  check("opened again from the start", spawned[2].sprite == "sprites/umbrella/open.png" and spawned[2].shown == 0)

  w = new_match()
  w.weapon = "px.wings"
  wa_fires(w)
  check("another parachute's fire is not the umbrella's", #spawned == 0 and w.body_visible)
end

print("ALL PASS")
