local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'config'

local UsedWeapons = {}
local weaponInHands = {}
local currentWeaponSerial = nil
local infinityOn = false

------------------------------------------
-- EXPORTS
------------------------------------------
exports('weaponInHands', function()
    return next(weaponInHands) and weaponInHands or nil
end)

exports('UsedWeapons', function(serial)
    UsedWeapons[serial] = nil
end)

exports('GetUsedWeapons', function()
    return UsedWeapons
end)

exports('CheckWeaponSerial', function()
    local serial, hash
    local _, wepHash = GetCurrentPedWeapon(cache.ped, true, 0, true)

    if currentWeaponSerial then
        for k, v in pairs(weaponInHands) do
            if tonumber(wepHash) == tonumber(k) then
                hash, serial = k, v
                break
            end
        end
    end

    if config.Debug then
        print(('^5Weapon Serial^7   : ^2%s^7'):format(tostring(serial)))
        print(('^5Weapon Hash^7     : ^2%s^7'):format(tostring(hash)))
    end
    return serial, hash
end)

------------------------------------------
-- UTILS
------------------------------------------
local function getGuidFromItemId(inventoryId, itemData, category, slotId)
    itemData = itemData or 0
    local outItem = DataView.ArrayBuffer(8 * 13)
    local success = Citizen.InvokeNative(0x886DFD3E185C8A89, inventoryId, itemData, category, slotId, outItem:Buffer())
    return success and outItem:Buffer() or nil
end

local function addWardrobeInventoryItem(itemName, slotHash)
    local itemHash = GetHashKey(itemName)
    if not Citizen.InvokeNative(0x6D5D51B188333FD1, itemHash, 0) then return false end

    local inventoryId = 1
    local characterItem = getGuidFromItemId(inventoryId, nil, GetHashKey("CHARACTER"), 0xA1212100)
    if not characterItem then return false end

    local wardrobeItem = getGuidFromItemId(inventoryId, characterItem, GetHashKey("WARDROBE"), 0x3DABBFA7)
    if not wardrobeItem then return false end

    local itemData = DataView.ArrayBuffer(8 * 13)
    local added = Citizen.InvokeNative(0xCB5D11F9508A928D, inventoryId, itemData:Buffer(), wardrobeItem, itemHash, slotHash, 1, GetHashKey("ADD_REASON_DEFAULT"))
    if not added then return false end

    return Citizen.InvokeNative(0x734311E2852760D0, inventoryId, itemData:Buffer(), true)
end

local function equipWeaponToPed(hash, weaponName)
    GiveWeaponToPed(cache.ped, hash, 0, false, true)
    SetCurrentPedWeapon(cache.ped, hash, true)
    SetAmmoInClip(cache.ped, hash, 0)
    if config.WeaponComponents then
        TriggerServerEvent('rsg-weaponcomp:server:check_comps')
    end
end

------------------------------------------
-- USE WEAPON
------------------------------------------
RegisterNetEvent('rsg-weapons:client:UseWeapon', function(weaponData)
    local weaponName = tostring(weaponData.name)
    local hash = joaat(weaponData.name)
    local wepSerial = tostring(weaponData.info.serie)
    local wepQuality = weaponData.info.quality
    local EquippedWeapons = exports['rsg-weapons']:EquippedWeapons() or {}
    local isGun = Citizen.InvokeNative(0x705BE297EEBDB95D, hash)
    local isOneHanded = Citizen.InvokeNative(0xD955FEE4B87AFA07, hash)

    if wepQuality <= 1 then
        WeaponAPI.RemoveWeaponFromPeds(weaponName, wepSerial)
        UsedWeapons[wepSerial] = nil
        TriggerEvent('rsg-weapons:client:brokenweapon', wepSerial)
        if config.WeaponComponents then
            TriggerServerEvent("rsg-weaponcomp:server:removeComponents", "DEFAULT", weaponName, wepSerial)
            TriggerServerEvent('rsg-weaponcomp:server:check_comps')
        end
        return lib.notify({ title = locale('cl_weapon_degraded'), type = 'error', duration = 5000 })
    end

    for _, v in pairs(EquippedWeapons) do
        if v.hash == hash then
            WeaponAPI.used2 = true
            break
        end
    end

    if not UsedWeapons[wepSerial] then
        UsedWeapons[wepSerial] = { name = weaponName, WeaponHash = hash, data = weaponData, serie = wepSerial }

        if weaponName:find('weapon_bow') then
            equipWeaponToPed(hash)
        elseif isGun and isOneHanded then
            addWardrobeInventoryItem("CLOTHING_ITEM_M_OFFHAND_000_TINT_004", 0xF20B6B4A)
            addWardrobeInventoryItem("UPGRADE_OFFHAND_HOLSTER", 0x39E57B01)
            WeaponAPI.EquipWeapon(weaponName, WeaponAPI.used2 and 1 or 0, wepSerial, hash)
        else
            equipWeaponToPed(hash)
        end

        currentWeaponSerial, weaponInHands[hash] = wepSerial, wepSerial

        -- Set degradation
        local entityIndex = GetCurrentPedWeaponEntityIndex(cache.ped, 0)
        local object = GetObjectIndexFromEntityIndex(entityIndex)
        if DoesEntityExist(object) then
            local currentDeg = wepQuality == 100 and 0.0 or (1.0 - (wepQuality / 100))
            Citizen.InvokeNative(0xA7A57E89E965D839, object, currentDeg)
        end
    else
        WeaponAPI.RemoveWeaponFromPeds(weaponName, wepSerial)
        UsedWeapons[wepSerial] = nil
    end
end)

------------------------------------------
-- USE THROWN WEAPON
------------------------------------------
RegisterNetEvent('rsg-weapons:client:UseThrownWeapon', function(weaponData)
    local weaponName = tostring(weaponData.name)
    local hash = joaat(weaponData.name)
    local ammoType = config.ThrowableWeaponAmmoTypes[weaponName]
    local ammoDefinition = exports['rsg-ammo']:GetAmmoTypes()[ammoType]
    if not ammoDefinition then return lib.print.info('No definition', ammoType, weaponName) end

    local desiredAmount = GetPedAmmoByType(cache.ped, ammoDefinition.hash) + ammoDefinition.refill
    if desiredAmount > ammoDefinition.maxAmmo then
        return lib.notify({ title = locale('cl_ammo_max'), type = 'error', duration = 5000 })
    end

    if not HasPedGotWeapon(cache.ped, hash) then
        GiveWeaponToPed(cache.ped, hash, 0)
    end

    AddAmmoToPedByType(cache.ped, ammoDefinition.hash, ammoDefinition.refill)
    SetCurrentPedWeapon(cache.ped, hash, true)
    TriggerServerEvent('rsg-weapons:server:removeitem', weaponName, 1)
end)

------------------------------------------
-- USE EQUIPMENT
------------------------------------------
RegisterNetEvent('rsg-weapons:client:UseEquipment', function(weaponData)
    local weaponName = tostring(weaponData.name)
    local hash = joaat(weaponData.name)

    if weaponName == 'weapon_melee_torch' and not HasPedGotWeapon(cache.ped, hash) then
        equipWeaponToPed(hash)
        return TriggerServerEvent('rsg-weapons:server:removeitem', weaponName, 1)
    end

    if not HasPedGotWeapon(cache.ped, hash) then
        equipWeaponToPed(hash)
    else
        RemoveWeaponFromPed(cache.ped, hash)
    end
end)

------------------------------------------
-- THREADS (MERGED FOR PERFORMANCE)
------------------------------------------
CreateThread(function()
    while true do
        Wait(0) -- run every frame
        if IsPedShooting(cache.ped) then
            local heldWeapon = Citizen.InvokeNative(0x8425C5F057012DAB, cache.ped)
            if heldWeapon and heldWeapon ~= -1569615261 then
                TriggerServerEvent('rsg-weapons:server:degradeWeapon', weaponInHands[heldWeapon])
            end
        end
        SetPlayerWeaponDamageModifier(PlayerId(), config.WeaponDmg)
        SetPlayerMeleeWeaponDamageModifier(PlayerId(), config.MeleeDmg)
        if IsPlayerFreeAiming(PlayerId()) then
            DisableControlAction(0, 0x8FFC75D6, true)
        end
    end
end)

------------------------------------------
-- REPAIR WEAPON (STANDARD)
------------------------------------------
RegisterNetEvent('rsg-weapons:client:repairweapon', function()
    local heldWeapon = Citizen.InvokeNative(0x8425C5F057012DAB, cache.ped)
    local currentSerial = weaponInHands[heldWeapon]
    local hasItem = RSGCore.Functions.HasItem('weapon_repair_kit', 1)

    if hasItem and currentSerial and heldWeapon ~= -1569615261 then
        LocalPlayer.state:set("inv_busy", true, true)
        lib.progressBar({
            duration = config.RepairTime,
            position = 'bottom',
            label = locale('cl_repairing_weapon'),
            canCancel = false,
            disable = { move = true, mouse = true }
        })
        TriggerServerEvent('rsg-weapons:server:removeitem', 'weapon_repair_kit', 1)
        TriggerServerEvent('rsg-weapons:server:repairweapon', currentSerial)
        LocalPlayer.state:set("inv_busy", false, true)
    else
        lib.notify({
            title = locale('cl_no_weapon_found'),
            description = locale('cl_no_weapon_found_desc'),
            type = 'inform',
            icon = 'fa-solid fa-gun',
            iconAnimation = 'shake',
            duration = 7000
        })
    end
end)

------------------------------------------
-- BROKEN WEAPON PROMPT
------------------------------------------
RegisterNetEvent('rsg-weapons:client:brokenweapon', function(serial)
    local input = lib.inputDialog(locale('cl_weapon_repair'), {
        {
            type = 'select',
            label = locale('cl_weapon_repair_p'),
            options = {
                { value = 'yes', text = locale('cl_reapir_yes') },
                { value = 'no',  text = locale('cl_reapir_no') }
            },
            required = true
        }
    })
    if input and input[1] == 'yes' then
        TriggerEvent('rsg-weapons:client:repairbrokenweapon', serial)
    end
end)

------------------------------------------
-- REPAIR BROKEN WEAPON
------------------------------------------
RegisterNetEvent('rsg-weapons:client:repairbrokenweapon', function(serial)
    local hasItem = RSGCore.Functions.HasItem('weapon_repair_kit', 1)
    if hasItem and serial then
        LocalPlayer.state:set("inv_busy", true, true)
        lib.progressBar({
            duration = config.RepairTime,
            position = 'bottom',
            label = locale('cl_repairing_weapon'),
            canCancel = false,
            disable = { move = true, mouse = true }
        })
        TriggerServerEvent('rsg-weapons:server:removeitem', 'weapon_repair_kit', 1)
        TriggerServerEvent('rsg-weapons:server:repairweapon', serial)
        LocalPlayer.state:set("inv_busy", false, true)
    else
        lib.notify({
            title = locale('cl_item_need'),
            description = locale('cl_item_need_desc'),
            type = 'inform',
            icon = 'fa-solid fa-gun',
            iconAnimation = 'shake',
            duration = 7000
        })
    end
end)

------------------------------------------
-- INFINITE AMMO (ADMIN)
------------------------------------------
RegisterCommand('infinityammo', function()
    TriggerServerEvent('rsg-weapons:requestToggle')
end, false)

RegisterNetEvent('rsg-weapons:toggle', function()
    local ped = cache.ped
    local hasWeapon, weaponHash = GetCurrentPedWeapon(ped, true)
    if hasWeapon and weaponHash ~= `WEAPON_UNARMED` then
        infinityOn = not infinityOn
        SetPedInfiniteAmmoClip(ped, infinityOn)
        SetPedInfiniteAmmo(ped, infinityOn, weaponHash)
        lib.notify({
            title = 'Infinity Ammo',
            description = infinityOn and 'Infinite ammo enabled.' or 'Infinite ammo disabled.',
            type = infinityOn and 'success' or 'inform'
        })
    else
        lib.notify({
            title = 'Infinity Ammo',
            description = 'You are not holding a weapon.',
            type = 'error'
        })
    end
end)
