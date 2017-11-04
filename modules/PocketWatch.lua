local PocketWatch = {}
local watchMt = { __index = PocketWatch }
local taskListMt = { __index = function(t,k) if type(k) ~= "number" then return end t[k] = {} return t[k] end}

function PocketWatch:Do(isPatient, task, ...)
  if (self.isBlocking or (not isPatient)) then
    return task(...)
  end
  if not self.earlyTasks and self.taskCount < self.taskList then
    self.taskCount = self.taskCount + 1
    return task(...)
  else --too much! relinquish control and let the simulation tick
    self:Schedule({task, ...})
  end
end

function PocketWatch:Schedule( task, old)
  if self.earlyTasks then
    table.insert(self.taskList.earlyTasks, task)
  else
    local taskList = self.taskList[self.now + interval]
    if old then
      table.insert(taskList,1, task)
    else
      table.insert(taskList, task)
    end
  end
end

function PocketWatch:DoTasks(time)
  if not time then return end
  if self.earlyTasks then
    self.taskCount = 0
    self.isEarly = true
    for _, task in ipairs(self.earlyTasks) do
      if self.taskCount < self.taskLimit then
        self:Do(true, unpack(task))
      else
        self:Schedule(task, true)
      end
    end
    self.isEarly = nil
    self.earlyTasks = nil
  end
  self.now = time
  local tasks = self.taskList[self.now]
  if tasks then
    for _, task in ipairs(tasks) do
      if self.taskCount < self.taskLimit then
        self:Do(true, unpack(task))
      else
        self:Schedule(task, true)
      end
    end
  end
  self.taskList[self.now] = nil
end

function PocketWatch:New()
  --creates a new Pocketwatch object.
  local watch = setmetatable({
    taskList = {},
    earlyTasks = {},
    isBlocking = nil,
    taskLimit = 10,
    taskCount = 0,
    now = 0,
  }, watchMt)
  return watch
end

function PocketWatch.setmetatables(watch)
  setmetatable(watch, watchMt)
  setmetatable(watch.taskList, taskListMt)
  return watch
end

return PocketWatch
