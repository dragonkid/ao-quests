-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or {}
InAction = false -- Prevents the agent from taking multiple actions at once.
BeingAttacked = false

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

local function situationalAwareness()
    local player = LatestGameState.Players[ao.id]

    local targetId = nil
    local targetInRange = false
    local awayDirection = ""
    local towardsDirection = ""
    local nearestPlayer = nil
    local nearestDistance = 9999999

    -- Check if any player is within range and find the nearest player
    for target, state in pairs(LatestGameState.Players) do
        if target == ao.id then
            goto continue
        end
        if target == "ET1HkDJVwGp9nDDyAeDkCOm7nU4ymi4vkmLS3rdSsXo" and inRange(player.x, player.y, state.x, state.y, 1) then
        -- if inRange(player.x, player.y, state.x, state.y, 1) then
            targetId = target
            targetInRange = true
            break
        end

        local distance = calDistance(player.x, player.y, state.x, state.y)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestPlayer = target
        end
        ::continue::
    end

    nearestPlayer = "ET1HkDJVwGp9nDDyAeDkCOm7nU4ymi4vkmLS3rdSsXo"

    if nearestPlayer ~= nil then
        local targetState = LatestGameState.Players[nearestPlayer]
        local dx = targetState.x - player.x
        local dy = targetState.y - player.y

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

    return targetInRange, targetId, awayDirection, towardsDirection, nearestPlayer
end

-- Decides the next action based on player proximity and energy.
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
local function decideNextAction()
    local targetInRange = false
    local target = nil
    local awayDirection = nil
    local towardsDirection = nil
    local nearestPlayer = nil
    local player = LatestGameState.Players[ao.id]

    targetInRange, target, awayDirection, towardsDirection, nearestPlayer = situationalAwareness()

    if player.health < 40 then
        print(colors.red .. "Player health is low. Withdrawing." .. colors.reset)
        Send({Target = Game, Action = "Withdraw" })
    end

    if targetInRange then
        -- if player.energy >= 50 or LatestGameState.Players[target].health <= 10 then
        if player.energy >= LatestGameState.Players[target].health then
            BeingAttacked = false
            print(colors.red .. "Player " .. target .. " in range. Attacking." .. colors.reset)
            ao.send({
                Target = Game,
                Action = "PlayerAttack",
                Player = ao.id,
                AttackEnergy = tostring(player.energy)
            })
        end

        if player.energy < LatestGameState.Players[target].health and BeingAttacked then
            print("Player has insufficient energy(" ..
                player.energy .. "). Moving away from " .. nearestPlayer .. ". Direction: " .. awayDirection)
            ao.send({
                Target = Game,
                Action = "PlayerMove",
                Player = ao.id,
                Direction = awayDirection
            })
        end
    else
        print("No player in range. Moving towards " .. nearestPlayer ..". Direction: " .. towardsDirection)
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = towardsDirection })
    end
    InAction = false -- InAction logic added
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add("PrintAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    if msg.Event == "Started-Waiting-Period" then
        ao.send({
            Target = ao.id,
            Action = "AutoPay"
        })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
        InAction = true -- InAction logic added
        ao.send({ Target = Game, Action = "GetGameState" })
    elseif InAction then -- InAction logic added
        print("[PrintAnnouncements]Previous action still in progress. Skipping.")
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
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

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add("AutoPay", Handlers.utils.hasMatchingTag("Action", "AutoPay"), function(msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
end)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Statue:" ..  LatestGameState.GameMode)
        for k, v in pairs(LatestGameState.Players) do
            local name = ""
            if v.name ~= nil then
                name = v.name
            end
            print("Player: " ..  k .. " Energy: " .. v.energy .. " Health: " .. v.health .. " X: " .. v.x .. " Y: " .. v.y .. " Name: " .. name)
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

Handlers.add(
    "AutoWithdraw",
    Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
    function(msg)
        print(colors.red .. "Player health is low. Withdrawing." .. colors.reset)
        ao.send({ Target = Game, Action = "Withdraw" })
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
            elseif playerEnergy < 50 then
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
                    AttackEnergy = tostring(50)
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

-- Game = "bmgDDTk5sJk7ohDidto3Vmm-ur2BopjJtmX0mVYF-ig"

-- Send({ Target = Game, Action = "Register" })
-- Send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})


CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
Game = "MsVWw4JeFHBEHQZxbs1n8JvuqgGsuUUYI8sg40ECJ44"
-- Send({Target = CRED, Action = "Transfer", Quantity = "10", Recipient = Game})
-- Send({Target = ao.id, Action = "Tick"})