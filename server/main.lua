local QBCore = exports['qb-core']:GetCoreObject()
local OutsideVehicles = {}

QBCore.Functions.CreateCallback("qb-garage:server:GetGarageVehicles", function(source, cb, garage, type, category)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if type == "public" then        --Public garages give player cars in the garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ?', {pData.PlayerData.citizenid, garage, 1}, function(result)
            if result[1] then
                cb(result)
            else
                cb(nil)
            end
        end)
    elseif type == "depot" then    --Depot give player cars that are not in garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ? OR state = ?)', {pData.PlayerData.citizenid, 0, 2}, function(result)
            local tosend = {}
            if result[1] then
                --Check vehicle type against depot type
                for _, vehicle in pairs(result) do
                    if not OutsideVehicles[vehicle.plate] or not DoesEntityExist(OutsideVehicles[vehicle.plate].entity) then
                        if category == "air" and ( QBCore.Shared.Vehicles[vehicle.vehicle].category == "helicopters" or QBCore.Shared.Vehicles[vehicle.vehicle].category == "planes" ) then
                            tosend[#tosend + 1] = vehicle
                        elseif category == "sea" and QBCore.Shared.Vehicles[vehicle.vehicle].category == "boats" then
                            tosend[#tosend + 1] = vehicle
                        elseif category == "car" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "helicopters" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "planes" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "boats" then
                            tosend[#tosend + 1] = vehicle
                        end
                    end
                end
                cb(tosend)
            else
                cb(nil)
            end
        end)
    else                            --House give all cars in the garage, Job and Gang depend of config
        local shared = ''
        if not SharedGarages and type ~= "house" then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
        MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?'..shared, {garage, 1}, function(result)
            if result[1] then
                cb(result)
            else
                cb(nil)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback("qb-garage:server:validateGarageVehicle", function(source, cb, garage, type, plate)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if type == "public" then        --Public garages give player cars in the garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ? AND plate = ?', {pData.PlayerData.citizenid, garage, 1, plate}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    elseif type == "depot" then    --Depot give player cars that are not in garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ? OR state = ?) AND plate = ?', {pData.PlayerData.citizenid, 0, 2, plate}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    else
        local shared = ''
        if not SharedGarages and type ~= "house" then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
        MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND plate = ?'..shared, {garage, 1, plate}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback("qb-garage:server:checkOwnership", function(source, cb, plate, type, house, gang)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if type == "public" then        --Public garages only for player cars
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    elseif type == "house" then     --House garages only for player cars that have keys of the house
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                local hasHouseKey = exports['qb-houses']:hasKey(result[1].license, result[1].citizenid, house)
                if hasHouseKey then
                    cb(true)
                else
                    cb(false)
                end
            else
                cb(false)
            end
        end)
    elseif type == "gang" then        --Gang garages only for gang members cars (for sharing)
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                --Check if found owner is part of the gang
                local resultplayer = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', { result[1].citizenid })
                if resultplayer then
                    local playergang = json.decode(resultplayer.gang)
                    if playergang.name == gang then
                        cb(true)
                    else
                        cb(false)
                    end
                else
                    cb(false)
                end
            else
                cb(false)
            end
        end)
    else                            --Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local shared = ''
        if not SharedGarages then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?'..shared, {plate}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback("qb-garage:server:GetVehicleProperties", function(_, cb, plate)
    local properties = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then
        properties = json.decode(result[1].mods)
    end
    cb(properties)
end)

QBCore.Functions.CreateCallback("qb-garage:server:IsSpawnOk", function(source, cb, plate, type, vehicle, position, heading)
    local model = vehicle.vehicle
    local ok
    if type == "depot" then         --If depot, check if vehicle is not already spawned on the map
        if OutsideVehicles[plate] and DoesEntityExist(OutsideVehicles[plate].entity) then
            ok = false
        else
            ok = true
        end
    else
        ok = true
    end
    if not ServerSpawnCars then
        cb(ok)
    else
        if ok then
            local src = source
            local pData = QBCore.Functions.GetPlayer(src)
            OutsideVehicles[plate] = {citizenid = pData.PlayerData.citizenid}
            local CreateAutomobile = GetHashKey("CREATE_AUTOMOBILE")
            local veh = Citizen.InvokeNative(CreateAutomobile, GetHashKey(model), position, heading, true, false)
            local netId
            while not DoesEntityExist(veh) do
                Wait(25)
            end
            if DoesEntityExist(veh) then
                netId = NetworkGetNetworkIdFromEntity(veh)
                TriggerClientEvent("qb-garage:client:SetProperties", -1, netId, vehicle, heading, source, true)
                cb(true)
            else
                cb(false)
            end
        end
    end
end)

RegisterNetEvent('qb-garage:server:finishSpawn', function(netId)
    TriggerClientEvent("qb-garage:client:finishSpawn", -1, netId)
end)

RegisterNetEvent('qb-garage:server:updateVehicle', function(state, fuel, engine, body, plate, garage, type, gang)
    QBCore.Functions.TriggerCallback('qb-garage:server:checkOwnership', source, function(owned)     --Check ownership
        if owned then
            if state == 0 or state == 1 or state == 2 then                                          --Check state value
                if type ~= "house" then
                    if Garages[garage] then                                                             --Check if garage is existing
                        MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {state, garage, fuel, engine, body, plate})
                    end
                else
                    MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {state, garage, fuel, engine, body, plate})
                end
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_owned"), 'error')
        end
    end, plate, type, garage, gang)
end)

RegisterNetEvent('qb-garage:server:updateVehicleState', function(state, plate, garage)
    local citizenid = QBCore.Functions.GetPlayer(source).PlayerData.citizenid
    local type
    if Garages[garage] then
        type = Garages[garage].type
    else
        type = "house"
    end

    QBCore.Functions.TriggerCallback('qb-garage:server:validateGarageVehicle', source, function(owned)     --Check ownership
        if owned then
            if state == 0 then                                          --Check state value
                MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ?, citizenidout = ? WHERE plate = ?', {state, 0, citizenid, plate})
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_owned"), 'error')
        end
    end, garage, type, plate)
end)

RegisterNetEvent('qb-garage:server:UpdateVehicleStatus', function(plate, body, motor, position, heading, fuel)
    if OutsideVehicles[plate] then
        OutsideVehicles[plate].body = body
        OutsideVehicles[plate].engine = motor
        OutsideVehicles[plate].position = position
        OutsideVehicles[plate].heading = heading
        OutsideVehicles[plate].fuel = fuel
    end
end)

RegisterNetEvent('qb-garage:server:UpdateOutsideVehicle', function(plate, vehicle)
    if vehicle then
        local entity = NetworkGetEntityFromNetworkId(vehicle)
        OutsideVehicles[plate].netID = vehicle
        OutsideVehicles[plate].entity = entity            
    else
        OutsideVehicles[plate] = nil
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(100)
        if AutoRespawn then
            MySQL.update('UPDATE player_vehicles SET state = 1 WHERE state = 0', {})
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for k, v in pairs(OutsideVehicles) do
            DeleteEntity(v.entity)
        end
    end
end)



RegisterNetEvent('qb-garage:server:PayDepotPrice', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cashBalance = Player.PlayerData.money["cash"]
    local bankBalance = Player.PlayerData.money["bank"]

    local vehicle = data.vehicle

    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {vehicle.plate}, function(result)
        if result[1] then
            if cashBalance >= result[1].depotprice then
                Player.Functions.RemoveMoney("cash", result[1].depotprice, "paid-depot")
                TriggerClientEvent("qb-garage:client:takeOutGarage", src, data)
            elseif bankBalance >= result[1].depotprice then
                Player.Functions.RemoveMoney("bank", result[1].depotprice, "paid-depot")
                TriggerClientEvent("qb-garage:client:takeOutGarage", src, data)
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_enough"), 'error')
            end
        end
    end)
end)



--External Calls
--Call from qb-vehiclesales
QBCore.Functions.CreateCallback("qb-garage:server:checkVehicleOwner", function(source, cb, plate)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(result)
        if result[1] then
            cb(true, result[1].balance)
        else
            cb(false)
        end
    end)
end)

--Call from qb-phone
QBCore.Functions.CreateCallback("qb-garage:server:trackVehicle", function(source, cb, plate)
    if OutsideVehicles[plate] and DoesEntityExist(OutsideVehicles[plate].entity) then
        cb(GetEntityCoords(OutsideVehicles[plate].entity))
    end
end)

QBCore.Functions.CreateCallback('qb-garage:server:GetPlayerVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local Vehicles = {}

    MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result[1] then
            for _, v in pairs(result) do
                local VehicleData = QBCore.Shared.Vehicles[v.vehicle]

                local VehicleGarage = Lang:t("error.no_garage")
                if v.garage ~= nil then
                    if Garages[v.garage] ~= nil then
                        VehicleGarage = Garages[v.garage].label
                    else
                        VehicleGarage = Lang:t("info.house_garage")         -- HouseGarages[v.garage].label
                    end
                end

                if v.state == 0 then
                    v.state = Lang:t("status.out")
                elseif v.state == 1 then
                    v.state = Lang:t("status.garaged")
                elseif v.state == 2 then
                    v.state = Lang:t("status.impound")
                end

                local fullname
                if VehicleData["brand"] ~= nil then
                    fullname = VehicleData["brand"] .. " " .. VehicleData["name"]
                else
                    fullname = VehicleData["name"]
                end
                Vehicles[#Vehicles+1] = {
                    fullname = fullname,
                    brand = VehicleData["brand"],
                    model = VehicleData["name"],
                    plate = v.plate,
                    garage = VehicleGarage,
                    state = v.state,
                    fuel = v.fuel,
                    engine = v.engine,
                    body = v.body
                }
            end
            cb(Vehicles)
        else
            cb(nil)
        end
    end)
end)







local function updateDB(plate, body, motor, position, heading, fuel, citizenid)
    local pos = vector4(position.x, position.y, position.z, heading)
    local posenc = json.encode(pos)
    MySQL.update('UPDATE player_vehicles SET fuel = ?, engine = ?, body = ?, citizenidout = ?, location = ? WHERE plate = ?', {fuel, motor, body, citizenid, posenc, plate})
end

CreateThread(function()
    while true do
        Wait(1000 * 60 * 1)     --Every minute, save vehicles status to db
        for k, v in pairs(OutsideVehicles) do
            if v.netID ~= 0 then
                updateDB(k, v.body, v.engine, v.position, v.heading, v.fuel, v.citizenid)
            end
        end
    end
end)

CreateThread(function()
    if fullPersistence then
        MySQL.query('SELECT * FROM player_vehicles WHERE state = ? and location != ""', {0}, function(result)
            if result[1] then
                for k, v in pairs(result) do
                    local pos = json.decode(v.location)
                    OutsideVehicles[v.plate] = {}
                    OutsideVehicles[v.plate].body = v.body
                    OutsideVehicles[v.plate].engine = v.engine
                    OutsideVehicles[v.plate].position = vector3(pos.x, pos.y, pos.z)
                    OutsideVehicles[v.plate].heading = pos.w
                    OutsideVehicles[v.plate].fuel = v.fuel    
                    OutsideVehicles[v.plate].netID = 0
                    OutsideVehicles[v.plate].entity = 0
                    OutsideVehicles[v.plate].model = v.vehicle
                    OutsideVehicles[v.plate].citizenid = v.citizenidout
                    TriggerEvent('qb-vehiclekeys:server:RestoreVehicleKeys', v.plate, v.citizenidout)
                end
            end
        end)
    end
end)

local function SpawnVehicle(data)
    local CreateAutomobile = GetHashKey("CREATE_AUTOMOBILE")
    local vehicle = Citizen.InvokeNative(CreateAutomobile, GetHashKey(data.model), data.position, data.heading, true, false)
    while not DoesEntityExist(vehicle) do
        Wait(25)
    end
    if DoesEntityExist(vehicle) then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        return netId
    else
        return false
    end    
end

local function GetClosestPlayerToCoords(players, coords)
    local closestDist, closestPlayerId, ped, dist, pedCoords
    for k, v in pairs(players) do
        ped = GetPlayerPed(v)
        if ped then
            pedCoords = GetEntityCoords(ped)
            dist = #(pedCoords - coords)
            if not closestDist or dist < closestDist then
                closestDist = dist
                closestPlayerId = v
            end
            if closestDist < respawnDistance then
                break
            end
        end
        
    end
    return closestPlayerId, closestDist
end

CreateThread(function()
    while true do
        Wait(2000)
        if fullPersistence then
            for plate, data in pairs(OutsideVehicles) do
                if not DoesEntityExist(data.entity) then
                    --local closestPlayerId, closestDistance = GetOwnerDistance(data.citizenid, data.position)
                    local closestPlayerId, closestDistance = GetClosestPlayerToCoords(QBCore.Functions.GetPlayers(), data.position)
                    if closestPlayerId and closestDistance < respawnDistance and not data.sent then
                        --print('Send spawn request ' .. data.model .. ' for player ' .. closestPlayerId)
                        --data.sent = closestPlayerId
                        local veh = SpawnVehicle(data)
                        if veh then
                            data.plate = plate
                            TriggerClientEvent("qb-garage:client:SetProperties", -1, veh, data, data.heading, data.citizenid, false)
                        end
                        Wait(1000)
                    end
                end
            end
        end
    end
end)