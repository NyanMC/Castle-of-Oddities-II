--[[

  Wariodashing.lua v1.2 by "Master" of Disaster
  
  So I got bored and thought "yeah I might as well just do this"
  And now you have Wario's signature shoulderbash!!

  Wario would sell stuff others as his own (he probably did multiple times now), don't be like Wario. Credit me instead
  
]]--

local wariodashing = {
dash = false, 		-- whether Wario is shoulderbashing
canairdash = true,	-- set false to make him unable to perform the shoulderbash in the air
cooldown = 0,		-- counts down to 0; if higher than 0 the player is not able to dash
gfxoffsetY = 8, 	-- the default amount of pixels the graphic is rendered below the place it actually would; used so it can actually be renderered on grounded
gfxwidth = 50,		-- the width one frame takes up on a spritesheet
gfxheight = 50, 	-- the height one frame takes up on a spritesheet
groundframes = 4, 	-- the default amount of frames the ground dashing animation has
airframes = 3,		-- the default amount of frames the air dashing animation has
acceleration = 7,	-- the speed the player gains when shoulderbashing
}

function wariodashing.whitelistCharacter(character,spritesheet,gfxoffsetY,groundframes,airframes)
	local whitelistedCharacter = {}
	whitelistedCharacter.character = character
	whitelistedCharacter.spritesheet = Graphics.loadImageResolved(spritesheet)
	if not gfxoffsetY == nil then
		whitelistedCharacter.gfxoffsetY = gfxoffsetY				-- sets your given one (if provided)
	else
		whitelistedCharacter.gfxoffsetY = wariodashing.gfxoffsetY	-- sets the default otherwise
	end
	if not groundframes == nil then
		whitelistedCharacter.groundframes = groundframes				-- sets your given one (if provided)
	else
		whitelistedCharacter.groundframes = wariodashing.groundframes	-- sets the default otherwise
	end
	if not airframes == nil then
		whitelistedCharacter.airframes = airframes				-- sets your given one (if provided)
	else
		whitelistedCharacter.airframes = wariodashing.airframes	-- sets the default otherwise
	end
	table.insert(players, whitelistedCharacter)
end

function wariodashing.blacklistBlock(id)	-- put in your luna.lua file wariodashing.blacklistBlock(id) and it puts the id you inserted into the blacklist!
	table.insert(blacklistedBlocks , id)
end

function wariodashing.whitelistBlock(id)	-- put in your luna.lua file wariodashing.whitelistBlock(id) and it puts the id you inserted into the whitelist!
	table.insert(whitelistedBlocks , id)
end

function wariodashing.whitelistNPC(id)	-- put in your luna.lua file wariodashing.whitelistNPC(id) and it puts the id you inserted into the whitelist!
	table.insert(whitelistedNPCs , id)
end

function wariodashing.blacklistNPC(id)
	table.insert(blacklistedNPCs, id)
end

function wariodashing.whitelistFrontHitNPC(id)
	table.insert(fronthittableNPCs, id)
end

function wariodashing.whitelistBackHitNPC(id)
	table.insert(backhittableNPCs, id)
end

blacklistedBlocks = {		-- list of all block ids that should not be broken by a dash, regardless of Smash Map

}

whitelistedBlocks = {		-- list of all block ids that should be broken, even though they can't be broken by the player

}

whitelistedNPCs = {		-- list of all npc ids that should be hit by a shoulder bash

}

blacklistedNPCs = {		-- list of all npc ids that can't be hit by a shoulder bash, even though they should

}

fronthittableNPCs = {	-- list of all npc ids that can only be bashed from the front

}

backhittableNPCs = {	-- list of all npc ids that can only be bashed from behind
	623,		-- default npcs: snailicorns
	624
}

players = {

}

local dashingColliderNPC = Colliders.Rect(0, 0, 1, 1, 0)
--dashingColliderNPC:debug(true)
local dashingColliderBlock = Colliders.Rect(0, 0, 1, 1, 0)


local bashtimer = 0		-- counting down until the shoulderbash expires
local usedinair = false	-- whether the player has already used the air dash; prevents him from doing it twice
local dashdirection = 0 -- the direction the player is dashing into; used to detect when he turns around (which stops the dash)
local dashSFX = Misc.resolveFile("dive.ogg")
local hitwallSFX = Misc.resolveFile("Wario_landonenemy.wav")
local dashframes = Graphics.loadImageResolved("shoulderbashingframes.png")
local wariorolling = require("wariorolling")
local burning = require("transformation_burning")
local bouncing = require("transformation_bouncing")
local inair = 0		-- if the player is in the air while dashing; used for the graphics
local frame = 0		-- the frame of the dashing animation
local frametimer = 0	-- a timer that counts up so the animation can go on
local isRegistered = false	-- is true when the current player character is whitelisted
local i = 0
local CurrentRegister = {}

registerEvent(wariodashing,"onStart")
registerEvent(wariodashing,"onTick")		-- register the events I used
registerEvent(wariodashing,"onTickEnd")
registerEvent(wariodashing,"onDraw")

local function canDash() return (
			not player:mem(0x50,FIELD_BOOL) and 		-- spinjumping
			--not player:mem(0x36,FIELD_BOOL)	and			-- In water
			not player:mem(0x06,FIELD_BOOL)	and			-- in quicksand
			not (player:mem(0x40,FIELD_WORD) > 0)	and		-- Climbing
			not player:mem(0x44, FIELD_BOOL) and		-- Riding a rainbow shell
			not player:mem(0x13C, FIELD_BOOL) and 		-- not alive
			not player.holdingNPC and
			not player.isMega and
			not player.keys.down and					-- not holding down
			not wariorolling.rollingstate and			-- not rolling
			not wariodashing.dash and					-- already dashing
			not (wariodashing.cooldown > 0) and			-- on a cooldown
			not player:mem(0x3C,FIELD_BOOL) and			-- sliding
			not burning.isBurning and					-- not burning
			--not bouncing.isBouncing and					-- not bouncing
			player.deathTimer == 0 and
			Level.winState() == 0 and
			isRegistered and								-- if the player is registered to be able to do a shoulderbash
			player.forcedState == 0
	) end

local function blockFilter(o)
    if not (o.isHidden or Block.SLOPE_MAP[o.id] or not Block.SOLID_MAP[o.id]) then
        return true
    end
end

function wariodashing.onStart()
	defaultrunspeed = Defines.player_runspeed
end

function wariodashing.onTickEnd()
		dashingColliderNPC.width = player.width + 12
        dashingColliderNPC.height = player.height - 8
        dashingColliderNPC.x = player.x + (player.width / 2) + player.direction * 16
        dashingColliderNPC.y = player.y + (player.height / 2) - 8
		
		dashingColliderBlock.width = player.width + 8
        dashingColliderBlock.height = player.height - 16
        dashingColliderBlock.x = player.x + (player.width / 2) + player.direction * 16
        dashingColliderBlock.y = player.y + (player.height / 2) - 8
end

function wariodashing.onTick()

	if not (table.maxn(players) == nil) then		-- checks if the given player is allowed to shoulderbash
		if (CurrentRegister == {}) then
			CurrentRegister = players[i]
		else
			if player.character == CurrentRegister.character then
				isRegistered = true
			else
				if not (table.maxn(players) <= i) then
					i = i + 1
					CurrentRegister = players[i]
					
				else
					i = 0
					isRegistered = false
				end
			end
		end
	end
	
	
	if player.keys.altRun == KEYS_PRESSED and canDash() and not (usedinair) and
	not (wariodashing.cooldown > 0) then
		wariodashing.dash = true
		bashtimer = 30
		if bouncing.isBouncing then -- chromanyan - abort any bouncing when initiating a shoulder bash
			bouncing.abort()
		end
	end
	if wariodashing.dash then					-- do the dashing code
		if bashtimer == 30 then
				if player:isOnGround() then		-- grounded dash
					if player.speedX * player.direction >= 10 - wariodashing.acceleration then
						player.speedX = 10 * player.direction
						Defines.player_runspeed = 10
					else
						Defines.player_runspeed = math.abs( 0.5 * player.speedX + 0.5 * math.abs(player.speedX) * player.direction + wariodashing.acceleration * player.direction)
						player.speedX = 0.5 * player.speedX + 0.5 * math.abs(player.speedX) * player.direction + wariodashing.acceleration * player.direction
					end
					SFX.play(dashSFX)
					dashdirection = player.direction
				elseif not player:isOnGround() and wariodashing.canairdash then					-- midair dash
					if player:mem(0x36,FIELD_BOOL) then -- are we underwater?
						player.speedY = -1 -- gives roughly enough height to just barely counter gravity
						player.speedX = 10 * player.direction
					else
						player.speedY = -7
						player.speedX = 6 * player.direction
					end
					Defines.player_runspeed = defaultrunspeed
					usedinair = true
					dashdirection = player.direction
					SFX.play(dashSFX)
					local dasheffect = Effect.spawn(10,player)
					dasheffect.speedY = 2
					dasheffect.speedX = -1.5 * player.direction
				end
				player.keys.run = false
				Defines.player_runspeed = defaultrunspeed + 4 * bashtimer / 30	-- so he can run faster
		end
		if (bashtimer > 0) then		-- frame stuff and speed stuff
			bashtimer = bashtimer - 1
			Defines.player_runspeed = defaultrunspeed + 4 * bashtimer / 30		-- sets the max speed the player is able to run; necessary as it's higher than the base speed
		end
		if (bashtimer == 0) or (player:mem(0x3C,FIELD_BOOL)) or (player:mem(0x40,FIELD_WORD) > 0) or (dashdirection ~= player.direction) or (player.keys.down) then	-- if the timer is 0, Wario is sliding, climbing, turning around or ducking
			Defines.player_runspeed = defaultrunspeed
			wariodashing.dash = false
			bashtimer = 0
		end
	
		
		if player:isOnGround() then			-- plays the ground animation
			inair = 0						-- the player is not in the air (note for the animation, hence it's in integer values)
			if (frame < CurrentRegister.groundframes - 1) and frametimer > 1 then	-- go up one frame
				frame = frame + 1
				frametimer = 0
			elseif (frame >= CurrentRegister.groundframes - 1) and frametimer > 1 then	-- get back to default frame
				frame = 0
				frametimer = 0
			elseif frametimer <= 1 then
				frametimer = frametimer + 1								-- counts up the frametimer until it reaches 2, then it gets back to 0
			end
			if frame > CurrentRegister.groundframes - 1 then	-- so the player isn't invisible for a frame when changing from air dash to ground dash in a bad moment (Necessary as the animation for ground and air are varying in length)
				frame = 0												
			end
		else															-- plays the air animation
			inair = 1													-- the player is in the air (note for the animation, hence it's in integer values)
			if (frame < CurrentRegister.airframes - 1) and frametimer > 1 then			-- go up one frame
				frame = frame + 1
				frametimer = 0
			elseif (frame >= CurrentRegister.airframes - 1) and frametimer > 1 then		-- get back to default frame
				frame = 0
				frametimer = 0
			elseif frametimer <= 1 then
				frametimer = frametimer + 1								-- counts up the frametimer until it reaches 2, then it gets back to 0
			end
			if frame > CurrentRegister.airframes - 1 then	-- so the player isn't invisible for a frame when changing from ground dash to air dash in a bad moment (Necessary as the animation for ground and air are varying in length)
				frame = 0
			end
		end
		
		for p, b in ipairs(Colliders.getColliding{a = dashingColliderBlock, btype = Colliders.BLOCK, filter = blockFilter}) do        -- check if it is really a slope hit
			if ((Block.MEGA_SMASH_MAP[b.id]) or (table.contains(whitelistedBlocks,b.id))) and not (table.contains(blacklistedBlocks,b.id)) then
				b:remove(true)
			end
			b:hit()
			SFX.play(hitwallSFX)
			if player:mem(0x36,FIELD_BOOL) then
				player.speedY = -1
			else
				player.speedY = -3
			end
			player.speedX = -4 * player.direction
			Defines.player_runspeed = defaultrunspeed
			bashtimer = 0
			wariodashing.cooldown = 20
			wariodashing.dash = false
			
		end
		for p, v in ipairs(Colliders.getColliding{a = dashingColliderNPC, btype = Colliders.NPC}) do        -- check if it is really a npc that is bashable
			if ((NPC.HITTABLE_MAP[v.id]) or (NPC.MULTIHIT_MAP[v.id]) or (NPC.SHELL_MAP[v.id]) or (table.contains(whitelistedNPCs,v.id))) and not table.contains(blacklistedNPCs,v.id) then
				if ((table.contains(fronthittableNPCs,v.id) and v.direction ~= player.direction) or (table.contains(backhittableNPCs,v.id) and v.direction == player.direction)) or not (table.contains(fronthittableNPCs,v.id) or table.contains(backhittableNPCs,v.id)) then
					if (NPC.HITTABLE_MAP[v.id] or (table.contains(whitelistedNPCs,v.id))) and not NPC.SHELL_MAP[v.id] then
						v:harm(3)
					elseif (NPC.MULTIHIT_MAP[v.id]) then
						v:harm(1)
					elseif (NPC.SHELL_MAP[v.id]) then
						v.speedY = - 4
						v.speedX = player.direction * 6
					end
					if player:mem(0x36,FIELD_BOOL) then
						player.speedY = -1
					else
						player.speedY = -3
					end
					player.speedX = -4 * player.direction
					bashtimer = 0
					wariodashing.cooldown = 20
					Defines.player_runspeed = defaultrunspeed
					SFX.play(hitwallSFX)
					wariodashing.dash = false
				end
			end
		end
		
	end
	if player:isOnGround() or (player:mem(0x40,FIELD_WORD) > 0) or (player:mem(0x36,FIELD_BOOL)) or (player:mem(0x06,FIELD_BOOL)) then	--on ground, climbing or in water or quicksand
		usedinair = false
	end
	if (wariodashing.cooldown > 0) then
		wariodashing.cooldown = wariodashing.cooldown - 1
	end
end

function wariodashing.onDraw()
	if wariodashing.dash then
		player:setFrame(-50)
		Graphics.drawBox{
			texture      = CurrentRegister.spritesheet,
			sceneCoords  = true,
			x            = player.x + (player.width / 2),
			y            = player.y + (player.height / 2) - CurrentRegister.gfxoffsetY,
			width        = wariodashing.gfxwidth * 2 * player.direction,
			height       = wariodashing.gfxheight * 2,
			sourceX      = 0 + wariodashing.gfxwidth * (player.powerup - 1) * 2 + inair * wariodashing.gfxwidth,
			sourceY      = 0 + wariodashing.gfxheight * frame,
			sourceWidth  = wariodashing.gfxwidth,
			sourceHeight = wariodashing.gfxheight,
			centered     = true,
			priority     = -25,
			color        = Color.white .. 1,--playerOpacity,
			rotation     = 0,
		}
	end
end

return wariodashing