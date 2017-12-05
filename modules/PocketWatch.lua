local PocketWatch = {}
local watchMt = { __index = PocketWatch }

PocketWatch.isEarly = true
PocketWatch.taskMap = {}

function PocketWatch:New()
  --creates a new Pocketwatch object.
  local watch = setmetatable({
    taskList = {},
    isBlocking = nil,
    taskLimit = 10,
    taskCount = 0,
    globalCount = 0,
    ticksWorked = 0,
    now = 0,
  }, watchMt)
  return watch
end

function PocketWatch:Do(id, ...)
  local task = self.taskMap[id]
  if task then
    if self.isBlocking or self.isEarly then
      return task(...)
    end
    if self.taskCount < self.taskLimit then
      self.taskCount = self.taskCount + 1
      return task(...)
    else --too much! relinquish control and let the simulation tick
      if not self.working then
        self.working = true
        script.on_event(defines.events.on_tick, self.ContinueWork)
      end
      self:Schedule({id, ...})
    end
  end
end

function PocketWatch:Schedule(task, old)
  local taskList
  if not self.taskList[self.now + 1] then
    self.taskList[self.now + 1] = {}
  end
  taskList = self.taskList[self.now + 1]
  if old then
    table.insert(taskList, 1, task)
  else
    table.insert(taskList, task)
  end
  if not self.working then
    script.on_event(defines.events.on_tick, self.ContinueWork)
  end
end

function PocketWatch:DoTasks(time)
  if not time then return end
  local tooBusy
  self.now = time
  self.globalCount = self.globalCount + self.taskCount
  self.taskCount = 0
  self.isEarly = false
  local tasks = self.taskList[self.now]
  for _, task in ipairs(self.tasks) do
      if self.taskCount < self.taskLimit then
        self:Do(unpack(task))
      else
        tooBusy = true
        self:Schedule(task, true)
      end
    end
  end
  if self.taskCount > 0 then
    self.ticksWorked = self.ticksWorked + 1
  end
  self.working = tooBusy
  self.taskList[self.now] = nil
end

function PocketWatch:ContinueWork(event)
  self:DoTasks(event.tick)
  if not self.working then
    script.on_event(defines.events.on_tick, nil)
  end
end

function PocketWatch:Dump(method, playerID)
  local toLog = ([[----------------------------------------------
ProductionChain: PocketWatch Dump at: %d
* ID: %s
* Unfinished tasks: %d
* Total Tasks completed: %d
* Ticks Spent working: %d
]]):format(
    self.now or 0,
    self.id or "unkown",
    #(self.taskList[self.now] or {}),
    self.globalCount or 0,
    self.ticksWorked or 0
  )
  if method == "file" then
    game.write_file("PocketWatch_log", toLog, true, playerID)
  elseif method == "console" then
    local print = playerID and game.players[playerID].print or game.print
    print(toLog)
  elseif method == "log" then
    log(toLog)
  end
end


function PocketWatch.setmetatables(watch)
  setmetatable(watch, watchMt)
  return watch
end

return PocketWatch
