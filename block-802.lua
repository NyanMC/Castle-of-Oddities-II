local blockmanager = require("blockmanager")
local chainreaction = require("blocks/ai/chainreaction")
local blockutils = require("blocks/blockutils")
local bouncing = require("transformation_bouncing")
local blockID = BLOCK_ID

local block = {}

--[[blockmanager.setBlockSettings({
	id = blockID,
	bumpable = true
})]]--


function block.onPostBlockHit(v)
	if v.id ~= blockID or not bouncing.isBouncing then return end
	blockutils.kirbyDetonate(v, chainreaction.getIDList())
end

function block.onInitAPI()
    registerEvent(block, "onPostBlockHit")
end

chainreaction.register(blockID)

return block