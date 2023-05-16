<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD041 -->

<img align="right" width="300" src="res/logo.png" />

# Wizgoose

![Validation](https://github.com/Daw588/wizgoose/actions/workflows/validation.yaml/badge.svg)

Wizgoose is a library that adds replication and change tracking to Luau tables through metatable magic. Said magical objects have `Value` property which knows when it's changed, what changed, and how it changed, thus allowing it to signal changes, such as when property changes, or when an array has an item added into it or removed from, this applies both to server and client.

## Resources

- [GitHub](https://github.com/Daw588/wizgoose)
- [Documentation](https://moonward.gitbook.io/wizgoose/)
- [Download](https://create.roblox.com/marketplace/asset/10207465581)
- [License](LICENSE)

## Example

```lua
-- Server.luau
local sessionData = Wizgoose.new("session-data", {
    timer = 0
})

for i = 100, 1, -1 do
    sessionData.Value.timer = i
    task.wait(1)
end

-- Client.luau
local sessionData = Wizgoose.get("session-data")
sessionData:Changed("timer"):Connect(function(seconds)
    print(seconds)
end)
```

## Users

- [Brawling Grounds](https://www.roblox.com/games/9386846196/) (2.7M+ visits)
