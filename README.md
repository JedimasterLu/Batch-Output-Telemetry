# Batch-Output-Telemetry

An addon for Tacview to output telemetry data of more than one .acmi file.

# Manual

## How to install

Create a folder `Tacview/AddOns/Batch Output Telemetry` and put all codes in it.

## How to use

- Activate Batch Output Telemetry like other addons.

- In the first box that pops out, choose the folder that contains .acmi file to be output. Be aware that no other files is allowed in that folder. 

- In the second box that pops out, choose the folder that you wish to export into.

- Wait for the output to complete.

## About files generated

### Result of Exp.csv

To store the result of all the .acmi files.

- Sample：The sequence of sample.

- Winner：the country that win.

- Time：time when the mission ends.

- Loser：ID of the aircraft that is splashed. 

- SplashedBy：ID of the aircraft that shoots.

### Sample#_xxxx_xxx.csv

\# is the sequence of sample. In the middle is the type of the aircraft. On the right side is the ID of the aircraft。This file store the flight data of one aircraft.

- Time：(s)

- x：x coordinate relative to bullseye（m）

- y：y coordinate relative to bullseye（m）

- Altitude：absolute height（m)

- Roll：(deg)

- Pitch：(deg)

- Yaw：(deg)

- Heading：(deg)

- GS：ground speed (m/s)

- x，y，z-velocity：GS in x，y，z directions（m/s）

### Sample#_FlightLog.csv

\# is the sequence of sample. This file store flight log.
