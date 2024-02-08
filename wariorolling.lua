
--[[

	Wariorolling.lua v1.3 by "Master" of Disaster

	You really want to see this funny Wahh guy roll, right? Then here you go!

	I know, Wario would sell everything as his own but you shouldn't; just credit me if it's used.
	
	How to use: Just have this in your episode/level folder and add in the luna.lua file:
	local warioroll = require("wariorolling")
	
	You can also access these variables:
	warioroll.rollingstate = [true / false]				-- you can externally start or stop the roll
	warioroll.hitboxheight = [height of your player]	-- if you are using another costume, you should change the hitbox height to the respective value
	warioroll.canbrake = [true / false]					-- whether the player can brake by holding back while rolling
	warioroll.framecount = [number of frames on rollingframes.png]	-- if you use another costume which rolling animation has more or less than 6 frames, you can change it here to apply that change
	warioroll.gfxoffsetY = [number of pixels] -- if you are using another character (like vanilla Wario), you can enter a custom offset that is added so the graphic is showing on ground
	warioroll.gfxwidth = [width of one spritesheet-sprite] -- the width one frame takes up on a spritesheet, if 50px don't serve you
	warioroll.gfxheight = [height of one spritesheet-sprite] -- the height one frame takes up on a spritesheet, if 50px don't serve you
]]


local spinframes = Graphics.loadImageResolved("rollingframes.png")
local slidetimer = 0		-- timer that counts up until the player starts rolling
local frametimer = 0		-- timer that counts up until it hits a certain point and then changes the animation frame
local frame = 0				-- the frame of the rolling animation
local underceiling = false	-- whether the player is in a small hallway
local waittimer = 0			-- used for underceiling setting
local isRegistered = false	-- whether the character is registered (if not, they are not able to roll)
local i = 0					-- index for registered players
Rollplayers = {}
CurrentRollRegister = {}
playerheight = {}

local rolling = {
rollingstate = false,	-- whether Wario is doing the Bowling ball thingy
canbrake = true,	-- whether Wario can brake when holding back
--hitboxheight = 54,	-- the hitbox the player has when standing; defaults at 54, but can be changed via rolling.hitboxheight = [new hitbox height]
framecount = 6,		-- the amount of frames the rolling animation has; defaults at 6, but can be changed via rolling.framecount = [new frame count]
gfxoffsetY = 8,		-- the amount of pixels the rolling animation is moved to the bottom; use it to configurate it with other characters
gfxwidth = 50,		-- the width of one rolling frame
gfxheight = 50,		-- the height of one rolling frame
}

local rollingCollider = Colliders.Rect(0, 0, 1, 1, 0)	-- A collider that breaks blocks, I know, stunning!
local ceilingCollider = Colliders.Rect(0, 0, 1, 1, 0)	-- A collider that automatically makes the player crouch when below a ceiling

registerEvent(rolling,"onStart")	-- register the events I used
registerEvent(rolling,"onTick")		
registerEvent(rolling,"onTickEnd")
registerEvent(rolling,"onDraw")

local function blockFilter(o)
    if not (o.isHidden or Block.SLOPE_MAP[o.id] or not Block.SOLID_MAP[o.id]) then
        return true
    end
end


function rolling.whitelistCharacter(character,spritesheet,gfxoffsetY,framecount)
	local whitelistedRollCharacter = {}
	whitelistedRollCharacter.character = character
	whitelistedRollCharacter.spritesheet = Graphics.loadImageResolved(spritesheet)
	if not gfxoffsetY == nil then
		whitelistedRollCharacter.gfxoffsetY = gfxoffsetY				-- sets your given one (if provided)
	else
		whitelistedRollCharacter.gfxoffsetY = rolling.gfxoffsetY	-- sets the default otherwise
	end
	if not framecount == nil then
		whitelistedRollCharacter.framecount = framecount				-- sets your given one (if provided)
	else
		whitelistedRollCharacter.framecount = rolling.framecount	-- sets the default otherwise
	end

	table.insert(Rollplayers, whitelistedRollCharacter)
end

function rolling.onStart()
	for i = 1, 7 do
		local settings = PlayerSettings.get(player.character, i)				-- resize the player's hitbox for all powerups to make them crouch
		playerheight[i] = settings.hitboxHeight
	end
end

function rolling.onTick()

	if not (table.maxn(Rollplayers) == 0) then		-- checks if the given player is allowed to roll
		if (CurrentRollRegister == {}) then
			CurrentRollRegister = Rollplayers[i]
		else
			if player.character == CurrentRollRegister.character then
				isRegistered = true
			else
				if not (table.maxn(Rollplayers) <= i) then
					i = i + 1
					CurrentRollRegister = Rollplayers[i]
					
				else
					i = 0
					isRegistered = false
				end
			end
		end
	end
	
	if isRegistered then		
		if player:isOnGround() and ((player:mem(0x3C,FIELD_BOOL) and not (player:mem(0x48,FIELD_WORD) == 0 or math.abs(player.speedX) < 3)) or rolling.rollingstate) then	-- if sliding and not too slow when on flat ground
			if not player:mem(0x0A,FIELD_BOOL) and not (wariorolling.canbrake and (player.keys.left and player.speedX > 0) or (player.keys.right and player.speedX < 0)) then		-- if the player is not on slippery ice
				player.speedX = player.speedX + 0.1 * player.direction		-- 0.1 is the X speed the player looses per frame when on normal ground
			elseif player:mem(0x0A,FIELD_BOOL) and not (wariorolling.canbrake and (player.keys.left and player.speedX > 0) or (player.keys.right and player.speedX < 0)) then
				player.speedX = player.speedX + 0.025 * player.direction	-- 0.025 is the X speed the player looses per frame when on ice; that's how friction works
			end
			if player.speedX > 0 then	-- make Wario face the direction he is sliding to
				player.direction = 1
			else
				player.direction = -1
			end
		end
		if player:mem(0x3C,FIELD_BOOL) and not (slidetimer > 35) then	-- If Wario is sliding, count up the timer
			slidetimer = slidetimer + 1
		elseif not player:mem(0x3C,FIELD_BOOL) then	-- reset that timer when he stops sliding
			slidetimer = 0
		end
		if (slidetimer >= 35 or (player:mem(0x48,FIELD_WORD) == 0 and player:mem(0x3C,FIELD_BOOL) and player:isOnGround())) and (math.abs(player.speedX) > 3) then		-- That's where the REAL fun begins!
			rolling.rollingstate = true
		end
		if rolling.rollingstate then
			player.keys.left = false
			player.keys.right = false
			player.keys.run = false
			player.keys.altRun = false
			player:mem(0x3C,FIELD_BOOL,true)		-- make him slide constantly!
			player:setFrame(-50)					-- makes him invisible so he can be rendered via lua instead
			local settings = PlayerSettings.get(player.character, player.powerup)				-- resize the player's hitbox for all powerups to make them crouch
			settings.hitboxHeight = 30
			
			for p, n in ipairs(Colliders.getColliding{a = rollingCollider, btype = Colliders.BLOCK, filter = blockFilter}) do			-- A collider that breaks blocks!
				if Block.MEGA_SMASH_MAP[n.id] then
					n:remove(true)
				end
				n:hit(2)
			end
			for p, v in ipairs(Colliders.getColliding{a = rollingCollider, btype = Colliders.NPC}) do			-- A collider that breaks blocks!
				if NPC.HITTABLE_MAP[v.id] then
					v:harm(3)
				end
			end
			
			if frametimer < 12 then					-- play the animation
				frametimer = frametimer + math.abs(player.speedX)
			elseif frametimer >= 12 then
				if (frame < CurrentRollRegister.framecount - 1) then
					frame = frame + 1
				else
					frame = 0
				end
				frametimer = 0
			end
			
			if (player:mem(0x14C,FIELD_WORD) == 2) or (player:mem(0x148,FIELD_WORD) == 2) then		-- if Wario hits a wall
				rolling.rollingstate = false
				if underceiling then
					player:mem(0x3C,FIELD_BOOL,false)	-- stop the slide
					player.keys.down = true
				else
					player.speedY = -6
				end
				player.speedX = player.direction * -2	-- bounce Wario back a bit
				Audio.playSFX(37)		-- *WHOMP NOISE*
				Defines.earthquake = 3	-- littl Earthquake
				for i = 1, 7 do
					local settings = PlayerSettings.get(player.character, i)				-- resize the player's hitbox for all powerups to make them crouch
					settings.hitboxHeight = playerheight[i]
				end
			end
			if (player:mem(0x48,FIELD_WORD) == 0) and (math.abs(player.speedX) < 3) then
				rolling.rollingstate = false
				for i = 1, 7 do
					local settings = PlayerSettings.get(player.character, i)				-- resize the player's hitbox for all powerups to the default
					settings.hitboxHeight = playerheight[i]
				end
			end
			for p, n in ipairs(Colliders.getColliding{a = ceilingCollider, btype = Colliders.BLOCK, filter = blockFilter}) do			-- A collider that breaks blocks!
				underceiling = true
				waittimer = 5
			end
		end
	end
end

function rolling.onTickEnd()
		rollingCollider.width = player.width + 26
        rollingCollider.height = player.height - 2
        rollingCollider.x = player.x + (player.width / 2)
        rollingCollider.y = player.y + (player.height / 2)
		
		ceilingCollider.width = player.width - 4
        ceilingCollider.height = player.height - 8
        ceilingCollider.x = player.x + (player.width / 2)
        ceilingCollider.y = player.y + (player.height / 2) - 16
		--ceilingCollider:debug(true)
		
	if underceiling then
		if waittimer > 0 then
			waittimer = waittimer - 1
		else
			underceiling = false
		end
	end
end

function rolling.onDraw()
	if rolling.rollingstate then
		Graphics.drawBox{
			texture      = CurrentRollRegister.spritesheet,
			sceneCoords  = true,
			x            = player.x + (player.width / 2),
			y            = player.y + (player.height / 2) - CurrentRollRegister.gfxoffsetY,
			width        = rolling.gfxwidth * 2 * player.direction,
			height       = rolling.gfxheight * 2,
			sourceX      = 0 + rolling.gfxwidth * (player.powerup - 1),
			sourceY      = 0 + rolling.gfxheight * frame,
			sourceWidth  = rolling.gfxwidth,
			sourceHeight = rolling.gfxheight,
			centered     = true,
			priority     = -25,
			color        = Color.white .. 1,--playerOpacity,
			rotation     = 0,
		}
	end
end

return rolling