-- envelope_actions.lua
local r = reaper
local M = {}

local function dbg(opts, fmt, ...)
  if opts and opts.debug then
    r.ShowConsoleMsg(string.format(fmt, ...))
  end
end

function M.onEnvelopePoint(ctx)
  -- Example: set point shape to linear
  if ctx.env then
    r.Main_OnCommand(40548, 0) -- Envelope: Set shape: linear
  end
end

function M.onEnvelope(ctx)
  -- Example: insert point at edit cursor
  r.Main_OnCommand(40332, 0) -- Envelope: Insert point at current position
end


local function sws_ok() return r.APIExists("BR_GetMouseCursorContext") end

local function env_has_selected_points(env)
  local take_id = -1
  local n = r.CountEnvelopePointsEx(env, take_id)
  for i = 0, n - 1 do
    local ok, _, _, _, _, sel = r.GetEnvelopePointEx(env, take_id, i)
    if ok and sel then return true end
  end
  return false
end

--- Set or insert envelope point(s) using a display/internal value.
--- Behavior:
---   - If selected points exist on the selected envelope: set them all.
---   - Else: insert at mouse envelope/time when SWS available and matches the selected env.
---   - Else (fallback_to_cursor ~= false): insert at edit cursor on the selected envelope.
local function set_env_value_display(disp_value, opts)
  opts = opts or {}
  local env = r.GetSelectedEnvelope(0)
  if not env then return end

  local take_id = -1
  local have_sel = env_has_selected_points(env)
  --dbg(opts, "Have selected points: %s\n", tostring(have_sel))

  -- r.Undo_BeginBlock(); r.PreventUIRefresh(1) -- (Uncomment if you want full UI wrapping here)

  if have_sel then
    local n = r.CountEnvelopePointsEx(env, take_id)
    for i = 0, n - 1 do
      local ok, t, _, shape, tens, sel = r.GetEnvelopePointEx(env, take_id, i)
      if ok and sel then
        r.SetEnvelopePointEx(
          env, take_id, i, t, disp_value,
          shape or 0, tens or 0,
          true, true
        )
      end
    end
  else
    -- No selection: insert at mouse (if SWS + same env), else at edit cursor (fallback)
    local mouse_env, mouse_t = nil, nil
    if sws_ok() then
      r.BR_GetMouseCursorContext() -- must call first
      mouse_env = select(1, r.BR_GetMouseCursorContext_Envelope())
      mouse_t   = r.BR_GetMouseCursorContext_Position()
      --dbg(opts, "Mouse time: %s, mouse env: %s\n", tostring(mouse_t), tostring(mouse_env))
    else
      dbg(opts, "SWS extension not available.\n")
    end

    local insert_t = nil
    if mouse_env and r.ValidatePtr2(0, mouse_env, "TrackEnvelope*") and mouse_env == env then
      insert_t = mouse_t
    elseif opts.fallback_to_cursor ~= false then
      insert_t = r.GetCursorPosition()
    else
      dbg(opts, "No insert location (no-op).\n")
      return
    end

    r.InsertEnvelopePointEx(
      env, take_id, insert_t, disp_value,
      opts.shape or 0, opts.tension or 0,
      opts.select_created ~= false, true
    )
  end

  r.Envelope_SortPointsEx(env, take_id)
  -- r.PreventUIRefresh(-1); r.UpdateArrange()
  -- r.Undo_EndBlock("Set/Insert Envelope Value", -1)
end

-- --- Public API --------------------------------------------------------------

-- Map absolute CC [0..127] to an envelope value and apply/insert it.
-- Keeps your original mapping logic:
--   - scaling == 0: map CC→[-1..+1] (your behavior).
--   - scaling != 0: treat CC as dB range -> amplitude -> ScaleToEnvelopeMode.
function M.SetEnvFromCC_Absolute(cc, min_disp, max_disp, opts)

    -- ReaScript: throttle to >=5 ms per action trigger
    local THRESH = 0.005 -- seconds
    
    local is_new, _, sectionID, cmdID = reaper.get_action_context()
    local key = ("CC_THROTTLE_%d_%d"):format(sectionID or 0, cmdID or 0)
    
    local now = reaper.time_precise()
    local last = tonumber(reaper.GetExtState("CC_THROTTLE", key)) or 0
    
    if (now - last) < THRESH then return end
    reaper.SetExtState("CC_THROTTLE", key, string.format("%.9f", now), false)

  opts = opts or {}
  local env = r.GetSelectedEnvelope(0)
  if not env then
    r.ShowMessageBox("No envelope selected", "Error", 0)
    return
  end

  -- Normalize CC
  local norm = math.min(math.max(cc / 127.0, 0.0), 1.0)

  -- Determine envelope scaling mode
  local scaling = r.GetEnvelopeScalingMode(env)  -- 0 = linear/raw, 1 = fader taper (e.g., volume)
  --dbg(opts, "Scaling mode: %s\n", tostring(scaling))

  -- Compute the new value once (no need to iterate over points)
  local new_val
  if scaling == 0 then
    -- Your original behavior: [-1..+1] for unscaled envelopes
    new_val = (norm * 2.0) - 1.0
  else
    -- Map CC to a dB range, convert to amplitude, then to envelope mode
    -- (You had -30..+6 dB; keeping that.)
    local min_db, max_db = -30.0, 6.0
    local db  = min_db + norm * (max_db - min_db)
    local amp = (db <= -120.0) and 0.0 or (10 ^ (db / 20.0))
    new_val   = r.ScaleToEnvelopeMode(scaling, amp)
  end

  --dbg(opts, "CC=%s → norm=%.3f → new_val=%.6f\n", tostring(cc), norm, new_val)
  set_env_value_display(new_val, opts)
end

-- Optional convenience wrapper if you want the old function name available:
SetEnvValue_Display = set_env_value_display


-- Relative CC nudge → adjust Bezier tension of points
-- cc_delta: signed nudge (e.g., -1, +1, ±2 ...)
-- opts:
--   step            = per-count tension increment (default 0.05)
--   tension_min/max = clamp (default -1 .. +1)
--   set_bezier      = true to force shape=Bezier for affected points (default true)
--   accel           = true to scale by |delta| (default false)
--   gamma           = accel exponent (default 1.0)
--   pick_radius     = seconds for nearest-point search (default 0.02)
--   fallback_to_cursor = true/false (default true)
--   debug           = true for logs
function M.NudgeBezierFromCC_Relative(cc_delta, opts)
  opts = opts or {}
  local r = reaper
  local env = r.GetSelectedEnvelope(0)
  if not env then
    r.ShowMessageBox("No envelope selected", "Error", 0)
    return
  end

  local take_id = -1
  local n = r.CountEnvelopePointsEx(env, take_id)
  if n == 0 then return end

  local step        = opts.step or 0.05
  local tens_min    = (opts.tension_min ~= nil) and opts.tension_min or -1.0
  local tens_max    = (opts.tension_max ~= nil) and opts.tension_max or  1.0
  local force_bz    = (opts.set_bezier ~= false)
  local accel       = opts.accel == true
  local gamma       = opts.gamma or 1.0
  local pick_radius = opts.pick_radius or 0.02

  local delta_mag = math.abs(cc_delta or 0)
  local signed_delta = (cc_delta >= 0 and 1 or -1) * (accel and (delta_mag ^ gamma) or delta_mag)
  local d_tension = step * signed_delta

  local function apply_on_index(i)
    local ok, t, v, shape, tens, sel = r.GetEnvelopePointEx(env, take_id, i)
    if not ok then return end
    if force_bz and shape ~= 5 then shape = 5 end -- 5 = Bezier
    tens = (tens or 0.0) + d_tension
    if tens_min and tens < tens_min then tens = tens_min end
    if tens_max and tens > tens_max then tens = tens_max end
    r.SetEnvelopePointEx(env, take_id, i, t, v, shape, tens, true, true)
  end

  -- Path 1: selected points
  local had_sel = false
  for i = 0, n - 1 do
    local ok, _, _, _, _, sel = r.GetEnvelopePointEx(env, take_id, i)
    if ok and sel then
      had_sel = true
      apply_on_index(i)
    end
  end
  if had_sel then
    r.Envelope_SortPointsEx(env, take_id)
    return
  end

  -- Path 2: point under mouse (same envelope)
  local target_i = nil
  if r.APIExists("BR_GetMouseCursorContext") then
    r.BR_GetMouseCursorContext()
    local mouse_env = select(1, r.BR_GetMouseCursorContext_Envelope())
    local mouse_t   = r.BR_GetMouseCursorContext_Position()
    if mouse_env and r.ValidatePtr2(0, mouse_env, "TrackEnvelope*") and mouse_env == env then
      target_i = find_nearest_point_index(env, take_id, mouse_t, pick_radius)
    end
  end

  -- Path 3: nearest to edit cursor
  if not target_i and (opts.fallback_to_cursor ~= false) then
    local cur_t = r.GetCursorPosition()
    target_i = find_nearest_point_index(env, take_id, cur_t, pick_radius)
  end

  if target_i then
    apply_on_index(target_i)
    r.Envelope_SortPointsEx(env, take_id)
  end
end




function M.onEnvelopeSelector(ctx, click, val)
  -- Example: select track under mouse
  if click then
    r.SetOnlyTrackSelected(ctx.track)
    return
  end

  if val > 0 then
      id = reaper.NamedCommandLookup("_SWS_BRMOVEEDITSELNEXTENV")
      r.Main_OnCommand(id, val) -- Envelope: 
  end
  if val < 0 then
      id = reaper.NamedCommandLookup("_SWS_BRMOVEEDITSELPREVENV")
      r.Main_OnCommand(id, val) -- Envelope: 
  end 
end

function M.onEnvelopeRotary(ctx, val, idx)
  -- Example: nudge edit cursor by grid
    if idx == 1 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 2 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 3 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 4 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 5 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 6 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 7 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 8 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
end

function M.onEnvelopePad(ctx, idx)
  -- Example: nudge edit cursor by grid
    if idx == 1 then
        r.SetOnlyTrackSelected(ctx.track)    
    end
    if idx == 2 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 3 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 4 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 5 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 6 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 7 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
    if idx == 8 then
        r.SetOnlyTrackSelected(ctx.track)  
    end
end

function M.onEnvelopeSlider(ctx, val, idx)
  -- Example: nudge edit cursor by grid
    if idx == 1 then
        --r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
        env = r.GetSelectedEnvelope(0)
        if not env then return end

        count = r.CountEnvelopePoints(env)
        for i = 0, count-1 do
            local retval, time, value, shape, tension, selected = r.GetEnvelopePoint(env, i)
            if selected then
                r.SetEnvelopePoint(env, i, time, 0.75, shape, tension, selected, true)
            end
        end
        r.Envelope_SortPoints(env)
        r.UpdateArrange()
        --r.Main_OnCommand(41987, val) -- Envelope: Set shape: linear
    end
    if idx == 2 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 3 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
    if idx == 4 then
        r.CSurf_OnPanChange(ctx.track, val, false) -- [-1.0, 1.0]Change to midi values
    end
end

return M
