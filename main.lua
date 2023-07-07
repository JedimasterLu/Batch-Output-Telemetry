---@diagnostic disable: lowercase-global
require("lua-strict")

local Tacview = require("Tacview188")
local lfs = require("lfs")

flightData = nil -- A Table contain all the processed data
numOfSamples = 0 -- Numbers of samples that have been processed
resultOfExp = {}
pts = 0.1

-- Split string by mark into str table

function Splitline(line,mark)
    local infoLine = line
    local lineTable = {}
    while true do
        local pos = string.find(infoLine,mark)
        if pos == nil then
            table.insert(lineTable,infoLine)
            break
        end
        local msg = string.sub(infoLine,1,pos-1)
        table.insert(lineTable,msg)
        infoLine = string.sub(infoLine,pos+1)
    end
    return lineTable
end

function GetLogTable(flightLogPath)
    local flightLog = io.open(flightLogPath,'r')
    if flightLog == nil then
        return nil
    else
        local resultList = {
            time = nil,
            loser = nil,
            splashBy = nil,
            winner = nil
        }
        local dualFlg = true
        for logLine in flightLog:lines("l") do
            local logLineTable = Splitline(logLine,',')
            --for i,j in pairs(logLineTable) do
            --    print(i.."   "..j)
            --end
            if logLineTable[8] == 'HasBeenHitBy' then
                dualFlg = false
                resultList.time = tonumber(string.format("%.1f",tonumber(logLineTable[1])))
                resultList.loser = logLineTable[5]
                resultList.splashBy = logLineTable[19]
                if logLineTable[3] == 'Su-27 Flanker' then
                    resultList.winner = 'US'
                else
                    resultList.winner = 'RUS'
                end
            end
        end
        if dualFlg == true then
            resultList.winner = 'Dual'
        end
        return resultList
    end
end

-- Convert radian value to degree

function RadtoDegree(radNum)
	local degreeNum = radNum * 57.29578
	return degreeNum
end

-- Generate File Name

function TargetFileName(numofSample,nameofElement,typeofElement)

	local targetFileName
	targetFileName = "Sample"..numofSample.."_"..nameofElement.."_"..typeofElement
    return targetFileName

end

-- Get the maximum value in a table consist of positive numbers.
-- Return the maximun value

function GetPositiveTableMax(tableName)
    local maxValue = -1
    for _,value in pairs(tableName) do
        if type(value) ~= "number" then
            Tacview.Log.Error("Error from GetPositiveTableMax: The table must only contain numbers!")
            return
        end
        if value > maxValue then
            maxValue = value
        end
    end
    return maxValue
end

-- Transfer tags from bits to string

function TransferTags(objectTags)
    local domainTable = {
        Air = Tacview.Telemetry.Tags.Air,
        Ground = Tacview.Telemetry.Tags.Ground,
        Sea = Tacview.Telemetry.Tags.Sea,
        Space = Tacview.Telemetry.Tags.Space,
        Weapon = Tacview.Telemetry.Tags.Weapon,
        Sensor = Tacview.Telemetry.Tags.Sensor,
        Navaid = Tacview.Telemetry.Tags.Navaid,
        Abstract = Tacview.Telemetry.Tags.Abstract,
        Misc = Tacview.Telemetry.Tags.Misc
    }
    local domainType
    for domainName,domain in pairs(domainTable) do
        if Tacview.Telemetry.AnyGivenTagActive(objectTags,domain) then
            domainType = domainName
            break
        end
	end
    local basicTable = {
        FixedWing = Tacview.Telemetry.Tags.FixedWing,
		Rotorcraft = Tacview.Telemetry.Tags.Rotorcraft,
		Spacecraft = Tacview.Telemetry.Tags.Spacecraft,
		Armor = Tacview.Telemetry.Tags.Armor,
		AntiAircraft = Tacview.Telemetry.Tags.AntiAircraft,
		Vehicle = Tacview.Telemetry.Tags.Vehicle,
		Watercraft = Tacview.Telemetry.Tags.Watercraft,
		Human = Tacview.Telemetry.Tags.Human,
		Biologic = Tacview.Telemetry.Tags.Biologic,
		Missile = Tacview.Telemetry.Tags.Missile,
		Rocket = Tacview.Telemetry.Tags.Rocket,
		Bomb = Tacview.Telemetry.Tags.Bomb,
		Torpedo = Tacview.Telemetry.Tags.Torpedo,
		Projectile = Tacview.Telemetry.Tags.Projectile,
		Beam = Tacview.Telemetry.Tags.Beam,
		Decoy = Tacview.Telemetry.Tags.Decoy,
		Building = Tacview.Telemetry.Tags.Building,
		Bullseye = Tacview.Telemetry.Tags.Bullseye,
		Waypoint = Tacview.Telemetry.Tags.Waypoint
    }
    local basicType
    for basicName, basic in pairs(basicTable) do
        if  Tacview.Telemetry.AnyGivenTagActive(objectTags,basic) then
            basicType = basicName
        end
    end
    local transferTags
    if not domainType and not basicType then
        transferTags = 'Not Included'
    end
    if domainType and not basicType then
        transferTags = domainType
    end
    if not domainType and basicType then
        transferTags = basicType
    end
    if domainType and basicType then
        transferTags = basicType
    end
    return transferTags
end

-- return objectInfo = {
--    objectHandle = handle,
--    objectId = objectId,
--    name = name,
--    tags = transferTags,
--    parentHandle = parentHandle,
--    parentId = parentId
-- }

function GetObjectInfo(handle)
    local objectId = Tacview.Telemetry.GetObjectId(handle)
    local name = Tacview.Telemetry.GetCurrentShortName(handle)
    local tags = Tacview.Telemetry.GetCurrentTags(handle)
    local transferTags = TransferTags(tags)
    local parentHandle = Tacview.Telemetry.GetCurrentParentHandle(handle)
    local parentId
    if parentHandle then
        parentId = Tacview.Telemetry.GetObjectId(parentHandle)
    end
    local absTime = Tacview.Telemetry.GetLifeTime(handle)
    local pilotIndex = Tacview.Telemetry.GetObjectsTextPropertyIndex(Tacview.Telemetry.Property.Text.Pilot,false)
    local pilot = Tacview.Telemetry.GetTextSample(handle,absTime,pilotIndex)
    local objectInfo = {
        objectHandle = handle,
        objectId = objectId,
        name = name,
        tags = transferTags,
        parentHandle = parentHandle,
        parentId = parentId,
        pilot = pilot
    }
    return objectInfo
end

-- Return a list of all the FixedWings' handles in current sample

function GetAircraftHandles()
    local objectCount = Tacview.Telemetry.GetObjectCount()
    local aircraftHandles = {}
    for index = 0,objectCount-1 do
        local handle = Tacview.Telemetry.GetObjectHandleByIndex(index)
        local tags = Tacview.Telemetry.GetCurrentTags(handle)
        if Tacview.Telemetry.AnyGivenTagActive(tags,Tacview.Telemetry.Tags.FixedWing) then
            table.insert(aircraftHandles,handle)
        end
    end
    return aircraftHandles
end

-- Return a list of all the Missiles' handles in current sample

function GetMissileHandles()
    local objectCount = Tacview.Telemetry.GetObjectCount()
    local missileHandles = {}
    for index = 0,objectCount-1 do
        local handle = Tacview.Telemetry.GetObjectHandleByIndex(index)
        local tags = Tacview.Telemetry.GetCurrentTags(handle)
        if Tacview.Telemetry.AnyGivenTagActive(tags,Tacview.Telemetry.Tags.Missile) then
            table.insert(missileHandles,handle)
        end
    end
    return missileHandles
end

-- Return the handle of missile shooter

function GetMissileFireFrom(missileHandle)
    local missileInfo = GetObjectInfo(missileHandle)
    local missileShooterHandle = missileInfo['parentHandle']
    return missileShooterHandle
end

-- Get the missile target.
-- If hit, return target handle. If miss, return nil value.

function GetMissileTarget(missileHandle,aircraftHandles)
    local _,missileLifeEndTime = Tacview.Telemetry.GetLifeTime(missileHandle)
    local missileTarget = nil
    for _,aircraftHandle in pairs(aircraftHandles) do
        local _,aircraftEndTime = Tacview.Telemetry.GetLifeTime(aircraftHandle)
        if missileLifeEndTime == aircraftEndTime then
            missileTarget = aircraftHandle
            break
        end
    end
    if missileLifeEndTime == Tacview.Telemetry.EndOfTime then
        missileTarget = nil
    end
    return missileTarget
end

-- Get the Id by pilot, return nil if not found

function GetIDFromPilot(pilot)
    local id = nil
    local aircraftHandles = GetAircraftHandles()
    for _,handle in pairs(aircraftHandles) do
        local aircraftInfo = GetObjectInfo(handle)
        if aircraftInfo.pilot == pilot then
            id = aircraftInfo.objectId
        end
    end
    return id
end

-- Perform actions on each .acmi file to collect statistics

function ProcessFile(filePath)

    -- Purge any telemetry previously loaded in memory
	Tacview.Telemetry.Clear()

	-- Load the file
	local fileLoaded = Tacview.Telemetry.Load(filePath)
	if not fileLoaded then
		Tacview.Log.Error("Failed to load:", filePath)
		return
	end
	Tacview.Log.Info("Processing:", filePath)

	-- Get absbeginTime
	local absbeginTime,_ = Tacview.Telemetry.GetDataTimeRange()
	absbeginTime = math.floor(absbeginTime)

	-- Get object Handles
	local aircraftHandles = GetAircraftHandles()
	local missileHandles = GetMissileHandles()

	flightData[numOfSamples] = {
        aircraft = {},
        missile = {}
    }

    -- Process aircrafts' data
	for _,aircraftHandle in pairs(aircraftHandles) do
		flightData[numOfSamples]['aircraft'][aircraftHandle] = {}

		local beginTime,endTime = Tacview.Telemetry.GetTransformTimeRange(aircraftHandle)
        beginTime = 1
        endTime = math.floor(endTime - absbeginTime)

        for time = beginTime,endTime,pts do
            local dataOfTheSec = Tacview.Telemetry.GetTransform(aircraftHandle,time+absbeginTime)
            local dataOfFormer = Tacview.Telemetry.GetTransform(aircraftHandle,time+absbeginTime+0.1)
            local rollRate = dataOfFormer.roll - dataOfTheSec.roll
            local gForce = Tacview.Telemetry.GetAbsoluteGForce(aircraftHandle,time+absbeginTime)
            local xVelocity = (dataOfFormer.x-dataOfTheSec.x)/0.1
            local yVelocity = (dataOfFormer.y-dataOfTheSec.y)/0.1
            local zVelocity = (dataOfFormer.altitude-dataOfTheSec.altitude)/0.1
            local groundSpd = math.sqrt((xVelocity)^2 + (yVelocity)^2 + (zVelocity)^2)
            if not gForce then
                gForce = 1.0
            end
            flightData[numOfSamples]['aircraft'][aircraftHandle][time] = {
                longitude = dataOfTheSec.longitude,
                latitude = dataOfTheSec.latitude,
                altitude = dataOfTheSec.altitude,
                x = dataOfTheSec.x,
                y = dataOfTheSec.y,
                z = dataOfTheSec.z,
                roll = dataOfTheSec.roll,
                pitch = dataOfTheSec.pitch,
                yaw = dataOfTheSec.yaw,
                heading = dataOfTheSec.heading,
                lifeTime = endTime - beginTime + 1,
                rollRate = rollRate,
                gForce = gForce,
                xV = xVelocity,
                yV = yVelocity,
                zV = zVelocity,
                GS = groundSpd
            }
        end
	end

    -- Process missiles' data
    for _,missileHandle in pairs(missileHandles) do
		flightData[numOfSamples]['missile'][missileHandle] = {
			from = nil,
			target = nil,
			dataBySec = {}
		}

        local missileFireFromHandle = GetMissileFireFrom(missileHandle)
        local missileTargetHandle = GetMissileTarget(missileHandle,aircraftHandles)
        flightData[numOfSamples]['missile'][missileHandle]['from'] = missileFireFromHandle
        flightData[numOfSamples]['missile'][missileHandle]['target'] = missileTargetHandle

        local beginTime,endTime = Tacview.Telemetry.GetTransformTimeRange(missileHandle)
        beginTime = 1
        endTime = math.floor(endTime - absbeginTime)

        for time = beginTime,endTime,pts do
            local dataOfTheSec = Tacview.Telemetry.GetTransform(missileHandle,time+absbeginTime)
            flightData[numOfSamples]['missile'][missileHandle]['dataBySec'][time] = {
                longitude = dataOfTheSec.longitude,
                latitude = dataOfTheSec.latitude,
                altitude = dataOfTheSec.altitude,
            }
        end
    end

    -- Write an info in log.
    Tacview.Log.Info("Data of Sample"..numOfSamples.." loaded!")
end

--Process all the file in the folder

function ProcessFolder(folderPath,exportPath)

    -- Traverse all the file in the folder
	for fileName in lfs.dir(folderPath) do
		if fileName ~= "." and fileName ~= ".." then
			local filePath = folderPath..fileName
			local fileAttribute = lfs.attributes (filePath)
			if (type(fileAttribute) == "table") then
				if fileAttribute.mode == "directory" then
					ProcessFolder(filePath..'/')
				else
					numOfSamples = numOfSamples+1
					ProcessFile(filePath)
                    ExportFlightLog(filePath,exportPath)
                    ExportFile(exportPath)
				end
			end
		end
	end

    Tacview.Telemetry.Clear()
end

-- Export Flight Log

function ExportFlightLog(filePath,exportPath)
    local flightLogPath = exportPath..'Sample'..numOfSamples..'_FlightLog.csv'
    local cmdLine = 'Tacview.exe -Open:'..filePath..' -ExportFlightLog:'..flightLogPath..' -Quiet -Quit'
    os.execute(cmdLine)

    -- Judge the winner and store in resultOfExp
    local logTable = GetLogTable(flightLogPath)
    if logTable ~= nil then
        logTable.loser = GetIDFromPilot(logTable.loser)
        logTable.splashBy = GetIDFromPilot(logTable.splashBy)
    end
    resultOfExp[numOfSamples] = logTable
end

-- Export the data in current Sample to .csv files

function ExportFile(exportPath)
    -- Export Aircraft Data
	for currentHandle,_ in pairs(flightData[numOfSamples]['aircraft']) do

        -- Set file name
        local currentName = Tacview.Telemetry.GetCurrentShortName(currentHandle)
        local currentId = Tacview.Telemetry.GetObjectId(currentHandle)
        local targetFileName = TargetFileName(numOfSamples,currentName,currentId)
        local targetFilePath = exportPath..targetFileName..".csv"
        if not targetFilePath then
            Tacview.Log.Error("Filename is empty.")
            return
        end

        -- Create a csv file
        local file = io.open(targetFilePath, "wb")
        if not file then
            Tacview.Log.Error("Failed to create a .csv file")
            return
        end

        -- Write csv file header then the statistics collected.
        file:write("Time,x,y,Altitude,Roll,Pitch,Yaw,Heading,GS,x-velocity,y-velocity,z-velocity\n")
        local endTime = flightData[numOfSamples]['aircraft'][currentHandle][1].lifeTime
        for time = 1,endTime,pts do
            local dataofSec = flightData[numOfSamples]['aircraft'][currentHandle][time]
            file:write
            (
                string.format
                (
                    "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
                    time,
                    dataofSec.y,
                    dataofSec.x,
                    dataofSec.altitude,
                    RadtoDegree(dataofSec.roll),
                    RadtoDegree(dataofSec.pitch),
                    RadtoDegree(dataofSec.yaw),
                    RadtoDegree(dataofSec.heading),
                    dataofSec.GS,
                    dataofSec.xV,
                    dataofSec.yV,
                    dataofSec.zV
                )
            )
        end

        -- close the file
        file:close()
        -- Tacview.Log.Info(targetFilePath.."Export successful")
	end

    -- Export Missile Data
    for currentHandle,currentData in pairs(flightData[numOfSamples]['missile']) do

        -- Set file name
        local currentName = Tacview.Telemetry.GetCurrentShortName(currentHandle)
        local currentId = Tacview.Telemetry.GetObjectId(currentHandle)
        local targetFileName = TargetFileName(numOfSamples,currentName,currentId)
        local targetFilePath = exportPath..targetFileName..".csv"
        if not targetFilePath then
            Tacview.Log.Error("Filename is empty.")
            return
        end

        -- Create a csv file
        local file = io.open(targetFilePath, "wb")
        if not file then
            Tacview.Log.Error("Failed to create a .csv file")
            return
        end

        -- Get from Id and target Id
        local missileFireFromHandle = currentData['from']
        local missileTargetHandle = currentData['target']
        local fromId = Tacview.Telemetry.GetObjectId(missileFireFromHandle)
        local targetId
        if missileTargetHandle then
            targetId = Tacview.Telemetry.GetObjectId(missileTargetHandle)
        else
            targetId = 'None'
        end

        -- Sort dataBySec list by keys
        local keyTest ={}
        for time,_ in pairs(currentData['dataBySec']) do
            table.insert(keyTest,time)
        end
        table.sort(keyTest,function(a,b)return (tonumber(a) <  tonumber(b)) end) -- Increading order

        -- Write header and data by seconds
        file:write("Time,Longitude,Latitude,Altitude,From,Target\n")
        for _,time in pairs(keyTest) do
            local dataOfSec = currentData['dataBySec'][time]
            file:write
            (
                string.format
                (
                    "%s,%s,%s,%s,%s,%s\n",
                    time,
                    RadtoDegree(dataOfSec.longitude),
                    RadtoDegree(dataOfSec.latitude),
                    dataOfSec.altitude,
                    fromId,
                    targetId
                )
            )
        end

        -- close the file
        file:close()
        -- Tacview.Log.Info(targetFilePath.." export successful")
	end

    Tacview.Log.Info("Sample"..numOfSamples.." export successful")
end

--Export result file

function ExportResult(exportPath)

	--Generate result file
	local resultFileName = exportPath.."Result of Exp.csv"
	local resultFile = io.open(resultFileName, "wb")
	if not resultFile then
		Tacview.Log.Error("Failed to export result data.\n\nEnsure there is enough space and that you have permission to save in this location.")
		return
	end
	resultFile:write("Sample,Winner,Time,Loser,SplashedBy\n") -- The title of column
	for currentSampleNum,logTable in pairs(resultOfExp) do
        if logTable ~= nil then
            -- Result of each sample
            resultFile:write
            (
                string.format
                (
                    "%s,%s,%s,%s,%s\n",
                    currentSampleNum,
                    logTable.winner,
                    logTable.time,
                    logTable.loser,
                    logTable.splashBy
                )
            )
        else
            resultFile:write
            (
                string.format
                (
                    "%s,%s\n",
                    currentSampleNum,
                    'Error: Flight Log not found!'
                )
            )
        end
	end
	resultFile:close()

	Tacview.Log.Info("Result file export successful")
end

--Menu Callback

function OnBatchProcess()
	flightData = {}
    resultOfExp = {}

	-- Request import and export folder paths from user
	local importFolderPath = Tacview.UI.MessageBox.GetFolderName()
	if not importFolderPath then
		return
	end
    Tacview.Log.Info("Import from: "..importFolderPath)

    local exportFolderPath = Tacview.UI.MessageBox.GetFolderName()
	if not exportFolderPath then
		return
	end
    Tacview.Log.Info("Export to: "..exportFolderPath)

	-- Process all files in the folder and export statistics to .csv file
	ProcessFolder(importFolderPath,exportFolderPath)

	-- Export result
	ExportResult(exportFolderPath)

    Tacview.UI.MessageBox.Info("All files export successful")
end

--Setting Addon info

function Initialize()
    Tacview.AddOns.Current.SetTitle("Batch Output Telemetry")
    Tacview.AddOns.Current.SetVersion("1.8.8")
    Tacview.AddOns.Current.SetAuthor("Lu")
    Tacview.AddOns.Current.SetNotes("A tool to output multiple telemetry in certain order")

    Tacview.UI.Menus.AddCommand(nil, "Batch Output Telemetry", OnBatchProcess)
end

Initialize()