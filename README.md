# qb-garages

**Installation**
* Add in qb-vehiclekeys/server
RegisterNetEvent('qb-vehiclekeys:server:RestoreVehicleKeys', function(plate, citizenid)             --Change Add
    if not VehicleList[plate] then                                                                  --Change Add
        VehicleList[plate] = {}                                                                     --Change Add
        VehicleList[plate][citizenid] = {}                                                          --Change Add
    end                                                                                             --Change Add
    VehicleList[plate][citizenid] = true                                                            --Change Add
end)                                                                                                --Change Add

* Add in the database the 2 columns
ALTER TABLE `player_vehicles`
ADD COLUMN `citizenidout` varchar(50) DEFAULT NULL;
ALTER TABLE `player_vehicles`
ADD COLUMN `location` text DEFAULT NULL,

* Change in qb-phone/client/main
RegisterNUICallback('track-vehicle', function(data, cb)
    local veh = data.veh
    TriggerEvent('qb-garage:client:TrackVehicle', veh.plate)
    cb("ok")
end)

* Comment this in qb-phone/client/main
local function findVehFromPlateAndLocate(plate)
    local gameVehicles = QBCore.Functions.GetVehicles()
    for i = 1, #gameVehicles do
        local vehicle = gameVehicles[i]
        if DoesEntityExist(vehicle) then
            if QBCore.Functions.GetPlate(vehicle) == plate then
                local vehCoords = GetEntityCoords(vehicle)
                SetNewWaypoint(vehCoords.x, vehCoords.y)
                return true
            end
        end
    end
end

**Public Garages**
* Park owned cars in public garages.
* You can only parks vehicles that you own in public garages. 

![image](https://user-images.githubusercontent.com/82112471/149678987-02ec660f-76c9-4414-af7b-bac284ed58b7.png)

![image](https://user-images.githubusercontent.com/82112471/149678977-2a574ee9-8ecc-494f-a845-e17281a74594.png)

**Server side car spawn**
* With the option ServerSpawnCars car can be spawned from the server, making them existing at any time as long the server is not restart

**Persistence**
Ability to have vehicles automatically respawned at server restart at their previous location

**House Garages**
* Park owned cars in house garages. To add a house garage, you must have the realestate job and do /addgarage.
* You can only parks vehicles from persons that have the key in a house garage. 
* You can take every vehicle from the house garages to which you have the key. 
* You can only parks ground vehicles in house garages. 

**Gang Garages**
* Allows for gangs to have their own garages.
* You can parks every vehicle that is owned by gang members in gang garages. 
* You can take every vehicle from the gang garages. 

**Job Garages**
* Allows jobs to have garage specific.
* You can parks every vehicle that is owned by someone in job garages. 
* You can take every vehicle from the job garages. 

**Depot Garages**
* Allows depot cars to be retreived from here. Cops can do /depot [price] to send a car to the depot.

**Auto Respawn Config**
* If set to true, cars that are currently outside will be placed in the last garage used.
* If set to false, cars that are currently outside will be placed in the depot.

**Shared garages Config**
* If set to true, Gang and job garages are shared.
* If set to false, Gang and Job garages are personal.

**Configurations**
* You can only parks ground vehicles in garages of type "car" in config. 
* You can only parks water vehicles in garages of type "sea" in config. 
* You can only parks air vehicles in garages of type "air" in config. 
* Vehicle types and jobs or gang can be mixed in config.

**Blips and names**
* Blips and names are modifiable for each garage. 


# License

    QBCore Framework
    Copyright (C) 2021 Joshua Eger

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>

