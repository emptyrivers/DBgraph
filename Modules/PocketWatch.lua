local PocketWatch = {}
local watchMt = { __index = PocketWatch }

function PocketWatch:Do(isPatient, task,  ...)
  if self.isBlocking or (not isPatient) then
    return task(...)
  end
  if self.taskCount < self.taskLimit then
    self.taskCount = self.taskCount + 1
    return task(...)
  else --too much! relinquish control and let the simulation tick
    self:Schedule(task, 1, ...)
  end
end

function PocketWatch:Schedule(task, interval, ...)
  self.taskList[self.now + interval] = self.taskList[self.now + interval] or {}
  table.insert(self.taskList[self.now + interval], {task, ...})
end

function PocketWatch:DoTasks()
  local tasks = self.taskList[self.now]
  if tasks then
    for _, task in ipairs(tasks) do
      self:Do(true, unpack(task))
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
  }, watchMt)
  return watch
end

function PocketWatch.setmetatables(watch)
  setmetatable(watch, watchMt)
end

return PocketWatch
