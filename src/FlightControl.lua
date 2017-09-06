-- Util
function logVector(I, v, title)
    I:Log(string.format("%s (%.2f,%.2f,%.2f)", title, v.x, v.y, v.z))
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

function Propulsion:update(I, targetPosition, orientation)
    updateRotational(I, orientation)
    updateAngular(I, targetPosition)
end

function updateAngular(I, targetPosition)
    local vectorToTarget = targetPosition - I:GetConstructCenterOfMass()
    vectorToTarget = Vector3(vectorToTarget.x, vectorToTarget.y + Mathf.Max(abs(vectorToTarget.x), abs(vectorToTarget.y)), vectorToTarget.z)
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
    if velocity < desiredVelocity then
        I:RequestThrustControl(posThrust, thrust)
    else
        I:RequestThrustControl(negThrust, thrust)
    end
end

function updateRotational(I, target)
    local localAngularVelocity = I:GetLocalAngularVelocity() -- x: pitch, y: yaw, z: roll
    setDumbRotation(I, 0, I:GetConstructPitch(), localAngularVelocity.x, 10, 11) -- pitch
    setDumbRotation(I, 0, I:GetConstructYaw(), localAngularVelocity.y, 9, 8) -- yaw
    setDumbRotation(I, 0, I:GetConstructRoll(), localAngularVelocity.z, 6, 7) -- roll
end

function setDumbRotation(I, desiredAngle, curAngle, curVel, posThrust, negThrust)
    local angleDelta =  normalizedAngle(curAngle - desiredAngle)
    local thrust = Mathf.Min(Mathf.Pow(2, abs(angleDelta / 90)) -1, 1)
    local desiredVel = (Mathf.Pow(2, abs(angleDelta / 90)) - 1) * (angleDelta / abs(angleDelta)) * -1
    I:Log(string.format("desiredAngle: %.2f, curAngle: %.2f, angleDelta: %.2f, curVel: %.2f, desiredVel: %.2f",
        desiredAngle, curAngle, angleDelta, curVel, desiredVel))

    if curVel > desiredVel then
        I:RequestThrustControl(posThrust, thrust)
    else
        I:RequestThrustControl(negThrust, thrust)
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
    end
    local home = Vector3(-80,200,-200)
    local farAway = Vector3(0, 200, 500)
    propulsion:update(I, home, Vector3(0, 1, 0))

    I:Log(clock:curTick())
end
