local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'config'

WeaponAPI = {
    used = false,
    used2 = false
}

local EquippedWeapons = {}
exports('EquippedWeapons', function()
    return EquippedWeapons
end)

------------------------------------------
-- LOW-LEVEL HELPERS
------------------------------------------
local function ItemdatabaseIsKeyValid(weaponHash, unk)
    return Citizen.InvokeNative(0x6D5D51B188333FD1, weaponHash, unk)
end

local function InventoryAddItemWithGuid(inventoryId, itemData, parentItem, itemHash, slotHash, amount, addReason)
    return Citizen.InvokeNative(0xCB5D11F9508A928D, inventoryId, itemData, parentItem, itemHash, slotHash, amount, addReason)
end

local function InventoryEquipItemWithGuid(inventoryId, itemData, bEquipped)
    return Citizen.InvokeNative(0x734311E2852760D0, inventoryId, itemData, bEquipped)
end

local function getGuidFromItemId(inventoryId, itemData, category, slotId)
    local outItem = DataView.ArrayBuffer(8 * 13)
    local success = Citizen.InvokeNative(0x886DFD3E185C8A89, inventoryId, itemData or 0, category, slotId, outItem:Buffer())
    return success and outItem or nil
end

local function moveInventoryItem(inventoryId, old, new, slot)
    local outGUID = DataView.ArrayBuffer(8 * 13)
    local sHash = "SLOTID_WEAPON_" .. tostring(slot or 1)
    local success = Citizen.InvokeNative(0xDCCAA7C3BFD88862, inventoryId, old, new, joaat(sHash), 1, outGUID:Buffer())
    return success and outGUID or nil
end

------------------------------------------
-- EQUIP WEAPON
------------------------------------------
WeaponAPI.EquipWeapon = function(weaponName, slot, id, hash)
    local ped = cache.ped
    local weaponHash = joaat(weaponName)
    local slotHash = joaat("SLOTID_WEAPON_" .. tostring(slot))
    local addReason = ADD_REASON_DEFAULT
    local inventoryId = 1
    local move = false

    -- Slot-correctie
    if slot == 0 and id and #EquippedWeapons > 0 then
        slot = 1
    end

    if not ItemdatabaseIsKeyValid(weaponHash, 0) then
        if config.Debug then print(("Weapon %s not valid"):format(weaponName)) end
        return false
    end

    local characterItem = getGuidFromItemId(inventoryId, nil, joaat("CHARACTER"), 0xA1212100)
    if not characterItem then
        if config.Debug then print("No character item found") end
        return false
    end

    local weaponItem = getGuidFromItemId(inventoryId, characterItem:Buffer(), 923904168, -740156546)
    if not weaponItem then
        if config.Debug then print("No weapon container item found") end
        return false
    end

    if slot == 1 then
        if #EquippedWeapons > 0 then
            if not moveInventoryItem(inventoryId, EquippedWeapons[1].guid, weaponItem:Buffer(), 1) then
                if config.Debug then print("Cannot move item") end
                return false
            end
            slotHash = joaat('SLOTID_WEAPON_0')
            slot, move = 0, true
        else
            slotHash = joaat('SLOTID_WEAPON_0')
            slot = 0
        end
    end

    local itemData = DataView.ArrayBuffer(8 * 13)
    if not InventoryAddItemWithGuid(inventoryId, itemData:Buffer(), weaponItem:Buffer(), weaponHash, slotHash, 1, addReason) then
        if config.Debug then print("Item not added") end
        return false
    end

    if not InventoryEquipItemWithGuid(inventoryId, itemData:Buffer(), true) then
        if config.Debug then print("Unable to equip item") end
        return false
    end

    WeaponAPI.used = true
    Citizen.InvokeNative(0x12FB95FE3D579238, ped, itemData:Buffer(), true, slot, false, false)

    if move then
        Citizen.InvokeNative(0x12FB95FE3D579238, ped, EquippedWeapons[1].guid, true, 1, false, false)
    end

    if id then
        table.insert(EquippedWeapons, {
            id = id,
            name = weaponName,
            hash = hash,
            guid = itemData:Buffer()
        })
    end

    return true
end

------------------------------------------
-- REMOVE WEAPON FROM PED
------------------------------------------
WeaponAPI.RemoveWeaponFromPeds = function(weaponName, serial)
    local ped = cache.ped
    local weaponHash = joaat(weaponName)
    local isGun = Citizen.InvokeNative(0x705BE297EEBDB95D, weaponHash)
    local isOneHanded = Citizen.InvokeNative(0xD955FEE4B87AFA07, weaponHash)
    local inventoryId = 1
    local weaponRemoved = false

    if isGun and isOneHanded then
        for k, v in pairs(EquippedWeapons) do
            if v.id == serial then
                Citizen.InvokeNative(0x3E4E811480B3AE79, inventoryId, v.guid, 1, joaat("REMOVE_REASON_DEFAULT"))
                table.remove(EquippedWeapons, k)
                weaponRemoved = true
                break
            end
        end
    end

    if weaponRemoved and #EquippedWeapons > 0 then
        exports['rsg-weapons']:UsedWeapons(serial)
        WeaponAPI.used2 = false

        local characterItem = getGuidFromItemId(inventoryId, nil, joaat("CHARACTER"), 0xA1212100)
        if not characterItem then
            if config.Debug then print("Character item not found") end
            return false
        end

        local weaponItem = getGuidFromItemId(inventoryId, characterItem:Buffer(), 923904168, -740156546)
        if not weaponItem then
            if config.Debug then print("Weapon item not found") end
            return false
        end

        if moveInventoryItem(inventoryId, EquippedWeapons[1].guid, weaponItem:Buffer(), 0) then
            Citizen.InvokeNative(0x12FB95FE3D579238, ped, EquippedWeapons[1].guid, true, 0, false, false)
        else
            if config.Debug then print("Error moving remaining weapon") end
        end
    else
        RemoveWeaponFromPed(ped, weaponHash, true, 0)
        exports['rsg-weapons']:UsedWeapons(serial)
        WeaponAPI.used = false
    end
end
exports('RemoveWeaponFromPeds', WeaponAPI.RemoveWeaponFromPeds)

------------------------------------------
-- RETURN TABLE
------------------------------------------
return WeaponAPI