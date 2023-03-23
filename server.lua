local dimension = 0 -- change to 336 in production/dev
local aclGroup = "Admin" -- change to "EM" in production/dev
local isGatheringObjects = false
local isEventRunning = false
local createdHardcodedObjects = false
local timer = nil
local areObjectsHidden = false
local missileSpawnInterval = nil
local activeMissile = nil
local gapInterval = 5000
local playersInEvent = {}
local intervalInMs = nil
local missileHolder = nil
local roundsPlayed = 0
local activeColor = nil
local colors = { 
    { 0, 0, 255, "BLUE" }, -- blue
    { 255, 0, 0, "RED" },  -- red
    { 255, 255, 0, "YELLOW" },  -- yellow
    { 0, 255, 0, "GREEN" }, -- green
    { 0, 0, 0, "BLACK" } -- green
}
local hardcodedCoords = {
    { 3006.699951171875, -1225.199951171875, 20.20000076293945 }, 
    { 3015.699951171875, -1225.199951171875, 20.20000076293945 }, 
    { 3024.699951171875, -1225.199951171875, 20.20000076293945 }, 
    { 3033.699951171875, -1225.199951171875, 20.20000076293945 }, 
    { 3033.699951171875, -1234.199951171875, 20.20000076293945 }, 
    { 3024.699951171875, -1234.199951171875, 20.20000076293945 }, 
    { 3015.699951171875, -1234.199951171875, 20.20000076293945 }, 
    { 3006.699951171875, -1234.199951171875, 20.20000076293945 }, 
    { 3006.699951171875, -1243.199951171875, 20.20000076293945 }, 
    { 3006.699951171875, -1252.199951171875, 20.20000076293945 }, 
    { 3015.699951171875, -1252.199951171875, 20.20000076293945 }, 
    { 3024.699951171875, -1252.199951171875, 20.20000076293945 }, 
    { 3033.699951171875, -1252.199951171875, 20.20000076293945 }, 
    { 3033.699951171875, -1243.199951171875, 20.20000076293945 }, 
    { 3024.699951171875, -1243.199951171875, 20.20000076293945 }, 
    { 3015.699951171875, -1243.199951171875, 20.20000076293945 } 
}
local tiles = {}
local warningMessages = { 
    [1] = "You must be CEM to execute this command!", 
    [2] = "This command can only be executed in the event dimension!", 
    [3] = "Invalid argument!",
    [4] = "Event is already running!",
    [5] = "No valid tiles were found on the map. Valid ID: 3095",
    [6] = "Wait until tiles are detected",
    [7] = "There's a timer running",
    [8] = "Time value in SECONDS is missing. Syntax: /cdf time <number of seconds, minimum value is 4>",
    [9] = "Time value in SECONDS is too low, minimum value is 4.",
    [10] = "Event is not running.",
    [11] = "A missile pickup is still to be taken. Wait until someone takes it!",
    [12] = "Event has been stopped.",
    [13] = "STOPPED: This event requires at least 2 participants.",
    [14] = "STOPPED: The event reached 20 rounds and this is done to prevent it from running endlessly. You can restart it with /cdf start",
}

function commandsHandler(player, command, argument, intervalInSeconds)
    if (not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup(aclGroup))) then
        outputChatbox(warningMessages[1], player, 255, 0, 0)
        return false
    end
    if (getElementDimension(player) ~= dimension) then
		outputChatBox(warningMessages[2], player, 255, 0, 0)
		return false
	end
    if (not argument or argument == "") then
        outputChatBox(warningMessages[3], player, 255, 0, 0)
		return false
    end
    if (argument == "start") then
        if (not intervalInMs) then
            -- If no time
            outputChatBox(warningMessages[8], player, 255, 0, 0)
            return false
        end
        if (isEventRunning or #tiles > 0) then
            -- If is already running
            outputChatBox(warningMessages[4], player, 255, 0, 0)
            return false
        end
        if (#playersInEvent == 0) then
            -- If not enough players in dim 336. NOTE: I don't know how players added with "/event add" are detected so this check probablu
            -- needs an enhancement
            local numberOfPlayers = getPlayersInEvent()
            -- ==========> REMOVE THIS CONDITION WHILE TESTING <=================
            if (numberOfPlayers < 2) then
                outputChatBox(warningMessages[13], player, 255, 0, 0)
                stopGamemode(player)
                return
            end
        end
        -- Create objects (ONLY FOR TESTING PURPOSES)
        if (not createdHardcodedObjects) then
            for i, v in ipairs(hardcodedCoords) do
                createObject(3095, hardcodedCoords[i][1], hardcodedCoords[i][2], hardcodedCoords[i][3])
            end
            outputChatBox('Hardcoded map loaded', player, 255, 255, 255)
            createdHardcodedObjects = true
        end
        -- Retrieve valid objects from the loaded map (loaded from /emsaves). Hopefully it works
        outputChatBox('Detecting objects with ID 3095...', player, 255, 255, 0)
        isGatheringObjects = true
        for i, v in ipairs(getElementsByType("object")) do
            if (getElementModel(v) == 3095) then
                local x, y, z = getElementPosition(v)
                local newItem = { v, x, y, z, false, 0, nil }
                -- FORMATTED AS: { elementValue, x, y, z, hidden?, colorIndex }
                table.insert(tiles, newItem)
            end
        end
        if (#tiles == 0) then
            -- If after detecting the tiles none was found then throw error
            outputChatBox(warningMessages[5], player, 255, 0, 0)
            return false
        end
        outputChatBox('Worked. '.. #tiles .." objects have been found.", player, 255, 255, 0)
        isGatheringObjects = false
        launchGamemode(player)
    end
    if (argument == "stop") then
        stopGamemode(player)
    end
    if (argument == "time") then
        if (not intervalInSeconds) then
            -- No time argument
            outputChatBox(warningMessages[8], player, 255, 0, 0)
            return false
        end
        local intervalInSecondsConverted = tonumber(intervalInSeconds)
        if (intervalInSecondsConverted < 4) then
            -- Time in secs must be above at least 4
            outputChatBox(warningMessages[9], player, 255, 0, 0)
            return false
        end
        intervalInMs = intervalInSecondsConverted*1000
        outputChatBox("Time gap between tile drop set to "..intervalInSeconds.." seconds.", player, 255, 255, 0)
    end
    if (argument == "missile") then
        if (missileSpawnInterval) then
            outputChatBox("You can only spawn a missile pickup every 10 seconds.", player, 255, 0, 0)
            return false
        end
        -- The EM can spawn a missile on a random tile that players can take to kill their opponents.
        if (not isEventRunning) then
            -- Event is not running
            outputChatBox(warningMessages[10], player, 255, 0, 0)
            return false
        end
        if (activeMissile) then
            -- Already spawned
            outputChatBox(warningMessages[11], player, 255, 0, 0)
            return false
        end
        local randomTileIndex = math.random(tostring(#tiles))
        local v, x, y, z = tiles[randomTileIndex][1], tiles[randomTileIndex][2], tiles[randomTileIndex][3], tiles[randomTileIndex][4] + 2
        activeMissile = createPickup(x, y, z, 3, 345)
        outputChatBox("Missile spawned successfully!", player, 0, 255, 0)
        missileSpawnInterval = setTimer(function() 
            killTimer(missileSpawnInterval) 
            missileSpawnInterval = nil
        end, 10000, 1)
    end
end

addCommandHandler('dash', commandsHandler)

function stopGamemode(player)
    if (not isEventRunning) then
        outputChatBox(warningMessages[10], player, 255, 0, 0)
        return false
    end
    if (timer) then
        killTimer(timer)
        timer = nil
    end
    if (areObjectsHidden) then
        for i, v in ipairs(tiles) do
            tiles[i][6] = 0
            if (tiles[i][5]) then
                tiles[i][5] = false
                setElementAlpha(tiles[i][1], 255)
                setElementCollisionsEnabled(tiles[i][1], true)
            end
        end    
    end
    isEventRunning = false
    isGatheringObjects = false
    triggerClientEvent(playersInEvent, "paintTilesHandler", root, "unpaint", tiles, colors, isEventRunning)
    timer = nil
    areObjectsHidden = false
    missileSpawnInterval = nil
    activeMissile = nil
    missileHolder = nil
    roundsPlayed = 0
    tiles = {}
    triggerClientEvent(playersInEvent, "drawTextHandler", root, "colorNotification", isEventRunning, activeColor, colors, "abort", intervalInMs)
    intervalInMs = nil
    activeColor = nil
    playersInEvent = {}
    outputChatBox(warningMessages[12], player, 255, 255, 0)
    return false
end

function launchGamemode(player)
    if (roundsPlayed == 20) then
        -- Game automatically stops when 20 rounds are reached to prevent it from running infinitely when the CEM forgot to use /dash stop.
        stopGamemode(player)
        outputChatBox(warningMessages[14], player, 255, 0, 0)
        return false
    end
    if (isGatheringObject) then
        -- This is unlikely to happen but better to keep
        outputChatBox(warningMessages[6], player, 255, 0, 0)
        return false
    end
    isEventRunning = true
    roundsPlayed = roundsPlayed + 1
    activeColor = math.random(tostring(#colors))
    local colorsUsed = {}
    for i, v in ipairs(tiles) do
        tiles[i][6] = math.random(tostring(#colors))
        local key = tiles[i][6]
        colorsUsed[key] = true
        if (tiles[i][6] ~= activeColor) then
            tiles[i][5] = true
        else
            tiles[i][5] = false
        end
    end
    -- Prevent the script from showing 0 tiles when none of the tiles are colored with the active color
    for i, v in ipairs(colors) do
        if (not colorsUsed[i]) then
            outputChatBox("Special case", player, 255, 0, 0)
            local missingColor = i
            local randomTileIndex = math.random(tostring(#tiles))
            tiles[randomTileIndex][6] = missingColor
            if (missingColor ~= activeColor) then
                tiles[randomTileIndex][5] = true
            else
                tiles[randomTileIndex][5] = false
            end
        end
    end
    -- Paint the tiles
    paintTiles(player)
end

function paintTiles(player)
    -- Re-checking because the user may leave after using /dash start
    getPlayersInEvent()
    if (not isGatheringObjects and activeColor and (#tiles > 0)) then
        local r, g, b = colors[activeColor][1], colors[activeColor][2], colors[activeColor][3]
        local hexColor = "#"..string.format("%.2X%.2X%.2X", r, g, b)
        outputChatBox("#FF0000Round "..roundsPlayed..": #FFFFFFDrive to the "..hexColor..colors[activeColor][4].." #FFFFFFtiles to survive!", playersInEvent, r, g, b, true)
        triggerClientEvent(playersInEvent, "paintTilesHandler", root, "paint", tiles, colors, isEventRunning)
        drawText("display")
        launchTimer("hideObjects", player)
    end
end

function drawText(request)
    if (not isGatheringObjects) then
        triggerClientEvent(playersInEvent, "drawTextHandler", root, "colorNotification", isEventRunning, activeColor, colors, request, intervalInMs)
    end
end

function givePlayerMissile(player)
    if (missileHolder == player) then
        -- If missileHolder is nil then no one has taken the missile. Otherwise, someone has already taken it so don't do anything.
        return false
    end
    if (getPickupType(source) == 3 and getElementModel(source) == 345 and isPedInVehicle(player)) then
        missileHolder = player
        triggerClientEvent(player, "giveMissile", player, isEventRunning)
        if (isElement(activeMissile)) then
            destroyElement(activeMissile)
            activeMissile = nil
            missileHolder = nil
        end
    end
end

addEventHandler("onPickupHit", root, givePlayerMissile)

function launchTimer(request, player)
    if (intervalInMs > 4*1000) then
        -- If the interval is over 4, execute progressive interval reductions according to the number of rounds played.
        if (roundsPlayed > 5 and roundsPlayed < 10) then
            intervalInMs = intervalInMs - 1000
        end
        if (roundsPlayed > 10 and roundsPlayed < 15) then
            intervalInMs = intervalInMs - 2000
        end
        if (roundsPlayed > 15) then
            intervalInMs = intervalInMs - 3000
        end
    end
    local time
    if (request == "display") then
        -- If the tiles are hidden, then the time until they're shown again must be less than the time that it takes to hide them.
        time = gapInterval
    else
        -- If the tiles are not hidden, then use the interval provided by the EM, which is the time taken before the tiles are hidden.
        time = intervalInMs
    end
    timer = setTimer(handleHideObjRequest, time, 1, request, player)
end

function getPlayersInEvent()
    -- Just a basic dimension check. This is actually not the players added with "/eventwarp" or "/event add" because 
    -- I don't know how that's done on CIT.
    playersInEvent = {}
    for i, v in ipairs(getElementsByType("player")) do
        if (getElementDimension(v) == dimension) then
            table.insert(playersInEvent, v)
        end
    end
    return tonumber(#playersInEvent)
end

function handleHideObjRequest(request, player)
    -- Useful function to execute an action conditionally
    if (request == "hideObjects") then
        -- If the request is "hideObjects", then the objects are currently visible and ought to be hidden.
        areObjectsHidden = true
        for i, v in ipairs(tiles) do
            if (tiles[i][5]) then
                setElementAlpha(tiles[i][1], 0)
                setElementCollisionsEnabled(tiles[i][1], false)
            end
        end

        local r, g, b = colors[activeColor][1], colors[activeColor][2], colors[activeColor][3]
        local dxTextColor = tocolor(r, g, b)
        drawText("hide")
        launchTimer("display", player)
    else
        -- If the request is not "hideObjects", then show the objects again.
        activeColor = nil
        areObjectsHidden = false
        for i, v in ipairs(tiles) do
            tiles[i][6] = 0
            if (tiles[i][5]) then
                tiles[i][5] = false
                setElementAlpha(tiles[i][1], 255)
                setElementCollisionsEnabled(tiles[i][1], true)
            end
        end
        launchGamemode(player)
    end
end