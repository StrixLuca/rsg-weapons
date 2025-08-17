local RSGCore = exports['rsg-core']:GetCoreObject()


------------------------------------------
-- GET WEAPON INFO
------------------------------------------
RSGCore.Functions.CreateCallback('rsg-weapons:server:getweaponinfo', function(source, cb, weaponserial)
    local weaponinfo = MySQL.query.await(
        'SELECT * FROM player_weapons WHERE serial = @serial',
        { ['@serial'] = weaponserial }
    )

    if not weaponinfo or not weaponinfo[1] then
        return cb(nil)
    end

    cb(weaponinfo)
end)

------------------------------------------
-- DEGRADE WEAPON
------------------------------------------
RegisterNetEvent('rsg-weapons:server:degradeWeapon', function(serie)
    local config = require 'config'
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    for _, v in pairs(Player.PlayerData.items) do
        if v.type == 'weapon' and v.info.serie == serie then
            local newQuality = math.floor((v.info.quality - config.DegradeRate) * 10) / 10
            v.info.quality = newQuality

            if newQuality <= 0 then
                TriggerClientEvent('rsg-weapons:client:UseWeapon', src, v)
            end

            Player.Functions.SetInventory(Player.PlayerData.items)
            return -- stop direct zodra gevonden
        end
    end
end)

------------------------------------------
-- USEABLE: WEAPON REPAIR KIT
------------------------------------------
RSGCore.Functions.CreateUseableItem('weapon_repair_kit', function(source)
    TriggerClientEvent('rsg-weapons:client:repairweapon', source)
end)

------------------------------------------
-- REPAIR WEAPON
------------------------------------------
RegisterNetEvent('rsg-weapons:server:repairweapon', function(serie)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    for _, v in pairs(Player.PlayerData.items) do
        if v.type == 'weapon' and v.info.serie == serie then
            v.info.quality = 100
            Player.Functions.SetInventory(Player.PlayerData.items)

            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_weapon_repaired'),
                type = 'success',
                duration = 5000
            })
            return
        end
    end
end)

------------------------------------------
-- REMOVE ITEM FROM PLAYER
------------------------------------------
RegisterNetEvent('rsg-weapons:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.Functions.RemoveItem(item, amount) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
    end
end)

------------------------------------------
-- INFINITY AMMO (ADMIN ONLY)
------------------------------------------
RegisterNetEvent('rsg-weapons:requestToggle', function()
    local src = source

    if RSGCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('rsg-weapons:toggle', src)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Infinity Ammo',
            description = 'You do not have permission to use this command.',
            type = 'error'
        })
    end
end)