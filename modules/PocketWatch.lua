local PocketWatch = {}
local watchMt = { __index = PocketWatch }

function PocketWatch:Do(isPatient, task, ...)
  if (self.isBlocking or (not isPatient)) then
    return task(...)
  end
  if not self.isEarly then
    self.taskCount = self.taskCount + 1
    return task(...)
  else --too much! relinquish control and let the simulation tick
    self:Schedule(1, true, task, ...)
  end
end

function PocketWatch:Schedule(interval, isNew, ...)
  if self.isEarly then
    self.taskList.early = self.taskList.early or {}
    table.insert(self.taskList.early, {...})
  else
    self.taskList[self.now + interval] = self.taskList[self.now + interval] or {}
    if isNew then
      table.insert(self.taskList[self.now + interval], {...})
    else
      table.insert(self.taskList[self.now + interval], (...))
    end
  end
end

function PocketWatch:DoTasks(time)
  if not time then return end
  if self.tasks.early then
    self.taskCount = 0
    for _, task in ipairs(self.tasks,early) do
      if self.taskCount < self.taskLimit then
        self:Do(true, unpack(task))
      else
        self:Schedule(1, false, task)
      end
    end
  end
  self.tasks.early = nil
  self.isEarly = nil
  self.now = time
  local tasks = self.taskList[self.now]
  if tasks then
    for _, task in ipairs(tasks) do
      if self.taskCount < self.taskLimit then
        self:Do(true, unpack(task))
      else
        self:Schedule(1, false, task)
      end
    end
  end
  self.taskList[self.now] = nil
end

function PocketWatch:New()
  --creates a new Pocketwatch object.
  local watch = setmetatable({
    taskList = {},
    isBlocking = nil,
    taskLimit = 10,
    taskCount = 0,
    now = 0,
    isEarly = true,
  }, watchMt)
  return watch
end

function PocketWatch.setmetatables(watch)
  setmetatable(watch, watchMt)
end

return PocketWatch
