-- AO EFFECT: Game Mechanics for AO Arena Game

-- Game grid dimensions
Width = 40  -- Width of the grid
Height = 40 -- Height of the grid
Range = 1   -- The distance for blast effect

-- Player energy settings
MaxEnergy = 100  -- Maximum energy a player can have
EnergyPerSec = 1 -- Energy gained per second

-- Attack settings
AverageMaxStrengthHitsToKill = 3 -- Average number of hits to eliminate a player

-- Airdrop
LastAirdrop = nil
AirdropInterval = 60000 -- 1 minute
-- Airdrop types
HealingDraught = "Healing Draught"
EnergyPhial = "Energy Phial"
VistaLens = "Vista Lens" -- increased range to 3
PowerGem = "Power Gem" -- double damage
AirdropTypes = { HealingDraught, EnergyPhial, VistaLens, PowerGem }

Airdrop = nil

-- GameMode = "Not-Started"
-- Players = {}
-- Waiting = {}
-- Listeners = {}
-- PaymentToken = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"

-- Initializes default player state
-- @return Table representing player's initial state
function playerInitState()
    return {
        x = math.random(0, Width),
        y = math.random(0, Height),
        health = 100,
        energy = 0,
        weapon = nil
    }
end

function resetPlayerWithWeapon()
   for player, state in pairs(Players) do
        if state.weapon then
            state.weapon = nil
        end
    end
end


local function airdrop()
    resetPlayerWithWeapon()
    local json = require("json")

    local x = math.random(0, Width)
    local y = math.random(0, Height)
    local airdropType = AirdropTypes[math.random(1, #AirdropTypes)]

    Airdrop = { x = x, y = y, type = airdropType }
    print("Airdrop: " .. x .. "," .. y .. " Type: " .. airdropType)

    for player, _ in pairs(Players) do
        ao.send({ Target = player, Action = "Airdrop", Data = json.encode(Airdrop)})
    end
end


-- Function to incrementally increase player's energy
-- Called periodically to update player energy
function onTick()
    if GameMode ~= "Playing" then return end -- Only active during "Playing" state

    if LastAirdrop == nil or Now - LastAirdrop >= AirdropInterval then
        LastAirdrop = Now
        airdrop()
    end

    if LastTick == nil then LastTick = Now end

    local Elapsed = Now - LastTick
    if Elapsed >= 1000 then -- Actions performed every second
        for player, state in pairs(Players) do
            local newEnergy = math.floor(math.min(MaxEnergy, state.energy + (Elapsed * EnergyPerSec // 2000)))
            state.energy = newEnergy
        end
        LastTick = Now
    end
end

-- Handles player movement
-- @param msg: Message request sent by player with movement direction and player info
function move(msg)
    local playerToMove = msg.From
    local direction = msg.Tags.Direction

    local directionMap = {
        Up = { x = 0, y = -1 },
        Down = { x = 0, y = 1 },
        Left = { x = -1, y = 0 },
        Right = { x = 1, y = 0 },
        UpRight = { x = 1, y = -1 },
        UpLeft = { x = -1, y = -1 },
        DownRight = { x = 1, y = 1 },
        DownLeft = { x = -1, y = 1 }
    }

    -- calculate and update new coordinates
    if directionMap[direction] then
        local newX = Players[playerToMove].x + directionMap[direction].x
        local newY = Players[playerToMove].y + directionMap[direction].y

        -- updates player coordinates while checking for grid boundaries
        Players[playerToMove].x = (newX - 1) % Width + 1
        Players[playerToMove].y = (newY - 1) % Height + 1

        announce("Player-Moved",
            playerToMove .. " moved to " .. Players[playerToMove].x .. "," .. Players[playerToMove].y .. ".")

        -- test if player has reached the airdrop
        if Airdrop and Players[playerToMove].x == Airdrop.x and Players[playerToMove].y == Airdrop.y then
            if Airdrop.type == HealingDraught then
                Players[playerToMove].health = math.min(100, Players[playerToMove].health + 20)
            elseif Airdrop.type == EnergyPhial then
                Players[playerToMove].energy = math.min(MaxEnergy, Players[playerToMove].energy + 20)
            elseif Airdrop.type == VistaLens then
                Players[playerToMove].weapon = VistaLens
            elseif Airdrop.type == PowerGem then
                Players[playerToMove].weapon = PowerGem
            end
            print("Player " .. playerToMove .. " picked up " .. Airdrop.type)
            local json = require("json")
            for player, _ in pairs(Players) do
                ao.send({ Target = player, Action = "Airdrop-Picked", Data = json.encode({player = playerToMove, type = Airdrop.type})})
            end
            Airdrop = nil
        end
    else
        ao.send({ Target = playerToMove, Action = "Move-Failed", Reason = "Invalid direction." })
    end
    onTick() -- Optional: Update energy each move
    ao.send({ Target = playerToMove, Action = "Tick" })
end

-- Handles player attacks
-- @param msg: Message request sent by player with attack info and player state
function attack(msg)
    local player = msg.From
    local attackEnergy = math.abs(tonumber(msg.Tags.AttackEnergy))

    local range = Range
    if Players[player].weapon == VistaLens then
        range = 3
    end

    -- get player coordinates
    local x = Players[player].x
    local y = Players[player].y

    -- check if player has enough energy to attack
    if Players[player].energy < attackEnergy then
        ao.send({ Target = player, Action = "Attack-Failed", Reason = "Not enough energy." })
        return
    end

    -- update player energy and calculate damage
    Players[player].energy = Players[player].energy - attackEnergy
    local damage = math.floor((math.random() * 2 * attackEnergy) * (1 / AverageMaxStrengthHitsToKill))
    if Players[player].weapon == PowerGem then
        damage = damage * 2
    end

    announce("Attack", player .. " has launched a " .. damage .. " damage attack from " .. x .. "," .. y .. "!")

    -- check if any player is within range and update their status
    for target, state in pairs(Players) do
        if target ~= player and inRange(x, y, state.x, state.y, range) then
            local newHealth = state.health - damage
            if newHealth <= 0 then
                eliminatePlayer(target, player)
            else
                Players[target].health = newHealth
                ao.send({ Target = target, Action = "Hit", Damage = tostring(damage), Health = tostring(newHealth) })
                ao.send({ Target = player, Action = "Successful-Hit", Recipient = target, Damage = tostring(damage), Health =
                tostring(newHealth) })
            end
        end
    end
    ao.send({ Target = player, Action = "Tick" })
end

-- Helper function to check if a target is within range
-- @param x1, y1: Coordinates of the attacker
-- @param x2, y2: Coordinates of the potential target
-- @param range: Attack range
-- @return Boolean indicating if the target is within range
function inRange(x1, y1, x2, y2, range)
    return x2 >= (x1 - range) and x2 <= (x1 + range) and y2 >= (y1 - range) and y2 <= (y1 + range)
end

-- HANDLERS: Game state management for AO-Effect

-- Handler for player movement
Handlers.add("PlayerMove", Handlers.utils.hasMatchingTag("Action", "PlayerMove"), move)

-- Handler for player attacks
Handlers.add("PlayerAttack", Handlers.utils.hasMatchingTag("Action", "PlayerAttack"), attack)

Handlers.prepend("RequestTokens",
    Handlers.utils.hasMatchingTag("Action", "RequestTokens"),
    Handlers.utils.reply("Sorry, this game does not give out tokens you must use $CRED")
)
