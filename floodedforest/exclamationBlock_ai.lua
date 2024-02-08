--[[

	Written by MrDoubleA
	Please give credit!

	Graphics from Sednaiur's SMW Expanded graphics pack

	Part of MrDoubleA's NPC Pack

]]

local blockManager = require("blockManager")
local blockutils = require("blocks/blockutils")

local redirector = require("redirector")

local exclamationBlock = {}

exclamationBlock.spawnerIDList = {}
exclamationBlock.spawnerIDMap = {}

local spawnedBlocks = {}

local blinkShader = Shader()
blinkShader:compileFromFile(nil,Misc.resolveFile("exclamationBlock_blink.frag"))

local sprites = {}

-- I went through the effort of discovering these addresses, but I didn't even need them lol
--[[local IBLOCK_COUNT = 0x00B25784
local IBLOCK_ADDR = mem(0x00B25798,FIELD_DWORD)]]

local function getDirectionVector(x,y,width,height)
    for _,v in ipairs(BGO.getIntersecting(x,y,x+width,y+height)) do
        if v.id == redirector.TERMINUS then
            return -1
        else
            return redirector.VECTORS[v.id]
        end
    end

    return nil
end

function exclamationBlock.onInitAPI()
    registerEvent(exclamationBlock,"onTick")
    registerEvent(exclamationBlock,"onDraw")

    registerEvent(exclamationBlock,"onBlockHit")
end

function exclamationBlock.expand(v,count,eventObj)
    if not exclamationBlock.spawnerIDMap[v.id] then return end

    local config = Block.config[v.id]
    local data = v.data

    local settings = v.data._settings
    if not settings.override then settings = config end

    local sConfig = Block.config[settings.outputBlockID]

    if not data.spawnedBlocks then return end

    local cancel = false

    if data.hitCount < data.hightestDirectionCount then
        --data.cooldown = math.floor(math.max(v.width,v.height)/settings.outputBlockSpeed)

        if config.expandSFX then
            SFX.play(config.expandSFX)
        end
    else
        cancel = true
    end

    if data.timeRemaining <= 0 then
        data.timeRemaining = settings.outTime
    end

    data.hitCount = data.hitCount + (count or 1)

    return cancel
end

function exclamationBlock.registerSpawner(id)
    blockManager.registerEvent(id,exclamationBlock,"onTickBlock","onTickSpawner")
    blockManager.registerEvent(id,exclamationBlock,"onCameraDrawBlock","onCameraDrawSpawner")

    blockManager.registerEvent(id,exclamationBlock,"onPostExplosionBlock","onPostExplosionSpawner")

    table.insert(exclamationBlock.spawnerIDList,id)
    exclamationBlock.spawnerIDMap[id] = true
end

function exclamationBlock.onTick()
    -- Remove all spawned blocks that no longer have their spawners
    local k = 1
    while k <= #spawnedBlocks do
        local v = spawnedBlocks[k]

        if not v.child.isValid or not v.parent.isValid or v.parent.isHidden or v.parent:mem(0x5A,FIELD_BOOL) then
            if v.child.isValid then
                v.child:remove(true)
                v.child:delete()
            end

            table.remove(spawnedBlocks,k)
        else
            k = k + 1
        end
    end
end

function exclamationBlock.onDraw()
    for _,id in ipairs(exclamationBlock.spawnerIDList) do
        blockutils.setBlockFrame(id,-1024) -- Note that when getting the block's frame, it always assumes it has a height of 32
    end
end

function exclamationBlock.onBlockHit(eventObj,v,fromTop,w)
    if not exclamationBlock.spawnerIDMap[v.id] then return end

    if v:mem(0x56,FIELD_WORD) == 0 then -- If not recently hit
        eventObj.cancelled = exclamationBlock.expand(v)
    else
        eventObj.cancelled = true
    end
end

function exclamationBlock.onPostExplosionSpawner(v,e)
    if v.isHidden or v:mem(0x5A,FIELD_BOOL) then return end

    local config = Block.config[v.id]
    local data = v.data

    if not data.spawnedBlocks then return end

    if e.collider:collide(v) then -- If hit by the explosion
        if e.strong then -- If the explosion is strong, break
            v:remove(true)
        else -- If the explosion is weak, expand fully
            exclamationBlock.expand(v,data.hightestDirectionCount)
        end
    end
end

function exclamationBlock.onTickSpawner(v)
    local config = Block.config[v.id]
    local data = v.data

    local settings = v.data._settings
    if not settings.override then settings = config end -- Use config settings instead of extra settings if not set to override

    local sConfig = Block.config[settings.outputBlockID]

    if not sConfig then return end

    -- Uninitialise if hidden
    if v.isHidden or v:mem(0x5A,FIELD_BOOL) then
        data.blockDirectionList = nil
        data.hightestDirectionCount = nil

        data.spawnedBlocks = nil

        data.timeRemaining = nil
        data.hitCount = nil
        --data.cooldown = nil

        return
    end

    if not data.blockDirectionList then
        data.blockDirectionList = {} -- Table for keeping track of directions to move

        data.hightestDirectionCount = 0 -- The longest group's direction count
        
        for _,w in ipairs(BGO.getIntersecting(v.x,v.y,v.x+v.width,v.y+v.height)) do
            local direction = redirector.VECTORS[w.id]

            if direction then
                local list = {[0] = direction} -- Create a group for this direction

                local x = (v.x+(v.width /2))+(((v.width /2)+(sConfig.width /2))*direction.x) -- Start to the side of the block
                local y = (v.y+(v.height/2))+(((v.height/2)+(sConfig.height/2))*direction.y)

                for i=1,64 do
                    direction = getDirectionVector(x-(sConfig.width/2),y-(sConfig.height/2),sConfig.width,sConfig.height) or direction -- Use either the redirector here or continue in the same direction

                    table.insert(list,direction) -- Insert this direction into the direction list

                    if direction == -1 then -- If it's a terminus, stop here
                        break
                    else -- Otherwise, move
                        x = x + (direction.x*sConfig.width)
                        y = y + (direction.y*sConfig.height)
                    end
                end

                data.hightestDirectionCount = math.max(data.hightestDirectionCount,#list) -- If this group is longer than the priorly longest one

                table.insert(data.blockDirectionList,list) -- Insert the group
            end
        end

        data.spawnedBlocks = {} -- Table to keep track of all blocks of a group

        for k,l in ipairs(data.blockDirectionList) do -- Go through every group that was established earlier
            data.spawnedBlocks[k] = {} -- Create a table for this group

            for _,d in ipairs(l) do
                local w = Block.spawn(settings.outputBlockID,v.x+(v.width/2)-(sConfig.width/2),v.y+(v.height/2)-(sConfig.height/2))

                w.layerName = v.layerName
                w.isHidden = true

                table.insert(data.spawnedBlocks[k],w)
                table.insert(spawnedBlocks,{parent = v,child = w}) -- Insert it into the global spawned blocks table
            end
        end

        data.timeRemaining = 0
        data.hitCount = 0
        --data.cooldown = 0
    end

    --data.cooldown = math.max(0,(data.cooldown or 0) - 1)

    if data.timeRemaining > 0 then
        data.timeRemaining = data.timeRemaining - 1

        if data.timeRemaining <= 0 then
            data.hitCount = 0

            -- Spawn the effects on the blocks
            for groupIndex,group in ipairs(data.spawnedBlocks) do
                for k,w in ipairs(group) do
                    if w.isValid and not w.isHidden then
                        local e = Effect.spawn(10,0,0)

                        e.x = (w.x+(w.width /2))-(e.width /2)
                        e.y = (w.y+(w.height/2))-(e.height/2)
                    end
                end
            end

            if config.disappearSFX then
                SFX.play(config.disappearSFX)
            end
        elseif data.timeRemaining <= ((settings.outTime/10)*settings.blinks) and data.timeRemaining%math.floor(settings.outTime/10) == 0 then
            if config.blinkSFX then
                SFX.play(config.blinkSFX)
            end
        end
    end

    -- Do appropriate logic for all blocks
    for groupIndex,group in ipairs(data.spawnedBlocks) do
        for k,w in ipairs(group) do
            if w.isValid and not w.layerObj.isHidden then -- If it hasn't been destroyed
                local wData = w.data

                local directionIndex = ((k-#group)+math.min(#group-1,data.hitCount-1)) -- Get the index of the direction to be on

                if data.hitCount <= 0 or k < (#group-math.min(#group-1,data.hitCount-1)) then
                    -- Move to the source block
                    local distanceX = (v.x+(v.width /2))-(w.x+(w.width /2))
                    local distanceY = (v.y+(v.height/2))-(w.y+(w.height/2))
                    
                    if distanceX ~= 0 or distanceY ~= 0 then
                        w:translate(distanceX,distanceY)
                    end

                    w.isHidden = true
                else
                    local startDirection = data.blockDirectionList[groupIndex][0]
                    local goalX = (v.x+(v.width /2))+(((v.width /2)-(w.width /2))*startDirection.x)
                    local goalY = (v.y+(v.height/2))+(((v.height/2)-(w.height/2))*startDirection.y)

                    for i=0,directionIndex do -- Go through all directions for this group
                        local d = data.blockDirectionList[groupIndex][i]
                        if not d or d == -1 then break end -- Stop if there isn't a direction left or we've hit a terminus

                        goalX = goalX + (d.x*w.width )
                        goalY = goalY + (d.y*w.height)
                    end

                    -- Get the distance between here and the goal
                    local distanceX = (goalX)-(w.x+(w.width /2))
                    local distanceY = (goalY)-(w.y+(w.height/2))

                    if distanceX ~= 0 or distanceY ~= 0 then
                        w.speedX = math.min(math.abs(distanceX),settings.outputBlockSpeed)*math.sign(distanceX) -- Get either the distance between the goal and the current position or the speed it's set to come out at (depending on which is smaller), amd move by that
                        w.speedY = math.min(math.abs(distanceY),settings.outputBlockSpeed)*math.sign(distanceY)

                        w:translate(w.speedX,w.speedY)
                    else
                        w.speedX,w.speedY = 0,0
                    end

                    w.isHidden = false
                end
            end
        end
    end
end

function exclamationBlock.onCameraDrawSpawner(v,camIdx)
    if v.isHidden or v:mem(0x5A, FIELD_BOOL) then return end

    local config = Block.config[v.id]
    local data = v.data

    local settings = v.data._settings
    if not settings.override then settings = config end

    if not data.blockDirectionList then return end

    if blockutils.visible(Camera(camIdx),v.x,v.y,v.width,v.height) then -- If visible
        local frame = (math.floor(lunatime.drawtick()/config.framespeed)%(config.frames/2))
        if data.hitCount >= data.hightestDirectionCount and v:mem(0x56,FIELD_WORD) == 0 then
            frame = frame+(config.frames/2) -- Use hit frame
        end

        Graphics.drawImageToSceneWP(
            Graphics.sprites.block[v.id].img,
            v.x,v.y+v:mem(0x56,FIELD_WORD),0,frame*v.height,
            v.width,v.height,1,-64
        )
    end

    for _,l in ipairs(data.spawnedBlocks) do
        for _,w in ipairs(l) do
            if w.isValid and not w.layerObj.isHidden and not w.isHidden and not w:mem(0x5A,FIELD_BOOL) and blockutils.visible(Camera(camIdx),w.x,w.y,w.width,w.height) then
                local wConfig = Block.config[w.id]

                local brightness = 0
                if data.timeRemaining <= ((settings.outTime/10)*settings.blinks) then
                    brightness = (math.log(math.max(0,(data.timeRemaining/(settings.outTime/10)))%1)+1) -- Get how bright the block should be
                end

                if brightness > 0 then
                    if not sprites[wConfig.frames] then
                        sprites[wConfig.frames] = Sprite{texture = Graphics.sprites.block[w.id].img,frames = wConfig.frames}
                    else
                        sprites[wConfig.frames].texture = Graphics.sprites.block[w.id].img
                    end

                    local sprite = sprites[wConfig.frames]

                    sprite.x,sprite.y = w.x,w.y+w:mem(0x56,FIELD_WORD)
                    sprite.width,sprite.height = w.width,w.height

                    sprite.frame = blockutils.getBlockFrame(w.id)

                    sprite:draw{priority = -65,sceneCoords = true,shader = blinkShader,uniforms = {brightness = brightness}} -- Use a shader to make it brighter
                end
            end
        end
    end
end

return exclamationBlock