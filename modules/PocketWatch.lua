--[[
General Purpose Tick Spreader for Factorio.

Usage:
local PocketWatch = require"path.to.PocketWatch"
-- defines the PocketWatch class. The path is relative, as always with require.

PocketWatch.taskMap[id] = <function>
-- teach PocketWatch how to perform a task. Since functions cannot be serialized currently, we can't simply drop function objects (especially closures) into the global table.
-- I recommend that you structure your recursive task functions like so (this creates behavior that is somewhat similar to how coroutines work)
PocketWatch.taskMap['someTask'] = function(state, ...)

  -- perform some small manipulation to state

  return watch:Do('someTask', state, ...) -- where watch is a PocketWatch Object
end

global.watch = PocketWatch:New()
-- create a new PocketWatch Object

watch:Do(id, ...)
-- will attempt to call PocketWatch.taskMap[id](...). If the # of tasks performed in the current tick exceeds the
-- task limit, then this will Schedule the task for the next tick, and allow the simulation to continue.

watch.isBlocking = <bool>
-- if isBlocking is true, then PocketWatch will act synchronously and immediately perform all tasks assigned, instead of spreading them across ticks.

watch.taskLimit = <uint>
-- maximum # of tasks that a single watch can perform, before it relinquishes control and allows the simulation to continue.

watch:Schedule(task, isOld, sleepTime)
-- schedules a task for later execution (by default on the next tick).
-- The task object must be an array whose first element (the 1 index) maps to a valid function from PocketWatch.taskMap,
-- and the extra information in the task object is what is passed to the task function.
-- The isOld flag causes the task to be placed last in the queue, instead of in the front.

watch.ContinueWork
-- should be registered to on_tick by on_load script, to ensure that desyncs do not occur. Otherwise, this should not be touched.

watch:Dump(method, playerID)
-- dumps stats about the watch to script-output, current-log, or the console, depending on the value of method.
-- "file" sends the dump to script-output, "log" goes to the log, and "console" goes to the console. PlayerID can be specified to force the dump to only occur for one player.

watch:DoTasks(time)
-- Performs tasks scheduled for the specified time. Should not be necessary to explicitly call - on_tick will handle that.

PocketWatch.setmetatables(watch)
-- Call this on_load to ensure that metatables are repaired from the loading process.
--]]
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
    futureTasks = 0
    emptyTicks = 0
    now = 0,
  }, watchMt)
  return watch
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
    self.emptyTicks or 0,
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
