local PocketWatch = {}
local watchMt = { __index = PocketWatch }

function PocketWatch:Do(task, forceBlocking, priority)
  if self.isBlocking or forceBlocking then
    return task()
  end
  if self.taskCount < self.taskLimit then
    self.taskCount = self.taskCount
    return task()
  else
    self:Schedule(task, priority and priority * 5 or 15)
  end
end  

function PocketWatch:Schedule(task, interval)
  self.taskList[self.now + interval] = self.taskList[self.now + interval] or {}
  table.insert(self.taskList[self.now + interval], task)
end

function PocketWatch:DoTasks()
  local tasks = self.taskList[self.now] 
  if tasks then
    for _, task in ipairs(self.taskList[self.now]) do
      self:Do(task)
    end
  end
  self.taskList[self.now] = nil
end

function PocketWatch:New()
  --creates a new Pocketwatch object.
  local watch = setmetatable({
    taskList = {}
    isBlocking = nil,
    taskLimit = 1,
    taskCount = 0,
    now = 0,
  }, watchMt)
  return watch
end

return PocketWatch