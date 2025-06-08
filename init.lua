 -- By: RedFrog
-- Version 1.02
-- Date: October 13, 2024
-- https://everquest.allakhazam.com/db/quest.html?quest=2317
-- Added zone check for PoK or Rathe Mountains and automated travel if in PoK
-- Merged bag searching functionality from RedFrog's BagFinder.lua

local mq = require('mq')

-- Ensure we are in the right zone and travel if needed
local function moving()
    while mq.TLO.Nav.Active() do mq.delay(100) end  -- Added delay to reduce CPU usage
    return
end

local function zoning(z_id)
    while mq.TLO.Zone.ID() ~= z_id do mq.delay(100) end  -- Added delay to reduce CPU usage
end

local npcName = "Dar Forager Lumun"
local illusionBuff = "Illusion: Guktan"

local function peltPrint(msg)
    print(string.format("\ao[\agPeltTrade\ao]\at %s", msg))
end

local peltBag = nil -- Will hold the bag found with pelts

-- Function to check if the character is Guktan or has a Guktan illusion
local function checkGuktan()
    local race = mq.TLO.Me.Race()
    local hasIllusion = mq.TLO.Me.Buff(illusionBuff)()

    if race == "Froglok" or hasIllusion then
        peltPrint("You are either \agGuktan\ax or under a valid \agGuktan illusion\ax. Continuing...")
        return true
    else
        peltPrint("This quest requires Guktan or an Enchanter's Guktan illusion or potion.")
        return false
    end
end

-- Function to check if the player is in the correct zone
local function checkZone()
    if mq.TLO.Zone.ID() ~= 202 and mq.TLO.Zone.ID() ~= 50 then
        peltPrint("\ayYou must start this script in Plane of Knowledge or The Rathe Mountains.\ax")
        return false
    end
    return true
end

-- Function to travel to The Rathe Mountains from PoK
local function travelToRathe()
    if mq.TLO.Zone.ID() == 202 then
        mq.cmd('/squelch /travelto rathemtn')
        zoning(50)
        peltPrint("\aoTraveling to The Rathe Mountains...\ax")
        mq.delay(5000)
    else
        peltPrint("\aoAlready in The Rathe Mountains.\ax")
    end
end

-- Function to check if the NPC is spawned
local function isNPCSpawned()
    local npc = mq.TLO.Spawn(npcName)
    if not npc() then
        peltPrint(npcName .. " is not in the zone. He usually returns around 6-8 am Norrath time.")
        peltPrint("Current game time: " .. mq.TLO.GameTime()())
        return false
    else
        peltPrint(npcName .. " is available, let's go see him!")
        return true
    end
end

-- Function to move to the NPC location
local function moveToNPC()
    mq.cmdf('/squelch /nav loc -2096, 252, -2.4 log=off')
    moving()
    mq.delay(1000)
    mq.cmdf('/squelch /nav loc -2083.3, 206.8, -7 log=off')
    moving()
    mq.delay(1000)
end

-- Function to interact with the NPC
local function interactWithNPC()
    mq.cmdf("/target %s", npcName)
    mq.delay(1000)
    mq.cmd("/say I am here to make an exchange")
end

-- Define pelt types categorized by quality
local peltTypes = {
    ["Low Quality"] = {
        "Low Quality Bear Skin",
        "Low Quality Cat Pelt",
        "Low Quality Wolf Skin"
    },
    ["Medium Quality"] = {
        "Medium Quality Bear Skin",
        "Medium Quality Cat Pelt",
        "Medium Quality Wolf Skin"
    },
    ["High Quality"] = {
        "High Quality Bear Skin",
        "High Quality Cat Pelt",
        "High Quality Wolf Skin"
    }
}

-- Function to count and print pelt totals, broken down by quality and type
local function countPelts()

--local function countPeltsFromBags()
    local peltCounts = {
        Bear = { Low = 0, Medium = 0, High = 0 },
        Cat = { Low = 0, Medium = 0, High = 0 },
        Wolf = { Low = 0, Medium = 0, High = 0 }
    }

    -- Loop through all main inventory slots (slots 23-32 are typically bag slots)
    for slot = 23, 32 do
        local container = mq.TLO.Me.Inventory(slot)
        
        if container() and container.Container() > 0 then
            -- Search the bag for the pelts
            for bagSlot = 1, container.Container() do
                local item = container.Item(bagSlot)
                if item() then
                    local itemName = item.Name()
                    local itemCount = item.StackCount()
                    if peltBag == nil and (itemName == "Low Quality Bear Skin" or itemName == "Low Quality Cat Pelt" or itemName == "Low Quality Wolf Skin" or
                    itemName == "Medium Quality Bear Skin" or itemName == "Medium Quality Cat Pelt" or itemName == "Medium Quality Wolf Skin") then
                    peltBag = container  -- Assign the bag with pelts to peltBag
                    end
                    -- Check and increment counts based on item name
                    if itemName == "Low Quality Bear Skin" then
                        peltCounts.Bear.Low = peltCounts.Bear.Low + itemCount
                    elseif itemName == "Medium Quality Bear Skin" then
                        peltCounts.Bear.Medium = peltCounts.Bear.Medium + itemCount
                    elseif itemName == "High Quality Bear Skin" then
                        peltCounts.Bear.High = peltCounts.Bear.High + itemCount
                    elseif itemName == "Low Quality Cat Pelt" then
                        peltCounts.Cat.Low = peltCounts.Cat.Low + itemCount
                    elseif itemName == "Medium Quality Cat Pelt" then
                        peltCounts.Cat.Medium = peltCounts.Cat.Medium + itemCount
                    elseif itemName == "High Quality Cat Pelt" then
                        peltCounts.Cat.High = peltCounts.Cat.High + itemCount
                    elseif itemName == "Low Quality Wolf Skin" then
                        peltCounts.Wolf.Low = peltCounts.Wolf.Low + itemCount
                    elseif itemName == "Medium Quality Wolf Skin" then
                        peltCounts.Wolf.Medium = peltCounts.Wolf.Medium + itemCount
                    elseif itemName == "High Quality Wolf Skin" then
                        peltCounts.Wolf.High = peltCounts.Wolf.High + itemCount
                    end
                end
            end
        end
    end

    -- Print out the totals
    peltPrint(string.format("\apStarting Totals:\ax Bear - Low: %d, Medium: %d, High: \ag%d\ax", peltCounts.Bear.Low, peltCounts.Bear.Medium, peltCounts.Bear.High))
    peltPrint(string.format("\apStarting Totals:\ax Cat - Low: %d, Medium: %d, High: \ag%d\ax", peltCounts.Cat.Low, peltCounts.Cat.Medium, peltCounts.Cat.High))
    peltPrint(string.format("\apStarting Totals:\ax Wolf - Low: %d, Medium: %d, High: \ag%d\ax", peltCounts.Wolf.Low, peltCounts.Wolf.Medium, peltCounts.Wolf.High))

    return peltCounts
end


--[[-- Function to trade pelts to NPC
local function tradePelts()
    local peltsTraded = false -- Track if we traded any pelts

    -- Ensure peltBag is set and valid
    if not peltBag then
        peltPrint("Not enough pelts of any type to trade up. Go farm some.")
        return
    else
        peltPrint("Pelt bag found. Proceeding to trade pelts.")    
    end

    -- Ensure the NPC is targeted and interact with NPC to open trade
    mq.cmd("/target Dar Forager Lumun")
    mq.delay(1000)  -- Delay to ensure targeting

    -- Loop through each quality and type of pelt
    for quality, pelts in pairs(peltTypes) do
        -- Skip High Quality pelts, as they are the final result
        if quality == "High Quality" then
            peltPrint("\aoSkipping High Quality pelts, they are the final result.\ax")
        else
            for _, pelt in ipairs(pelts) do
                -- Use FindItem to find the pelt in the inventory or bags
                local itemInBag = mq.TLO.FindItem(pelt)
                local itemSlot = itemInBag.ItemSlot()
                local itemSlot2 = itemInBag.ItemSlot2()

                -- Check if the item exists in the inventory or bags
                if itemInBag() and itemSlot then
                    local count = itemInBag.StackCount()

                    -- Calculate the correct bag slot (pack) and item slot inside the bag
                    local bagSlot = itemSlot - 22  -- Adjust for bag slot, assuming slots 23-32 are bags
                    local bagItemSlot = itemSlot2 + 1  -- Adjust for item slot inside the bag

                    -- Trade pelts 3 at a time until we have fewer than 3
                    while count >= 3 do
                        peltsTraded = true  -- Set flag that pelts were traded
                        peltPrint("Giving 3 " .. tostring(pelt) .. " to NPC...")

                        -- Pick up the pelt from the bag and place it on the cursor
                        mq.cmdf('/itemnotify in pack%d %d leftmouseup', bagSlot, bagItemSlot)  -- Interact with the item slot inside the open bag
                        mq.delay(500)  -- Small delay to simulate pickup

                        -- Check if the Quantity window opens (for stacks), and set quantity to 3
                        if mq.TLO.Window("QuantityWnd").Open() then
                            peltPrint("Quantity window detected. Selecting 3 pelts.")
                            mq.cmd('/notify QuantityWnd QTYW_slider newvalue 3')  -- Set the quantity to 3
                            mq.delay(500)
                            mq.cmd('/notify QuantityWnd QTYW_Accept_Button leftmouseup')  -- Accept the quantity selection
                            mq.delay(500)
                        end

                        -- Validate the item on the cursor
                        if mq.TLO.Cursor.ID() ~= itemInBag.ID() then
                            peltPrint("[Invalid item on cursor] " .. tostring(mq.TLO.Cursor.Name()))
                            mq.exit()
                        end

                        -- Use /notify to place the item in the NPC's trade window
                        mq.cmd("/notify GiveWnd GVW_MyItemSlot0 leftmouseup")  -- Place the item in the trade window slot
                        mq.delay(500)

                        -- Confirm the trade with NPC using the Give button
                        mq.cmd("/notify GiveWnd GVW_Give_Button leftmouseup")
                        mq.delay(1000)  -- Wait for the NPC response

                        -- Update the remaining count of pelts
                        count = itemInBag.StackCount()  -- Update after trading
                        peltPrint("Remaining " .. tostring(pelt) .. " count: " .. tostring(count))
                        mq.delay(1000) -- Wait for NPC response and exchange
                    end
                else
                    peltPrint("\aoPelt not found in inventory: \ax" .. tostring(pelt))
                end
            end
        end
    end

    -- If no pelts were traded, print a message indicating the quest is complete
    if not peltsTraded then
        peltPrint("\ayNo more pelts to trade. \agQuest complete!\ax The script will now end.\ax")
        mq.cmd('/keypress CLOSE_INV_BAGS')
    end--]]

    local function tradePelts()
        local peltsTraded = false  -- Track if we traded any pelts
    
        -- Ensure peltBag is set and valid
        if not peltBag then
            peltPrint("Not enough pelts of any type to trade up. Go farm some.")
            return
        else
            peltPrint("Pelt bag found. Proceeding to trade pelts.")    
        end
    
        -- Ensure the NPC is targeted and interact with NPC to open trade
        mq.cmd("/target Dar Forager Lumun")
        mq.delay(1000)  -- Delay to ensure targeting
    
        -- Loop through each quality and type of pelt
        for quality, pelts in pairs(peltTypes) do
            -- Skip High Quality pelts, as they are the final result
            if quality == "High Quality" then
                peltPrint("\aoSkipping High Quality pelts, they are the final result.\ax")
            else
                for _, pelt in ipairs(pelts) do
                    -- Use FindItem to find the pelt in the inventory or bags
                    local itemInBag = mq.TLO.FindItem(pelt)
                    
                    if itemInBag() then  -- Check if the item exists
                        local count = itemInBag.StackCount()
    
                        -- Check if we have enough pelts to trade
                        if count >= 3 then
                            peltsTraded = true  -- Set flag that pelts were traded
                            peltPrint("Giving 3 " .. tostring(pelt) .. " to NPC...")
    
                            -- Proceed with trading logic (as in your original code)
                            -- Pick up and trade pelts 3 at a time, and confirm the trade
    
                        else
                            peltPrint("Not enough " .. tostring(pelt) .. " to trade.")
                        end
                    else
                        peltPrint("\aoPelt not found in inventory: \ax" .. tostring(pelt))  -- Only print if item not found
                    end
                end
            end
        end
    
        if not peltsTraded then
            peltPrint("No pelts were traded. Make sure you have enough to trade.")
        end
    end
    
--    mq.exit()  -- End the script


-- Function to recount pelts after trading
local function recountPelts()
local peltCounts = {
    Bear = { Low = 0, Medium = 0, High = 0 },
    Cat = { Low = 0, Medium = 0, High = 0 },
    Wolf = { Low = 0, Medium = 0, High = 0 }
}

-- Loop through all main inventory slots (slots 23-32 are typically bag slots)
for slot = 23, 32 do
    local container = mq.TLO.Me.Inventory(slot)
    
    if container() and container.Container() > 0 then
        -- Search the bag for the pelts
        for bagSlot = 1, container.Container() do
            local item = container.Item(bagSlot)
            if item() then
                local itemName = item.Name()
                local itemCount = item.StackCount()

                -- Check and increment counts based on item name
                if itemName == "Low Quality Bear Skin" then
                    peltCounts.Bear.Low = peltCounts.Bear.Low + itemCount
                elseif itemName == "Medium Quality Bear Skin" then
                    peltCounts.Bear.Medium = peltCounts.Bear.Medium + itemCount
                elseif itemName == "High Quality Bear Skin" then
                    peltCounts.Bear.High = peltCounts.Bear.High + itemCount
                elseif itemName == "Low Quality Cat Pelt" then
                    peltCounts.Cat.Low = peltCounts.Cat.Low + itemCount
                elseif itemName == "Medium Quality Cat Pelt" then
                    peltCounts.Cat.Medium = peltCounts.Cat.Medium + itemCount
                elseif itemName == "High Quality Cat Pelt" then
                    peltCounts.Cat.High = peltCounts.Cat.High + itemCount
                elseif itemName == "Low Quality Wolf Skin" then
                    peltCounts.Wolf.Low = peltCounts.Wolf.Low + itemCount
                elseif itemName == "Medium Quality Wolf Skin" then
                    peltCounts.Wolf.Medium = peltCounts.Wolf.Medium + itemCount
                elseif itemName == "High Quality Wolf Skin" then
                    peltCounts.Wolf.High = peltCounts.Wolf.High + itemCount
                end
            end
        end
    end
end

-- Print out the final totals only
peltPrint(string.format("\apFinal Totals:\ax Bear - Low: %d, Medium: %d, High: \ag%d\ax", peltCounts.Bear.Low, peltCounts.Bear.Medium, peltCounts.Bear.High))
peltPrint(string.format("\apFinal Totals:\ax Cat - Low: %d, Medium: %d, High: \ag%d\ax", peltCounts.Cat.Low, peltCounts.Cat.Medium, peltCounts.Cat.High))
peltPrint(string.format("\apFinal Totals:\ax Wolf - Low: %d, Medium: %d, High: \ag%d\ax", peltCounts.Wolf.Low, peltCounts.Wolf.Medium, peltCounts.Wolf.High))

return peltCounts
end


-- Main function to handle the process
local function upgradePelts()
    peltPrint(">>-->>> Starting Pelt Trade <<<--<<")
    if not checkZone() then return end
    if not checkGuktan() then return end

    travelToRathe()

    if mq.TLO.Zone.ID() == 50 then
        if isNPCSpawned() then
            moveToNPC()
            -- Search all bags for pelts, interact with NPC, and perform trades
            --findItemsInAllBags()
            countPelts()
            interactWithNPC()
            tradePelts()
            recountPelts()
        end
    end
end

-- Script Execution
upgradePelts()
