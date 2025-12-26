--[[
    FS25_UsedPlus - Maintenance System Registration

    Registers the UsedPlusMaintenance vehicle specialization.
    Pattern from: HeadlandManagement headlandManagementRegister.lua

    This file is loaded BEFORE the main specialization to:
    1. Add the specialization to the specialization manager
    2. Add it to all motorized vehicle types
]]

local specName = g_currentModName .. ".UsedPlusMaintenance"

-- Add specialization to manager
if g_specializationManager:getSpecializationByName("UsedPlusMaintenance") == nil then
    g_specializationManager:addSpecialization(
        "UsedPlusMaintenance",
        "UsedPlusMaintenance",
        g_currentModDirectory .. "src/specializations/UsedPlusMaintenance.lua",
        nil
    )
    UsedPlus.logDebug("Specialization 'UsedPlusMaintenance' added to manager")
end

-- Add to all motorized vehicle types
-- Pattern from: HeadlandManagement - add to vehicles that are drivable, enterable, and motorized
for typeName, typeEntry in pairs(g_vehicleTypeManager.types) do
    -- Only add to motorized vehicles (tractors, harvesters, etc.)
    if SpecializationUtil.hasSpecialization(Drivable, typeEntry.specializations)
        and SpecializationUtil.hasSpecialization(Enterable, typeEntry.specializations)
        and SpecializationUtil.hasSpecialization(Motorized, typeEntry.specializations)
        -- Exclude locomotives
        and not SpecializationUtil.hasSpecialization(Locomotive, typeEntry.specializations)
    then
        g_vehicleTypeManager:addSpecialization(typeName, specName)
        UsedPlus.logTrace("UsedPlusMaintenance registered for vehicle type: " .. typeName)
    end
end

UsedPlus.logInfo("UsedPlusMaintenance registration complete")
