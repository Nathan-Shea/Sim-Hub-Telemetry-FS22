




local AITaskStopEvent_mt = Class(AITaskStopEvent, Event)




---
function AITaskStopEvent.emptyNew()
    local self = Event.new(AITaskStopEvent_mt)
    return self
end


---
function AITaskStopEvent.new(job, task, wasJobStopped)
    local self = AITaskStopEvent.emptyNew()

    self.job = job
    self.wasJobStopped = wasJobStopped
    self.task = task

    return self
end


---
function AITaskStopEvent:readStream(streamId, connection)
    local jobId = streamReadInt32(streamId)
    self.job = g_currentMission.aiSystem:getJobById(jobId)
    self.task = self.job:getTaskByIndex(streamReadUInt8(streamId))
    self.wasJobStopped = streamReadBool(streamId)

    self:run(connection)
end


---
function AITaskStopEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.job.jobId)
    streamWriteUInt8(streamId, self.task.taskIndex)
    streamWriteBool(streamId, self.wasJobStopped)
end


---
function AITaskStopEvent:run(connection)
    self.job:stopTask(self.task, self.wasJobStopped)
end
