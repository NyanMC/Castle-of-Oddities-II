local blockmanager = require("blockmanager")
local chainreaction = require("blocks/ai/chainreaction")
local blockutils = require("blocks/blockutils")
local dashattacking = require("wariodashattacking")
local blockID = BLOCK_ID

local block = {}

blockmanager.setBlockSettings({
	id = blockID,
	bumpable = true,
	smashable = 1
})


function block.onPostBlockHit(v)
	if v.id ~= blockID or not dashattacking.dashattacking then return end
	blockutils.kirbyDetonate(v, chainreaction.getIDList())
	v:remove(true)
end

function block.onInitAPI()
    registerEvent(block, "onPostBlockHit")
end

chainreaction.register(blockID)

return block