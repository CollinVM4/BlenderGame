local vfxTests = assert(loadstring(sources.BlendVFXTests))()
vfxTests({
    Sources = sources,
    Env = env,
    Instance = instance,
    Signal = signal,
    Frame = frame,
    Services = services,
    Parent = parent,
    Check = check,
})
