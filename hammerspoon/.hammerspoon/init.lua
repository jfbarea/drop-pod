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
