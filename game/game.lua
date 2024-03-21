Game = "0rVZYFxvfJpO__EfOz0_PUQ3GFE9kEaES0GkUDNXjvE"

Send({ Target = Game, Action = "Register" })
Send({ Target = Game, Action = "RequestTokens"})
Send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
