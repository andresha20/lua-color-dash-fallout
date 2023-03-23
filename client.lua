local width, height = guiGetScreenSize()
local dimension = 0 -- change to 336 in production/dev
local shouldRender = false
local shouldRenderMissile = false
local keyBound = false
local projectile = nil
local hasProjectile = false
local shotProjectile = false
local isRunning
local testFunction
local activeColorText
local dxTextColor
local endTime
local projectileExpiresAfter
local shaderReferences = {}

function drawTextColor()
    if (getElementDimension(localPlayer) ~= dimension) then
        return false
    end    
    local countdownOnScreen = (endTime - getTickCount())/1000
    dxDrawText(activeColorText, 0, 0, width, height/2, dxTextColor, 2, 2, "pricedown", "center", "center")
    dxDrawText(countdownOnScreen, 0, 0, width, height/1.54, tocolor(255, 255, 255), 1, 1, "pricedown", "center", "center")
end

function drawMissileText()
    if (hasProjectile) then
        local projectileCountdown = (projectileExpiresAfter - getTickCount())/1000
        dxDrawText("Missile expires in "..projectileCountdown.." seconds!", 0, 0, width, height/1.3, tocolor(100, 47, 80), 0.7,0.7, "pricedown", "center", "center")
    end
end

function handleRendering(targetType, isEventRunning, activeColor, colors, request, intervalInMs)
    if (targetType == "colorNotification") then
        isRunning = isEventRunning
        if (not isRunning) then
            removeEventHandler("onClientRender", root, drawTextColor)
            shouldRender = false
            return false
        end
        local r, g, b = colors[activeColor][1], colors[activeColor][2], colors[activeColor][3]
        dxTextColor = tocolor(r, g, b)
        activeColorText = colors[activeColor][4]
        endTime = getTickCount() + intervalInMs
        if (request == "display" or not shouldRender) then
            addEventHandler("onClientRender", root, drawTextColor)
            shouldRender = true
        else
            removeEventHandler("onClientRender", root, drawTextColor)
            shouldRender = false
        end
    end
end

addEvent("drawTextHandler", true)
addEventHandler("drawTextHandler", localPlayer, handleRendering)

function shootMissile()
    if (getElementDimension(localPlayer) ~= dimension) then
        return false
    end   
	local vehicle = getPedOccupiedVehicle(localPlayer)
	if (vehicle) then
		local x, y, z = getElementPosition(vehicle)
        if (not shotProjectile) then
            projectile = createProjectile(vehicle, 19, x, y, z)
            shotProjectile = true
        end
    end
end

function playerPressedKey(button, pressed, player)
    if (pressed) then -- Only output when they press it down
        if (button == 'mouse1' and projectile and keyBound) then
            projectile = nil
            unbindKey("mouse1", "down", shootMissile)
            keyBound = false
        end
    end
end

addEventHandler("onClientKey", root, playerPressedKey)

function resetMissileHandlers()
    removeEventHandler("onClientRender", root, drawMissileText) 
    removeEventHandler("onClientKey", root, playerPressedKey)
    unbindKey("mouse1", "down", shootMissile)
    shouldRenderMissile = false
    hasProjectile = false
    shotProjectile = false
end

function handleMissileGiveaway(isEventRunning)
    isRunning = isEventRunning
    if (not isEventRunning) then
        outputChatBox("Event is not running")
        if (keyBound) then
            unbindKey(localPlayer, "mouse1", "down", shootMissile)
            removeEventHandler("onClientKey", root, playerPressedKey)
        end
        return false
    end
    shotProjectile = false
    outputChatBox("#FFFFFFYou have been given a #FF78CBMISSILE. #FFFFFFYou've got #FF78CB5 seconds#FFFFFF to kill your opponents (press LMB to shoot) before it expires!", 255, 255, 255, true)
    bindKey("mouse1", "down", shootMissile)
    keyBound = true
    if (not shouldRenderMissile) then
        hasProjectile = true
        addEventHandler("onClientRender", root, drawMissileText)
        projectileExpiresAfter = getTickCount() + 5000
        shouldRenderMissile = true
        setTimer(resetMissileHandlers, 5000, 1)
    end	
end

addEvent("giveMissile", true)
addEventHandler("giveMissile", localPlayer, handleMissileGiveaway)

function paintTiles(request, tiles, colors, isEventRunning)
    for i, v in ipairs(tiles) do
        if (not tiles or not tiles[i] or not tiles[i][6]) then
            outputChatBox("Invalid element")
            return false;
        end 
        if (not shaderReferences[i] or (shaderReferences[i] and (shaderReferences[i][1] ~= tiles[i][1]))) then
            local elementReference = tiles[i][1]
            local shader = dxCreateShader( "shader.fx", 0, 0, false, "object")
            shaderReferences[i] = { elementReference, shader }
        end
        local colorIndex = tiles[i][6]
        if (colorIndex == 0) then
            colorIndex = 1
        end
        local r, g, b = colors[colorIndex][1], colors[colorIndex][2], colors[colorIndex][3]
        dxSetShaderValue(shaderReferences[i][2], "red", (tonumber(r)/255))
        dxSetShaderValue(shaderReferences[i][2], "green", (tonumber(g)/255))
        dxSetShaderValue(shaderReferences[i][2], "blue", (tonumber(b)/255))
        if (request == "paint" or isEventRunning) then
            engineApplyShaderToWorldTexture(shaderReferences[i][2], "*", shaderReferences[i][1])
        else
            engineRemoveShaderFromWorldTexture(shaderReferences[i][2], "*", shaderReferences[i][1])
        end
    end
end

addEvent("paintTilesHandler", true)
addEventHandler("paintTilesHandler", localPlayer, paintTiles)

