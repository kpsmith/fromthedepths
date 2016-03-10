-- Util
function logVector(I, v, title)
    I:Log(title .. "" .. v.x .. " " .. v.y .. " " .. v.z)
end

function normalizedAngle(angle)
    return ((angle + 180) % 360) - 180
end

function abs(i)
    -- TODO: why the fuck is Mathf.Abs returning ints?
    return (i ^ 2) ^ .5
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

function Propulsion:setDesiredMovement(x, y, z)

end

function Propulsion:setDesiredOrientation(I, yaw, pitch, roll)
    -- TODO: negate angular acceleration

    local maxX = 0
    local maxY = 0
    local maxZ = 0

    local thruster_tau_vectors = {}
    local thruster_values = {}

    local num_thrusters = I:Component_GetCount(9)

    -- TODO: only recompute if num thrusters or COM changes
    for i = 0, num_thrusters - 1, 1 do
        local blockInfo = I:Component_GetBlockInfo(9, i)
        local tau_vector = Vector3.Cross(blockInfo.LocalForwards, blockInfo.LocalPositionRelativeToCom)
        thruster_tau_vectors[i] = tau_vector
        if tau_vector.x > maxX then
            maxX = tau_vector.x
        end
        if tau_vector.y > maxY then
            maxY = tau_vector.y
        end
        if tau_vector.z > maxZ then
            maxZ = tau_vector.z
        end
        thruster_values[i] = 0
        --        if (tau_vector.x < 1) then
        --            I:Log(i ..  " true " .. math.floor(tau_vector.x))
        --        else
        --            I:Log(i ..  " false " .. math.floor(tau_vector.x))
        --        end
        ----        I:Log(i ..  " true")
        --        logVector(I, tau_vector)
    end

    --    -- roll (z)
    local constructRoll = normalizedAngle(I:GetConstructRoll())
    local normalizedroll = normalizedAngle(roll)
    local rollDelta = normalizedAngle(normalizedroll - constructRoll)
    local power_mul = abs(rollDelta / 180)
    for i = 0, num_thrusters - 1, 1 do
        if thruster_tau_vectors[i].z * rollDelta > 0 then
            thruster_values[i] = thruster_values[i] + abs((thruster_tau_vectors[i].z / maxZ) * power_mul)
        end
    end
    --
    --    -- pitch (x)
    local constructPitch = normalizedAngle(I:GetConstructPitch())
    local normalizedPitch = normalizedAngle(pitch)
    local pitchDelta = normalizedAngle(normalizedPitch - constructPitch)
    local power_mul = abs(pitchDelta / 180)
    for i = 0, num_thrusters - 1, 1 do
        if thruster_tau_vectors[i].x * pitchDelta > 0 then
            thruster_values[i] = thruster_values[i] + abs((thruster_tau_vectors[i].x / maxX) * power_mul)
        end
    end

    -- yaw (y)
    local constructYaw = normalizedAngle(I:GetConstructYaw())
    local normalizedYaw = normalizedAngle(yaw)
    local yawDelta = normalizedAngle(normalizedYaw - constructYaw)
    local power_mul = abs(yawDelta / 180)
    for i = 0, num_thrusters - 1, 1 do
        if thruster_tau_vectors[i].y * yawDelta > 0 then
            thruster_values[i] = thruster_values[i] + abs((thruster_tau_vectors[i].y / maxY) * power_mul)
        end
    end

    for i = 0, num_thrusters - 1, 1 do
        --        I:Log(i .. " " .. thruster_values[i])
        I:Component_SetFloatLogic(9, i, thruster_values[i] / 3)
    end
end

function Propulsion:update(I, targetPosition, orientation)
    -- (,vertical,)
    local newPosition = Vector3(targetPosition.x, targetPosition.y + Mathf.Max(abs(targetPosition.x), abs(targetPosition.y)), targetPosition.z)
    updateRotational(I, orientation)
    updateAngular(I, targetPosition)
end

function updateAngular(I, targetPosition)
    -- (,vertical,)
    local vectorToTarget = targetPosition - I:GetConstructCenterOfMass()
    vectorToTarget = Vector3(vectorToTarget.x, vectorToTarget.y + Mathf.Max(abs(vectorToTarget.x), abs(vectorToTarget.y)), vectorToTarget.z)
--    logVector(I, targetPosition, "target ")
--    logVector(I, I:GetConstructCenterOfMass(), "position ")
--    logVector(I, vectorToTarget, "to target ")
    setNormalizedThrust(I, vectorToTarget, I:GetConstructRightVector(), 2, 3)
    setNormalizedThrust(I, vectorToTarget, I:GetConstructUpVector(), 4, 5) -- up down
    setNormalizedThrust(I, vectorToTarget, I:GetConstructForwardVector(), 0, 1)

end

function setNormalizedThrust(I, vector, projectionVector, posThrust, negThrust)
    -- distance
    local projectedVector = Vector3.Project(vector, projectionVector)
    local angleToTarget = angle(vector, projectionVector)
    local delta = projectedVector.magnitude
    if angleToTarget > 90 then
        delta = delta * -1
    end

--    I:Log("delta " .. delta)

    -- velocity
    local velocityVector = I:GetVelocityVector()
    local projectedVelocity = Vector3.Project(velocityVector, projectionVector)
    local angleOfVelocity = angle(velocityVector, projectionVector)
    local velocity = projectedVelocity.magnitude
    if angleOfVelocity > 90 then
        velocity = velocity * -1
    end

--    I:Log("projected velocity: " .. velocity)

    -- thrust
    local maxThrustDelta = 10
    local thrust = Mathf.Min(Mathf.Pow(2, abs(delta)/2) - 1, 1)


    local maxVelocity = 20

    local desiredVelocity = Mathf.Min(Mathf.Pow(2, abs(delta)/maxThrustDelta) -1, 1)  * Mathf.Sign(delta) * maxVelocity
--    thrust = Mathf.Pow(2, abs(desiredVelocity)/maxVelocity) -1

--    thrust = abs(desiredVelocity/maxVelocity)
    thrust = Mathf.Pow(2,abs(desiredVelocity) - 1)
    I:Log(string.format("delta: %.2f, velocity: %.2f, thrust: %.2f, desiredVelocity: %.2f", delta, velocity, thrust, desiredVelocity))

--    if (angleToTarget < 90) then
    if velocity < desiredVelocity then
--    if delta > 0 then
        I:RequestThrustControl(posThrust, thrust)
    else
        I:RequestThrustControl(negThrust, thrust)
    end
end

function updateRotational(I, target)
    -- a point in front of me in space
--    local pitch = normalizedAngle(I:GetConstructPitch())
--    I:Log(pitch)
--    if pitch < 0 then
--        I:RequestThrustControl(10, pitch / 180)
--    else
--        I:RequestThrustControl(11, pitch / 180)
--    end
--    local pointInFront = I:GetConstructCenterOfMass() + (I:GetConstructForwardVector() * 100)
--    local pointInFront = I:GetConstructCenterOfMass() + (Vector3.forward)
--    logVector(I, I:GetConstructCenterOfMass(), "i am here ")
--    logVector(I, pointInFront, "point in front ")
--    local vectorToTarget = pointInFront - I:GetConstructCenterOfMass()
--    logVector(I, vectorToTarget, "vector to target  ")
--    setNormalizedRotation(I, Vector3.left, I:GetConstructUpVector(), 6, 7) -- roll (keep a point to the right of the craft perpendicular to up vector)
--    setNormalizedRotation(I, Vector3.forward, I:GetConstructUpVector(), 10, 11) -- pitch (keep a point in front of the craft perpendicular to up vector)
    setNormalizedRotation(I, Vector3.forward, I:GetConstructForwardVector(), 8, 9)
end

function setNormalizedRotation(I, vector, projectionVector, posThrust, negThrust)
    local projectedVector = Vector3.Project(vector, projectionVector)

    local delta = projectedVector.magnitude
    local maxThrustDelta = 10

--    local thrust = Mathf.Min(Mathf.Pow(2, delta/maxThrustDelta) - 1, 1)
    --    I:Log("delta " .. delta .. " thrust " .. thrust)

    local a = normalizedAngle( angle(vector, projectionVector) - 90)
--    local thrust = Mathf.Pow(2, projectedVector.magnitude) - 1
    local thrust = Mathf.Min(Mathf.Pow(2, abs(a / 90)) - 1, .4)
    local thrust = (Mathf.Pow(2, abs(a / 90)) - 1)
    I:Log("thrust " .. thrust)
    I:Log("angle " .. a)
    if (a < 0) then
        I:RequestThrustControl(negThrust, thrust)
    else
        I:RequestThrustControl(posThrust, thrust)
    end
end

function angle(v, j)
    -- TODO: why doesn't Vector3.Angle work?
    return Mathf.Acos( Vector3.Dot(v, j) / (v.magnitude * j.magnitude)) * Mathf.Rad2Deg
end

clock = nil
propulsion = nil
function Update(I)
    -- clock
    if clock == nil then
        clock = Clock:new(I)
    end
    clock:update()

    if propulsion == nil then
        propulsion = Propulsion:new(I)
        --        propulsion:logPropulsion(I)
    end
--    propulsion:turnEverythingOff(I)
    local home = Vector3(-80,200,-200)
    local farAway = Vector3(0, 200, 500)
    propulsion:update(I, farAway, Vector3(0, 1, 0))

--    I:RequestThrustControl(2, 1)
--    I:RequestThrustControl(2)
--    I:RequestThrustControl(9, -1)

    I:Log(clock:curTick())
end