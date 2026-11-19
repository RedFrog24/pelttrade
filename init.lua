-- pelttrade/init.lua
-- Created by: RedFrog
-- Created: October 13, 2024
-- Version controlled by `version` below (single source of truth - drives the startup print).
--
-- Trades pelts up a quality step with Dar Forager Lumun in the Rathe Mountains:
-- three of one kind, below High quality, become one of the next quality up.
-- https://everquest.allakhazam.com/db/quest.html?quest=2317
--
-- He only deals with frogloks, so any other race needs a Guktan illusion up first.
-- Start in the Plane of Knowledge and it travels for you, or start in the Rathe Mountains.

local mq = require('mq')

local version = "1.09"

local npcName = "Dar Forager Lumun"
local ratheZoneId = 50
local pokZoneId = 202

-- The three families he accepts. Lion, cougar, tundra kodiak, horse, coyote, snake and
-- cragbeast pelts all share the same "<quality> Quality <animal>" naming and he takes none
-- of them, so the kinds are listed out rather than matched on the word "Quality".
local peltKinds = { "Bear Skin", "Cat Pelt", "Wolf Skin" }

-- Low is traded before Medium so the Mediums produced during a run are upgraded in the
-- same pass. The old build looped this with pairs(), whose order is undefined, so that
-- cascade only happened by luck.
local tradeQualities = { "Low Quality", "Medium Quality" }

-- Me.Race is the character's TRUE race: MQ reads the race field and not the illusion's
-- override, so an illusioned player can only ever be recognised by the buff.
-- ONLY the Guktan pair. A plain Froglok illusion does NOT satisfy him, so letting one past
-- this gate would walk somebody all the way out to the Rathe Mountains to be refused.
local guktanIllusions = {
    "Illusion: Guktan",
    "Mass Illusion: Guktan",
}

local giveWnd = mq.TLO.Window('GiveWnd')
local quantityWnd = mq.TLO.Window('QuantityWnd')

-- Utility Functions

local function peltPrint(msg)
    print(string.format("\ao[\agPeltTrade\ao]\at %s\ax", msg))
end

-- mq.delay hands back nil rather than a boolean, so the condition is re-read afterwards
-- and that is what gets returned. The callback must give a real boolean or the delay errors.
local function waitFor(condition, timeoutMs)
    mq.delay(timeoutMs, function() return condition() == true end)
    return condition() == true
end

local function pluginReady(name, feature)
    if mq.TLO.Plugin(name).IsLoaded() then return true end
    mq.cmdf('/plugin %s load noauto', name:lower())
    if waitFor(function() return mq.TLO.Plugin(name).IsLoaded() end, 5000) then return true end
    peltPrint(string.format("\arCould not load %s - %s.", name, feature))
    return false
end

local function cursorEmpty()
    return (mq.TLO.Cursor.ID() or 0) == 0
end

local function stowCursor()
    if cursorEmpty() then return true end
    mq.cmd('/autoinventory')
    return waitFor(cursorEmpty, 2000)
end

-- Counts what is in bags and on the character. FindItemCount walks the inventory and the
-- keyring only, never the bank, and the "=" prefix forces an exact name match so a
-- "Medium Quality Bear Skin" is never counted as a "Bear Skin".
local function countOf(itemName)
    return mq.TLO.FindItemCount('=' .. itemName)() or 0
end

local function reportCounts(label)
    peltPrint(string.format("\ap%s:", label))
    for _, kind in ipairs(peltKinds) do
        peltPrint(string.format("  %-10s Low \ay%-4d\at Medium \ay%-4d\at High \ag%d",
            kind, countOf("Low Quality " .. kind), countOf("Medium Quality " .. kind),
            countOf("High Quality " .. kind)))
    end
end

-- Preflight

local function checkZone()
    local zoneId = mq.TLO.Zone.ID()
    if zoneId ~= pokZoneId and zoneId ~= ratheZoneId then
        peltPrint("\ayStart this in the Plane of Knowledge or the Rathe Mountains.")
        return false
    end
    return true
end

local function looksGuktan()
    if mq.TLO.Me.Race() == "Froglok" then return true end
    for _, illusion in ipairs(guktanIllusions) do
        if mq.TLO.Me.Buff(illusion)() then return true end
    end
    return false
end

local function checkGuktan()
    if looksGuktan() then return true end
    peltPrint("\ayHe only deals with Guktans - be a froglok, or get a \agGuktan\ay illusion up.")
    peltPrint("\ayA plain Froglok illusion will not do - he refuses those.")
    return false
end

-- Zoning drops an illusion for any character without the AA that carries one across a zone line,
-- and he will not deal with whatever walks in. Rather than fail the run, stop where we are and
-- wait for a recast. A real froglok passes instantly, so this only ever holds up an illusion.
local function waitForIllusion()
    if looksGuktan() then return true end
    if mq.TLO.Nav.Active() then mq.cmd('/squelch /nav stop') end
    peltPrint("\arLost the illusion - please recast it. I will carry on as soon as it is back.")

    local waited = 0
    while waited < 180000 do
        mq.delay(1000)
        waited = waited + 1000
        if looksGuktan() then
            peltPrint("\agIllusion is back - carrying on.")
            return true
        end
        if waited % 30000 == 0 then
            peltPrint(string.format("\ayStill waiting for the illusion - %d seconds.", waited / 1000))
        end
    end
    peltPrint("\arGave up waiting for the illusion.")
    return false
end

local function travelToRathe()
    if mq.TLO.Zone.ID() == ratheZoneId then return true end
    if not pluginReady('MQ2EasyFind', "cannot travel to the Rathe Mountains from here") then
        return false
    end

    peltPrint("\aoTravelling to the Rathe Mountains...")
    mq.cmd('/squelch /travelto rathemtn')
    -- EasyFind.Active tells travelling apart from a /travelto that never started, which a
    -- bare zone poll cannot do - that was an endless loop in the old build when it failed.
    if not waitFor(function() return mq.TLO.EasyFind.Active() end, 5000) then
        peltPrint("\ar/travelto did not start. Make your own way to the Rathe Mountains.")
        return false
    end

    if not waitFor(function() return mq.TLO.Zone.ID() == ratheZoneId end, 300000) then
        mq.cmd('/squelch /travelto stop')
        peltPrint("\arGave up waiting on the trip to the Rathe Mountains.")
        return false
    end
    -- Settle after the zone, or the spawn list is still filling when he is searched for.
    mq.delay(3000)
    return true
end

-- Approach

-- He shelters under a lean-to, and ANY route that heads straight at him climbs onto the roof,
-- which has no way down. Single-leg and two-leg approaches both ended up there, so the walk is
-- staged wide around the tent. Every point measured in game.
local approachPath = {
    { y = -2067.46, x = 245.87, z = -0.15 },   -- wide, on the far side
    { y = -2109.68, x = 224.54, z =  0.58 },   -- round to the front of the tent
    { y = -2086.68, x = 203.49, z = -4.80 },   -- in beside him, 9.4 away and facing him
}

-- One nav leg, judged by where we end up rather than by the nav state: a short hop can finish
-- before the first poll, so a leg that never reports Active is not by itself a failure.
local function navLeg(y, x, z)
    mq.cmdf('/squelch /nav loc %s %s %s', y, x, z)
    waitFor(function() return mq.TLO.Nav.Active() end, 3000)
    waitFor(function() return not mq.TLO.Nav.Active() end, 120000)
end

-- Flat distance from where we are to a waypoint. Z is deliberately ignored: the ground rises
-- away from him, so the staging points sit 4-5 ABOVE him and a 3D test would read as "wrong".
local function flatDistTo(wp)
    local dy, dx = (mq.TLO.Me.Y() or 0) - wp.y, (mq.TLO.Me.X() or 0) - wp.x
    return math.sqrt(dy * dy + dx * dx)
end

local function goToNPC()
    local npc = mq.TLO.Spawn('npc =' .. npcName)
    if (npc.ID() or 0) == 0 then
        peltPrint(string.format("\ay%s is not in the zone - he is a static spawn, so he has most likely been killed.", npcName))
        peltPrint("\ayHe is usually back about 10 minutes later.")
        return nil
    end

    local npcId = npc.ID()
    -- Each leg is checked for arrival, so a walk that still ends up stuck NAMES the leg that
    -- did it and prints where we stopped. Guessing at waypoints blind has cost three attempts.
    if (npc.Distance() or 999) > 15 then
        peltPrint(string.format("\aoWalking to %s...", npcName))
        for i, wp in ipairs(approachPath) do
            navLeg(wp.y, wp.x, wp.z)
            if flatDistTo(wp) > 10 then
                mq.cmd('/squelch /nav stop')
                peltPrint(string.format("\arStuck on approach leg %d of %d - heading for %.2f, %.2f.",
                    i, #approachPath, wp.y, wp.x))
                peltPrint(string.format("\arStopped at \ay%.2f, %.2f, %.2f\ar - that leg's waypoint needs moving.",
                    mq.TLO.Me.Y() or 0, mq.TLO.Me.X() or 0, mq.TLO.Me.Z() or 0))
                return nil
            end
        end
    end

    if (mq.TLO.Spawn(npcId).Distance() or 999) > 15 then
        mq.cmd('/squelch /nav stop')
        peltPrint(string.format("\arCould not get close enough to %s.", npcName))
        return nil
    end

    -- Distance alone cannot catch the roof: up there you are only a few away from him, straight
    -- up. Height can. Beside him you are level (measured -4.80 against his -4.59); on the roof
    -- you are about five above. Stop rather than trade down through the canvas.
    if (mq.TLO.Me.Z() or 0) - (mq.TLO.Spawn(npcId).Z() or 0) > 3 then
        mq.cmd('/squelch /nav stop')
        peltPrint(string.format("\arEnded up on top of %s's tent instead of beside him.", npcName))
        peltPrint("\arWalk down to ground level and run it again.")
        return nil
    end

    mq.cmdf('/target id %d', npcId)
    if not waitFor(function() return (mq.TLO.Target.ID() or 0) == npcId end, 3000) then
        peltPrint(string.format("\arCould not target %s.", npcName))
        return nil
    end

    -- Checked again here: the walk is long enough for a short illusion to lapse, and what
    -- matters is what he sees at the moment you speak to him.
    if not waitForIllusion() then return nil end

    -- He wants the hail before the keyword; the old build sent only the keyword.
    mq.cmdf('/say Hail, %s', npcName)
    mq.delay(1500)
    mq.cmd('/say I am here to make an exchange')
    mq.delay(1500)
    return npcId
end

-- Trading

-- Puts exactly one pelt on the cursor. /ctrlkey is what takes ONE from a stack: a plain
-- leftmouseup picks up the WHOLE stack and opens no quantity window at all - measured in game
-- at v1.03, where it put all 12 cat pelts on the cursor in one go.
-- The quantity branch below is kept as a fallback for any slot that does prompt; that window
-- has no Cancel button, so closing it is what takes nothing.
local function pickUpOne(itemName)
    mq.cmdf('/nomodkey /ctrlkey /itemnotify "%s" leftmouseup', itemName)
    waitFor(function() return quantityWnd.Open() == true or mq.TLO.Cursor.Name() == itemName end, 2000)

    if quantityWnd.Open() then
        local box = quantityWnd.Child('QTYW_SliderInput')
        box.SetText("1")
        if not waitFor(function() return box.Text() == "1" end, 1000) then
            quantityWnd.DoClose()
            waitFor(function() return not quantityWnd.Open() end, 1000)
            return false
        end
        quantityWnd.Child('QTYW_Accept_Button').LeftMouseUp()
        waitFor(function() return mq.TLO.Cursor.Name() == itemName end, 2000)
    end

    if mq.TLO.Cursor.Name() ~= itemName then return false end

    -- He discards the remainder of an over-sized hand-in, so a stack must never go over.
    if (mq.TLO.Cursor.Stack() or 1) > 1 then
        peltPrint(string.format("\arPicked up a whole stack of %s instead of one - putting it back.", itemName))
        stowCursor()
        return false
    end
    return true
end

-- One hand-in: three single pelts into three slots of the give window, then Give. They have
-- to go over UNSTACKED - a stack gets handed straight back. Returns true only when the
-- inventory count actually fell by three, never on the button press.
local function tradeThree(itemName, npcId)
    -- The give window is opened by left-clicking the TARGET, so a target that drifted would
    -- hand the pelts to whatever is selected instead. Checked every round, not just the first.
    if (mq.TLO.Target.ID() or 0) ~= npcId then
        peltPrint(string.format("\arLost the target on %s.", npcName))
        return false
    end

    local before = countOf(itemName)
    local placed = 0

    while placed < 3 do
        if not pickUpOne(itemName) then break end
        if placed == 0 then
            mq.TLO.Target.LeftClick()
            if not waitFor(function() return giveWnd.Open() == true end, 3000) then break end
        else
            mq.cmdf('/notify GiveWnd GVW_MyItemSlot%d leftmouseup', placed)
        end
        if not waitFor(function() return mq.TLO.Cursor.Name() ~= itemName end, 3000) then break end
        placed = placed + 1
    end

    if placed < 3 then
        if giveWnd.Open() then
            mq.cmd('/notify GiveWnd GVW_Cancel_Button leftmouseup')
            waitFor(function() return not giveWnd.Open() end, 2000)
        end
        stowCursor()
        return false
    end

    -- One press does not always take, so it is pressed again while the window stays open.
    local presses = 0
    while giveWnd.Open() and presses < 12 do
        mq.cmd('/notify GiveWnd GVW_Give_Button leftmouseup')
        waitFor(function() return not giveWnd.Open() end, 500)
        presses = presses + 1
    end

    if giveWnd.Open() then
        mq.cmd('/notify GiveWnd GVW_Cancel_Button leftmouseup')
        waitFor(function() return not giveWnd.Open() end, 2000)
        stowCursor()
        return false
    end

    waitFor(function() return countOf(itemName) <= before - 3 end, 5000)
    stowCursor()

    if countOf(itemName) > before - 3 then
        peltPrint(string.format("\ar%s handed the %s back.", npcName, itemName))
        return false
    end

    -- The target is re-read because the give window took focus off it for the next round.
    mq.cmdf('/target id %d', npcId)
    waitFor(function() return (mq.TLO.Target.ID() or 0) == npcId end, 2000)
    return true
end

local function tradeAll(npcId)
    local trades = 0

    for _, quality in ipairs(tradeQualities) do
        for _, kind in ipairs(peltKinds) do
            local itemName = quality .. " " .. kind
            while countOf(itemName) >= 3 do
                if not tradeThree(itemName, npcId) then
                    peltPrint(string.format("\ayStopping on %s.", itemName))
                    return trades
                end
                trades = trades + 1
                peltPrint(string.format("Traded 3 %s, \ay%d\at left.", itemName, countOf(itemName)))
                mq.delay(300)
            end
        end
    end

    return trades
end

-- Main Execution

local function upgradePelts()
    peltPrint(string.format(">>-->>> Pelt Trade v%s <<<--<<", version))

    if not checkZone() then return end
    if not checkGuktan() then return end
    if not pluginReady('MQ2Nav', "cannot walk to him") then return end
    if not stowCursor() then
        peltPrint("\arClear your cursor first.")
        return
    end

    local tradeable = 0
    for _, quality in ipairs(tradeQualities) do
        for _, kind in ipairs(peltKinds) do
            tradeable = tradeable + math.floor(countOf(quality .. " " .. kind) / 3)
        end
    end
    if tradeable == 0 then
        reportCounts("What you are carrying")
        peltPrint("\ayNothing to trade - he needs three of one kind below High quality.")
        return
    end

    if not travelToRathe() then return end
    -- Straight after the zone, before walking anywhere: zoning is what drops the illusion.
    if not waitForIllusion() then return end

    local npcId = goToNPC()
    if not npcId then return end

    reportCounts("Starting totals")
    local trades = tradeAll(npcId)

    if trades > 0 then
        reportCounts("Final totals")
    end
    peltPrint(string.format("\agDone\at - %d hand-in%s.", trades, trades == 1 and "" or "s"))
end

upgradePelts()
