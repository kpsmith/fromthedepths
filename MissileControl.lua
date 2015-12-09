-- Globals
CANNON = 0
MISSILE = 1
LASER = 2
HARPOON = 3
TURRET = 4
MISSILECONTROL = 5
FIRECONTROLCOMPUTER = 6

-- Utility
function weaponsOfType(I, weaponType)
    local weapons = {}
    for i = 0, I:GetWeaponCount(), 1 do
        local weaponInfo = I:GetWeaponInfo(i)
        if weaponInfo.Valid and weaponInfo.WeaponType == weaponType then
            weapons[i] = weaponInfo
        end
    end
    return weapons
end

function logVector(I, v)
    I:Log(v.x .. " " .. v.y .. " " .. v.z)
end

function getLeadAimPoint(targetInfo, targetPositionInfo, missileWarningInfo)
    local distance = Vector3.Distance(targetInfo.AimPointPosition, missileWarningInfo.Position)
    local v = missileWarningInfo.Velocity.magnitude
    local time = distance / v
    return targetInfo.AimPointPosition + (targetPositionInfo.Velocity * time)
end

function getGroundDistance(vectorA, vectorB)
    return Vector3(
        vectorA.x - vectorB.x,
        vectorA.z - vectorB.z).magnitude
end

-- Clock
Clock = {
    tick = -1
}

function Clock:new(I)
    I:Log("Clock init")
    self.__index = self
    self.i = I
    return self
end

function Clock:update()
    self.tick = self.tick + 1
end

function Clock:curTick()
    return self.tick
end

-- Missile Control
MissileControl = {
    cruiseAltitude = 200,
    detonationDistance = 4,
    estimatedTurningRadius = 60,
    beginStrikeDistance = 150,
    armingDistance = 50,
    armedDetonateDistance = 4,
    missileLog = {},
    missileTargets = {}
}

function MissileControl:new(I)
    I:Log("MissileControl init")
    self.__index = self
    return self
end

function MissileControl:update(I)
    if targetControl:getHasTargets() then
        self:fireAll(I)
    else
        self.missileTargets = {}
    end
    self:guideMissiles(I)
end

function MissileControl:fireAll(I)
    local p = I:GetConstructPosition()
    for weaponIndex, weaponInfo in pairs(weaponsOfType(I, MISSILECONTROL)) do
        I:AimWeaponInDirection(weaponIndex, p.x, p.y + 100, p.z, 0)
        I:FireWeapon(weaponIndex, 0)
    end
end

function MissileControl:guideMissiles(I)
    local missileInfo
    for luaTransceiverIndex = 0, I:GetLuaTransceiverCount() do
        for missileIndex = 0, I:GetLuaControlledMissileCount(luaTransceiverIndex) do
            self:guidance(I, luaTransceiverIndex, missileIndex)
        end
    end
end

function MissileControl:guidance(I ,luaTransceiverIndex, missileIndex)
    local missileWarningInfo = I:GetLuaControlledMissileInfo(luaTransceiverIndex, missileIndex)
    local aimpoint = Vector3(0,self.cruiseAltitude,0)

    -- get target
    local targetInfo
    local targetPositionInfo

    local targetId
    if self.missileTargets[missileWarningInfo.Id] == nil then
        targetId = targetControl:getRandomTargetId(I)
        self.missileTargets[missileWarningInfo.Id] = targetId
    else
        targetId = self.missileTargets[missileWarningInfo.Id]
    end
--    I:Log(targetId)
    if targetId ~= nil then
        targetInfo, targetPositionInfo = TargetControl:getTarget(I, targetId)
    end
    if targetInfo == nil then
        targetInfo, targetPositionInfo = TargetControl:getClosestTarget(I, missileWarningInfo.Position)
    end

    if targetInfo ~= nil then
--        aimpoint = targetInfo.AimPointPosition
        aimpoint = getLeadAimPoint(targetInfo, targetPositionInfo, missileWarningInfo)
    end
    local targetDistance = Vector3.Distance(missileWarningInfo.Position, aimpoint)
    local targetGroundDistance = getGroundDistance(missileWarningInfo.Position, aimpoint)
    if not missileWarningInfo.Valid then
        return
    end

    -- cruise
    local adjustedLaunchHeight = self.cruiseAltitude - self.estimatedTurningRadius
    if missileWarningInfo.TimeSinceLaunch < 4 and missileWarningInfo.Position.y < adjustedLaunchHeight then
        -- reach cruise altitude
        I:SetLuaControlledMissileAimPoint(
            luaTransceiverIndex,
            missileIndex,
            missileWarningInfo.Position.x,
            self.cruiseAltitude - self.estimatedTurningRadius,
            missileWarningInfo.Position.z
        )
    elseif targetInfo == nil then
        -- idle
        I:SetLuaControlledMissileAimPoint(
            luaTransceiverIndex,
            missileIndex,
            missileWarningInfo.Position.x,
            300,
            missileWarningInfo.Position.z)
    elseif targetGroundDistance > self.beginStrikeDistance then
        -- cruise
        I:SetLuaControlledMissileAimPoint(
            luaTransceiverIndex,
            missileIndex,
            aimpoint.x,
            math.max(aimpoint.y, self.cruiseAltitude),
            aimpoint.z)
    else
        -- strike
        I:SetLuaControlledMissileAimPoint(
            luaTransceiverIndex,
            missileIndex,
            aimpoint.x,
            aimpoint.y,
            aimpoint.z)
    end
    local detonate = false
    -- detonation
    if targetInfo ~= nil and targetDistance < self.armingDistance then
        -- under arming distance, detonate if we become further from the target
        if self.missileLog[missileWarningInfo.Id] ~= nil then
            local minDistance = self.missileLog[missileWarningInfo.Id]
            if (targetDistance - minDistance) > self.armedDetonateDistance then
                detonate = true
            end
            if targetDistance < minDistance then
                self.missileLog[missileWarningInfo.Id] = targetDistance
            end
        else
            self.missileLog[missileWarningInfo.Id] = targetDistance
        end

    end
    -- kill old missiles
    if missileWarningInfo.TimeSinceLaunch > 20 then
        detonate = true
    end
    if detonate then
        I:DetonateLuaControlledMissile(luaTransceiverIndex, missileIndex)
    end
end

-- TargetControl
TargetControl = {
    targets = {},
    numTargets = 0,
    targetIdTable = {}
}

function TargetControl:new(I)
    I:Log("MissileControl init")
    self.__index = self
    return self
end

function TargetControl:update(I)
    local targets = {}
--    local hasTargets = false
    local numTargets = 0
    local targetIdTable = {}
    local targetIdTableInd = 0
    for i = 0, I:GetNumberOfMainframes(), 1 do
        for j = 0, I:GetNumberOfTargets(i), 1 do
            local targetInfo = I:GetTargetInfo(i, j)
            if targetInfo.Valid then

--                local targetPositionInfo = I:GetTargetPositionInfo(i, j)
                targets[targetInfo.Id] = {
                    targetInfo=targetInfo,
                    targetPositionInfo=I:GetTargetPositionInfo(i, j)
                }
                targetIdTable[numTargets+1] = targetInfo.Id
                numTargets = numTargets + 1
--                targets[targetInfo] = I:GetTargetPositionInfo(i, j)
--                hasTargets = true
            end
        end
    end
--    self.hasTargets = hasTargets
    self.targetIdTable = targetIdTable
    self.numTargets = numTargets
    self.targets = targets
end

function TargetControl:getHasTargets()
    return self.numTargets ~= 0
end

function TargetControl:getClosestTarget(I, position)
    local curTargetInfo
    local curTargetPositionInfo
    local minDistance
    for targetId, targetPair in pairs(self.targets) do
        local curDistance = Vector3.Distance(position, targetPair.targetInfo.AimPointPosition)
        if curTargetInfo == nil or curDistance < minDistance then
            curTargetInfo = targetPair.targetInfo
            curTargetPositionInfo = targetPair.targetPositionInfo
            minDistance = curDistance
        end
    end
    return curTargetInfo, curTargetPositionInfo
end

function TargetControl:getRandomTargetId(I)
    if self.numTargets < 1 then
        return nil
    end
    local ind = math.floor(math.random() * self.numTargets) + 1
    local id = self.targetIdTable[ind]
    if id == nil then
        I:Log("attempt to access targets with ind: " .. ind .. " idtable has " .. table.getn(self.targetIdTable) .. " elements")
        local x = 1/0
    end
    return id
--    local targetList = {}
----    local targetPositionList = {}
--    for targetInfo, targetPosition in pairs(self.targets) do
--        targetList[table.getn(targetList)+1] = targetInfo.Id
----        targetPositionList[table.getn(targetPositionList)] = targetPosition
--    end
--    local tableLen = table.getn(targetList)
--    if tableLen > 0 then
--        local choice = math.floor(math.random() * tableLen)
--        return targetList[choice]
--    else
--        return nil
--    end
end

function TargetControl:getTarget(I, id)
    local targetPair = self.targets[id]
    if targetPair ~= nil then
        return  targetPair.targetInfo, targetPair.targetPositionInfo
    end
--    for targetInfo, targetPosition in pairs(self.targets) do
--        if targetInfo.Id == id then
--            return targetInfo, targetPosition
--        end
--    end
    return nil, nil
end

-- Update
clock = nil
missileControl = nil
targetControl = nil

function Update(I)
    -- clock
    if clock == nil then
        clock = Clock:new(I)
    end
    clock:update()
    -- targets
    if targetControl == nil then
        targetControl = TargetControl:new(I)
    end
    targetControl:update(I)
--    ti, tpi = getClosestTarget(I:GetConstructPosition())
--    I:Log(tpi.GroundDistance)
    -- missiles
    if missileControl == nil then
        missileControl = MissileControl:new(I)
    end
    missileControl:update(I)
end