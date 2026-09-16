require("hs.ipc")
hs.autoLaunch(true)
hs.dockIcon(false)
hs.accessibilityState(true)

local focusScript = os.getenv("HOME") .. "/.claude/hooks/claude-focus-last.sh"
local tapWindow = 0.6
local taps = 0
local lastTap = 0
local types = hs.eventtap.event.types

shiftTripleTap = hs.eventtap.new({ types.flagsChanged, types.keyDown }, function(event)
  if event:getType() == types.keyDown then
    taps = 0
    return false
  end
  local flags = event:getFlags()
  local shiftSolo = flags.shift and not (flags.cmd or flags.alt or flags.ctrl or flags.fn)
  if shiftSolo then
    local now = hs.timer.secondsSinceEpoch()
    if now - lastTap > tapWindow then taps = 0 end
    taps = taps + 1
    lastTap = now
    if taps >= 3 then
      taps = 0
      hs.task.new(focusScript, nil):start()
    end
  elseif next(flags) ~= nil then
    taps = 0
  end
  return false
end)
shiftTripleTap:start()

local props = hs.eventtap.event.properties
local sideButtons = { [3] = true, [4] = true }
local chordWindow = 0.08
local replayMarker = 0x4D43
local replayGap = 0.01
local pendingSide = nil
local chordUpsToSwallow = {}

local function replay(event)
  event:setProperty(props.eventSourceUserData, replayMarker)
  event:post()
end

local function holdSideButton(button, event)
  local entry = { button = button, event = event }
  entry.timer = hs.timer.doAfter(chordWindow, function()
    if pendingSide == entry then pendingSide = nil end
    replay(event)
  end)
  pendingSide = entry
end

local function releasePending()
  local entry = pendingSide
  pendingSide = nil
  entry.timer:stop()
  return entry.event
end

sideButtonChord = hs.eventtap.new({ types.otherMouseDown, types.otherMouseUp }, function(event)
  if event:getProperty(props.eventSourceUserData) == replayMarker then return false end

  local button = event:getProperty(props.mouseEventButtonNumber)
  if not sideButtons[button] then return false end

  if event:getType() == types.otherMouseDown then
    if pendingSide and pendingSide.button ~= button then
      releasePending()
      chordUpsToSwallow = { [3] = true, [4] = true }
      hs.spaces.toggleMissionControl()
      return true
    end
    if pendingSide then replay(releasePending()) end
    holdSideButton(button, event:copy())
    return true
  end

  if chordUpsToSwallow[button] then
    chordUpsToSwallow[button] = nil
    return true
  end

  if pendingSide and pendingSide.button == button then
    replay(releasePending())
    local pressUp = event:copy()
    hs.timer.doAfter(replayGap, function() replay(pressUp) end)
    return true
  end

  return false
end)
sideButtonChord:start()
