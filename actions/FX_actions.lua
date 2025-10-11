local r = reaper
local M = {}

-- delta: relative change in pan (e.g. +0.02 = 2%)
function M.NudgePanSelectedTracks(ctx, delta)
  local n = r.CountSelectedTracks(0); if n == 0 then return end
  r.Undo_BeginBlock();-- r.PreventUIRefresh(1)
  for i = 0, n-1 do
    local tr  = r.GetSelectedTrack(0,i)
    local pan = r.GetMediaTrackInfo_Value(tr, "D_PAN") or 0.0
    pan = math.max(-1, math.min(1, pan + (delta*0.01)))
    r.SetMediaTrackInfo_Value(tr, "D_PAN", pan)
  end
  --r.PreventUIRefresh(-1); 
  --r.TrackList_AdjustWindows(false); r.UpdateArrange()
  r.Undo_EndBlock("Nudge pan on selected tracks", -1)
end

local function dB_to_amp(db) return (db <= -150) and 0.0 or 10^(db/20) end

local function SetSelectedTracksVol_dB(db)
  local n = r.CountSelectedTracks(0); if n==0 then return end
  r.Undo_BeginBlock(); 
  for i=0,n-1 do
    local tr = r.GetSelectedTrack(0,i)
    r.SetMediaTrackInfo_Value(tr, "D_VOL", dB_to_amp(db))
  end
  r.Undo_EndBlock(("Set vol to %.2f dB"):format(db), -1)
end

--function M.SetSelectedTrackVolume(ctx, val)
--  local n = r.CountSelectedTracks(0); if n==0 then return end
--  local a = (val/127)*4
--  --r.Undo_BeginBlock(); 
--  for i=0,n-1 do
--    local tr = r.GetSelectedTrack(0,i)
--    r.SetMediaTrackInfo_Value(tr, "D_VOL",a )
--  end
--  --r.Undo_EndBlock(("Set vol to %.2f dB"):format(db), -1)
--end
function M.SetSelectedTrackVolume(ctx, val)
  local max_db = 15
  local min_db = -40
  local t = math.min(127, math.max(0, val))/127
  local db = (min_db or -60) + t * ((max_db or 15) - (min_db or -40))
  SetSelectedTracksVol_dB(db)
end

return M