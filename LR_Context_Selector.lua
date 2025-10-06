--[[
Contextual MIDI knob handler for REAPER (Lua)
Bind this script to your MIDI CC/encoder in the Actions list.
Behavior depends on where the mouse is hovering:
  - Track panel: adjust hovered track volume (dB)
  - Item area:  adjust hovered item volume (dB)
  - Envelope:   adjust selected envelope point value(s)

Notes:
- Works with relative and absolute encoder modes.
- For absolute encoders, we track last value in ExtState to compute delta.
- Tweak SENS settings and handlers below to do anything you like.
--]]

----------------------------------------
-- SETTINGS
----------------------------------------
local SENS = {
  db_step_per_tick = 0.5,   -- dB per encoder "tick" for track/item volume
  env_step          = 0.01,  -- linear step for envelope points (0..1 typical)
}

-- Optional: limit min/max gain (in dB) when writing track/item volume
local DB_MIN = -90.0
local DB_MAX =  12.0

----------------------------------------
-- UTILS
----------------------------------------
local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function gain_to_db(g)
  if g <= 0.0 then return DB_MIN end
  return 20.0 * math.log(g, 10)
end

local function db_to_gain(db)
  if db <= DB_MIN then return 0.0 end
  return 10.0 ^ (db / 20.0)
end

-- Helper: append message to console
local function msg(s)
  reaper.ShowConsoleMsg(tostring(s) .. "\n")
end

-- Heuristic to convert MIDI/OSC value to a signed "ticks" delta
-- Handles REAPER's common relative modes and falls back to absolute center.
local function get_encoder_delta(mode, resolution, val, ext_ns, key_suffix)
  -- Relative modes: try to interpret increments/decrements
  if mode and mode > 0 then
    -- 7-bit relatives (common): 1..63 = +ticks, 65..127 = -ticks (2's complement style)
    if resolution == 127 or resolution == 128 then
      if val == 0 then return 0 end
      if val >= 1 and val <= 63 then return val end
      if val >= 65 and val <= 127 then return -(128 - val) end
      -- Some devices send 127 for -1
      if val == 127 then return -1 end
      return 0
    end
    -- 14-bit relatives (rare): center 8192
    if resolution == 16383 or resolution == 16384 then
      local mid = 8192
      return val - mid
    end
    return 0
  end

  -- Absolute mode: compute delta from last absolute value (ExtState)
  local key = "LAST_ABS_" .. tostring(key_suffix or "0")
  local last = tonumber(reaper.GetExtState(ext_ns, key) or "") or val
  reaper.SetExtState(ext_ns, key, tostring(val), false)

  -- Common 7-bit absolute: treat 64 as center
  if resolution == 127 or resolution == 128 then
    return val - last
  end
  -- 14-bit absolute: use raw delta
  if resolution == 16383 or resolution == 16384 then
    return val - last
  end
  return val - last
end

-- Safe wrapper: works with or without SWS installed
local function get_env_from_point(x, y)
  if reaper.GetEnvelopeFromPoint then
    return reaper.GetEnvelopeFromPoint(x, y)
  elseif reaper.BR_EnvelopeFromPoint then
    return reaper.BR_EnvelopeFromPoint(x, y)
  else
    return nil
  end
end

-- Get hovered things
local function get_hover_context()
  local ctx = reaper.GetCursorContext() -- 0=tracks,1=items,2=envelopes
  local x, y = reaper.GetMousePosition()

  local hovered_track = nil
  local track, tcp_mcp = reaper.GetTrackFromPoint(x, y)
  if track then hovered_track = track end

  local hovered_item = nil
  local it, _ = reaper.GetItemFromPoint(x, y, false)
  if it then hovered_item = it end

  local hovered_env = get_env_from_point(x, y)

  return ctx, hovered_track, hovered_item, hovered_env
end

-- SETTINGS (add near your other SENS)
local ENV = {
  use_grid = true,            -- true: step by current grid; false: fixed seconds
  nav_step_seconds = 0.020,   -- used when use_grid=false
  clamp_to_proj = true,       -- avoid going <0 or >project end

  select_nearest_always = true,
  select_thresh_seconds = 0.030,
  clear_sel_if_none = false,
}

-- Find nearest envelope point to time t
local function find_nearest_point(env, t)
  local cnt = reaper.CountEnvelopePoints(env)
  if cnt == 0 then return -1, math.huge end
  local best_i, best_dt = -1, math.huge
  for i = 0, cnt - 1 do
    local ok, pt_t = reaper.GetEnvelopePoint(env, i)
    if ok then
      local d = math.abs(pt_t - t)
      if d < best_dt then best_dt, best_i = d, i end
    end
  end
  return best_i, best_dt
end

local function grid_step_seconds(at_time)
  local _, qn_div = reaper.GetSetProjectGrid(0, false, 0, 0, 0) -- division in QN
  if (not qn_div) or qn_div <= 0 then return ENV.nav_step_seconds end
  local qn = reaper.TimeMap2_timeToQN(0, at_time)
  local t0 = reaper.TimeMap2_QNToTime(0, qn)
  local t1 = reaper.TimeMap2_QNToTime(0, qn + qn_div)
  return math.max(1e-6, t1 - t0)
end

----------------------------------------
-- DEFAULT CONTEXT HANDLERS
----------------------------------------

-- Track panel: adjust hovered track volume in dB
local function handle_track_context(tick_delta, hovered_track)
  if not hovered_track or tick_delta == 0 then return end
  local cur_gain = reaper.GetMediaTrackInfo_Value(hovered_track, "D_VOL")
  local cur_db   = gain_to_db(cur_gain)
  local new_db   = clamp(cur_db + tick_delta * SENS.db_step_per_tick, DB_MIN, DB_MAX)
  reaper.SetMediaTrackInfo_Value(hovered_track, "D_VOL", db_to_gain(new_db))
end

-- Item area: jump edit cursor between transients within the hovered item
local function handle_item_context(tick_delta, hovered_item)
  if not hovered_item or tick_delta == 0 then return end

  -- Native actions (Main):
  -- 40375 = Item navigation: Move cursor to previous transient in items
  -- 40376 = Item navigation: Move cursor to next transient in items
  local CMD_PREV = 40375
  local CMD_NEXT = 40376

  -- Save current item selection
  
  local sel = {}
  local sel_cnt = reaper.CountSelectedMediaItems(0)
  for i = 0, sel_cnt-1 do sel[#sel+1] = reaper.GetSelectedMediaItem(0, i) end

  -- Temporarily select only the hovered item
  reaper.Main_OnCommand(40289, 0) -- Unselect all items
  reaper.SetMediaItemSelected(hovered_item, true)
  reaper.UpdateArrange()

  -- Move by |tick_delta| steps (encoder may send multiple)
  local steps = math.abs(tick_delta)
  local cmd = (tick_delta > 0) and CMD_NEXT or CMD_PREV
  for _ = 1, steps do
    reaper.Main_OnCommand(cmd, 0)
  end

  -- Clamp to hovered item bounds (stay within the item)
  
  local curpos = reaper.GetCursorPosition()
  local it_start = reaper.GetMediaItemInfo_Value(hovered_item, "D_POSITION")
  local it_len   = reaper.GetMediaItemInfo_Value(hovered_item, "D_LENGTH")
  local it_end   = it_start + it_len
  if curpos < it_start then reaper.SetEditCurPos(it_start, false, false) end
  if curpos > it_end   then reaper.SetEditCurPos(it_end,   false, false) end

  -- Restore previous selection
  reaper.Main_OnCommand(40289, 0) -- Unselect all items
  for _, it in ipairs(sel) do
    if it and reaper.ValidatePtr2(0, it, "MediaItem*") then
      reaper.SetMediaItemSelected(it, true)
    end
  end
  reaper.UpdateArrange()
end

-- Item area: adjust hovered item volume in dB
--local function handle_item_context(tick_delta, hovered_item)
--  if not hovered_item or tick_delta == 0 then return end
--  local cur_gain = reaper.GetMediaItemInfo_Value(hovered_item, "D_VOL")
--  local cur_db   = gain_to_db(cur_gain)
--  local new_db   = clamp(cur_db + tick_delta * SENS.db_step_per_tick, DB_MIN, DB_MAX)
--  reaper.SetMediaItemInfo_Value(hovered_item, "D_VOL", db_to_gain(new_db))
--  reaper.UpdateItemInProject(hovered_item)
--end

-- Envelope area: adjust SELECTED envelope points by a small step
-- (keeps it generic for any envelope type; tweak as needed)
local function handle_envelope_context(tick_delta, env)
  if not env or tick_delta == 0 then return end

  local cur = reaper.GetCursorPosition()
  local step
  if ENV.use_grid then
    local _, qn_div = reaper.GetSetProjectGrid(0, false, 0, 0, 0)
    if (not qn_div) or qn_div <= 0 then
      step = ENV.nav_step_seconds
    else
      local qn  = reaper.TimeMap2_timeToQN(0, cur)
      local t0  = reaper.TimeMap2_QNToTime(0, qn)
      local t1  = reaper.TimeMap2_QNToTime(0, qn + qn_div)
      step = math.max(1e-6, t1 - t0)
    end
  else
    step = ENV.nav_step_seconds
  end

  local newt = cur + (tick_delta * step)

  if ENV.clamp_to_proj then
    local proj_end = reaper.GetProjectLength(0)
    if newt < 0 then newt = 0 end
    if newt > proj_end then newt = proj_end end
  end

  reaper.SetEditCurPos(newt, false, false)

  -- Auto-select nearest envelope point
  local idx, dt = find_nearest_point(env, newt)
  if idx >= 0 then
    if ENV.select_nearest_always or (dt <= ENV.select_thresh_seconds) then
      -- Make that point exclusively selected
      local cnt = reaper.CountEnvelopePoints(env)
      for i = 0, cnt - 1 do
        local ok, pt_t, pt_v, sh, te, sel = reaper.GetEnvelopePoint(env, i)
        if ok then reaper.SetEnvelopePoint(env, i, pt_t, pt_v, sh, te, i == idx, true) end
      end
      reaper.Envelope_SortPoints(env)
    elseif ENV.clear_sel_if_none then
      -- Clear any selection if nothing close enough
      local cnt = reaper.CountEnvelopePoints(env)
      for i = 0, cnt - 1 do
        local ok, pt_t, pt_v, sh, te, sel = reaper.GetEnvelopePoint(env, i)
        if ok and sel then reaper.SetEnvelopePoint(env, i, pt_t, pt_v, sh, te, false, true) end
      end
      reaper.Envelope_SortPoints(env)
    end
  end
end

----------------------------------------
-- MAIN
----------------------------------------
local function main()
  local ok, _, sectionID, cmdID, mode, resolution, val, contextstr = reaper.get_action_context()
  if not ok then return end

  msg("=== MIDI EVENT ===")
  msg("val=" .. val .. " mode=" .. mode .. " resolution=" .. resolution)
  msg("contextstr=" .. tostring(contextstr))

  -- Unique namespace for ExtState keys (per script instance)
  local EXT_NS = "CTX_KNOB_SCRIPT"

  -- Use sectionID+cmdID to keep "last absolute" separate if you bind multiple instances
  local key_suffix = tostring(sectionID) .. ":" .. tostring(cmdID)
  local tick_delta = val-- get_encoder_delta(mode, resolution, val, EXT_NS, key_suffix)
  if val < 0 then
    val = val + 1
  end

  msg("Delta:" .. tostring(tick_delta))
  if tick_delta == 0 then return end

  local ctx, hovered_track, hovered_item, hovered_env = get_hover_context()

  -- Route by cursor context
  msg("cursor context=" .. ctx)
  if ctx == 0 then
    msg("Hovering TRACK")
    handle_track_context(tick_delta, hovered_track)
  elseif ctx == 1 then
    msg("Hovering ITEM")
    handle_item_context(tick_delta, hovered_item)
  elseif ctx == 2 then
    msg("Hovering ENVELOPE")
    handle_envelope_context(tick_delta, hovered_env)
  else
    -- Unknown context: do nothing (or add a fallback)
    return
  end

  -- Visual refresh
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Contextual MIDI knob handler", -1)
