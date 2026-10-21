for index, case in
    {
        { { "Blueberry", "Blueberry", "Blueberry" }, 9688, "A", "Thanks!", "+$9,688", "$7.5K" },
        { { "Blueberry", "Blueberry", "Banana" }, 7975, "B", "Thanks!", "+$7,975", "$7K" },
        { { "Fish", "Banana", "Banana" }, 30825, "C", "Not blue!", "+$30,825", "$34K" },
        { { "Noob", "Banana", "Banana" }, 9638, "D", "Not blue!", "+$9,638", "$64K" },
        { { "Dragon_Fruit", "Dragon_Fruit", "Dragon_Fruit" }, 495250, nil, "Thanks!", "+$495,250", "$495K", true },
    }
do
    customer.ActivateForPlayer(owner)
    if case[7] then
        config.RegularWildcardChance = 1
    end
    local model = customer.SpawnForPlayer(owner)
    flush()
    setup(model and customer.GetSnapshot(owner).Ready, "customer at counter")
    if index == 1 then
        setup(customer.SetForcedReaction(owner, "Disgust"), "force independent reaction")
    end
    local before = data.GetCash(owner)
    check(not customer.Serve(owner) and data.GetCash(owner) == before, "no cup cannot pay")
    cup = { Ingredients = case[1], Tags = { "Blue" }, BlendId = "cup-" .. index }
    check(customer.Serve(owner, model), "serve consumes assigned cup")
    check(
        not nestedServe and consumed == index and completed == index,
        "reentrant serve cannot double-consume or complete"
    )
    check(
        data.GetCash(owner) == before + case[2] and model:GetAttribute("Grade") == case[3],
        "server awards correct cash and grade"
    )
    check(model:GetAttribute("IsWildcard") == (case[7] == true), "serve exposes explicit wildcard state")
    if index == 1 then
        check(model:GetAttribute("Reaction") == "Disgust", "cosmetic reaction does not change payout or grade")
    end
    local graphic = model:FindFirstChild("CustomerResult", true)
    check(
        graphic and string.find(graphic:FindFirstChild("Result").Text, case[5], 1, true) ~= nil,
        "serve graphic shows actual award"
    )
    check(not graphic:FindFirstChild("Ingredients"), "serve shows only the final credited payout")
    flush()
    check(
        model:FindFirstChild("OrderBubble", true):FindFirstChildOfClass("TextLabel").Text == case[4],
        "assigned dialogue remains separate"
    )
    check(not customer.Serve(owner, model) and data.GetCash(owner) == before + case[2], "replayed serve cannot pay")
    local expectedAnnouncements = if index == 5 then 1 else 0
    check(
        #announcementsSent == expectedAnnouncements,
        "only a committed Mystery serve announces, including reentrant/replayed attempts"
    )
    if index == 5 then
        check(
            announcementsSent[1].Payout == data.GetCash(owner) - before
                and announcementsSent[1].DisplayName == owner.DisplayName,
            "serve announcement carries actual credited payout and DisplayName"
        )
    end
    if case[7] then
        check(
            graphic:FindFirstChild("Result").Text == '<font color="rgb(255,222,115)">+$495,250</font>',
            "wildcard result shows cash without a letter grade"
        )
    end
    customer.DeactivateForPlayer(owner)
end
