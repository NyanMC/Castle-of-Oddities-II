--[[

	Wariodashattacking.lua v1.0 by "Master" of Disaster
  
	My whole philosophy of this pack is literally "yeah I've done X so I might as well..."
	featuring both the version from Wario Land 4 and the cannon version from Shake it

	Wario would sell stuff others as his own (he probably did multiple times now), don't be like Wario. Credit me instead (literally copied from Wariodashing.lua)
  
]]--

local wariodashattacking = {
	dashattacking = false, 	-- whether Wario is dashattacking
	dashstate = 0,			-- if 0, it's not charged; if 1, it's charged; if 2, it's from a cannon
	
	candashattack = true,	-- if false, the player can only use the dash via a cannon
	airbehavior = 1,		-- 0: only chargable on ground, only usable on ground. 1: only chargable on ground, also usable in the air. 2: chargable and usable in the air
	chargeuptime = 60,		-- the time the player needs to charge up the dash
	
	gfxoffsetY = 8, 		-- the default amount of pixels the graphic is rendered below the place it actually would; used so it can actually be renderered on grounded
	gfxwidth = 50,			-- the width one frame takes up on a spritesheet
	gfxheight = 50, 		-- the height one frame takes up on a spritesheet
	runupframes = 4, 		-- the default amount of frames the ground dashing animation has
	chargedframes = 5,		-- the default amount of frames the air dashing animation has
	}
	
	function wariodashattacking.blacklistBlock(id)	-- put in your luna.lua file wariodashattacking.blacklistBlock(id) and it puts the id you inserted into the blacklist!
		table.insert(blacklisteddashBlocks , id)
	end
	
	function wariodashattacking.whitelistBlock(id)	-- put in your luna.lua file wariodashattacking.whitelistBlock(id) and it puts the id you inserted into the whitelist!
		table.insert(whitelisteddashBlocks , id)
	end
	
	function wariodashattacking.whitelistNPC(id)	-- put in your luna.lua file wariodashattacking.whitelistNPC(id) and it puts the id you inserted into the whitelist!
		table.insert(whitelisteddashNPCs , id)
	end
	
	function wariodashattacking.blacklistNPC(id)
		table.insert(blacklisteddashNPCs, id)
	end
	
	function wariodashattacking.whitelistFrontHitNPC(id)
		table.insert(fronthittabledashNPCs, id)
	end
	
	function wariodashattacking.whitelistBackHitNPC(id)
		table.insert(backhittabledashNPCs, id)
	end
	
	blacklisteddashBlocks = {		-- list of all block ids that should not be broken by a dash, regardless of Smash Map
	
	}
	
	whitelisteddashBlocks = {		-- list of all block ids that should be broken, even though they can't be broken by the player
	
	}
	
	whitelisteddashNPCs = {		-- list of all npc ids that should be hit by a shoulder bash
	
	}
	
	blacklisteddashNPCs = {		-- list of all npc ids that can't be hit by a shoulder bash, even though they should
	
	}
	
	fronthittabledashNPCs = {	-- list of all npc ids that can only be bashed from the front
	
	}
	
	backhittabledashNPCs = {	-- list of all npc ids that can only be bashed from behind
		623,		-- default npcs: snailicorns
		624
	}
	
	Dashplayers = {}
	
	local CurrentDashRegister = {}
	
	local dashingColliderNPC = Colliders.Rect(0, 0, 1, 1, 0)
	--dashingColliderNPC:debug(true)
	local dashingColliderBlock = Colliders.Rect(0, 0, 1, 1, 0)
	
	local dashdirection = 0 -- the direction the player is dashing into; used to detect when he turns around
	local dashframes = Graphics.loadImageResolved("dashattackingframes.png")
	local wariorolling = require("wariorolling")
	local wariodashing = require("wariodashing")
	--local wariodashing = require("wariodashing")
	local hitwallSFX = Misc.resolveFile("Wario_landonenemy.wav")
	local chargingtimer = 0	-- counts up until it reaches wariodashattacking.chargeuptime
	local frame = 0		-- the frame of the dashing animation
	local frametimer = 0	-- a timer that counts up so the animation can go on
	local turning = false	-- true if the player is turning around
	local effecttimer = 0	-- counts up until it reaches a threshold, then spawns an afterimage and goes back to 0
	local effectframe = 0	-- 0, 1, 2: normal dash animation. 3: turning around
	local turncounter = 0	-- counts up the amount of frames the player takes to turn around
	local inwater = 0	-- counts down to 0, is higher than 0 when on water. False if not
	local i = 0
	local prevspeed = 0	-- the player's speed of the previous frame; used to fix slope movement jank
	local isRegistered = false
	
	local dashSFX = Misc.resolveFile("Wario_godownpipe.wav")
	registerEvent(wariodashattacking,"onStart")		-- register the events I used
	registerEvent(wariodashattacking,"onTick")		
	registerEvent(wariodashattacking,"onTickEnd")
	registerEvent(wariodashattacking,"onDraw")
	
	function wariodashattacking.whitelistCharacter(character,spritesheet,gfxoffsetY,runupframes,chargedframes)
		local whitelistedDashCharacter = {}
		whitelistedDashCharacter.character = character
		whitelistedDashCharacter.spritesheet = Graphics.loadImageResolved(spritesheet)
		if not gfxoffsetY == nil then
			whitelistedDashCharacter.gfxoffsetY = gfxoffsetY				-- sets your given one (if provided)
		else
			whitelistedDashCharacter.gfxoffsetY = wariodashattacking.gfxoffsetY	-- sets the default otherwise
		end
		if not runupframes == nil then
			whitelistedDashCharacter.runupframes = runupframes				-- sets your given one (if provided)
		else
			whitelistedDashCharacter.runupframes = wariodashattacking.runupframes	-- sets the default otherwise
		end
		if not chargedframes == nil then
			whitelistedDashCharacter.chargedframes = chargedframes				-- sets your given one (if provided)
		else
			whitelistedDashCharacter.chargedframes = wariodashattacking.chargedframes	-- sets the default otherwise
		end
		table.insert(Dashplayers, whitelistedDashCharacter)
	end
	
	local function canStartDash() return (
				not player:mem(0x50,FIELD_BOOL) and 		-- not spinjumping
				not player:mem(0x36,FIELD_BOOL)	and			-- not In water
				not player:mem(0x06,FIELD_BOOL)	and			-- not in quicksand
				not (player:mem(0x40,FIELD_WORD) > 0) and	-- not Climbing
				not player:mem(0x44, FIELD_BOOL) and		-- not Riding a rainbow shell
				not player:mem(0x13C, FIELD_BOOL) and 		-- alive
				not player.holdingNPC and
				not player.isMega and
				not player.keys.down and					-- not holding down
				not wariorolling.rollingstate and			-- not rolling
				not wariodashing.dash and					-- not Shoulderbashing
				--not (wariodashing.cooldown > 0) and			-- not on a cooldown
				not player:mem(0x3C,FIELD_BOOL) and			-- not sliding
				(player:isOnGround() or wariodashattacking.airbehavior == 2) and	-- is on ground or able to start a dash in the air
				player.deathTimer == 0 and
				Level.winState() == 0 and
				player.forcedState == 0 and
				wariodashattacking.candashattack and		-- is allowed to dashattack
				not (wariodashattacking.dashstate > 0) and	-- not already in a charged dash
				math.abs(player.speedX) > 3	and 			-- is fast enough
				isRegistered
		) end
		
	local function canDash() return (
				not player:mem(0x50,FIELD_BOOL) and 		-- not spinjumping
				--not player:mem(0x36,FIELD_BOOL)	and			-- not In water
				--not player:mem(0x06,FIELD_BOOL)	and			-- not in quicksand
				not (player:mem(0x40,FIELD_WORD) > 0) and	-- not Climbing
				not player:mem(0x44, FIELD_BOOL) and		-- not Riding a rainbow shell
				not player:mem(0x13C, FIELD_BOOL) and 		-- alive
				not player.holdingNPC and
				not player.isMega and
				not (player.keys.down and wariodashattacking.dashstate ~= 2) and					-- not holding down
				not wariorolling.rollingstate and			-- not rolling
				not wariodashing.dash and					-- not Shoulderbashing
				--not (wariodashing.cooldown > 0) and			-- not on a cooldown
				not player:mem(0x3C,FIELD_BOOL) and			-- not sliding
				((player:isOnGround() or wariodashattacking.airbehavior ~= 0) or wariodashattacking.dashstate == 2) and	-- is on ground or able to keep the charge in the air or shot from a cannon
				player.deathTimer == 0 and
				Level.winState() == 0 and
				player.forcedState == 0 and
				wariodashattacking.dashstate ~= 0 and	-- charged a dash
				not (player:mem(0x148,FIELD_WORD) == 2) and	-- hits a wall from the left
				not (player:mem(0x14C,FIELD_WORD) == 2) and	-- hits a wall from the right
				(math.abs(player.speedX) > 6 or ((turning or inwater > 0) and wariodashattacking.dashstate == 2))	and				-- is fast enough or turning around when shot out of a cannon
				((wariodashattacking.candashattack and player.keys.altRun == KEYS_DOWN) or wariodashattacking.dashstate == 2) and		-- is allowed to dashattack or comes out of a cannon
				isRegistered
		) end
	
	local function StopDash()
		Defines.player_runspeed = defaultrunspeed		-- reset some variables
		chargingtimer = 0
		wariodashattacking.dashattacking = false
		wariodashattacking.dashstate = 0
		turning = false
		inwater = 0
	end
	
	local function blockFilter(o)
		if not (o.isHidden or Block.SLOPE_MAP[o.id] or not Block.SOLID_MAP[o.id]) then
			return true
		end
	end
	
	function wariodashattacking.onStart()
		defaultrunspeed = Defines.player_runspeed
	end
	
	function wariodashattacking.onTickEnd()
			dashingColliderNPC.width = player.width + 12
			dashingColliderNPC.height = player.height - 8
			dashingColliderNPC.x = player.x + (player.width / 2) + player.direction * 16
			dashingColliderNPC.y = player.y + (player.height / 2) - 8
			
			dashingColliderBlock.width = player.width + 8
			dashingColliderBlock.x = player.x + (player.width / 2) + player.direction * 16
			if player:mem(0x48,FIELD_WORD) == 0 then -- not on a slope. No weird collision stuff to worry about!
				dashingColliderBlock.height = player.height + 2
				dashingColliderBlock.y = player.y + (player.height / 2) - 3
			else
				dashingColliderBlock.height = player.height - 6
				dashingColliderBlock.y = player.y + (player.height / 2) - 3 - math.abs(player.speedX)
			end
	end
	
	function wariodashattacking.onTick()
	
		if not (table.maxn(Dashplayers) == nil) then		-- checks if the given player is allowed to dashattack
			if (CurrentDashRegister == {}) then
				CurrentDashRegister = Dashplayers[i]
			else
				if player.character == CurrentDashRegister.character then
					isRegistered = true
				else
					if not (table.maxn(Dashplayers) <= i) then
						i = i + 1
						CurrentDashRegister = Dashplayers[i]
						
					else
						i = 0
						isRegistered = false
					end
				end
			end
		end
		
		
		if wariodashattacking.dashstate > 0 then	-- for the spritesheet
			chargeddash = 1
		else
			chargeddash = 0
		end
		if canStartDash() and player.keys.altRun == KEYS_DOWN then							-- start to initiate the dash
			wariodashattacking.dashattacking = true
			Defines.player_runspeed = defaultrunspeed + (chargingtimer / wariodashattacking.chargeuptime) * 4
			player.speedX = player.speedX + 0.1 * player.direction
			if math.abs(player.speedX) > 5 then
				if chargingtimer < wariodashattacking.chargeuptime then
					chargingtimer = chargingtimer + 1
				else
					wariodashattacking.dashstate = 1		-- start the charged dash
					SFX.play(dashSFX)	
				end
			end
		elseif canDash() then		-- charged dash
			Defines.player_runspeed = defaultrunspeed + 5
			player.speedX = player.speedX + 0.1 * player.direction
			if not turning then
				dashdirection = player.direction
			end
			
			if wariodashattacking.dashstate == 2 then		-- make the player unable to stop by themselves or turn around in the air
				wariodashing.cooldown = 2
				player.keys.run = true
				player.keys.altRun = false
				player.keys.down = false
				if inwater < 2 then
					inwater = 2
				end
				if not player:isOnGround() then					-- no turning around in the air ):<
					player.keys.left = false
					player.keys.right = false
				end
				if player:mem(0x34,FIELD_WORD) == 2 then			-- if the player is touching water, make them run on it!
					inwater = 8
					player.speedX = 11 * dashdirection
					player.x = player.x + 11 * dashdirection
					player.speedY = -1
				else
					if inwater > 2 then				-- when the player jumps out of the water
						inwater = 2
						player.speedX = 11 * dashdirection
					end
				end
			end
			
			for p, v in ipairs(Colliders.getColliding{a = dashingColliderNPC, btype = Colliders.NPC}) do        -- collision with bashable npcs
				if ((NPC.HITTABLE_MAP[v.id]) or (NPC.MULTIHIT_MAP[v.id]) or (NPC.SHELL_MAP[v.id]) or (table.contains(whitelisteddashNPCs,v.id))) and not table.contains(blacklisteddashNPCs,v.id) then
					if ((table.contains(fronthittabledashNPCs,v.id) and v.direction ~= player.direction) or (table.contains(backhittabledashNPCs,v.id) and v.direction == player.direction)) or not (table.contains(fronthittabledashNPCs,v.id) or table.contains(backhittabledashNPCs,v.id)) then
						if (NPC.HITTABLE_MAP[v.id] or (table.contains(whitelistedNPCs,v.id))) and not NPC.SHELL_MAP[v.id] then
							v:harm(3)
						elseif (NPC.MULTIHIT_MAP[v.id]) then
							v:harm(1)
						elseif (NPC.SHELL_MAP[v.id]) then
							v.speedY = - 4
							v.speedX = player.direction * 12
						end
						SFX.play(hitwallSFX)
					end
				end
			end
			
			for p, b in ipairs(Colliders.getColliding{a = dashingColliderBlock, btype = Colliders.BLOCK, filter = blockFilter}) do        -- collision with bashable blocks
				if ((Block.MEGA_SMASH_MAP[b.id]) or (table.contains(whitelisteddashBlocks,b.id))) and not (table.contains(blacklisteddashBlocks,b.id)) then
					b:remove(true)
				else
					b:hit()
					player.speedY = -6
					player.speedX = -6 * player.direction
					SFX.play(hitwallSFX)
					Defines.earthquake = 10
					StopDash()
				end
			end
			
			if effecttimer < 12 - math.abs(player.speedX) * 0.8 then
				effecttimer = effecttimer + 1	-- counts up the timer
			else
				if turning then
					effectframe = 3		-- the afterimage for turning around
				else
					if effectframe < 2 then
						effectframe = effectframe + 1
					else
						effectframe = 0
					end
				end
				local afterimage = Effect.spawn(765,player)
				afterimage.y = player.y - 4
				afterimage.variant = 1 + effectframe
				afterimage.lifetime = 20
				afterimage.priority = -26
				afterimage.direction = -player.direction
				effecttimer = 0								-- reset the timer
			end
			
			if player:mem(0x58,FIELD_WORD) > 0 then													-- if the player is turning around
				turning = true
				turncounter = turncounter + 1
				player.speedX = player.speedX - 0.15 * player.direction
			else
				if turning and wariodashattacking.dashstate == 2  and turncounter >= 40 then		-- turning around
					player.speedX = 11 * player.direction
					dashdirection = player.direction
					SFX.play(dashSFX)
				elseif turning and wariodashattacking.dashstate == 2 and turncounter < 40 then		-- failing to turn around and speeding up again
					player.direction = -dashdirection
					player.speedX = 11 * player.direction
					SFX.play(dashSFX)
				end
				turning = false
				turncounter = 0
			end
			
		else						-- end dashing
			if wariodashattacking.dashattacking then
				StopDash()
			end
		end
		
		if wariodashattacking.dashattacking then						-- handles the animation, animation speed is dependant on the player's speed
		
			if wariodashattacking.dashstate > 0 and player:mem(0x48,FIELD_WORD) > 0 and math.abs(player.speedX) < 3 then	-- speed preservation on slopes
				player.speedX = prevspeed
			end
			
			frametimer = frametimer + 0.5 + math.abs(player.speedX) * 0.4
			if frametimer > 10 then
				if wariodashattacking.dashstate > 0 then
					if frame < CurrentDashRegister.chargedframes - 1 then
						frame = frame + 1
					else
						frame = 0
					end
				else
					if frame < CurrentDashRegister.runupframes - 1 then
						frame = frame + 1
					else
						frame = 0
					end
				end
				frametimer = 0
			end
		end
	
		prevspeed = player.speedX
	end
	
	function wariodashattacking.onDraw()
		if wariodashattacking.dashattacking and not turning then	-- if the player is dashattacking and not turning around
			player:setFrame(-50)
			Graphics.drawBox{
				texture      = CurrentDashRegister.spritesheet,
				sceneCoords  = true,
				x            = player.x + (player.width / 2),
				y            = player.y + (player.height / 2) - CurrentDashRegister.gfxoffsetY,
				width        = wariodashattacking.gfxwidth * 2 * player.direction,
				height       = wariodashattacking.gfxheight * 2,
				sourceX      = 0 + wariodashattacking.gfxwidth * (player.powerup - 1) * 2 + chargeddash * wariodashattacking.gfxwidth,
				sourceY      = 0 + wariodashattacking.gfxheight * frame,
				sourceWidth  = wariodashattacking.gfxwidth,
				sourceHeight = wariodashattacking.gfxheight,
				centered     = true,
				priority     = -25,
				color        = Color.white .. 1,--playerOpacity,
				rotation     = 0,
			}
		end
	end
	
	return wariodashattacking