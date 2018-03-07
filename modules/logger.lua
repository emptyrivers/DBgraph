local logger = {}

logger.level = 4

logger.notifyMessage = "logger message %s at t%=%d: %s"

logger.alwaysPrintToConsole = false

logger.defaultMethod = "console"

logger.allowError = true -- if true, then logger:log(level, message, "error") will call error() and halt execution of the game.

function logger:log(messageLevel, method, message, playerID) 
    if self.level == 0 then 
        return 
    elseif messageLevel <= self.level then
        method = (method ~= "error" or self.allowError) and method or self.defaultMethod
        if method == "error" then
            error(message, playerID or 2)
        elseif method == "console" then
            playerID = playerID or "emptyrivers"
            local print = (playerID and game.players[playerID] and game.players.print) or game.print
            print(message)
        elseif method == "log" then
            log(message)
            if self.alwaysPrintToConsole or self.level >= 5 then
                game.print(self.notifyMessage:format("logged", game and game.tick or -1, self:trim(message, 20)))
            end
        elseif method == "file" then
            game.write_file(message.filePath..'.log', message.data, message.append, message.for_player or 0)
            if self.alwaysPrintToConsole or self.level >= 5 then
                game.print(self.notifyMessage:format("written to script_output\\"..mesage.filePath, game and game.tick or -1, self:trim(message.data, 20)))
            end
        end
    end
end

function logger:trim(message,len)
    return #message <= len and message or (message:sub(1,len).."...")
end

return logger