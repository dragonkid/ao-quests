local html = [[
<html>
    <head>
        <style>
            body {
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                margin: 0;
            }
        </style>
    </head>
    <body>
        <h1>Big Blue Green Dot Club</h1>
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <circle cx="50" cy="50" r="40" fill="green" />
        </svg>
    </body>
</html>
]]

Send({
    Target = ao.id,
    Data = html,
    Tags = {
        ["Content-Type"] = "text/html",
    },
    Action = "UI-Deployed"
})

Handlers.add(
    "PrintEndpoint",
    Handlers.utils.hasMatchingTag("Action", "UI-Deployed"),
    function(msg)
        print("Endpoint: g8way.io/" .. msg.Id)
    end
)
