-- Pocketwatch! Spreads work across multiple ticks. Takes control of on_tick


local PocketWatch = {}
local watchMt = { __index = PocketWatch }

PocketWatch.isEarly = true
PocketWatch.taskMap = {}

function PocketWatch:Init()
  return self:New()
end

function PocketWatch:Load()
end

function PocketWatch:New()
  --creates a new Pocketwatch object.
  return self.setmetatables({
    taskList = {},
    isBlocking = nil,
    taskLimit = 10,
    taskCount = 0,
    globalCount = 0,
    ticksWorked = 0,
    futureTasks = 0,
    emptyTicks = 0,
    now = 0,
  })
end

function PocketWatch:Do(id, ...)
  local task = self.taskMap[id]
  if task then
    if self.isBlocking or self.isEarly then
      return task(...)
    elseif self.taskCount < self.taskLimit then
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

function PocketWatch:Schedule(task, old, sleepTime)
  local interval, taskList = sleepTime or 1
  if not self.taskList[self.now + interval] then
    self.taskList[self.now + interval] = {}
  end
  taskList = self.taskList[self.now + interval]
  if old then
    table.insert(taskList, interval, task)
  else
    self.futureTasks = self.futureTasks + 1
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
      self.futureTasks = self.futureTasks - 1
      self:Do(unpack(task))
    else
      tooBusy = true
      self:Schedule(task, true)
    end
  end
  if self.taskCount > 0 then
    self.ticksWorked = self.ticksWorked + 1
  else
    self.emptyTicks = self.emptyTicks + 1
  end
  self.working = tooBusy
  self.taskList[self.now] = nil
end

function PocketWatch:ContinueWork(event)
  self:DoTasks(event.tick)
  if self.futureTasks == 0 then
    script.on_event(defines.events.on_tick, nil)
  end
end

function PocketWatch:Dump(method, playerID)
  local toLog = ([[----------------------------------------------
ProductionChain: PocketWatch Dump at: %d
* ID: %s
* Unfinished tasks:                %d
* Total Tasks completed:           %d
* Ticks Spent working:             %d
* Ticks Spent Registered but idle: %d
]]):format(
    self.now or 0,
    self.id or "unkown",
    self.futureTasks or 0,
    self.globalCount or 0,
    self.ticksWorked or 0,
    self.emptyTicks or 0
  )
  if method == "file" then
    game.write_file("PocketWatch_log", toLog, true, playerID)
  elseif method == "newfile" then 
    game.write_file("PocketWatch_log", toLog, false, playerID)
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
