Members = Members or {}

Handlers.add(
    "Register",
    Handlers.utils.hasMatchingTag("Action", "Register"),
    function (msg)
        table.insert(Members, msg.From)
        Handlers.utils.reply("registered")(msg)
    end
)

Handlers.add(
    "Broadcast",
    Handlers.utils.hasMatchingTag("Action", "Broadcast"),
    function (msg)
        if Balances[msg.From] == nil or tonumber(Balances[msg.From]) < 1 then
            print("UNAUTHORIZED: " .. msg.From)
            return
        end

        print("Broadcasting message from " .. msg.From .. ", Content: " .. msg.Data)
        for _, member in ipairs(Members) do
            ao.send({
                Target = member,
                Action = "Broadcasted",
                Broadcaster = msg.From,
                Data = msg.Data,
            })
        end
        Handlers.utils.reply("Broadcasted...")(msg)
    end
)

-- regist yourself to chatroom first
-- Send({ Target = ao.id, Action = "Register" })

-- then invite Morpheus to join
-- Morpheus = "P2RS2VtQ4XtYEvAXYDulEA9pCBCIRpJDcakTR9aW434"
-- Send({ Target = Morpheus, Action = "Join" })

-- invite Trinity to join
-- Trinity = "6JYFAOkRBMPhnuWSu1meAfui6wA2zJqPzcajImveXuQ"
-- Send({ Target = Trinity, Action = "Join" })

-- create a token by blueprint, then transfer to Trinity
-- .load-blueprint token
-- Send({ Target = ao.id, Action = "Transfer", Recipient = Trinity, Quantity = "1000"})
