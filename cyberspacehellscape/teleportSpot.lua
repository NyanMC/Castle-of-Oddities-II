local tele = {}

local spline = require("spline")
local teleportSprite = Graphics.loadImage(Misc.resolveFile("tele_orb.png"))
local states = {
    NONE = 0,
    GROW = 1,
    FLY = 2,
    POP = 3
}
local teleImageFrames = {
    3,
    2,
    3
}

local transitionInfo = {
    state = states.NONE,
    cooldown = 0,
    timer = 0,
    spline = nil,
    speed = vector(0,0),    
    splinePosition = 0,
    opacity = 0,
    angle = 0
}

local lastID = 0
tele.cooldown = 24
tele.duration = 0.75
tele.teleportBGOIDs = {751, 752, 753}
local idMap = {}

for k,v in ipairs(tele.teleportBGOIDs) do
    idMap[v] = true
end

function tele.onInitAPI()
    registerEvent(tele, "onStart")
    registerEvent(tele, "onTick")
    registerEvent(tele, "onDraw")
end

local flameSprite = Graphics.loadImage(Misc.resolveFile("teleporter_flame.png"))

local flameEffects = {}

local function spawnFlameEffect(x, y)
    local f = {}
    f.l = x
    f.r = x + 32
    f.t = y
    f.b = y+64
    f.timer = (8 * #flameEffects) % 24

    table.insert(flameEffects, f)
end

function tele.onStart()
    for k,v in ipairs(BGO.get(tele.teleportBGOIDs)) do
        spawnFlameEffect(v.x, v.y - 32)
    end
end

local function seekBGOofID(id, x, y)
    local closestBGO = nil
    local closestDistance = 99999999999999
    for k,v in ipairs(BGO.get(id)) do
        local x2,y2 = v.x + 0.5 * v.width, v.y + 0.5 * v.height

        if x2 ~= x or y2 ~= y then
            local dist = vector(x2 - x, y2 - y)
            if dist.sqrlength < closestDistance then
                closestDistance = dist.sqrlength
                closestBGO = v
            end
        end
    end
    return closestBGO
end

local function drawSplineCustom(spline, steps, halfwidth, priority, opacity)
    steps = steps or 50
    local ps = {}
    local idx = 1
    local ds = 1/steps
    local s = 0
    local dir = spline.startTan
    local pold = spline:evaluate(0)
    local tx = {}
    for i = 0,steps do
        local p = spline:evaluate(s)
        s = s+ds
        local texCoord = 0.5
        if i == 0 then
            texCoord = 0
        elseif i == steps then
            texCoord = 1
        end

        local normal = vector(dir.x, dir.y):rotate(-90):normalize() * halfwidth
        
        ps[idx] = p[1] + normal.x
        ps[idx+1] = p[2] + normal.y
        ps[idx+2] = p[1] - normal.x
        ps[idx+3] = p[2] - normal.y
        tx[idx] = texCoord
        tx[idx+1] = 0
        tx[idx+2] = texCoord
        tx[idx+3] = 1

        if i < steps then
            dir = spline:evaluate(s+ds) - p
        end
        
        idx = idx+4
    end
		
    Graphics.glDraw{
        vertexCoords = ps,
        textureCoords = tx,
        primitive = Graphics.GL_TRIANGLE_STRIP,
        priority = priority,
        sceneCoords = true,
        color = Color.yellow .. opacity
    }
end

local function findClosestSection(s)
    local shortestDist = 9999999999999999999
    local chosenSection = nil
    for k,v in ipairs(Section.get()) do
        local v1 = vector(v.boundary.left, v.boundary.top) - s
        local v2 = vector(v.boundary.right, v.boundary.top) - s
        local v3 = vector(v.boundary.right, v.boundary.bottom) - s
        local v4 = vector(v.boundary.left, v.boundary.bottom) - s

        local sum = v1.sqrlength + v2.sqrlength + v3.sqrlength + v4.sqrlength
        if sum < shortestDist then
            chosenSection = k - 1
            shortestDist = sum
        end
    end
    return chosenSection
end

function tele.onTick()
    if transitionInfo.state == states.NONE then
        if transitionInfo.cooldown <= 0 then
            for k,v in ipairs(BGO.getIntersecting(player.x + 6, player.y + 6, player.x + player.width - 6, player.y + player.height - 6)) do
                if idMap[v.id] then
                    local partner = seekBGOofID(v.id, v.x + 0.5 * v.width, v.y + 0.5 * v.height)
                    if partner then
                        lastID = v.id
                        transitionInfo.state = states.GROW
                        transitionInfo.speed.x = player.speedX
                        transitionInfo.speed.y = player.speedY
                        transitionInfo.splinePosition = 0
                        transitionInfo.targetSection = findClosestSection(vector(partner.x + 0.5 * partner.width, partner.y + 0.5 * partner.height))
                        transitionInfo.spline = spline.segment{
                            start = vector(v.x + 0.5 * v.width, v.y + 0.5 * v.height),
                            stop = vector(partner.x + 0.5 * partner.width, partner.y + 0.5 * partner.height),
                            startTan = vector.zero2,
                            stopTan = transitionInfo.speed * 100,
                        }
                        inputLocked = true
                        transitionInfo.cooldown = tele.cooldown
                        SFX.play("teleport-in.ogg")
                    end
                end
            end
        else
            local countdown = true
            for k,v in ipairs(BGO.getIntersecting(player.x - 4, player.y - 4, player.x + player.width + 4, player.y + player.height + 4)) do
                if v.id == lastID then
                    countdown = false
                    break
                end
            end
            if countdown then
                transitionInfo.cooldown = transitionInfo.cooldown - 1
            end
        end
    elseif transitionInfo.state == states.GROW then
        player:mem(0x142, FIELD_BOOL, true)
        player:mem(0x122, FIELD_WORD, 499)
        transitionInfo.timer = transitionInfo.timer + 2
        transitionInfo.opacity = math.min(transitionInfo.opacity + 0.05, 1)
        local step = transitionInfo.spline(0)
        player.x = step.x - 0.5 * player.width
        player.y = step.y - 0.5 * player.height
        if transitionInfo.timer > 24 then
            transitionInfo.state = states.FLY
            transitionInfo.timer = 0
            transitionInfo.angle = 0
        end
    elseif transitionInfo.state == states.FLY then
        player:mem(0x122, FIELD_WORD, 499)
        transitionInfo.timer = transitionInfo.timer + 1

        transitionInfo.splinePosition = math.clamp(transitionInfo.timer/65 /tele.duration,0,1)
        local step = transitionInfo.spline(transitionInfo.splinePosition)
        local x,y = player.x, player.y
        player.x = step.x - 0.5 * player.width
        player.y = step.y - 0.5 * player.height
        transitionInfo.angle = math.deg(math.atan2(player.y - y, player.x - x))

        if transitionInfo.splinePosition >= 0.5 and player.section ~= transitionInfo.targetSection then
            player.section = transitionInfo.targetSection
            playMusic(transitionInfo.targetSection)
        end

        if transitionInfo.splinePosition >= 1 then
            inputLocked = false
            transitionInfo.state = states.POP
            player.speedX = transitionInfo.speed.x
            player.speedY = transitionInfo.speed.y
            transitionInfo.timer = 0
            transitionInfo.angle = 0
            player:mem(0x122, FIELD_WORD, 0)
            SFX.play("teleport-out.ogg")
        end
    else
        transitionInfo.timer = transitionInfo.timer + 2
        transitionInfo.opacity = math.max(transitionInfo.opacity - 0.1, 0)
        if transitionInfo.timer > 20 then
            transitionInfo.state = states.NONE
            transitionInfo.timer = 0
        end
    end 
end

function tele.onDraw()
    local fvt = {}
    local ftx = {}
    local tick = lunatime.tick()
    local i = 1
    for k,v in ipairs(flameEffects) do
        if v.l <= camera.x + camera.width and v.r >= camera.x and v.t <= camera.y + camera.height and v.b >= camera.y then
            fvt[i] = v.l
            fvt[i+1] = v.t
            fvt[i+2] = v.r
            fvt[i+3] = v.t
            fvt[i+4] = v.l
            fvt[i+5] = v.b
            fvt[i+6] = v.r
            fvt[i+7] = v.t
            fvt[i+8] = v.l
            fvt[i+9] = v.b
            fvt[i+10] = v.r
            fvt[i+11] = v.b

            local t = (math.floor((v.timer + tick) * 0.125) % 3) * 0.25
            local b = t + 0.25
            
            ftx[i] = 0
            ftx[i+1] = t
            ftx[i+2] = 1
            ftx[i+3] = t
            ftx[i+4] = 0
            ftx[i+5] = b
            ftx[i+6] = 1
            ftx[i+7] = t
            ftx[i+8] = 0
            ftx[i+9] = b
            ftx[i+10] = 1
            ftx[i+11] = b
            i = i + 12
        end
    end
    if #fvt > 0 then
        Graphics.glDraw{
            sceneCoords = true,
            vertexCoords = fvt,
            textureCoords = ftx, 
            primitive = Graphics.GL_TRIANGLES,
            priority = -70,
            texture = flameSprite
        }
    end

    if transitionInfo.state ~= 0 then
        if transitionInfo.state < 3 then
            player:mem(0x114, FIELD_WORD, 50 * player.direction)
        end
        drawSplineCustom(transitionInfo.spline, nil, 2, -56, transitionInfo.opacity)

        local vt = {
            vector(-32, -32),
            vector(32, -32),
            vector(-32, 32),
            vector(32, 32),
        }

        local t = (math.floor(transitionInfo.timer * 0.125) % teleImageFrames[transitionInfo.state]) * 0.25
        local t1 = t + 0.25
        local th = (transitionInfo.state - 1) * 0.25
        local th1 = th + 0.25

        local tx = {
            t, th,
            t1, th,
            t, th1,
            t1, th1
        }

        for k,v in ipairs(vt) do
            vt[k] = v:rotate(transitionInfo.angle)
        end

        local splineCoords = transitionInfo.spline(transitionInfo.splinePosition)

        local x,y = splineCoords.x, splineCoords.y

        Graphics.glDraw{
            vertexCoords = {
                x + vt[1].x, y + vt[1].y,
                x + vt[2].x, y + vt[2].y,
                x + vt[3].x, y + vt[3].y,
                x + vt[4].x, y + vt[4].y,
            },
            textureCoords = tx,
            priority = -25,
            texture = teleportSprite,
            primitive = Graphics.GL_TRIANGLE_STRIP,
            sceneCoords = true
        }
    end
end

return tele