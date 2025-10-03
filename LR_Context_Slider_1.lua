--[[
Contextual MIDI slider handler for REAPER (Lua)
Bind this script to your MIDI CC/fader in the Actions list.
Behavior depends on where the mouse is hovering:
  - Track panel: set hovered track volume based on slider position
  - Item area:  set hovered item volume based on slider position
  - Envelope:   write slider position to selected envelope point value(s)

Notes:
- Designed for absolute MIDI sliders/faders (7-bit or 14-bit resolution).
- Tweak the helpers below to customize the response curve or ranges.
--]]

----------------------------------------
-- SETTINGS
----------------------------------------
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

local function slider_to_normalized(val, resolution)
  if not resolution or resolution <= 0 then resolution = 127 end
  if resolution == 128 then resolution = 127 end
  if resolution == 16384 then resolution = 16383 end

  local norm = clamp(val / resolution, 0.0, 1.0)
  return norm
end

local function normalized_to_db(norm)
  norm = clamp(norm, 0.0, 1.0)
  return DB_MIN + (DB_MAX - DB_MIN) * norm
end

local function normalized_to_gain(norm)
  return db_to_gain(normalized_to_db(norm))
end

----------------------------------------
-- DEFAULT CONTEXT HANDLERS
----------------------------------------

-- Track panel: adjust hovered track volume in dB
local function handle_track_context(norm, hovered_track)
  if not hovered_track then return end
  local gain = normalized_to_gain(norm)
  reaper.SetMediaTrackInfo_Value(hovered_track, "D_VOL", gain)
end

-- Item area: adjust hovered item volume from slider position
local function handle_item_context(norm, hovered_item)
  if not hovered_item then return end
  local gain = normalized_to_gain(norm)
  reaper.SetMediaItemInfo_Value(hovered_item, "D_VOL", gain)
  reaper.UpdateItemInProject(hovered_item)
end

-- Envelope area: adjust SELECTED envelope points by a small step
-- (keeps it generic for any envelope type; tweak as needed)
local function handle_envelope_context(norm, env)
  if not env then return end
  local cnt = reaper.CountEnvelopePoints(env)
  if cnt == 0 then return end

  local any_sel = false
  for i = 0, cnt - 1 do
    local rv, time, val, shape, tens, sel = reaper.GetEnvelopePoint(env, i)
    if rv and sel then any_sel = true break end
  end
  if not any_sel then return end

  -- Apply slider position to selected points, then sort.
  for i = 0, cnt - 1 do
    local rv, time, val, shape, tens, sel = reaper.GetEnvelopePoint(env, i)
    if rv and sel then
      local new_val = clamp(norm, 0.0, 1.0)
      reaper.SetEnvelopePoint(env, i, time, new_val, shape, tens, sel, true)
    end
  end
  reaper.Envelope_SortPoints(env)
end

----------------------------------------
-- MAIN
----------------------------------------
local function main()
  local ok, _, sectionID, cmdID, mode, resolution, val, contextstr = reaper.get_action_context()
  if not ok then return end

  msg("=== MIDI SLIDER EVENT ===")
  msg("val=" .. val .. " mode=" .. mode .. " resolution=" .. resolution)
  msg("contextstr=" .. tostring(contextstr))

  local norm = slider_to_normalized(val, resolution)

  local ctx, hovered_track, hovered_item, hovered_env = get_hover_context()

  -- Route by cursor context
  msg("cursor context=" .. ctx)
  if ctx == 0 then
    msg("Hovering TRACK")
    handle_track_context(norm, hovered_track)
  elseif ctx == 1 then
    msg("Hovering ITEM")
    handle_item_context(norm, hovered_item)
  elseif ctx == 2 then
    msg("Hovering ENVELOPE")
    handle_envelope_context(norm, hovered_env)
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
reaper.Undo_EndBlock("Contextual MIDI slider handler", -1)
