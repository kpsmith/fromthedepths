-- Globals
CANNON = 0
MISSILE = 1
LASER = 2
HARPOON = 3
TURRET = 4
MISSILECONTROL = 5
FIRECONTROLCOMPUTER = 6

-- Util
function logVector(I, v, title)
    I:Log(string.format("%s (%.2f,%.2f,%.2f)", title, v.x, v.y, v.z))
end

function normalizedAngle(angle)
    return ((angle + 180) % 360) - 180
end

function abs(i)
    -- TODO: why is Mathf.Abs returning ints?
    return (i ^ 2) ^ .5
end

function angle(v, j)
    -- TODO: why doesn't Vector3.Angle work?
    return Mathf.Acos( Vector3.Dot(v, j) / (v.magnitude * j.magnitude)) * Mathf.Rad2Deg
end

function getGroundDistance(vectorA, vectorB)
    return Vector3(
        vectorA.x - vectorB.x,
        vectorA.z - vectorB.z).magnitude
end

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

function getLeadAimPoint(targetInfo, targetPositionInfo, missileWarningInfo)
    local distance = Vector3.Distance(targetInfo.AimPointPosition, missileWarningInfo.Position)
    local v = missileWarningInfo.Velocity.magnitude
    local time = distance / v
    return targetInfo.AimPointPosition + (targetPositionInfo.Velocity * time)
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

-- Propulsion
Propulsion = {

}

function Propulsion:new(I)
    self.__index = self
    return self
end

function Propulsion:turnEverythingOn(I)
    for i = 0, 11, 1 do
        I:RequestThrustControl(i, 1)
    end
end

function Propulsion:turnEverythingOff(I)
    for i = 0, 11, 1 do
        I:RequestThrustControl(i, 0)
    end
end

function Propulsion:logPropulsion(I)
    I:Component_GetCount(9)
    for i = 0, I:Component_GetCount(9), 1 do
        I:Log(i)
    end
end

function Propulsion:setPropulsion(I, val)
    for i = 0, I:Component_GetCount(9), 1 do
        I:Component_SetIntLogic(9, i, val)
    end
end

function Propulsion:update(I, targetPosition, orientation)
    if orientation == nil then
        -- pass
    else
        updateRotational(I, orientation)
    end
    updateAngular(I, targetPosition)
end

function updateAngular(I, targetPosition)
    local vectorToTarget = targetPosition - I:GetConstructCenterOfMass()
--    vectorToTarget = Vector3(vectorToTarget.x, vectorToTarget.y + Mathf.Max(abs(vectorToTarget.x), abs(vectorToTarget.y)), vectorToTarget.z)


    setNormalizedThrust(I, vectorToTarget, I:GetConstructRightVector(), 2, 3)
    setNormalizedThrust(I, vectorToTarget, I:GetConstructUpVector(), 4, 5) -- up down
    setNormalizedThrust(I, vectorToTarget, I:GetConstructForwardVector(), 0, 1)

--    local velocityVector = I:GetVelocityVector()
--    setDumbThrust(I, vectorToTarget.x, velocityVector.x, 2, 3)
--    setDumbThrust(I, vectorToTarget.y, velocityVector.y, 4, 5)
--    setDumbThrust(I, vectorToTarget.z, velocityVector.z, 0, 1)
end

function setDumbThrust(I, dist, vel, posThrust, negThrust)
    local maxVelocity = 20
    local maxThrustDelta = 10
    local desiredVel = Mathf.Min(Mathf.Pow(2, abs(dist) / maxThrustDelta) - 1, 1) * Mathf.Sign(dist) * maxVelocity
    local thrust = Mathf.Min(Mathf.Pow(2, abs(dist) / maxThrustDelta), 1)
    if vel < desiredVel then
        I:RequestThrustControl(posThrust, thrust)
    else
        I:RequestThrustControl(negThrust, thrust)
    end
end

function setNormalizedThrust(I, vector, projectionVector, posThrust, negThrust)
    -- distance
    local projectedVector = Vector3.Project(vector, projectionVector)
    local angleToTarget = angle(vector, projectionVector)
    local delta = projectedVector.magnitude
    if angleToTarget > 90 then
        delta = delta * -1
    end
    -- velocity
    local velocityVector = I:GetVelocityVector()
    local projectedVelocity = Vector3.Project(velocityVector, projectionVector)
    local angleOfVelocity = angle(velocityVector, projectionVector)
    local velocity = projectedVelocity.magnitude
    if angleOfVelocity > 90 then
        velocity = velocity * -1
    end
    -- thrust
    local maxThrustDelta = 10
    local maxVelocity = 20
    local desiredVelocity = Mathf.Min(Mathf.Pow(2, abs(delta)/maxThrustDelta) -1, 1)  * Mathf.Sign(delta) * maxVelocity
    local thrust = Mathf.Pow(2,abs(desiredVelocity) - 1)
--    local thrust = Mathf.Min(Mathf.Pow(2, abs(delta) / maxThrustDelta - 1), 1)
    if velocity < desiredVelocity then
        I:RequestThrustControl(posThrust, thrust)
    else
        I:RequestThrustControl(negThrust, thrust)
    end
end

function updateRotational(I, target)
    local localAngularVelocity = I:GetLocalAngularVelocity() -- x: pitch, y: yaw, z: roll
    setDumbRotation(I, target.x, I:GetConstructPitch(), localAngularVelocity.x, 10, 11) -- pitch
    setDumbRotation(I, target.y, I:GetConstructYaw(), localAngularVelocity.y, 9, 8) -- yaw
    setDumbRotation(I, target.z, I:GetConstructRoll(), localAngularVelocity.z, 6, 7) -- roll
end

function setDumbRotation(I, desiredAngle, curAngle, curVel, posThrust, negThrust)
    local angleDelta =  normalizedAngle(curAngle - desiredAngle)
    local thrust = Mathf.Min(Mathf.Pow(2, abs(angleDelta / 90)) -1, 1)
--    local thrust = .5
    local desiredVel = (Mathf.Pow(2, abs(angleDelta / 90)) - 1) * (angleDelta / abs(angleDelta)) * -1
--    I:Log(string.format("desiredAngle: %.2f, curAngle: %.2f, angleDelta: %.2f, curVel: %.2f, desiredVel: %.2f",
--        desiredAngle, curAngle, angleDelta, curVel, desiredVel))

    if curVel > desiredVel then
        I:RequestThrustControl(posThrust, thrust)
    else
        I:RequestThrustControl(negThrust, thrust)
    end
end

-- TargetControl
TargetControl = {
    targets = {},
    numTargets = 0,
    targetIdTable = {}
}

function TargetControl:new(I)
    I:Log("TargetControl init")
    self.__index = self
    return self
end

function TargetControl:update(I)
    local targets = {}
    local numTargets = 0
    local targetIdTable = {}
    for i = 0, I:GetNumberOfMainframes(), 1 do
        for j = 0, I:GetNumberOfTargets(i), 1 do
            local targetInfo = I:GetTargetInfo(i, j)
            if targetInfo.Valid then
                targets[targetInfo.Id] = {
                    targetInfo=targetInfo,
                    targetPositionInfo=I:GetTargetPositionInfo(i, j)
                }
                targetIdTable[numTargets+1] = targetInfo.Id
                numTargets = numTargets + 1
            end
        end
    end
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
    for _, targetPair in pairs(self.targets) do
        local curDistance = Vector3.Distance(position, targetPair.targetInfo.AimPointPosition)
        if curTargetInfo == nil or curDistance < minDistance then
            curTargetInfo = targetPair.targetInfo
            curTargetPositionInfo = targetPair.targetPositionInfo
            minDistance = curDistance
        end
    end
    return curTargetInfo, curTargetPositionInfo
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
--    local adjustedLaunchHeight = self.cruiseAltitude - self.estimatedTurningRadius
--    if missileWarningInfo.TimeSinceLaunch < 4 and missileWarningInfo.Position.y < adjustedLaunchHeight then
--        -- reach cruise altitude
--        I:SetLuaControlledMissileAimPoint(
--            luaTransceiverIndex,
--            missileIndex,
--            missileWarningInfo.Position.x,
--            self.cruiseAltitude - self.estimatedTurningRadius,
--            missileWarningInfo.Position.z
--        )
--    else
    if targetInfo == nil then
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
        I:LogToHud("strike")
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

-- Init
clock = nil
propulsion = nil
targetControl = nil
function Update(I)
    -- clock
    if clock == nil then
        clock = Clock:new(I)
    end
    clock:update()
    if propulsion == nil then
        propulsion = Propulsion:new(I)
    end
    if targetControl == nil then
        targetControl = TargetControl:new(I)
    end
    targetControl:update(I)
    local curTargetInfo, curTargetPositionInfo = targetControl:getClosestTarget(I, I:GetConstructPosition())
    local home = Vector3(-80,200,-200)
    local farAway = Vector3(0, 200, 500)
    local p
    local d
    local t
    if curTargetPositionInfo == nil then
        p = Vector3(-280, 400, -200)
        d = Vector3(0, 180, 0)
        t = Vector3(-80, 200, -200)
    else
        logVector(I, curTargetPositionInfo.Position, "target position")
        logVector(I, curTargetPositionInfo.Direction, "target direction")
        p = curTargetPositionInfo.Position + Vector3(200, 200, 0)
        d = curTargetPositionInfo.Direction
        local yawToTarget = normalizedAngle(I:GetConstructYaw() - d.y)
        I:Log(string.format("yaw to target %d", yawToTarget))
        d = Vector3(0, -d.y, 0)
        t = curTargetPositionInfo.Position
    end
--    logVector(I, angle(p - I:GetConstructPosition(), Vector3.left), "dir")
--    logVector(I, Vector3.up, "dir")
    --
    local alpha = I:GetConstructPosition()
    local foo = Vector3(t.x, 0, t.z) - Vector3(alpha.x, 0, alpha.z)
    logVector(I, foo, "targetVector")
    local angle = angle(foo, Vector3.forward) - 0
    if foo.z < 0 then
        angle = 360 - angle
    end
    d = Vector3(0, angle, 0)
    d = nil
    --
    I:Log(string.format("angle %d", angle))
--    I:Log(string.format("distance %d", Vector3.Distance(I:GetConstructPosition(), p)))
--    if Vector3.Distance(I:GetConstructPosition(), p) > 500 then
--        d = nil
--    end
    propulsion:update(I, p, d)

    if missileControl == nil then
        missileControl = MissileControl:new(I)
    end
    missileControl:update(I)

    I:Log(clock:curTick())
end
