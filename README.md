# Extended Vehicle Maintenance

Extended Vehicle Maintenance makes vehicle care in Farming Simulator 25 feel less instant and more meaningful.

Instead of repairing everything with one quick click, vehicles and implements need regular service based on their operating hours. When a machine goes into maintenance, it is actually unavailable for a while: it cannot be used, started or driven until the service is finished.

The mod also adds realistic technical problems. Poorly maintained or unlucky machines can suffer from issues such as engine failures, emergency-mode/RPM limitations, flat tires, hydraulic problems, brake failures and battery faults. On top of that, the included battery simulation handles charging and discharging depending on vehicle use and electrical consumers.

This mod is designed especially for realistic multiplayer servers and long-term savegames where maintenance, downtime and planning should matter.

## Features

- Maintenance system based on operating hours
- Vehicles and implements are locked while service is active
- Different service options: workshop, on-site technician and self-repair
- Workshop service takes time and removes the machine from use
- On-site technician is the most expensive option
- Self-repair is the cheapest option, but takes the longest
- Realistic malfunction system with multiple failure types
- Battery charging and discharging simulation
- HUD for maintenance, battery and vehicle condition information
- Adjustable HUD size and position
- Multiplayer/server support
- Console commands for testing, debugging and recovery

## Service Options

Extended Vehicle Maintenance offers different ways to handle service and repairs:

### Workshop Service

Send the machine to the workshop and wait until the work is finished. The vehicle cannot be used during this time.

### On-Site Technician

Call a technician to handle the repair. This is the most expensive option, but useful when you want the work done professionally without choosing the cheapest route.

### Self-Repair

Repair the machine yourself. This is the cheapest option, but it takes the longest to complete.

## Malfunctions

Vehicles can suffer from different technical issues, including:

- Engine problems
- Flat tires
- RPM/emergency-mode failures
- Hydraulic failures
- Brake failures
- Battery-related problems

These failures are meant to make machines feel less perfect and give maintenance more importance during normal gameplay.

## Battery Simulation

The battery system simulates basic charging and discharging behavior.

Electrical consumers can slowly drain the battery when the engine is off. When the engine is running, the battery can recharge again. This makes parked or poorly handled vehicles feel more believable over time.

## Console Commands

The following commands are mainly intended for server owners, admins, testing and recovery.

### Failure / Malfunction Commands

```txt
evmFailure engine
evmFailure flatTire
evmFailure rpm
evmFailure hydraulic
evmFailure brake
evmFailure battery
```

Forces a failure on the current or nearby vehicle.

```txt
evmClearFailure
```

Removes the active failure from the current or nearby vehicle.

### Maintenance Commands

```txt
evmSetDue
```

Sets the current vehicle maintenance state to due immediately.

```txt
evmResetPool
```

Resets the maintenance interval of the current vehicle.

```txt
evmStatus
```

Shows the maintenance status of the current vehicle.

```txt
evmClearService
```

Clears the service lock from the current or nearby vehicle. Useful if a vehicle is still locked after service due to an old saved state or test version.

```txt
evmClearAllService
```

Clears all service locks from all vehicles.

```txt
evmFleetReset
```

Resets all vehicles by clearing failures, restoring maintenance intervals and removing incorrect saved states. This is mainly useful after testing or after updating from older versions.

### Debug / Diagnostic Commands

```txt
evmDebug 1
evmDebug 0
```

Enables or disables EVM debug output.

```txt
evmDiag
```

Checks whether EVM is loaded correctly on the current vehicle.

```txt
evmRepairDiag
```

Shows diagnostic information about available repair and damage functions on the current vehicle.

```txt
evmCollisionTest
evmCollisionTest 15
```

Tests collision damage on the current vehicle. An optional damage percentage can be provided.

### HUD Commands

```txt
evmHudScale 1.10
```

Changes the HUD size. Supported range:

```txt
0.55 - 1.50
```

```txt
evmHudPos 0.993 0.512
```

Sets the HUD position directly using X/Y screen coordinates.

```txt
evmHudEdit 1
evmHudEdit 0
```

Starts or stops HUD edit mode. While edit mode is enabled, the HUD can be positioned with the mouse. Disabling edit mode saves the position.

```txt
evmHudNudge left
evmHudNudge right
evmHudNudge up
evmHudNudge down
```

Moves the HUD step by step.

With a custom step size:

```txt
evmHudNudge left 0.01
evmHudNudge right 0.01
evmHudNudge up 0.01
evmHudNudge down 0.01
```

Direct X/Y movement:

```txt
evmHudNudge 0.01 -0.02
```

```txt
evmHudReset
```

Resets HUD position and size to default.

## Notes

Extended Vehicle Maintenance is developed with multiplayer and dedicated servers in mind. Some commands are included for testing and recovery and should only be used by server owners or trusted admins.

The mod is still being improved and may receive balancing changes, new failure types and further workshop improvements over time.

## Support

Support is available on Discord:

https://discord.gg/C9yRZmQ6M3

## Usage Terms

Copyright (C) 2026 Nico B / SimuTools

This repository is provided for review, testing, issue reporting and contribution purposes only.

You may:
- view the source code
- use it privately for testing
- submit issues and pull requests

You may not, without explicit written permission:
- redistribute this mod
- reupload this mod
- publish modified versions
- repack this mod into other mod packs
- sell or commercially use this mod
- remove or alter author credits

Official distribution is only allowed by Nico B / SimuTools.

All rights reserved.
