-- Pocketwatch! Spreads work across multiple ticks. Takes control of on_tick.


local PocketWatch = {}
local watchMt = { __index = PocketWatch }
local inspect = require 'inspect'

PocketWatch.taskMap = {}
PocketWatch.timers = {}
PocketWatch.mt = watchMt

function PocketWatch:Init()
  global.timers = self.timers
  return timers
end

function PocketWatch:Load()
  for _, timer in pairs(global.timers) do
    self.setmetatable(timer)
  end
  return global.timers
end

function PocketWatch:New(id)
  --creates a new Pocketwatch object.
  self.timers[id] = self.timers[id] or self.setmetatable({
    taskList = {},
    id = id,
    isBlocking = nil,
    taskLimit = 1,
    taskCount = 0,
    globalCount = 0,
    ticksWorked = 0,
    futureTasks = 0,
    emptyTicks = 0,
    now = 0,
    type = "PocketWatch",
  })
  return timer
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
  local nextTick, taskList = game.tick + (sleepTime or 1)
  if not self.taskList[nextTick] then
    self.taskList[nextTick] = {}
  end
  taskList = self.taskList[nextTick]
  if old then
    table.insert(taskList, 1, task)
  else
    self.futureTasks = self.futureTasks + 1
    table.insert(taskList, task)
  end
  if not self.working then
    script.on_event(defines.events.on_tick, self.ContinueWork)
  end
end

function PocketWatch:DoTasks()
  local now = game.tick
  local tooBusy
  self.globalCount = self.globalCount + self.taskCount
  self.taskCount = 0
  local tasks = self.taskList[now]
  if tasks then
    for _, task in ipairs(tasks) do
      if self.taskCount < self.taskLimit then
        self.futureTasks = self.futureTasks - 1
        self:Do(unpack(task))
      else
        tooBusy = true
        self:Schedule(task, true)
      end
    end
  end
  if self.taskCount > 0 then
    self.ticksWorked = self.ticksWorked + 1
  else
    self.emptyTicks = self.emptyTicks + 1
  end
  self.working = tooBusy
  self.taskList[now] = nil
end

function PocketWatch.ContinueWork(event)
  local futureTasks = 0
  for _, timer in pairs(PocketWatch.timers) do
    timer:DoTasks(game.tick)
    futureTasks = futureTasks + timer.futureTasks
  end
  if futureTasks == 0 then
    script.on_event(defines.events.on_tick, nil)
  end
end

function PocketWatch:Dump()
  local toLog = ([[
PocketWatch Dump at: %d
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
  return toLog
end

function PocketWatch.setmetatable(watch)
  setmetatable(watch, watchMt)
  return watch
end

return PocketWatch
