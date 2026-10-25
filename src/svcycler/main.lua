-- Servo Cycler for FrSky Ethos  -  by ABRC   (version 1.8.8)
-- READ DISCLAIMER.txt and the Servo Cycler manual (PDF) FIRST: test model only, never in a model that is flown or driven.
-- MIT license, (c) 2026 Adam Bednarik (ABRC). https://github.com/adambednarik-ABRC/servo-cycler
-- Copy to the radio as:  /scripts/svcycler/main.lua  (+ the logot_*.png files)
--
-- Registers:
--   * Lua source "Servo Cycler"  -> enable it in the model (Model > Lua), then use it as
--                                   the source of a Free mix on each servo channel (CH1..CH16)
--   * Widget     "Servo Cycler"  -> dashboard (long-press > Configure for the settings)
--                                   Designed for a FULL-SCREEN layout (one widget).
--
-- SMOOTH MOTION (new in 1.8): the radio's mixer moves the servos, not the script.
--   Set Slow up = 0.5 s and Slow down = 0.5 s EITHER in every mix that uses the Servo
--   Cycler source OR on the output channel (Outputs > channel), not both.
--   (Ethos "slow" is the time for 100 %, i.e. centre to one end: 0.5 s gives a full
--   sweep from end to end in 1.0 s.)
--   The script only sets the next end point (+, -, centre) at the right moment; the mix
--   "slow" then moves the servo at an even rate, calculated by the radio itself at full
--   speed. Screen refreshes and script pauses can no longer make the servo stutter.
--   Speed is fixed at 30 cycles/min (2 s per cycle): 1.0 s for a full sweep end to end.
--
-- The test runs a set number of cycles (1..999). One cycle = centre > one end > other end > centre.
-- Starting / stopping: the start switch (set in Configure). ON = start fresh, OFF = stop.
--   If the switch is already ON when the radio is switched on, nothing starts: switch it
--   OFF and ON again to start.
--   After a finished test (DONE), flip the switch OFF and ON to run again.
-- Stopping returns the servos to centre (at the slow rate); the last result stays on screen.
--
-- Safety: a test can only run in the model that has the Servo Cycler widget on its screen.
-- Switching to another model stops a running test at once, and the start switch is ignored
-- in every other model. The source only moves servos in models whose mixes use it.
--
-- Dashboard (grey / orange):
--   top     : while running a full-width bar that fills green from left to right with the
--             progress: elapsed time | RUNNING | time left.  Not running: a small status box
--             (IDLE, STOPPED, DONE, NO SWITCH in red) with elapsed time and total / time left
--   left    : ABRC logo with "SERVO CYCLER"
--   right   : the 4 hottest of up to 8 temperature sensors as bars (green > red)
--   centre  : big CYCLES dial with a servo: the arm is the pointer, the count is on the case,
--             current (A) and RX battery (V) at the end of the servo wire
--   bottom  : TRAVEL dial left (pot 1), CYCLES setting dial right (pot 2)
--
-- Settings:
--   Cycles knob   : sets the number of cycles (exponential: 25 % = 17, 50 % = 126,
--                   75 % = 422, full = 999); frozen while running
--   Travel knob   : one way = 0 % (centre), other way = full travel
--   Without a knob, the fixed values in Configure are used.
--
-- Screen sizes: the dashboard scales itself (X20 / X18RS 800x480, X14 640x360,
-- X18 / X18S / X18SE 480x320, X10 / X12S 480x272, and smaller zones).

local MAX_CYCLES = 999
local PERIOD     = 2.0  -- one cycle in s (30 cycles/min); matches Slow up/down 0.5 s
local SLOW_TIME  = 0.5  -- the Slow up / Slow down to set (Ethos: time for 100 %, centre to end)

---------------------------------------------------------------- fonts per screen size

-- first font constant that exists on this Ethos version
local function pick(...)
  local n = select("#", ...)
  for i = 1, n do
    local v = select(i, ...)
    if v ~= nil then return v end
  end
  return FONT_STD
end

local FONTSETS = {
  large = {
    small  = pick(FONT_S, FONT_STD),
    smallb = pick(FONT_S_BOLD, FONT_S, FONT_STD),
    normal = pick(FONT_STD),
    bold   = pick(FONT_STD_BOLD, FONT_STD),
    big    = pick(FONT_L_BOLD, FONT_L, FONT_STD_BOLD),
    gauge  = pick(FONT_XL, FONT_L),
    huge   = pick(FONT_XXL, FONT_XL, FONT_L),
  },
  medium = {
    small  = pick(FONT_XS, FONT_S),
    smallb = pick(FONT_XS_BOLD, FONT_XS, FONT_S_BOLD, FONT_S),
    normal = pick(FONT_S, FONT_STD),
    bold   = pick(FONT_S_BOLD, FONT_STD_BOLD, FONT_STD),
    big    = pick(FONT_STD_BOLD, FONT_STD),
    gauge  = pick(FONT_L, FONT_STD),
    huge   = pick(FONT_XL, FONT_L),
  },
  small = {
    small  = pick(FONT_XXS, FONT_XS, FONT_S),
    smallb = pick(FONT_XXS, FONT_XS_BOLD, FONT_XS, FONT_S),
    normal = pick(FONT_XS, FONT_S),
    bold   = pick(FONT_XS_BOLD, FONT_S_BOLD, FONT_S),
    big    = pick(FONT_S_BOLD, FONT_STD_BOLD, FONT_STD),
    gauge  = pick(FONT_STD, FONT_S),
    huge   = pick(FONT_L, FONT_STD),
  },
}

local F = FONTSETS.large   -- current font set, chosen in paint

---------------------------------------------------------------- colours: ABRC grey + orange

local C_BG      = lcd.RGB(18, 19, 21)
local C_PANEL   = lcd.RGB(45, 48, 52)
local C_SEG_OFF = lcd.RGB(62, 65, 70)
local C_GREY    = lcd.RGB(120, 124, 130)
local C_DIM     = lcd.RGB(150, 153, 158)
local C_LIGHT   = lcd.RGB(235, 236, 238)
local C_ORANGE  = lcd.RGB(255, 122, 0)
local C_GREEN   = lcd.RGB(0, 200, 70)
local C_RED     = lcd.RGB(230, 40, 40)
local C_BLACK   = lcd.RGB(0, 0, 0)
-- servo drawing
local C_CASE    = lcd.RGB(43, 46, 51)
local C_PLATE   = lcd.RGB(58, 62, 68)
local C_EDGE    = lcd.RGB(110, 115, 122)
local C_ARM     = lcd.RGB(31, 33, 36)
local C_HOLE    = lcd.RGB(90, 94, 102)
local C_CROSS   = lcd.RGB(154, 158, 164)
local C_PLUG    = lcd.RGB(26, 28, 31)
local C_PIN     = lcd.RGB(201, 204, 208)
local C_W_BROWN = lcd.RGB(138, 90, 43)
local C_W_RED   = lcd.RGB(208, 48, 48)

---------------------------------------------------------------- settings and state

local settings = {
  switch    = nil,  -- start switch (optional)
  cycles    = 999,  -- target when no cycles knob is set
  travel    = 100,  -- fixed % of full travel, used when no travel knob
  travelSrc = nil,  -- knob for travel (pot 1)
  targetSrc = nil,  -- knob for the number of cycles (pot 2)
  dialOrder = 0,    -- bottom dials: 0 = Travel left / Cycles right, 1 = Cycles left / Travel right
  temps     = {},   -- up to 8 temperature sensors (telemetry), slots 1..8
  tempWarn  = 60,   -- temperature warning limit in deg C (bars are fully red at this value)
  currSrc   = nil,  -- current sensor (telemetry), optional
  battSrc   = nil,  -- receiver battery voltage sensor (telemetry), optional
}

local state = {
  status     = "Idle",  -- Idle / Running / Done / Stopped
  running    = false,
  done       = false,
  startTime  = 0,
  elapsed    = 0,
  phase      = 0,       -- cycles completed (fractional), from the clock
  count      = 0,
  curPeriod  = PERIOD,  -- cycle time in s (fixed)
  curTravel  = 100,     -- current travel %
  out        = 0,       -- current output value -1024..1024 (an end point or centre)
}

local function now()
  return os.clock()
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- source value -1024..1024 -> 0..1 ; nil if no source is set
local function knobRatio(src)
  local t = type(src)
  if t ~= "userdata" and t ~= "table" then return nil end
  local ok, v = pcall(function() return src:value() end)
  if not ok or type(v) ~= "number" then return nil end
  return clamp((v + 1024) / 2048, 0, 1)
end

local function currentTravel()
  local r = knobRatio(settings.travelSrc)
  if r == nil then
    return settings.travel
  end
  return r * 100
end

-- knob position 0..1 -> number of cycles, exponential: fine steps for small numbers,
-- coarse ones near the top (25 % = 17, 50 % = 126, 75 % = 422, full = 999)
local function cyclesFromRatio(r)
  return clamp(math.floor(1 + (r * r * r) * (MAX_CYCLES - 1) + 0.5), 1, MAX_CYCLES)
end

-- read the cycles knob into the number of cycles (only when not running)
local function updateTargetFromKnob()
  local r = knobRatio(settings.targetSrc)
  if r == nil then return end
  settings.cycles = cyclesFromRatio(r)
end

-- where the servo must head in this part of the cycle (-1, 0, 1).
-- The slow setting moves it there at an even rate: 1/4 cycle centre > +end,
-- 1/2 cycle +end > -end, then -end > +end straight through the centre into the next
-- cycle. Only the last cycle stops at the centre. (Stopping at the centre between
-- cycles would show as a small jerk whenever the servo got there a moment early.)
local function targetPoint(frac, lastCycle)
  if frac < 0.25 then return 1 end
  if frac < 0.75 then return -1 end
  if lastCycle then return 0 end
  return 1
end

local function switchOn()
  local sw = settings.switch
  local t = type(sw)
  if t ~= "userdata" and t ~= "table" then return false end
  local ok, on = pcall(function() return sw:state() end)
  return ok and on == true
end

-- run control: switch
local control = {
  switchBlocked = false,  -- switch was already ON when coming into the model: flip OFF / ON first
  armed         = false,  -- the start switch has been seen once since the radio was switched on
}

---------------------------------------------------------------- model guard
-- A test may only run in the model that contains the Servo Cycler widget.

local guard = {
  owner     = nil,   -- name of the model whose widget last ran
  lastModel = nil,   -- model seen on the previous update
}

local function currentModelName()
  if model and model.name then
    local ok, n = pcall(model.name)
    if ok and n ~= nil then return tostring(n) end
  end
  return nil
end

local function guardCheck()
  local cur = currentModelName()
  if cur ~= guard.lastModel then
    if guard.lastModel ~= nil then
      -- model changed: stop everything and require a fresh start
      if state.running then state.status = "Stopped" end
      state.running         = false
      state.done            = false
      control.switchBlocked = switchOn()
    end
    guard.lastModel = cur
  end
  if cur == nil then
    return guard.owner ~= nil
  end
  return guard.owner ~= nil and cur == guard.owner
end

local function markOwner()
  local cur = currentModelName()
  guard.owner = cur or guard.owner or "?"
  if guard.lastModel == nil then guard.lastModel = cur end
end

local function isActive(allowed)
  -- first look at the switch after power-up: if it is already ON, nothing starts
  -- until it has been switched OFF and ON again
  local swt = type(settings.switch)
  if not control.armed and (swt == "userdata" or swt == "table") then
    control.armed = true
    control.switchBlocked = switchOn()
  end
  local sw = switchOn()
  if not sw then control.switchBlocked = false end
  if not allowed then
    return false
  end
  return sw and not control.switchBlocked
end

---------------------------------------------------------------- telemetry sensors (optional)

local MAX_TEMPS = 8

-- per test: highest temperature per slot and highest current
local sens = {
  now   = {},    -- current temperature per slot (nil = no data)
  max   = {},    -- highest temperature per slot during the test
  name  = {},    -- short display name per slot
  cNow  = nil,   -- current draw now
  cMax  = nil,   -- highest current during the test
  vNow  = nil,   -- battery voltage now
  vMin  = nil,   -- lowest battery voltage during the test
  last  = -10,   -- time of the last reading
}

local function isObj(v)
  local t = type(v)
  return t == "userdata" or t == "table"
end

-- value of a telemetry sensor, or nil when it is not set / not reporting
local function sensorValue(src)
  if not isObj(src) then return nil end
  local okS, st = pcall(function() return src:state() end)
  if okS and st == false then return nil end           -- telemetry lost
  local ok, v = pcall(function() return src:value() end)
  if ok and type(v) == "number" then return v end
  return nil
end

local function sensorName(src, slot)
  local ok, n = pcall(function() return src:name() end)
  n = (ok and type(n) == "string" and n ~= "") and n or ("T" .. slot)
  n = string.match(n, "^%s*(%S+)") or n        -- first word only: "SRV2 temp" -> "SRV2"
  if #n > 6 then n = string.sub(n, 1, 6) end
  return n
end

local function resetSensorMax()
  sens.max  = {}
  sens.cMax = nil
  sens.vMin = nil
end

-- read all sensors (about twice a second) and track the maximum during a test
local function readSensors(t)
  if t - sens.last < 0.5 then return end
  sens.last = t
  for i = 1, MAX_TEMPS do
    local src = settings.temps[i]
    if isObj(src) then
      local v = sensorValue(src)
      sens.now[i] = v
      sens.name[i] = sens.name[i] or sensorName(src, i)
      if v and state.running and (sens.max[i] == nil or v > sens.max[i]) then sens.max[i] = v end
    else
      sens.now[i], sens.name[i] = nil, nil
    end
  end
  local c = sensorValue(settings.currSrc)
  sens.cNow = c
  if c and state.running and (sens.cMax == nil or c > sens.cMax) then sens.cMax = c end
  local v = sensorValue(settings.battSrc)
  sens.vNow = v
  if v and state.running and (sens.vMin == nil or v < sens.vMin) then sens.vMin = v end
end

-- the (up to) 4 hottest configured sensors, hottest first
local function hottest()
  local list = {}
  for i = 1, MAX_TEMPS do
    -- only sensors that are set AND reporting right now (telemetry active)
    if isObj(settings.temps[i]) and sens.now[i] ~= nil then
      list[#list + 1] = { name = sens.name[i] or ("T" .. i), now = sens.now[i], max = sens.max[i] }
    end
  end
  table.sort(list, function(a, b)
    local av = a.now or a.max or -1000
    local bv = b.now or b.max or -1000
    return av > bv
  end)
  while #list > 4 do table.remove(list) end
  return list
end

---------------------------------------------------------------- engine

-- when Ethos last updated the Lua source
local rate = { last = -10 }

-- The test engine. The source drives it whenever Ethos updates the source; the
-- widget only drives it when the source is not being updated, so the dashboard
-- and the knobs always stay live.
-- The script only decides WHERE the servo goes (an end point or centre) and WHEN,
-- from the radio clock. The mix "slow" does the actual movement, so the motion stays
-- even even when the script is paused for a moment (e.g. by a screen refresh).
local function tick()
  local out = 0
  state.curTravel = currentTravel()

  readSensors(now())

  local allowed = guardCheck()

  if allowed and not state.running then
    updateTargetFromKnob()
  end

  if isActive(allowed) then
    if not state.running and not state.done then
      state.running    = true
      state.startTime  = now()
      state.phase      = 0
      resetSensorMax()
      state.count      = 0
      state.elapsed    = 0
      state.status     = "Running"
    end

    if state.running then
      state.elapsed = now() - state.startTime
      if state.elapsed < 0 then state.elapsed = 0 end
      state.phase = state.elapsed / PERIOD

      local n = math.floor(state.phase)
      if n >= settings.cycles then
        state.running    = false
        state.done       = true
        state.count      = settings.cycles
        state.phase      = settings.cycles
        state.status     = "Done"
      else
        state.count = n
        out = targetPoint(state.phase - n, n >= settings.cycles - 1) * state.curTravel / 100
      end
    end
  else
    if state.running then
      state.status = "Stopped"
    end
    state.running = false
    state.done    = false
  end

  state.out = math.floor(out * 1024 + 0.5)
end

---------------------------------------------------------------- source

local function sourceInit(source)
  source:value(0)
end

-- last script error, shown on the dashboard so a problem can be reported
local lastError = nil
local lastErrorTime = 0

local function sourceWakeup(source)
  local ok, err = pcall(tick)
  if not ok then lastError = "engine: " .. tostring(err); lastErrorTime = now() end
  source:value(state.out or 0)
  local t = now()
  rate.last = t
end

-- widget side: only drives the engine when the source is not being updated
local function widgetTick()
  if now() - rate.last > 0.5 then
    local ok, err = pcall(tick)
    if not ok then lastError = "engine: " .. tostring(err); lastErrorTime = now() end
  end
end

---------------------------------------------------------------- values for display

local function fmtTime(s)
  if s < 0 then s = 0 end
  s = math.floor(s)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function hasResult()
  return state.running or state.done or state.status == "Stopped"
end

local function progress()
  if state.done then return 1 end
  if not hasResult() then return 0 end
  return clamp(state.phase / settings.cycles, 0, 1)
end

-- seconds left, estimated from the current speed
local function timeLeft()
  if state.done then return 0 end
  local left = settings.cycles - (hasResult() and state.phase or 0)
  return math.max(0, left) * state.curPeriod
end

local function timeTotal()
  return settings.cycles * state.curPeriod
end

-- cycles setting as knob position 0..1 (for the dial)
local function targetFrac()
  local r = knobRatio(settings.targetSrc)
  if r ~= nil then return r end
  return ((settings.cycles - 1) / (MAX_CYCLES - 1)) ^ (1 / 3)
end

---------------------------------------------------------------- colour scales

local function lerp(a, b, t)
  return math.floor(a + (b - a) * t + 0.5)
end

-- 0 = green, 0.5 = orange-yellow, 1 = red
local function heatColor(f)
  f = clamp(f, 0, 1)
  if f < 0.5 then
    local k = f / 0.5
    return lcd.RGB(lerp(0, 255, k), 200, lerp(70, 0, k))
  end
  local k = (f - 0.5) / 0.5
  return lcd.RGB(lerp(255, 230, k), lerp(200, 40, k), lerp(0, 40, k))
end

-- travel dial: red at low travel, gradually green up to 66 %, green above
-- cycles dial: green up to 66 %, then gradually red
local function cyclesSegColor(f)
  if f <= 0.66 then return C_GREEN end
  return heatColor((f - 0.66) / 0.34)
end

local function travelSegColor(f)
  if f >= 0.66 then return C_GREEN end
  return heatColor(1 - f / 0.66)
end

---------------------------------------------------------------- drawing helpers

-- text metrics are cached: measuring text is one of the costlier screen calls
local metric = { h = {}, w = {}, n = 0 }

local function fontHeight(font)
  local h = metric.h[font]
  if h == nil then
    lcd.font(font)
    local _, th = lcd.getTextSize("0")
    h = th
    metric.h[font] = h
  end
  return h
end

local function textWidth(font, text)
  local key = tostring(font) .. "|" .. text
  local tw = metric.w[key]
  if tw == nil then
    lcd.font(font)
    tw = lcd.getTextSize(text)
    metric.n = metric.n + 1
    if metric.n > 400 then metric.w = {}; metric.n = 0 end
    metric.w[key] = tw
  end
  return tw
end

local function drawText(x, y, text, font, color)
  lcd.font(font)
  lcd.color(color)
  lcd.drawText(math.floor(x), math.floor(y), text)
end

local function drawCentered(cx, y, text, font, color)
  drawText(cx - textWidth(font, text) / 2, y, text, font, color)
end

-- text centred on (cx, cy)
local function drawMid(cx, cy, text, font, color)
  drawText(cx - textWidth(font, text) / 2, cy - fontHeight(font) / 2, text, font, color)
end

-- first font in the list that makes the text fit in maxW
local function fitFont(text, maxW, ...)
  local n = select("#", ...)
  local last = nil
  for i = 1, n do
    local f = select(i, ...)
    if f ~= nil then
      last = f
      if textWidth(f, text) <= maxW then return f end
    end
  end
  return last
end

-- first font in the list that makes the text fit in maxW x maxH
local function fitFontWH(text, maxW, maxH, ...)
  local n = select("#", ...)
  local last = nil
  for i = 1, n do
    local f = select(i, ...)
    if f ~= nil then
      last = f
      if textWidth(f, text) <= maxW and fontHeight(f) <= maxH then return f end
    end
  end
  return last
end

-- text whose characters are drawn in colA left of splitX and colB right of it
-- (used for text on a bar that is partly filled)
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local SPLIT = { n = 0 }   -- character positions per text, measured once

local function drawSplitText(x, y, text, font, splitX, colA, colB)
  local tw = textWidth(font, text)
  if splitX <= x then
    drawText(x, y, text, font, colB)
    return
  end
  if splitX >= x + tw then
    drawText(x, y, text, font, colA)
    return
  end
  -- the text crosses the edge of the fill: draw it as two parts, split between characters
  local key = tostring(font) .. "|" .. text
  local cuts = SPLIT[key]
  if cuts == nil then
    cuts = {}                                -- { byte position, x offset } after each character
    local pos, off = 0, 0
    for ch in string.gmatch(text, UTF8_CHAR) do
      pos = pos + #ch
      off = off + textWidth(font, ch)
      cuts[#cuts + 1] = { pos, off, textWidth(font, ch) }
    end
    SPLIT.n = SPLIT.n + 1
    if SPLIT.n > 60 then SPLIT = { n = 1 } end
    SPLIT[key] = cuts
  end
  local rel = splitX - x
  local cutPos, cutX = 0, 0
  for i = 1, #cuts do
    local c = cuts[i]
    if c[2] - c[3] / 2 < rel then cutPos, cutX = c[1], c[2] else break end
  end
  x, y = math.floor(x), math.floor(y)
  lcd.font(font)
  if cutPos > 0 then
    lcd.color(colA)
    lcd.drawText(x, y, string.sub(text, 1, cutPos))
  end
  if cutPos < #text then
    lcd.color(colB)
    lcd.drawText(x + math.floor(cutX + 0.5), y, string.sub(text, cutPos + 1))
  end
end

-- Drawing goes through G: normally the screen (lcd), but parts that never change are
-- drawn once into a recorder and afterwards replayed from that list, which is much
-- cheaper than working out every shape again on each refresh.
local G = lcd

local function newRecorder()
  local ops = {}
  local rec = { ops = ops }
  local last = nil
  rec.color = function(c)
    if c ~= last then ops[#ops + 1] = { lcd.color, c }; last = c end
  end
  rec.drawFilledRectangle = function(x, y, w, h) ops[#ops + 1] = { lcd.drawFilledRectangle, x, y, w, h } end
  rec.drawLine = function(x1, y1, x2, y2) ops[#ops + 1] = { lcd.drawLine, x1, y1, x2, y2 } end
  if lcd.drawFilledCircle then
    rec.drawFilledCircle = function(x, y, r) ops[#ops + 1] = { lcd.drawFilledCircle, x, y, r } end
  end
  if lcd.drawFilledTriangle then
    rec.drawFilledTriangle = function(a, b, c, d, e, f) ops[#ops + 1] = { lcd.drawFilledTriangle, a, b, c, d, e, f } end
  end
  return rec
end

-- run fn(...) into a list of drawing steps
local function record(fn, ...)
  local rec = newRecorder()
  G = rec
  local ok, err = pcall(fn, ...)
  G = lcd
  if not ok then error(err, 0) end
  return rec.ops
end

local function replay(ops)
  for i = 1, #ops do
    local o = ops[i]
    o[1](o[2], o[3], o[4], o[5], o[6], o[7])
  end
end

local function drawBox(x, y, w, h, color)
  G.color(color)
  G.drawFilledRectangle(math.floor(x), math.floor(y), math.floor(w), math.floor(h))
end

local INSETS = {}   -- corner shape per radius, computed once

-- filled rectangle with rounded corners (works on any Ethos version)
local function fillRounded(x, y, w, h, r, color)
  x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
  if w < 1 or h < 1 then return end
  r = math.floor(math.max(0, math.min(r, w / 2, h / 2)))
  G.color(color)
  local rect = G.drawFilledRectangle
  if r < 1 then
    rect(x, y, w, h)
    return
  end
  local circ = G.drawFilledCircle
  if circ and r >= 2 then
    -- two rectangles and four corner circles: few drawing steps
    local d = r * 2
    rect(x + r, y, w - d, h)
    if h > d then rect(x, y + r, w, h - d) end
    circ(x + r, y + r, r)
    circ(x + w - 1 - r, y + r, r)
    circ(x + r, y + h - 1 - r, r)
    circ(x + w - 1 - r, y + h - 1 - r, r)
    return
  end
  -- corner shape: rows with the same inset are merged into one rectangle
  local bands = INSETS[r]
  if bands == nil then
    bands = {}                               -- { first row, rows, inset }
    for i = 0, r - 1 do
      local dy = r - i - 0.5
      local inset = math.floor(r - math.sqrt(r * r - dy * dy) + 0.5)
      local last = bands[#bands]
      if last and last[3] == inset then
        last[2] = last[2] + 1
      else
        bands[#bands + 1] = { i, 1, inset }
      end
    end
    INSETS[r] = bands
  end
  for i = 1, #bands do
    local b = bands[i]
    local row, rows, inset = b[1], b[2], b[3]
    rect(x + inset, y + row,             w - inset * 2, rows)
    rect(x + inset, y + h - row - rows,  w - inset * 2, rows)
  end
  if h - r * 2 > 0 then rect(x, y + r, w, h - r * 2) end
end

-- rounded box with a border of the given thickness
local function drawRoundedBox(x, y, w, h, r, fillColor, borderColor, thick)
  thick = thick or 2
  fillRounded(x, y, w, h, r, borderColor)
  fillRounded(x + thick, y + thick, w - thick * 2, h - thick * 2, r - thick, fillColor)
end

-- filled circle (built-in when available)
local function fillCircle(x, y, r, color)
  if r < 0.5 then return end
  if G.drawFilledCircle then
    G.color(color)
    G.drawFilledCircle(math.floor(x + 0.5), math.floor(y + 0.5), math.floor(r + 0.5))
  else
    fillRounded(x - r, y - r, r * 2, r * 2, r, color)
  end
end

-- line about 2 px thick
local function thickLine(x1, y1, x2, y2, color)
  G.color(color)
  x1, y1, x2, y2 = math.floor(x1 + 0.5), math.floor(y1 + 0.5), math.floor(x2 + 0.5), math.floor(y2 + 0.5)
  G.drawLine(x1, y1, x2, y2)
  if math.abs(x2 - x1) > math.abs(y2 - y1) then
    G.drawLine(x1, y1 + 1, x2, y2 + 1)
  else
    G.drawLine(x1 + 1, y1, x2 + 1, y2)
  end
end

-- filled quadrilateral (two triangles)
local function fillQuad(ax, ay, bx, by, cx, cy, dx, dy, color)
  G.color(color)
  ax, ay, bx, by = math.floor(ax + 0.5), math.floor(ay + 0.5), math.floor(bx + 0.5), math.floor(by + 0.5)
  cx, cy, dx, dy = math.floor(cx + 0.5), math.floor(cy + 0.5), math.floor(dx + 0.5), math.floor(dy + 0.5)
  local tri = G.drawFilledTriangle
  if tri then
    tri(ax, ay, bx, by, cx, cy)
    tri(ax, ay, cx, cy, dx, dy)
  else
    G.drawLine(ax, ay, bx, by)
    G.drawLine(bx, by, cx, cy)
    G.drawLine(cx, cy, dx, dy)
    G.drawLine(dx, dy, ax, ay)
  end
end

-- angle in degrees, 0 = up, clockwise
local function polar(cx, cy, r, deg)
  local a = math.rad(deg)
  return math.floor(cx + r * math.sin(a) + 0.5), math.floor(cy - r * math.cos(a) + 0.5)
end

-- fallback when filled triangles are not available
local function drawSegment(cx, cy, r1, r2, a0, a1)
  if lcd.drawAnnulusSector then
    lcd.drawAnnulusSector(cx, cy, r1, r2, (a0 + 360) % 360, (a1 + 360) % 360)
  else
    local r = r1
    while r <= r2 do
      local x1, y1 = polar(cx, cy, r, a0)
      local x2, y2 = polar(cx, cy, r, a1)
      lcd.drawLine(x1, y1, x2, y2)
      r = r + 1
    end
  end
end

-- segment corner points are computed once per dial position/size and reused
local DIALS = {}

local function dialGeometry(cx, cy, r, segments, thickF)
  cx, cy, r = math.floor(cx), math.floor(cy), math.floor(r)
  local key = cx .. ":" .. cy .. ":" .. r .. ":" .. segments .. ":" .. thickF
  local g = DIALS[key]
  if g then return g end
  g = {}
  local thick = math.max(4, math.floor(r * thickF))
  local r1 = r - thick
  local stepA = 270 / segments
  local gap = stepA * 0.28
  for i = 0, segments - 1 do
    local a0 = -135 + i * stepA + gap / 2
    local a1 = a0 + stepA - gap
    local x1, y1 = polar(cx, cy, r1, a0)
    local x2, y2 = polar(cx, cy, r, a0)
    local x3, y3 = polar(cx, cy, r, a1)
    local x4, y4 = polar(cx, cy, r1, a1)
    g[i + 1] = { x1, y1, x2, y2, x3, y3, x4, y4, cx, cy, r1, r, a0, a1 }
  end
  DIALS[key] = g
  return g
end

-- 270 degree segmented dial, frac 0..1 lit; colorFn(position 0..1) gives the lit colour
local function drawDial(cx, cy, r, frac, segments, colorFn, thickF)
  local g = dialGeometry(cx, cy, r, segments, thickF or 0.2)
  local lit = math.floor(clamp(frac, 0, 1) * segments + 0.5)
  local tri = lcd.drawFilledTriangle
  -- segment colours are worked out once per dial
  g.colors = g.colors or {}
  local colors = g.colors[colorFn or 1]
  if colors == nil then
    colors = {}
    for i = 1, segments do
      colors[i] = colorFn and colorFn((i - 0.5) / segments) or C_ORANGE
    end
    g.colors[colorFn or 1] = colors
  end
  for i = 1, segments do
    if i <= lit then
      lcd.color(colors[i])
    else
      lcd.color(C_SEG_OFF)
    end
    local s = g[i]
    if tri then
      tri(s[1], s[2], s[3], s[4], s[5], s[6])
      tri(s[1], s[2], s[5], s[6], s[7], s[8])
    else
      drawSegment(s[9], s[10], s[11], s[12], s[13], s[14])
    end
  end
end

-- bar with a coloured border, filled to frac in the same colour; the text is drawn
-- in the bar colour on the empty part and in black on the filled part
local function invBar(x, y, w, h, frac, col, leftText, rightText, font, inset, thick)
  local rad = h * 0.35
  drawRoundedBox(x, y, w, h, rad, C_BLACK, col, thick)
  local fw = math.floor(w * clamp(frac, 0, 1))
  if fw >= 2 then fillRounded(x, y, fw, h, math.min(rad, fw / 2), col) end
  local split = x + fw
  local ty = y + (h - fontHeight(font)) / 2
  if leftText then drawSplitText(x + inset, ty, leftText, font, split, C_BLACK, col) end
  if rightText then
    drawSplitText(x + w - inset - textWidth(font, rightText), ty, rightText, font, split, C_BLACK, col)
  end
end

---------------------------------------------------------------- servo drawing

-- plug at the end of the servo wire, relative to the servo (800 x 480 scale)
local PLUG_DX, PLUG_DY = 46, 40

local SERVO = { key = nil }   -- recorded drawing of the fixed servo parts, per layout

-- fixed parts of the servo: ears, case, plate, screws, wire and plug
local function buildServoStatic(L)
  local cx, cy, k = L.cx, L.cy, L.k
  local off, bw, bh, ear = 40 * k, 92 * k, 164 * k, 14 * k
  local x0, y0 = cx - bw / 2, cy - off

  -- mounting ears with holes
  drawRoundedBox(x0 + bw * 0.16, y0 - ear, bw * 0.68, ear + 2, 3 * k, C_CASE, C_EDGE, 1)
  drawRoundedBox(x0 + bw * 0.16, y0 + bh - 2, bw * 0.68, ear + 2, 3 * k, C_CASE, C_EDGE, 1)
  local hr = 4.2 * k
  for _, p in ipairs({ { cx - bw * 0.2, y0 - ear / 2 }, { cx + bw * 0.2, y0 - ear / 2 },
                       { cx - bw * 0.2, y0 + bh + ear / 2 }, { cx + bw * 0.2, y0 + bh + ear / 2 } }) do
    fillCircle(p[1], p[2], hr + 1, C_EDGE)
    fillCircle(p[1], p[2], hr, C_BG)
  end

  -- case with orange edge, top plate and screws
  drawRoundedBox(x0, y0, bw, bh, 8 * k, C_CASE, C_ORANGE, 2)
  fillRounded(x0 + 6 * k, y0 + 6 * k, bw - 12 * k, bh * 0.46, 6 * k, C_PLATE)
  for _, p in ipairs({ { x0 + 8 * k, y0 + 8 * k }, { x0 + bw - 8 * k, y0 + 8 * k },
                       { x0 + 8 * k, y0 + bh - 8 * k }, { x0 + bw - 8 * k, y0 + bh - 8 * k } }) do
    fillCircle(p[1], p[2], 2.2 * k, C_EDGE)
  end

  -- wire from the bottom of the case to a plug
  local wy = y0 + bh + ear - 2
  local px, py = cx + PLUG_DX * k, wy + PLUG_DY * k
  local wcol = { C_W_BROWN, C_W_RED, C_ORANGE }
  for wi, d in ipairs({ -5 * k, 0, 5 * k }) do
    local x1, y1 = cx + d, wy
    local x2, y2 = cx + d, wy + 22 * k + d
    local x3, y3 = cx + PLUG_DX * 0.4 * k, py + d
    local x4, y4 = px, py + d
    local n = 8
    local lx, ly = x1, y1
    for i = 1, n do
      local t = i / n
      local u = 1 - t
      local a, b, c, e = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
      local nx, ny = a * x1 + b * x2 + c * x3 + e * x4, a * y1 + b * y2 + c * y3 + e * y4
      thickLine(lx, ly, nx, ny, wcol[wi])
      lx, ly = nx, ny
    end
  end
  drawRoundedBox(px - 2 * k, py - 10 * k, 22 * k, 20 * k, 3 * k, C_PLUG, C_EDGE, 1)
  for _, d in ipairs({ -5 * k, 0, 5 * k }) do
    drawBox(px + 20 * k, py + d - 1.5 * k, math.max(2, 5 * k), math.max(2, 3 * k), C_PIN)
  end
end

-- fixed parts of the arm hub: spline ring, screw with a cross (drawn on top of the arm)
local function buildHubStatic(L)
  local cx, cy, k = L.cx, L.cy, L.k
  local o = math.max(2, 2.5 * k)
  local hub = 28 * k
  fillCircle(cx, cy, hub + o / 2, C_ORANGE)
  fillCircle(cx, cy, hub - o / 2, C_ARM)
  G.color(C_EDGE)
  for i = 0, 23 do
    local x1, y1 = polar(cx, cy, 18 * k, i * 15)
    local x2, y2 = polar(cx, cy, 22 * k, i * 15)
    G.drawLine(x1, y1, x2, y2)
  end
  fillCircle(cx, cy, 12 * k, C_EDGE)
  fillCircle(cx, cy, 12 * k - math.max(1, 1.5 * k), C_BG)
  local c = 5.5 * k
  thickLine(cx - c * 0.7, cy - c * 0.7, cx + c * 0.7, cy + c * 0.7, C_CROSS)
  thickLine(cx - c * 0.7, cy + c * 0.7, cx + c * 0.7, cy - c * 0.7, C_CROSS)
end

local function servoParts(L)
  if SERVO.key ~= L.key then
    SERVO.body, SERVO.hub = nil, nil
    SERVO.key = L.key
  end
  if not SERVO.body then SERVO.body = record(buildServoStatic, L) end
  if not SERVO.hub  then SERVO.hub  = record(buildHubStatic, L) end
  return SERVO
end

-- Preparing the dials and the servo drawing takes a lot of work, more than the radio
-- allows in one screen refresh. It is done in small steps in the background (one step
-- per wakeup) before the full dashboard is drawn for the first time.
local WARM_STEPS = {
  function(L) dialGeometry(L.cx, L.cy, L.r, L.segBig, 0.13) end,
  function(L) dialGeometry(L.lcx, L.mcy, L.mr, L.segSmall, 0.2) end,
  function(L) dialGeometry(L.rcx, L.mcy, L.mr, L.segSmall, 0.2) end,
  function(L)
    if SERVO.key ~= L.key then SERVO.body, SERVO.hub, SERVO.key = nil, nil, L.key end
    SERVO.body = SERVO.body or record(buildServoStatic, L)
  end,
  function(L)
    if SERVO.key ~= L.key then SERVO.body, SERVO.hub, SERVO.key = nil, nil, L.key end
    SERVO.hub = SERVO.hub or record(buildHubStatic, L)
  end,
}
local warm = { key = nil, step = 0 }

local function warmDone(L)
  return warm.key == L.key and warm.step >= #WARM_STEPS
end

-- one preparation step; true when everything is ready
local function warmStep(L)
  if warm.key ~= L.key then warm.key, warm.step = L.key, 0 end
  if warm.step < #WARM_STEPS then
    warm.step = warm.step + 1
    WARM_STEPS[warm.step](L)
  end
  return warm.step >= #WARM_STEPS
end

-- servo case with the cycle count and the readouts at the end of the wire
local function drawServoBody(L, count, target)
  replay(servoParts(L).body)

  local cx, cy, k = L.cx, L.cy, L.k
  local off, bw, bh, ear = 40 * k, 92 * k, 164 * k, 14 * k
  local y0 = cy - off

  -- cycles on the case
  drawMid(cx, y0 + bh * 0.53, "CYCLES", F.smallb, C_ORANGE)
  local ct = tostring(count)
  local cf = fitFontWH(ct, bw - 10 * k, bh * 0.24, F.huge, F.gauge, F.big, F.bold, F.normal)
  drawMid(cx, y0 + bh * 0.68, ct, cf, C_LIGHT)
  drawMid(cx, y0 + bh * 0.85, "of " .. target, F.small, C_DIM)

  -- current and RX battery at the end of the wire, lined up above each other
  local wy = y0 + bh + ear - 2
  local px, py = cx + PLUG_DX * k, wy + PLUG_DY * k
  local vf = F.bold
  local hb = fontHeight(vf)
  local sp = math.max(24 * k, hb + 1)
  py = py + 6 * k                                   -- lined up with the plug
  local vx, ux = px + 80 * k, px + 86 * k           -- and further from the right dial
  if isObj(settings.currSrc) then
    local v, ty = sens.cNow and string.format("%.1f", sens.cNow) or "--", py - sp / 2 - hb / 2
    drawText(vx - textWidth(vf, v), ty, v, vf, C_LIGHT)
    drawText(ux, ty, "A", vf, C_ORANGE)
  end
  if isObj(settings.battSrc) then
    local v, ty = sens.vNow and string.format("%.2f", sens.vNow) or "--", py + sp / 2 - hb / 2
    drawText(vx - textWidth(vf, v), ty, v, vf, C_LIGHT)
    drawText(ux, ty, "V", vf, C_ORANGE)
  end
end

-- servo arm as the dial pointer, deg: 0 = up, clockwise
local ARM_HOLES = { 0.42, 0.58, 0.74, 0.9 }

local function drawServoArm(L, deg)
  local cx, cy, k = L.cx, L.cy, L.k
  local len = L.r * 0.76
  local hw, tw = 20 * k, 10 * k
  local o = math.max(2, 2.5 * k)
  local a = math.rad(deg)
  local dx, dy = math.sin(a), -math.cos(a)     -- along the arm
  local nx, ny = math.cos(a), math.sin(a)      -- across the arm
  local tx, ty = cx + dx * len, cy + dy * len

  -- arm: orange outline, dark inside, rounded tip
  fillQuad(cx - nx * (hw + o), cy - ny * (hw + o), tx - nx * (tw + o), ty - ny * (tw + o),
           tx + nx * (tw + o), ty + ny * (tw + o), cx + nx * (hw + o), cy + ny * (hw + o), C_ORANGE)
  fillCircle(tx, ty, tw + o, C_ORANGE)
  fillQuad(cx - nx * hw, cy - ny * hw, tx - nx * tw, ty - ny * tw,
           tx + nx * tw, ty + ny * tw, cx + nx * hw, cy + ny * hw, C_ARM)
  fillCircle(tx, ty, tw, C_ARM)

  -- holes along the arm
  for i = 1, 4 do
    local f = ARM_HOLES[i]
    local hr = (4.2 - f * 1.5) * k
    local hx, hy = cx + dx * len * f, cy + dy * len * f
    fillCircle(hx, hy, hr + 1, C_HOLE)
    fillCircle(hx, hy, hr, C_BG)
  end

  -- hub on top
  replay(servoParts(L).hub)
end

---------------------------------------------------------------- logo

-- the logo with "SERVO CYCLER" comes in several widths and is drawn at its own size
-- (scaling a picture on every refresh is slow and makes the servos stutter)
local LOGO_DIRS  = { "", "/scripts/svcycler/", "SCRIPTS:/svcycler/" }
local LOGO_SIZES = { 300, 260, 230, 200, 170, 150, 130, 110, 90 }

local function loadOne(name)
  for _, d in ipairs(LOGO_DIRS) do
    local ok, bmp = pcall(lcd.loadBitmap, d .. name)
    if ok and bmp ~= nil then return bmp end
  end
  return nil
end

local function loadLogo()
  local list = {}
  if not lcd.loadBitmap then return list end
  for _, sz in ipairs(LOGO_SIZES) do
    local bmp = loadOne("logot_" .. sz .. ".png")
    if bmp then list[#list + 1] = bmp end
  end
  return list
end

---------------------------------------------------------------- layout per screen size
-- Everything is placed on an 800 x 480 grid and scaled to the screen.

local TIER_OPTS = {
  large  = { pad = 8, segBig = 30, segSmall = 16 },
  medium = { pad = 6, segBig = 26, segSmall = 14 },
  small  = { pad = 4, segBig = 22, segSmall = 12 },
}

local LAYOUT = { key = nil }

local function computeLayout(w, h)
  local key = w .. "x" .. h
  if LAYOUT.key == key then
    F = FONTSETS[LAYOUT.tier]
    return LAYOUT
  end

  local tier = (h >= 420 and "large") or (h >= 300 and "medium") or "small"
  F = FONTSETS[tier]
  local o = TIER_OPTS[tier]
  local sx, sy = w / 800, h / 480
  local L = { key = key, tier = tier, pad = o.pad, segBig = o.segBig, segSmall = o.segSmall, sx = sx, sy = sy }

  -- top bar
  L.barX, L.barY = L.pad, L.pad
  L.barW = w - L.pad * 2
  L.barH = math.floor(math.max(46 * sy, fontHeight(F.normal) + 8))
  L.barInset = math.floor(16 * sx)
  L.barFont = fitFontWH("RUNNING", w * 0.3, L.barH - 6, F.gauge, F.big, F.bold, F.normal)
  L.below = L.barY + L.barH

  -- big dial in the centre
  L.r  = math.floor(math.min(158 * sy, w * 0.22))
  L.cx = math.floor(w / 2)
  L.cy = math.floor(250 * sy)
  L.k  = L.r / 158

  -- bottom dials
  L.mr  = math.floor(66 * sy)
  L.mcy = math.floor(392 * sy)
  L.lcx = math.floor(120 * sx)
  L.rcx = w - L.lcx

  -- temperature bars on the right
  L.tW = math.floor(w * 0.25)
  L.tX = w - L.pad - L.tW
  L.tH = math.floor(math.max(23 * sy, fontHeight(F.small) + 4))
  L.tStep = math.floor(math.max(28 * sy, L.tH + 3))
  L.tY = math.floor(math.max(74 * sy, L.below + 8))
  L.tInset = math.floor(math.max(4, 8 * sx))
  L.tThick = (L.tH >= 20) and 2 or 1

  -- logo top left: as large as fits between the bar and the travel dial
  L.logoX = L.pad
  L.logoY = L.below + math.floor(6 * sy)
  L.logoMaxW = math.floor(w * 0.38)
  L.logoMaxH = (L.mcy - L.mr) - 8 - L.logoY

  LAYOUT = L
  return L
end

---------------------------------------------------------------- widget

local function widgetCreate()
  markOwner()
  return { last = 0, logo = loadLogo() }
end

-- minimal view for very small zones
local function paintCompact(widget, w, h)
  F = FONTSETS.small
  local hs = fontHeight(F.small)
  drawText(3, 2, string.upper(state.status), F.bold, state.running and C_GREEN or C_RED)
  local countFont = fitFont(tostring(state.count), w - 6, F.huge, F.gauge, F.normal)
  drawCentered(w / 2, hs + 4, tostring(state.count), countFont, C_LIGHT)
  drawCentered(w / 2, h - hs - 2, "of " .. settings.cycles .. "  " .. fmtTime(timeLeft()), F.small, C_ORANGE)
end

-- top bar: progress bar while running, status box otherwise
local function paintTopBar(L, w)
  local x, y, bw, bh = L.barX, L.barY, L.barW, L.barH
  local font = L.barFont
  local ty = y + (bh - fontHeight(font)) / 2
  local inset = L.barInset

  if state.running then
    -- empty at the start, fills green from left to right
    local p = progress()
    local rad = bh * 0.3
    drawRoundedBox(x, y, bw, bh, rad, C_BLACK, C_GREEN, 2)
    local fw = math.floor(bw * p)
    if fw >= 2 then fillRounded(x, y, fw, bh, math.min(rad, fw / 2), C_GREEN) end
    local split = x + fw
    local tEl, tLeft, mid = fmtTime(state.elapsed), fmtTime(timeLeft()), "RUNNING"
    drawSplitText(x + inset, ty, tEl, font, split, C_BLACK, C_GREEN)
    drawSplitText(x + bw / 2 - textWidth(font, mid) / 2, ty, mid, font, split, C_BLACK, C_GREEN)
    drawSplitText(x + bw - inset - textWidth(font, tLeft), ty, tLeft, font, split, C_BLACK, C_GREEN)
    return
  end

  -- not running: small status box in the middle, times to the sides
  local statusText = (settings.switch == nil) and "NO SWITCH" or string.upper(state.status)
  local sbW = math.floor(w * 0.34)
  local sf = fitFontWH(statusText, sbW - 16, bh - 6, F.gauge, F.big, F.bold, F.normal)
  drawRoundedBox(w / 2 - sbW / 2, y, sbW, bh, bh * 0.3, C_PANEL, C_RED, 2)
  drawMid(w / 2, y + bh / 2, statusText, sf, C_RED)

  local cyb = y + bh / 2
  local gap = math.floor(6 * L.sx)
  -- left: elapsed time of the last test
  local tEl = fmtTime(state.elapsed)
  drawText(x + inset, ty, tEl, font, C_LIGHT)
  drawText(x + inset + textWidth(font, tEl) + gap, cyb - fontHeight(F.small) / 2, "ELAPSED", F.small, C_DIM)
  -- right: time left of a stopped test, otherwise the total time of a test
  local label, tR
  if state.status == "Stopped" then
    label, tR = "LEFT", fmtTime(timeLeft())
  else
    label, tR = "TOTAL", fmtTime(timeTotal())
  end
  local rx = x + bw - inset - textWidth(font, tR)
  drawText(rx, ty, tR, font, C_LIGHT)
  drawText(rx - gap - textWidth(F.small, label), cyb - fontHeight(F.small) / 2, label, F.small, C_DIM)
end

local function paintDashboard(widget)
  local w, h = lcd.getWindowSize()

  drawBox(0, 0, w, h, C_BG)

  if w < 300 or h < 190 then
    paintCompact(widget, w, h)
    return
  end

  local L = computeLayout(w, h)
  local p = progress()

  if not warmDone(L) then
    -- still preparing (only right after start): show the logo, the rest follows in a moment
    widget.warmL = L
    if lcd.drawBitmap then
      for _, bmp in ipairs(widget.logo or {}) do
        local bw, bh = bmp:width(), bmp:height()
        if bw and bh and bw <= L.logoMaxW and bh <= L.logoMaxH then
          lcd.drawBitmap(math.floor(L.logoX), math.floor(L.logoY), bmp)
          break
        end
      end
    end
    return
  end
  widget.warmL = nil

  ------------------------------------------------ logo with "SERVO CYCLER" (top left)
  if lcd.drawBitmap then
    for _, bmp in ipairs(widget.logo or {}) do
      local bw, bh = bmp:width(), bmp:height()
      if bw and bh and bw <= L.logoMaxW and bh <= L.logoMaxH then
        lcd.drawBitmap(math.floor(L.logoX), math.floor(L.logoY), bmp)
        break
      end
    end
  end

  ------------------------------------------------ big dial with the servo
  drawDial(L.cx, L.cy, L.r, p, L.segBig, nil, 0.13)
  drawMid(L.cx - L.r * 0.62, L.cy + L.r * 0.86, "0", F.small, C_DIM)
  drawMid(L.cx + L.r * 0.62, L.cy + L.r * 0.86, tostring(settings.cycles), F.small, C_DIM)
  drawServoBody(L, state.count, settings.cycles)
  drawServoArm(L, -135 + 270 * p)

  ------------------------------------------------ top bar
  paintTopBar(L, w)

  ------------------------------------------------ temperatures (right): bars green > red
  local warn = settings.tempWarn or 60
  local fmtT = function(v) return v and string.format("%d", math.floor(v + 0.5)) or "--" end
  for i, row in ipairs(hottest()) do
    local y = L.tY + (i - 1) * L.tStep
    local col, frac = C_GREY, 0
    if row.now then
      col  = heatColor((row.now - 30) / math.max(1, warn - 30))
      frac = math.max(0.04, (row.now - 20) / math.max(1, warn + 10 - 20))
    end
    invBar(L.tX, y, L.tW, L.tH, frac, col, row.name, fmtT(row.now) .. " / " .. fmtT(row.max) .. " °C",
           F.small, L.tInset, L.tThick)
  end

  ------------------------------------------------ bottom dials: travel and cycles setting
  local travelCx, cyclesCx = L.lcx, L.rcx
  if settings.dialOrder == 1 then travelCx, cyclesCx = L.rcx, L.lcx end
  local mr, mcy = L.mr, L.mcy
  local inner = mr * 1.25
  local valFont = fitFont("100%", inner, F.big, F.bold, F.smallb, F.small)
  local hv = fontHeight(valFont)
  local showUnit = textWidth(F.small, "CYCLES") <= inner and mr >= 26
  local hu = showUnit and fontHeight(F.small) or 0

  drawDial(travelCx, mcy, mr, state.curTravel / 100, L.segSmall, travelSegColor)
  drawMid(travelCx, mcy, tostring(math.floor(state.curTravel + 0.5)) .. "%", valFont, C_LIGHT)
  drawCentered(travelCx, mcy + mr * 0.74, "TRAVEL", F.smallb, C_ORANGE)

  local vy = mcy - (hv + hu) / 2
  drawDial(cyclesCx, mcy, mr, targetFrac(), L.segSmall, cyclesSegColor)
  drawCentered(cyclesCx, vy, tostring(settings.cycles), valFont, C_LIGHT)
  if showUnit then drawCentered(cyclesCx, vy + hv, "CYCLES", F.small, C_DIM) end
  drawCentered(cyclesCx, mcy + mr * 0.74, "SET", F.smallb, C_ORANGE)
end

-- paint with error capture: a script error is shown on screen instead of a frozen dashboard
local function widgetPaint(widget)
  local ok, err = pcall(paintDashboard, widget)
  if not ok then
    lastError = "screen: " .. tostring(err)
    lastErrorTime = now()
  end
  if lastError and now() - (lastErrorTime or 0) > 15 then lastError = nil end   -- old message: hide
  if lastError then
    local w, h = lcd.getWindowSize()
    lcd.font(FONT_S or FONT_STD)
    lcd.color(C_RED)
    lcd.drawText(4, h - 20, string.sub(lastError, 1, 90))
  end
end

local function widgetWakeup(widget)
  markOwner()
  widgetTick()
  local t = now()

  -- dashboard still being prepared: one step per wakeup, then draw it
  if widget.warmL then
    local ok, err = pcall(warmStep, widget.warmL)
    if not ok then lastError = "prepare: " .. tostring(err); lastErrorTime = t end
    if not ok or warmDone(widget.warmL) then
      widget.warmL = nil
      widget.last = t
      lcd.invalidate()
    end
    return
  end

  -- always show start / stop at once
  if widget.wasRunning ~= state.running then
    widget.wasRunning = state.running
    widget.last = t
    lcd.invalidate()
    return
  end

  -- While a test runs the screen is refreshed about once a second, right AFTER the
  -- script has set the next end point: a refresh pauses the script for a moment, and
  -- this way the pause never delays the next turn. The movement itself is done by the
  -- mix "slow" and is not affected by refreshes at all.
  if state.running then
    local k = math.floor(state.phase * 4)       -- quarter cycles
    if k ~= widget.turnK then
      widget.turnK = k
      if t - widget.last >= 0.9 then
        widget.last = t
        lcd.invalidate()
      end
    end
    return
  end

  local interval = 0.2   -- idle: refresh often so the knobs show at once
  if t - widget.last > interval then
    widget.last = t
    lcd.invalidate()
  end
end

-- touching the dashboard just refreshes it; keys are left to Ethos (ENTER opens the widget menu)
local function widgetEvent(widget, category, value, x, y)
  if EVT_TOUCH and category == EVT_TOUCH and value == TOUCH_END then
    lcd.invalidate()
  end
  return false
end

local function widgetConfigure(widget)
  local line, f

  line = form.addLine("Start switch")
  form.addSwitchField(line, nil,
    function() return settings.switch end,
    function(v) settings.switch = v end)

  line = form.addLine("Cycles knob (pot 2)")
  form.addSourceField(line, nil,
    function() return settings.targetSrc end,
    function(v) settings.targetSrc = v end)

  line = form.addLine("Cycles (no knob)")
  form.addNumberField(line, nil, 1, MAX_CYCLES,
    function() return settings.cycles end,
    function(v) settings.cycles = v end)

  line = form.addLine("Travel knob (pot 1)")
  form.addSourceField(line, nil,
    function() return settings.travelSrc end,
    function(v) settings.travelSrc = v end)

  line = form.addLine("Travel (no knob)")
  f = form.addNumberField(line, nil, 10, 100,
    function() return settings.travel end,
    function(v) settings.travel = v end)
  f:suffix("%")

  line = form.addLine("Bottom dials")
  form.addChoiceField(line, nil, { { "Travel | Cycles", 0 }, { "Cycles | Travel", 1 } },
    function() return settings.dialOrder end,
    function(v) settings.dialOrder = v end)

  for i = 1, MAX_TEMPS do
    line = form.addLine("Temp sensor " .. i)
    form.addSourceField(line, nil,
      function() return settings.temps[i] end,
      function(v) settings.temps[i] = v; sens.name[i] = nil end)
  end

  line = form.addLine("Temp warning")
  f = form.addNumberField(line, nil, 30, 120,
    function() return settings.tempWarn end,
    function(v) settings.tempWarn = v end)
  f:suffix(" °C")

  line = form.addLine("Current sensor")
  form.addSourceField(line, nil,
    function() return settings.currSrc end,
    function(v) settings.currSrc = v end)

  line = form.addLine("RX battery sensor")
  form.addSourceField(line, nil,
    function() return settings.battSrc end,
    function(v) settings.battSrc = v end)

  -- reminder of the mix setting this version needs
  if form.addStaticText then
    line = form.addLine("Slow up/down")
    form.addStaticText(line, nil, string.format("%.1f s  (%d cycles/min)", SLOW_TIME, math.floor(60 / PERIOD + 0.5)))
  end
end

-- stored values are checked: settings saved by an older version (or a missing
-- one) must never be able to stop the script
local function readNum(key, def, lo, hi)
  local v = storage.read(key)
  if type(v) ~= "number" then return def end
  return clamp(math.floor(v + 0.5), lo, hi)
end

local function readObj(key)
  local v = storage.read(key)
  local t = type(v)
  if t == "userdata" or t == "table" then return v end
  return nil
end

-- switch, travel and sensors are kept from older versions; the cycles knob and the
-- dial order are new settings (stored values are checked, see readNum / readObj)
local function widgetRead(widget)
  markOwner()
  settings.switch    = readObj("switch")
  settings.cycles    = readNum("cycles", 100, 1, MAX_CYCLES)
  settings.travel    = readNum("travel", 100, 10, 100)
  settings.travelSrc = readObj("travelSrc")
  settings.targetSrc = readObj("cyclesSrc")
  settings.dialOrder = readNum("dialOrd8", 0, 0, 1)
  settings.temps     = {}
  for i = 1, MAX_TEMPS do settings.temps[i] = readObj("temp" .. i) end
  settings.tempWarn  = readNum("tempWarn", 60, 30, 120)
  settings.currSrc   = readObj("currSrc")
  settings.battSrc   = readObj("battSrc")
end

local function widgetWrite(widget)
  storage.write("switch",    settings.switch)
  storage.write("cycles",    settings.cycles)
  storage.write("travel",    settings.travel)
  storage.write("travelSrc", settings.travelSrc)
  storage.write("cyclesSrc", settings.targetSrc)
  storage.write("dialOrd8", settings.dialOrder)
  for i = 1, MAX_TEMPS do storage.write("temp" .. i, settings.temps[i]) end
  storage.write("tempWarn",  settings.tempWarn)
  storage.write("currSrc",   settings.currSrc)
  storage.write("battSrc",   settings.battSrc)
end

---------------------------------------------------------------- register

local function init()
  system.registerSource({
    key    = "svcyc",
    name   = "Servo Cycler",
    init   = sourceInit,
    wakeup = sourceWakeup,
  })

  system.registerWidget({
    key       = "svcycw",
    name      = "Servo Cycler",
    create    = widgetCreate,
    paint     = widgetPaint,
    wakeup    = widgetWakeup,
    event     = widgetEvent,
    configure = widgetConfigure,
    read      = widgetRead,
    write     = widgetWrite,
  })
end

return { init = init }
