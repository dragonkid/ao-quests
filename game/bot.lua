-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
InAction = InAction or false -- Prevents the agent from taking multiple actions at once.

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function calDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

function situationalAwareness(players)
    local player = LatestGameState.Players[ao.id]

    local targetId = nil
    local targetInRange = false
    local awayDirection = nil
    local towardsDirection = nil
    local nearestPlayer = nil
    local nearestDistance = 9999999

    for target, state in pairs(LatestGameState.Players) do
        if target ~= ao.id and inRange(player.x, player.y, state.x, state.y, 1) then
            targetId = target
            targetInRange = true
            break
        end

        distance = calDistance(player.x, player.y, state.x, state.y)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestPlayer = target
        end
    end

    if nearestPlayer ~= nil then
        local targetState = LatestGameState.Players[nearestPlayer]
        local dx = targetState.x - player.x
        local dy = targetState.y - player.y

        if math.abs(dx) > math.abs(dy) then
            if dx > 0 then
                towardsDirection = "Right"
                awayDirection = "Left"
            else
                towardsDirection = "Left"
                awayDirection = "Right"
            end
        else
            if dy > 0 then
                towardsDirection = "Down"
                awayDirection = "Up"
            else
                towardsDirection = "Up"
                awayDirection = "Down"
            end
        end
    end

    return targetInRange, targetId, awayDirection, towardsDirection
end

-- Decides the next action based on player proximity and energy.
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
function decideNextAction()
    local targetInRange = false
    local target = nil
    local awayDirection = nil
    local towardsDirection = nil

    targetInRange, target, awayDirection, towardsDirection = situationalAwareness(LatestGameState.Players)

    if player.energy > 5 and targetInRange then
        print(colors.green .. "Player " .. target .. "in range. Attacking." .. colors.reset)
        ao.send({
            Target = Game,
            Action = "PlayerAttack",
            Player = ao.id,
            AttackEnergy = tostring(player.energy)
        })
    else
        if player.energy <= 5 then
            print("Player has insufficient energy(" .. player.energy .. "). Moving away from others.")
            ao.send({
                Target = Game,
                Action = "PlayerMove",
                Player = ao.id,
                Direction = awayDirection
            })
        else
            print("No player in range. Moving towards others.")
            ao.send({
                Target = Game,
                Action = "PlayerMove",
                Player = ao.id,
                Direction = towardsDirection
            })
        end
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
        ao.send({
            Target = Game,
            Action = "GetGameState"
        })
    elseif InAction then -- InAction logic added
        print("Previous action still in progress. Skipping.")
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
end)

-- Handler to trigger game state updates.
Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function()
    if not InAction then -- InAction logic added
        InAction = true -- InAction logic added
        --   print(colors.gray .. "Getting game state..." .. colors.reset)
        ao.send({
            Target = Game,
            Action = "GetGameState"
        })
    else
        print("Previous action still in progress. Skipping.")
    end
end)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add("AutoPay", Handlers.utils.hasMatchingTag("Action", "AutoPay"), function(msg)
    print("Auto-paying confirmation fees.")
    ao.send({
        Target = Game,
        Action = "Transfer",
        Recipient = Game,
        Quantity = "1000"
    })
end)

-- Handler to update the game state upon receiving game state information.
Handlers.add("UpdateGameState", Handlers.utils.hasMatchingTag("Action", "GameState"), function(msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({
        Target = ao.id,
        Action = "UpdatedGameState"
    })
    -- print("Game state updated. Print \'LatestGameState\' for detailed view.")
end)

-- Handler to decide the next best action.
Handlers.add("decideNextAction", Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"), function()
    if LatestGameState.GameMode ~= "Playing" then
        InAction = false -- InAction logic added
        return
    end
    print("Deciding next action.")
    decideNextAction()
    ao.send({
        Target = ao.id,
        Action = "Tick"
    })
end)

-- Handler to automatically attack when hit by another player.
Handlers.add("ReturnAttack", Handlers.utils.hasMatchingTag("Action", "Hit"), function(msg)
    if not InAction then -- InAction logic added
        InAction = true -- InAction logic added
        local playerEnergy = LatestGameState.Players[ao.id].energy
        if playerEnergy == undefined then
            print(colors.red .. "Unable to read energy." .. colors.reset)
            ao.send({
                Target = Game,
                Action = "Attack-Failed",
                Reason = "Unable to read energy."
            })
        elseif playerEnergy == 0 then
            print(colors.red .. "Player has insufficient energy." .. colors.reset)
            ao.send({
                Target = Game,
                Action = "Attack-Failed",
                Reason = "Player has no energy."
            })
        else
            print(colors.red .. "Returning attack." .. colors.reset)
            ao.send({
                Target = Game,
                Action = "PlayerAttack",
                Player = ao.id,
                AttackEnergy = tostring(playerEnergy)
            })
        end
        InAction = false -- InAction logic added
        ao.send({
            Target = ao.id,
            Action = "Tick"
        })
    else
        print("Previous action still in progress. Skipping.")
    end
end)

Game = "0rVZYFxvfJpO__EfOz0_PUQ3GFE9kEaES0GkUDNXjvE"

Send({ Target = Game, Action = "Register" })
