return {
    -- Debug mode (true/false)
    debug = false,

    -- Use weapon components from this script
    -- false = allow /loadweapon to equip instead
    weaponComponents = true,

    -- Repair settings
    repairTime = 30000, -- ms for repair progress bar

    -- Weapon degradation rate per shot
    degradeRate = 0.01,

    -- Damage modifiers
    weaponDamage = 0.65,
    meleeDamage = 1.0,

    -- Throwable weapon ammo mappings
    ThrowableWeaponAmmoTypes = {
        ['weapon_thrown_throwing_knives']   = 'AMMO_THROWING_KNIVES',
        ['weapon_thrown_tomahawk']          = 'AMMO_TOMAHAWK',
        ['weapon_thrown_tomahawk_ancient']  = 'AMMO_TOMAHAWK_ANCIENT',
        ['weapon_thrown_bolas']             = 'AMMO_BOLAS',
        ['weapon_thrown_bolas_hawkmoth']    = 'AMMO_BOLAS_HAWKMOTH',
        ['weapon_thrown_bolas_ironspiked']  = 'AMMO_BOLAS_IRONSPIKED',
        ['weapon_thrown_bolas_intertwined'] = 'AMMO_BOLAS_INTERTWINED',
        ['weapon_thrown_dynamite']          = 'AMMO_DYNAMITE',
        ['weapon_thrown_molotov']           = 'AMMO_MOLOTOV',
        ['weapon_thrown_poisonbottle']      = 'AMMO_POISONBOTTLE',
        ['weapon_melee_hatchet']            = 'AMMO_HATCHET',
        ['weapon_melee_hatchet_hunter']     = 'AMMO_HATCHET_HUNTER',
        ['weapon_melee_cleaver']            = 'AMMO_HATCHET_CLEAVER',
    }
}
