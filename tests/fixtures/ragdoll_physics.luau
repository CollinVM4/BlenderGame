-- Engine boundary for isolated ragdoll tests; does not simulate rigid-body dynamics.
env.Enum.HumanoidRigType = { R15 = "R15", R6 = "R6" }
services.RunService.IsServer = function()
    return true
end
env.Enum.HumanoidStateType = { Physics = "Physics", GettingUp = "GettingUp", Jumping = "Jumping" }
local rawInstance = instance
instance = function(class)
    local object = rawInstance(class)
    object.DescendantAdded = signal()
    object.AssemblyMass = 16
    object.AutoRotate, object.PlatformStand, object.CanCollide = true, false, false
    object.AutomaticOwner = true
    object.RequiresNeck = true
    object.Massless = true
    object.State = "Running"
    function object:GetState()
        return self.State
    end
    local states = {}
    function object:GetStateEnabled(state)
        return states[state] ~= false
    end
    function object:SetStateEnabled(state, value)
        states[state] = value
    end
    function object:GetNetworkOwnershipAuto()
        return self.AutomaticOwner
    end
    function object:GetNetworkOwner()
        return self.NetworkOwner
    end
    function object:SetNetworkOwner(owner)
        self.NetworkOwner, self.AutomaticOwner = owner, false
    end
    function object:SetNetworkOwnershipAuto()
        self.AutomaticOwner = true
    end
    function object:ChangeState(state)
        self.State = state
    end
    function object:ApplyImpulse(impulse)
        self.Impulse = impulse
    end
    function object:ApplyAngularImpulse(impulse)
        self.AngularImpulse = impulse
    end
    return object
end
env.Instance.new = instance
