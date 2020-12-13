local function ControlDistributor(bot, cmd)
    local mem = bot.D3bot

    -- Don't take control if there is no D3bot structure
    if not mem then
        return
    end

    -- Run brain "think" callback. Ideally this will resume one or more coroutines, depending on how complex the brain is.
    if mem.Brain then
        if mem.Brain.Callback then
            mem.Brain.Callback(bot)
        end
    else
        -- "Insane in the membrane"
        -- "Crazy insane, got no brain"
        -- TODO: Call function to assign a brain to the bot
    end

    -- Check if there is a locomotion callback
    if mem.Locomotion == nil or mem.Locomotion.Callback == nil then
        cmd:ClearButtons()
        cmd:ClearMovement()
        return
    end

    -- "Don't you know I'm loco?"
    mem.Locomotion.Callback(bot, cmd)
end
hook.Add("StartCommand", D3bot.HookPrefix .. "ControlDistributor", ControlDistributor)
