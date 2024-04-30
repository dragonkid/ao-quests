-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or {}
Airdrop = Airdrop or nil
InAction = false -- Prevents the agent from taking multiple actions at once.
BeingAttacked = false
AttackEnergy = 10
Range = 1

HealingDraught = "Healing Draught"
EnergyPhial = "Energy Phial"
VistaLens = "Vista Lens" -- increased range to 3
PowerGem = "Power Gem" -- double damage

local colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m",
    yellow = "\27[33m",
}

local function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

local function calDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function getDirection(targetPos)
    local player = LatestGameState.Players[ao.id]

    local awayDirection = ""
    local towardsDirection = ""

    if targetPos ~= nil then
        local dx = targetPos.x - player.x
        local dy = targetPos.y - player.y

        if dy > 0 then
            towardsDirection = towardsDirection .. "Down"
            awayDirection = awayDirection .. "Up"
        elseif dy < 0 then
            towardsDirection = towardsDirection .. "Up"
            awayDirection = awayDirection .. "Down"
        end

        if dx > 0 then
            towardsDirection = towardsDirection .. "Right"
            awayDirection = awayDirection .. "Left"
        elseif dx < 0 then
            towardsDirection = towardsDirection .. "Left"
            awayDirection = towardsDirection .. "Right"
        end
    end

    return towardsDirection, awayDirection
end

local function getTargetPos()
    local player = LatestGameState.Players[ao.id]
    if Airdrop ~= nil then
        if Airdrop.type == VistaLens or Airdrop.type == PowerGem then
            return { x = Airdrop.x, y = Airdrop.y }, "Airdrop"
        end

        if Airdrop.type == HealingDraught and player.health < 50 then
            return { x = Airdrop.x, y = Airdrop.y }, "Airdrop"
        end

        if Airdrop.type == EnergyPhial and player.energy < 20 then
            return { x = Airdrop.x, y = Airdrop.y }, "Airdrop"
        end
    end

    local nearestPlayer = nil
    local nearestDistance = 9999999
    local players = LatestGameState.Players
    for target, state in pairs(players) do
        if target == ao.id then
            goto continue
        end

        local distance = calDistance(player.x, player.y, state.x, state.y)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestPlayer = target
        end
        ::continue::
    end

    return players[nearestPlayer], "Player"
end

local function situationalAwareness()
    local player = LatestGameState.Players[ao.id]

    local direction = ""

    local action = "DoNothing"

    local targetPos, targetType = getTargetPos()
    local towardsDirection, awayDirection = getDirection(targetPos)

    if targetType == "Airdrop" then
        print("Moving towards airdrop " .. targetPos .. ". Direction: " .. towardsDirection)
        return "Move", towardsDirection
    end

    if inRange(player.x, player.y, targetPos.x, targetPos.y, Range) then
        if player.energy < AttackEnergy and BeingAttacked then
            print("Player being attacked and has insufficient energy(" ..  player.energy .. "). Moving away from " .. targetPos .. ". Direction: " .. awayDirection)
            action = "Move"
            direction = awayDirection
        end

        if player.energy >= AttackEnergy then
            print(colors.red .. "Player " .. targetPos .. " in range. Attacking." .. colors.reset)
            action = "Attack"
        end
    else
        print("No player in range. Moving towards " .. targetPos .. ". Direction: " .. towardsDirection)
        action = "Move"
        direction = towardsDirection
    end

    return action, direction
end

-- Decides the next action based on player proximity and energy.
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
local function decideNextAction()
    local action, direction = situationalAwareness()

    if action == "Attack" then
        ao.send({
            Target = Game,
            Action = "PlayerAttack",
            Player = ao.id,
            AttackEnergy = tostring(10)
        })
    elseif action == "Move" then
        ao.send({
            Target = Game,
            Action = "PlayerMove",
            Player = ao.id,
            Direction = direction
        })
    else
        print("No action to take.")
    end
    InAction = false -- InAction logic added
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add("PrintAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    if msg.Event == "Started-Waiting-Period" then
        print("Auto-paying confirmation fees.")
        ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
        InAction = true -- InAction logic added
        ao.send({ Target = Game, Action = "GetGameState" })
    elseif InAction then -- InAction logic added
        print("[PrintAnnouncements]Previous action still in progress. Skipping.")
    end
end)

-- Handler to trigger game state updates.
Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function()
    if not InAction then -- InAction logic added
        InAction = true  -- InAction logic added
        print(colors.gray .. "Getting game state..." .. colors.reset)
        ao.send({ Target = Game, Action = "GetGameState" })
    else
        print("[GetGameStateOnTick]Previous action still in progress. Skipping.")
    end
end)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Statue:" ..
            LatestGameState.GameMode .. ". TimeRemaining:" .. LatestGameState.TimeRemaining)
        for k, v in pairs(LatestGameState.Players) do
            print(colors.gray ..
                "Player: " ..
                k .. " Energy: " .. v.energy .. " Health: " .. v.health .. " X: " .. v.x .. " Y: " .. v.y .. colors
                .reset)
        end
    end
)


-- Handler to decide the next best action.
Handlers.add(
    "DecideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function(msg)
        if LatestGameState.GameMode ~= "Playing" then
            print("Game not in playing mode. Skipping.")
            InAction = false -- InAction logic added
            return
        end
        print("Deciding next action.")
        decideNextAction()
        ao.send({
            Target = ao.id,
            Action = "Tick"
        })
    end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        BeingAttacked = true
        if not InAction then -- InAction logic added
            InAction = true -- InAction logic added
            local playerEnergy = LatestGameState.Players[ao.id].energy
            if playerEnergy == 0 then
                print(colors.red .. "Player has insufficient energy." .. colors.reset)
                ao.send({
                    Target = Game,
                    Action = "Attack-Failed",
                    Reason = "Player has no energy."
                })
            elseif playerEnergy < 10 then
                print(colors.red .. "Returning attack." .. colors.reset)
                ao.send({
                    Target = Game,
                    Action = "PlayerAttack",
                    Player = ao.id,
                    AttackEnergy = tostring(playerEnergy)
                })
            else
                print(colors.red .. "Returning attack." .. colors.reset)
                ao.send({
                    Target = Game,
                    Action = "PlayerAttack",
                    Player = ao.id,
                    AttackEnergy = tostring(10)
                })
            end
            InAction = false -- InAction logic added
            ao.send({
                Target = ao.id,
                Action = "Tick"
            })
        else
            print("[ReturnAttack]Previous action still in progress. Skipping.")
        end
    end
)

Handlers.add(
    "UpdateAirdrop",
    Handlers.utils.hasMatchingTag("Action", "Airdrop"),
    function(msg)
        Range = 1
        local json = require("json")
        Airdrop = json.decode(msg.Data)
        print("Airdrop updated. X:" .. Airdrop.x .. " Y:" .. Airdrop.y .. " Type:" .. Airdrop.type)
    end
)

Handlers.add(
    "AirdropPicked",
    Handlers.utils.hasMatchingTag("Action", "Airdrop-Picked"),
    function (msg)
        Airdrop = nil
        local json = require("json")
        local data = json.decode(msg.Data)
        print("Player " .. data.player .. " picked up " .. data.type)

        if data.type == VistaLens and data.player == ao.id then
            Range = 3
        end
    end
)


Game = "xqd2fD8u7LPnX-gio0ztbPjlveOKGsRer_366qXcNcE"
Send({ Target = Game, Action = "Register" })
