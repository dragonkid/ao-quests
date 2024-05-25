-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or {}
InAction = false -- Prevents the agent from taking multiple actions at once.
BeingAttacked = false
Target = nil

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
    local towardsDirection = ""
    local nearestPlayer = nil
    local nearestDistance = 9999999

    -- find the nearest player
    for target, state in pairs(LatestGameState.Players) do
        if target == ao.id then
            goto continue
        end

        local distance = state.health
        -- local distance = calDistance(player.x, player.y, state.x, state.y)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestPlayer = target
        end


        ::continue::
    end

    -- if LatestGameState.Players["OwobNCCgQaiOb1W37rY6VMpWeZHDIpmGw7mj71-4WvA"] ~= nil then
    --     nearestPlayer = "OwobNCCgQaiOb1W37rY6VMpWeZHDIpmGw7mj71-4WvA"
    -- end

    -- -- BattleBot
    -- if LatestGameState.Players["YIIAgYMedkwm84WDL61GeTBJVvPsdWrZnqtE-slJvrw"] ~= nil then
    --     nearestPlayer = "YIIAgYMedkwm84WDL61GeTBJVvPsdWrZnqtE-slJvrw"
    -- end

    -- if LatestGameState.Players["o7ojWM_2GCpjEq9LbQpNt98rK0yYR5sttDbXn_m7jgA"] ~= nil then
    --     nearestPlayer = "o7ojWM_2GCpjEq9LbQpNt98rK0yYR5sttDbXn_m7jgA"
    -- end

    -- -- Jonny5
    -- if LatestGameState.Players["PX6KWOIMVwYOSrxGd54QrkvjOzdKb2M2LAu1O5IqeDM"] ~= nil then
    --     nearestPlayer = "PX6KWOIMVwYOSrxGd54QrkvjOzdKb2M2LAu1O5IqeDM"
    -- end

    -- -- Trinity
    -- if LatestGameState.Players["ET1HkDJVwGp9nDDyAeDkCOm7nU4ymi4vkmLS3rdSsXo"] ~= nil then
    --     nearestPlayer = "ET1HkDJVwGp9nDDyAeDkCOm7nU4ymi4vkmLS3rdSsXo"
    -- end

    -- Doge
    -- if LatestGameState.Players["FD5Lava4E0eG6mOFWEQ-epiwScEG1vrFP5uP6In7wXQ"] ~= nil then
    --     nearestPlayer = "FD5Lava4E0eG6mOFWEQ-epiwScEG1vrFP5uP6In7wXQ"
    -- end

    -- check if player in range
    -- if target == "UiqtBPN1-VHYAhMWOCP7mOQ1CRPJS9kt3yHDX05Wodg" and inRange(player.x, player.y, state.x, state.y, 1) then
    if inRange(player.x, player.y, LatestGameState.Players[nearestPlayer].x, LatestGameState.Players[nearestPlayer].y, 1) then
        targetId = nearestPlayer
        targetInRange = true
        return targetInRange, targetId
    end


    if nearestPlayer ~= nil and LatestGameState.Players[nearestPlayer] ~= nil then
        local targetState = LatestGameState.Players[nearestPlayer]
        local dx = targetState.x - player.x
        local dy = targetState.y - player.y

        if dy > 0 then
            towardsDirection = towardsDirection .. "Down"
        elseif dy < 0 then
            towardsDirection = towardsDirection .. "Up"
        end

        local steps = math.abs(dy) - 1
        print("Move " .. steps .. " steps in " .. towardsDirection .. " direction.")
        if steps > 0 then
            for _ = 1, math.abs(dy) do
                Send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = towardsDirection })
            end
        end

        if dx > 0 then
            towardsDirection = "Right"
        elseif dx < 0 then
            towardsDirection = "Left"
        end

        local steps = math.abs(dx) - 1
        print("Move " .. steps .. " steps in " .. towardsDirection .. " direction.")
        if steps > 0 then
            for _ = 1, math.abs(dx) do
                Send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = towardsDirection })
            end
        end

    end

    Target = nearestPlayer

    return true, nearestPlayer
end

-- Decides the next action based on player proximity and energy.
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
local function decideNextAction()
    local targetInRange = false
    local target = nil
    local player = LatestGameState.Players[ao.id]

    targetInRange, target = situationalAwareness()

    if player.health < 55 then
        print(colors.red .. "Player health is low. Withdrawing." .. colors.reset)

        Send({Target = Game, Action = "Withdraw" })
    end

    if targetInRange then
        -- if player.energy >= 50 or LatestGameState.Players[target].health <= 10 then
        if player.energy >= LatestGameState.Players[target].health or player.energy >= 30 then
            BeingAttacked = false
            print(colors.red .. "Player " .. target .. " in range. Attacking." .. colors.reset)
            Send({
                Target = Game,
                Action = "PlayerAttack",
                Player = ao.id,
                AttackEnergy = tostring(player.energy)
            })
        end

        -- if player.energy < LatestGameState.Players[target].health and BeingAttacked then
        --     print("Player has insufficient energy(" ..
        --         player.energy .. "). Moving away from " .. nearestPlayer .. ". Direction: " .. awayDirection)
        --     ao.send({
        --         Target = Game,
        --         Action = "PlayerMove",
        --         Player = ao.id,
        --         Direction = awayDirection
        --     })
        -- end
    -- else
    --     print("No player in range. Moving towards " .. nearestPlayer .." Direction: " .. towardsDirection .. " Steps: " .. moveSteps)
    --     for _ = 1, moveSteps do
    --         Send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = towardsDirection })
    --     end
    end
    InAction = false -- InAction logic added
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add("PrintAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    if msg.Event == "Started-Waiting-Period" then
        Send({ Target = ao.id, Action = "AutoPay" })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
        InAction = true -- InAction logic added
        Send({ Target = Game, Action = "GetGameState" })
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
        Send({ Target = Game, Action = "GetGameState" })
    else
        print("[GetGameStateOnTick]Previous action still in progress. Skipping.")
    end
end)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add("AutoPay", Handlers.utils.hasMatchingTag("Action", "AutoPay"), function(msg)
    print("Auto-paying confirmation fees.")
    Send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
end)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        Send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Statue:" ..  LatestGameState.GameMode)
        for k, v in pairs(LatestGameState.Players) do
            local name = ""
            if v.name ~= nil then
                name = v.name
            end
            if k == ao.id then
                print(colors.green .. "Player: " ..  k .. " Energy: " .. v.energy .. " Health: " .. v.health .. " X: " .. v.x .. " Y: " .. v.y .. " Name: " .. name .. colors.reset)
            elseif k == Target then
                print(colors.red .. "Player: " ..  k .. " Energy: " .. v.energy .. " Health: " .. v.health .. " X: " .. v.x .. " Y: " .. v.y .. " Name: " .. name .. colors.reset)
            else
                print("Player: " ..  k .. " Energy: " .. v.energy .. " Health: " .. v.health .. " X: " .. v.x .. " Y: " .. v.y .. " Name: " .. name)
            end
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
        Send({ Target = ao.id, Action = "Tick" })
    end
)

Handlers.add(
    "AutoWithdraw",
    Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
    function(msg)
        if LatestGameState.Players[ao.id] ~= nil then
            print(colors.red .. "Reward Noticed. Withdrawing." .. colors.reset)
            if msg.Tags.Quantity ~= nil then
                print("Reward: " .. msg.Tags.Quantity)
                -- Send({ Target = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc", Action = "Transfer", Recipient = "--VDOfP6JI-JmfPlPP0yGcNrekFdAwE-1QCKaoI2Tfw", Quantity = msg.Tags.Quantity})
            end
            Send({ Target = Game, Action = "Withdraw" })
        end
    end
)

Handlers.add(
    "OnRemoved",
    Handlers.utils.hasMatchingTag("Action", "Removed"),
    function (msg)
        print(colors.red .. "Removed. Auto re-entrance the game." .. colors.reset)
        -- ao.send({ Target = Game, Action = "Withdraw" })
        Send({Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game})
        InAction = false
        Send({Target = ao.id, Action = "Tick"})
    end
)

Handlers.add(
    "OnEliminated",
    Handlers.utils.hasMatchingTag("Action", "Eliminated"),
    function (msg)
        print(colors.red .. "Eliminated. Auto re-entrance the game." .. colors.reset)
        Send({ Target = Game, Action = "Withdraw" })
    end
)

Handlers.add(
    "TriggerOnPaymentReceived",
    Handlers.utils.hasMatchingTag("Action", "Payment-Received"),
    function ()
        print(colors.red .. "Payment Received." .. colors.reset)
        InAction = false
        Send({Target = ao.id, Action = "Tick"})
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

        if LatestGameState.Players[ao.id] ~= nil and LatestGameState.Players[ao.id].health < 70 then
            print(colors.red .. "Player being attacked. And the health is low. Withdrawing." .. colors.reset)
            Send({ Target = Game, Action = "Withdraw" })
        end
    end
)

-- Game = "bmgDDTk5sJk7ohDidto3Vmm-ur2BopjJtmX0mVYF-ig"

-- Send({ Target = Game, Action = "Register" })
-- Send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})


CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
-- Game = "-vsAs0-3xQw6QUAYbUuonTbXAnFNJtzqhriKKOymQ9w"
-- Game = "ERRyYc0K3XurSBjpiTceT7Cg9acJaz-bES6w8SXhk-M"


-- Send({Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game})
-- Send({Target = ao.id, Action = "Tick"})
-- Send({Target = Game, Action = "Withdraw" })

-- Handlers.remove("OnRemoved")
-- Send({ Target = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc", Action = "Transfer", Recipient = "--VDOfP6JI-JmfPlPP0yGcNrekFdAwE-1QCKaoI2Tfw", Quantity = "10000"})

