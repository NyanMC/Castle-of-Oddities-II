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

local outputBlockID = (blockID+1)

local exclamationBlockSettings = {
	id = blockID,

	width = 64,
	height = 64,
	
	frames = 2,
	framespeed = 8,

	bumpable = true,
	smashable = 1,

	outputBlockID = outputBlockID, -- The ID of the block that comes out of this block.
	outputBlockSpeed = 12,         -- How fast any blocks that come out of this block move.

	outTime = 640, -- How long the blocks that come out of this block last before disappearing.
	blinks = 4,    -- How many times the blocks that come out of this block "blink" before disappearing.

	-- The sound effects played at various points. Can be nil for none, a number for a vanilla sound, or a sound effect object/string for a custom sound.
	expandSFX     = SFX.open(Misc.resolveFile("exclamationBlock_expand.wav")),
	blinkSFX      = SFX.open(Misc.resolveFile("exclamationBlock_blink.wav")),
	disappearSFX  = SFX.open(Misc.resolveFile("exclamationBlock_disappear.wav")),
}

blockManager.setBlockSettings(exclamationBlockSettings)

ai.registerSpawner(blockID)

return exclamationBlock