local blockmanager = require("blockmanager")
local chainreaction = require("blocks/ai/chainreaction")
local blockutils = require("blocks/blockutils")
local burning = require("transformation_burning")
local blockID = BLOCK_ID

local block = {}

--[[blockmanager.setBlockSettings({
	id = blockID,
	bumpable = true
})]]--


function block.onPostBlockHit(v)
	if v.id ~= blockID or not burning.isBurning then return end
	blockutils.kirbyDetonate(v, chainreaction.getIDList())
end

function block.onInitAPI()
    registerEvent(block, "onPostBlockHit")
end

chainreaction.register(blockID)

return block