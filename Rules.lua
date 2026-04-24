-- Rule helpers for the local MVP.
-- Keep this file intentionally small until the addon needs more policy logic.

local SC = Softcore

function SC:IsRunFailed()
    local db = self.db or SoftcoreDB
    return db and db.run and db.run.failed == true
end

function SC:IsRunActive()
    local db = self.db or SoftcoreDB
    return db and db.run and db.run.active == true
end
