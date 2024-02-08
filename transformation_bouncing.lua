--[[
	Bouncing v1.2 - by "Master" of Disaster
	The Bouncing transformation in the Wario Land series
	
	What you can configurate:
		bouncing.isBouncing = true			-- makes you start bouncing
		bouncing.gfxoffsetX = 12				-- Set the amount of pixels the sprite should be moved to the left (negative values for right) so it plays at the right position
		bouncing.gfxoffsetY = 20				-- Set the amount of pixels the sprite should be moved upwards so it plays at the right height
		bouncing.gfxwidth = 50				-- If your spritesheet needs a higher width than 50px, you can change it here
		bouncing.gfxheight = 50				-- If your spritesheet needs a higher height than 50px, you can change it here
		bouncing.groundbouncingframes = 3	-- If your spritesheet has more or less than 3 frames in the bouncing animation, you can change it here
		bouncing.airbouncingframes = 5		-- If your spritesheet has more or less than 5 frames in the high bouncing animation, you can change it here
		bouncing.bouncingendframes = 4		-- If your spritesheet has more or less than 4 frames in the ending animation, you can change it here
		
		bouncing.addBouncingStarterNPC(id)		-- add an NPC that starts the bouncing rush when touched
		bouncing.addBouncingStarterBlock(id)		-- add a Block that starts the bouncing rush when touched

		bouncing.addBreakableBlock(id)		-- add a Block that breaks when fully bouncing and touching it
		bouncing.addUnbreakableBlock(id)	-- add a Block that can't break by bouncing from beneath
		
	Credit is appreciated, after all you are probably a nice person that doesn't want to do plagriarism
]]--

local bouncing = {
isBouncing = false,	-- if set to true, the character starts to bounce
stage = 0,			-- 0: ground bouncing. 1: high air bouncing. 2: bounce end
gfxoffsetX = 0,
gfxoffsetY = 47,
gfxwidth = 50,
gfxheight = 50,
groundbouncingframes = 3,
airbouncingframes = 5,
bouncingendframes = 4,

}

bouncingstarterNPC = {}

bouncingstarterblock = {}

breakableBlock = {802}		-- default block: Bouncebreaking Block (that does the chain reaction)

unbreakableBlock = {}

function bouncing.addBouncingStarterNPC(id)
	table.insert(bouncingstarterNPC, id)
end

function bouncing.addBouncingStarterBlock(id)
	table.insert(bouncingstarterblock, id)
end

function bouncing.addBreakableBlock(id)
	table.insert(breakableBlock, id)
end

function bouncing.addUnbreakableBlock(id)
	table.insert(unbreakableBlock, id)
end

local particles = require("particles")
local BounceTrail = particles.Emitter(0, 0, Misc.resolveFile('particles_bouncetrail.ini'))

local bounceCollider = Colliders.Box(0, 0, 1, 1, 0)
local startCollider = Colliders.Rect(0, 0, 1, 1, 0)

local bouncingsprites = Graphics.loadImageResolved("bouncingframes.png")
local frame = 0		-- the current frame of the animation
local bouncetimer = 0	-- counts up every frame
--local bouncecycle = {0,1,2,1}
--local bouncecycle2 = {0,1,3}
local proceedToNextPhase = false
local direction = 1	-- stays at 1 until the last stage; then it depends on player speed
local hitCeiling = false	-- if the player hit the ceiling after a high bounce
local speedMultiplier = 0	-- so the player bounces up faster at the start before moving in a constant speed
local holdTimer = 0			-- a timer that counts up when the player holds jump when charging a super jump
local smallBouncesound = Misc.resolveFile("nsmbwiiSpringBoard1.wav")
local highBouncesound = Misc.resolveFile("nsmbwiiSpringBoard2.wav")
local isRegistered = false
local i = 0					-- index for registered players
Bounceplayers = {}
CurrentBounceRegister = {}

local function blockFilter(o)
    if not (o.isHidden or not Block.SOLID_MAP[o.id]) or Block.SLOPE_MAP[o.id] then
        return true
    end
end

local function StopBounce() return (
	player:mem(0x36,FIELD_BOOL)	or			-- In water
	player:mem(0x06,FIELD_BOOL)	or			-- in quicksand
	player:mem(0x13C, FIELD_BOOL) or		-- not alive
	player.deathTimer > 0 or				-- dying
	Level.winState() > 0 or					-- winning a level
	player.y <= camera.y - 64				-- at the top of the screen

) end

registerEvent(bouncing,"onStart")
registerEvent(bouncing,"onTick")
registerEvent(bouncing,"onDraw")
registerEvent(bouncing,"onTickEnd")
registerEvent(bouncing,"onPlayerHarm")

function bouncing.whitelistCharacter(character,spritesheet,gfxoffsetY,groundbouncingframes,airbouncingframes,bouncingendframes)
	local whitelistedBounceCharacter = {}
	whitelistedBounceCharacter.character = character
	whitelistedBounceCharacter.spritesheet = Graphics.loadImageResolved(spritesheet)
	if not gfxoffsetY == nil then
		whitelistedBounceCharacter.gfxoffsetY = gfxoffsetY				-- sets your given one (if provided)
	else
		whitelistedBounceCharacter.gfxoffsetY = bouncing.gfxoffsetY	-- sets the default otherwise
	end
	if not groundbouncingframes == nil then
		whitelistedBounceCharacter.groundbouncingframes = groundbouncingframes				-- sets your given one (if provided)
	else
		whitelistedBounceCharacter.groundbouncingframes = bouncing.groundbouncingframes	-- sets the default otherwise
	end
	if not airbouncingframes == nil then
		whitelistedBounceCharacter.airbouncingframes = airbouncingframes				-- sets your given one (if provided)
	else
		whitelistedBounceCharacter.airbouncingframes = bouncing.airbouncingframes	-- sets the default otherwise
	end
	if not bouncingendframes == nil then
		whitelistedBounceCharacter.bouncingendframes = bouncingendframes				-- sets your given one (if provided)
	else
		whitelistedBounceCharacter.bouncingendframes = bouncing.bouncingendframes	-- sets the default otherwise
	end
	table.insert(Bounceplayers, whitelistedBounceCharacter)
end

function bouncing.onStart()
	BounceTrail:attach(player)
end

function bouncing.onTickEnd()
		bounceCollider.width = player.width
        bounceCollider.height = player.height - 4
        bounceCollider.x = player.x
        bounceCollider.y = player.y - 12
		--bounceCollider:debug(true)
		
		startCollider.width = player.width + 8
        startCollider.height = player.height + 8
        startCollider.x = player.x + (player.width / 2)
        startCollider.y = player.y + (player.height/ 2)
		--startCollider:debug(true)
end

function bouncing.onTick()

	if not (table.maxn(Bounceplayers) == 0) then		-- checks if the given player is allowed to bounce
		if (CurrentBounceRegister == {}) then
			CurrentBounceRegister = Bounceplayers[i]
		else
			if player.character == CurrentBounceRegister.character then
				isRegistered = true
			else
				if not (table.maxn(Bounceplayers) <= i) then
					i = i + 1
					CurrentBounceRegister = Bounceplayers[i]
					
				else
					i = 0
					isRegistered = false
				end
			end
		end
	end
	
	if bouncing.isBouncing then
		player.keys.down = false	-- so the player can't crouch
		--player.keys.altRun = false	-- so the player can't statue or shoulderbash -- but i WANT the player to shoulderbash
		player.keys.up = false		-- no climbing
		if player.holdingNPC then
			player.keys.run = false
		end
		if bouncing.stage == 0 then
				if not ((player:isOnGround() or player:mem(0x176,FIELD_WORD) ~= 0 or player.speedY == -0) and player.keys.jump == KEYS_PRESSED) then		-- normal bounce cycle
					if (frame < CurrentBounceRegister.groundbouncingframes - 1) and (bouncetimer >= 6) and not player:isOnGround() then
						frame = frame + 1
						if (proceedToNextPhase) and (frame == CurrentBounceRegister.groundbouncingframes - 1) then	-- actually start the high bounce
							frame = CurrentBounceRegister.groundbouncingframes
							SFX.play(highBouncesound)
							player:mem(0x176,FIELD_WORD,0)	-- necessary so the player isn't stuck on a solid npc (act like the player was not on a solid npc)
							player.speedY = -9
							holdTimer = 0
							speedMultiplier = 40
						end
						bouncetimer = 0
					elseif (frame < CurrentBounceRegister.groundbouncingframes - 1) and (bouncetimer >= 6) and player:isOnGround() then
						if frame == 1 then
							frame = 0
							bouncetimer = 0
						elseif frame == 0 then
							frame = 1
							bouncetimer = 0
							player:mem(0x176,FIELD_WORD,0)	-- necessary so the player isn't stuck on a solid npc (act like the player was not on a solid npc)
							player.speedY = -9
							SFX.play(smallBouncesound)
						end
					elseif (frame == CurrentBounceRegister.groundbouncingframes) and (bouncetimer >= 6) then
						bouncing.stage = 1
					else
						bouncetimer = bouncetimer + 1
						if player:isOnGround() and not prevGround then
							frame = 1
							player.speedX = 0
							bouncetimer = 4
						end
					end
				else			-- start to initiate the high bounce!
					player:mem(0x11C,FIELD_WORD,0)	-- make the player stop jumping
					frame = 0
					player:mem(0x176,FIELD_WORD,0)	-- necessary so the player isn't stuck on a solid npc (act like the player was not on a solid npc)
					player.speedY = 5
					player.keys.left = false
					player.keys.right = false
					if not (holdTimer > 30) then
						bouncetimer = 0
						proceedToNextPhase = true
						player.keys.jump = false
						holdTimer = holdTimer + 1	-- count the timer up until it reaches a certain point, then initiate the jump nethertheless
					end
				end
				if player:isOnGround() and proceedToNextPhase and not hitCeiling then
					player.speedX = 0
				elseif player:isOnGround() and hitCeiling then	-- if the player is actually falling down again (and hitting the ground)
					player:mem(0x176,FIELD_WORD,0)
					player.speedY = -8
					player.speedX = player.direction * 3
					bouncing.stage = 2		-- start the little end bounce
					SFX.play(smallBouncesound)
				end
		elseif bouncing.stage == 1 then
			if speedMultiplier > 0 then
				player.speedY = -9 - speedMultiplier * 0.05 -- start to move up faster
				speedMultiplier = speedMultiplier - 1
			else
			player.speedY = -9	-- then end up at speed of 9 upwards
			end
			for p, b in ipairs(Colliders.getColliding{a = bounceCollider, btype = Colliders.BLOCK, filter = blockFilter}) do        -- check if it is really a slope hit
				if ((Block.MEGA_SMASH_MAP[b.id]) or (table.contains(breakableBlock,b.id))) and not (table.contains(unbreakableBlock,b.id)) then
					b:remove(true)
				elseif not ((Block.MEGA_SMASH_MAP[b.id]) or (table.contains(breakableBlock,b.id))) and not (table.contains(unbreakableBlock,b.id)) then
					bouncing.stage = 0		-- fall down again
					proceedToNextPhase = false
					hitCeiling = true		-- if you hit the ground, you'll now bounce and end the squish
					Defines.earthquake = 5
					frame = 0
				end
					b:hit()
			end
			for p, v in ipairs(Colliders.getColliding{a = bounceCollider, btype = Colliders.NPC}) do        -- hitting solid npcs stops the bounce as well
				if NPC.PLAYERSOLID_MAP[v.id] then
					bouncing.stage = 0		-- fall down again
					proceedToNextPhase = false
					hitCeiling = true		-- if you hit the ground, you'll now bounce and end the squish
					Defines.earthquake = 5
					frame = 0
				end
			end
			if (frame < CurrentBounceRegister.airbouncingframes - 1) and bouncetimer >= 3 then
				frame = frame + 1
				BounceTrail:setParam("speedX",player.speedX)
				BounceTrail:Emit(1)
				bouncetimer = 0
			elseif (frame >= CurrentBounceRegister.airbouncingframes - 1) and bouncetimer >= 3 then
				frame = 0
				BounceTrail:setParam("speedX",player.speedX)
				BounceTrail:Emit(1)
				bouncetimer = 0
			else
				bouncetimer = bouncetimer + 1
			end
			if (player:mem(0x14A,FIELD_WORD) == 2) or (player.speedY == -0.01) then	-- hit a ceiling
				bouncing.stage = 0		-- fall down again
				proceedToNextPhase = false
				hitCeiling = true		-- if you hit the ground, you'll now bounce and end the squish
				Defines.earthquake = 5
				frame = 0
			--	player.speedX = - player.direction * 3
			end
		elseif bouncing.stage == 2 then
			player.keys.left = false	-- no control
			player.keys.right = false
			if (frame < CurrentBounceRegister.bouncingendframes - 1) and (bouncetimer >= 8) then
				frame = frame + 1
				bouncetimer = 0
			else
				bouncetimer = bouncetimer + 1
			end
			if player.speedX > 0 then
				direction = 1
			else
				direction = -1
			end
			if player:isOnGround() and not hitCeiling then
				proceedToNextPhase = false
				hitCeiling = false
				frame = 0
				bouncing.stage = 0
				bouncetimer = 0
				direction = 1
				bouncing.isBouncing = false
				player:mem(0x140,FIELD_WORD,50)	-- 50 I frames
			else
				hitCeiling = false
			end
		end
		if StopBounce() then		-- if the player meets a condition to stop bouncing
			proceedToNextPhase = false
			hitCeiling = false
			frame = 0
			bouncing.stage = 0
			bouncetimer = 0
			direction = 1
			bouncing.isBouncing = false
			player:mem(0x140,FIELD_WORD,50)	-- 50 I frames
		end
	end
	prevGround = player:isOnGround()
	if not bouncing.isBouncing and not (player:mem(0x140,FIELD_WORD) > 0) and isRegistered then	-- start the bounce
		for p,n in ipairs(Colliders.getColliding{atype = Colliders.NPC, b = startCollider, filter = function(o) if not o.friendly and not o.isHidden and (table.contains(bouncingstarterNPC,o.id)) then return true end end}) do
			bouncing.isBouncing = true
			n.speedY = -6
			player:mem(0x11C,FIELD_WORD,0)	-- make the player stop jumping
			player.speedY = 5
			SFX.play(9)
		end
		for p,b in ipairs(Colliders.getColliding{a = startCollider, btype = Colliders.BLOCK, filter = function(o) if (table.contains(bouncingstarterblock,o.id)) then return true end end}) do
			bouncing.isBouncing = true
			player.speedY = 5
			player:mem(0x11C,FIELD_WORD,0)	-- make the player stop jumping
			SFX.play(9)
		end
	end
end

function bouncing.onPlayerHarm(event,player)
	if event.cancelled or not isRegistered then return end
		for p,n in ipairs(Colliders.getColliding{atype = Colliders.NPC, b = startCollider, filter = function(o) if not o.friendly and not o.isHidden and (table.contains(bouncingstarterNPC,o.id)) then return true end end}) do
               bouncing.isBouncing = true
			   event.cancelled = true
			   n.speedY = -6
			   player:mem(0x11C,FIELD_WORD,0)	-- make the player stop jumping
			   player.speedY = 5
			   SFX.play(9)
		end
		for p,b in ipairs(Colliders.getColliding{a = startCollider, btype = Colliders.BLOCK, filter = function(o) if (table.contains(bouncingstarterblock,o.id)) then return true end end}) do
               bouncing.isBouncing = true
			   event.cancelled = true
			   player.speedY = 5
			   SFX.play(9)
		end
end

function bouncing.onDraw()
	if bouncing.isBouncing then
		BounceTrail:draw(-30)
		player:setFrame(-50)
		Graphics.drawBox{
			texture      = CurrentBounceRegister.spritesheet,
			sceneCoords  = true,
			x            = player.x + (player.width / 2) - bouncing.gfxoffsetX * player.direction,
			y            = player.y + (player.height) - CurrentBounceRegister.gfxoffsetY,
			width        = bouncing.gfxwidth * 2 * direction,
			height       = bouncing.gfxheight * 2,
			sourceX      = bouncing.gfxwidth * (player.powerup - 1) * 3 + bouncing.gfxwidth * bouncing.stage,
			sourceY      = bouncing.gfxheight * frame,
			sourceWidth  = bouncing.gfxwidth,
			sourceHeight = bouncing.gfxheight,
			centered     = true,
			priority     = -25,
			color        = Color.white .. 1,--playerOpacity,
			rotation     = 0,
		}
	end
end

function bouncing.abort() -- added by chromanyan, stop a bounce NOW without granting iframes
	proceedToNextPhase = false
	hitCeiling = false
	frame = 0
	bouncing.stage = 0
	bouncetimer = 0
	direction = 1
	bouncing.isBouncing = false
end



return bouncing