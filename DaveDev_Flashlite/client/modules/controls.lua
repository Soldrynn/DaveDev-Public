local Client = DaveDevFlashliteClient
local K = Client.constants

local DISABLES = {
  { 0, 24 },
  { 0, 25 },
  { 0, K.FOLLOW_CONTROL },
  { 0, 44 },
  { 0, 140 },
  { 0, 141 },
  { 0, 142 },
  { 0, 37 },
  { 0, 45 },
  { 0, 289 },
}

function Client.setControlsDisabled(on)
  if not on then return end
  for i = 1, #DISABLES do
    DisableControlAction(DISABLES[i][1], DISABLES[i][2], true)
  end
end
