--Blockmanager is required for setting basic Block properties
local blockManager = require("blockManager")

--Create the library table
local atlantisBlock = {}
--BLOCK_ID is dynamic based on the name of the library file
local blockID = BLOCK_ID

--Defines Block config for our Block. You can remove superfluous definitions.
local atlantisBlockSettings = {
	id = blockID,
	-- -1 = left, 1 = right
	floorslope = 0, 
	ceilingslope = 1,
}

--Applies blockID settings
blockManager.setBlockSettings(atlantisBlockSettings)

--Gotta return the library table!
return castleBlock