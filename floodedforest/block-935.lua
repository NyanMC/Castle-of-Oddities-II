--[[

	Written by MrDoubleA
	Please give credit!

	Graphics from Sednaiur's SMW Expanded graphics pack

	Part of MrDoubleA's NPC Pack

]]

local blockManager = require("blockManager")
local ai = require("exclamationBlock_ai")

local exclamationBlock = {}
local blockID = BLOCK_ID

local exclamationBlockSettings = {
	id = blockID,

	width = 64,
	height = 64,
	
	frames = 1,
	framespeed = 8,
}

blockManager.setBlockSettings(exclamationBlockSettings)

return exclamationBlock