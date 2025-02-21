local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LOCAL_PLAYER = Players.LocalPlayer
local GAME_ID = 14229762361
local JUDAR_JSON_FILE = "JudarData.json"

-- **Ensure Required Services are Loaded**
local Loader = require(ReplicatedStorage.src.Loader)
local ItemInventoryServiceClient = nil
repeat
    task.wait(1) -- Wait until the service is available
    ItemInventoryServiceClient = Loader.load_client_service(script, "ItemInventoryServiceClient")
until ItemInventoryServiceClient

if not ItemInventoryServiceClient then
    error("Failed to load ItemInventoryServiceClient!")
end

print("ItemInventoryServiceClient loaded successfully.")

-- **Check if Player is in the Target Game**
local function isInTargetGame()
    return game.PlaceId == GAME_ID
end

-- **Load Team Loadout**
local function loadTeamLoadout(loadout)
    if ReplicatedStorage.endpoints.client_to_server.load_team_loadout then
        ReplicatedStorage.endpoints.client_to_server.load_team_loadout:InvokeServer(tostring(loadout))
    else
        warn("Failed to load team loadout: Endpoint not found!")
    end
end

-- **Equip a Unit by UUID**
local function equipUnit(uuid)
    if ReplicatedStorage.endpoints.client_to_server.equip_unit then
        ReplicatedStorage.endpoints.client_to_server.equip_unit:InvokeServer(uuid)
    else
        warn("Failed to equip unit: Endpoint not found!")
    end

    -- **Ensure Equipped Units Refresh Properly**
    if ItemInventoryServiceClient and typeof(ItemInventoryServiceClient.refresh_equipped_units) == "function" then
        ItemInventoryServiceClient.refresh_equipped_units()
    else
        warn("refresh_equipped_units function not available or not a function!")
    end
end

-- **Get All Owned Units**
local function getUnitsOwner()
    if ItemInventoryServiceClient then
        return ItemInventoryServiceClient["session"]["collection"]["collection_profile_data"]["owned_units"]
    end
    return {}
end

-- **Get Inventory Items**
local function getInventoryItems()
    return ItemInventoryServiceClient["session"]["inventory"]["inventory_profile_data"]["normal_items"]
end

-- **Count Judar Units**
local function countJudarUnits()
    local owned_units = getUnitsOwner()
    local count = 0

    for _, unit in pairs(owned_units) do
        if unit["unit_id"] == "judar" then
            count = count + 1
        end
    end

    return count
end

-- **Count Judar Spears**
local function countJudarSpears()
    local inventory = getInventoryItems()
    return inventory["judar_spear"] or 0
end

-- **Buy a Judar Spear**
local function buyJudarSpear()
    local args = {
        [1] = "judar_spear",
        [2] = "event",
        [3] = "event_shop",
        [4] = "1"
    }
    ReplicatedStorage.endpoints.client_to_server.buy_item_generic:InvokeServer(unpack(args))
    print("Purchased 1 Judar Spear.")
end

-- **Ensure Enough Judar Spears**
local function ensureJudarSpears()
    local judarCount = countJudarUnits()
    local judarSpearCount = countJudarSpears()

    print(string.format("Judar units: %d | Judar Spears: %d", judarCount, judarSpearCount))

    while judarSpearCount < judarCount do
        print("Buying 1 Judar Spear...")
        buyJudarSpear()
        task.wait(1) -- Prevent spamming
        judarSpearCount = countJudarSpears() -- Update count after buying
        print(string.format("Updated Judar Spears: %d", judarSpearCount))
    end

    print("Judar Spears are now equal to Judar units. Stopping purchase.")
end

-- **Log Judar's UUID, Takedowns, and Worthiness**
local function logJudarInfo()
    local judarData = {}

    for _, unit in pairs(getUnitsOwner()) do
        if unit["unit_id"]:lower() == "judar" then
            table.insert(judarData, { 
                uuid = unit["uuid"], 
                total_takedowns = unit["total_takedowns"] or 0, 
                worthiness = unit["stat_luck"] or 0 
            })
        end
    end

    -- Print out Judar information
    print(string.format("Total Judar units: %d", #judarData))
    for i, judar in ipairs(judarData) do
        print(string.format("%d: Judar | UUID: %s | Takedowns: %d | Worthiness: %d", 
            i, judar.uuid, judar.total_takedowns, judar.worthiness
        ))
    end

    return judarData
end

-- **Create JSON File**
local function createJsonFile(fileName, jsonData)
    local jsonString = HttpService:JSONEncode(jsonData)
    writefile(fileName, jsonString)
    print("JSON file created: " .. fileName)
end

-- **Save Judar Data**
local function saveFilteredJudarData()
    local judarData = logJudarInfo()
    createJsonFile(JUDAR_JSON_FILE, judarData)
end

-- **Fetch the Best Judar UUID (Highest Takedowns < 10k)**
local function getBestJudarUUID()
    if isfile(JUDAR_JSON_FILE) then
        local data = readfile(JUDAR_JSON_FILE)
        local judarList = HttpService:JSONDecode(data) or {}

        table.sort(judarList, function(a, b)
            return a.total_takedowns > b.total_takedowns -- Sort by highest takedowns
        end)

        for _, judar in ipairs(judarList) do
            if judar.total_takedowns < 10000 then
                return judar.uuid
            end
        end
    end
    return nil
end

-- **Main Execution Logic**
if isInTargetGame() then
    loadTeamLoadout(1)
    print("Selected team loadout 1 for the target game.")
    return -- **Exit Script to Stop All Other Functions**
else
    loadTeamLoadout(6)
    print("Selected team loadout 6 for non-target game.")

    saveFilteredJudarData()

    local bestJudarUUID = getBestJudarUUID()
    if bestJudarUUID then
        equipUnit(bestJudarUUID)
        print("Equipped Judar with UUID: " .. bestJudarUUID)
    else
        warn("No valid Judar found to equip!")
    end

    -- **Ensure we have enough Judar Spears**
    ensureJudarSpears()
end
