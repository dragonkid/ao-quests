# Intro

This is an extension of the Grid. Add some airdrops. Airdrops will be dropped randomly on the grid every 1 minutes.

* Healing Draught: Restore 20 HP
* Energy Phial: Restore 20 MP
* Vista Lens: Extends the attack range to 3
* Power Gem: Doubles the attack damage

# Howto

```lua
Game = "Kd7kqNEt5gV_6b59mqUSTXhwfsT3Et08rnA-iIiAO5k"

Send({ Target = Game, Action = "Register" })
Send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
Send({Target = ao.id, Action = "Tick"})
```
