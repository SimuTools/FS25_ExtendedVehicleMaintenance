# Extended Vehicle Maintenance

Extended Vehicle Maintenance adds a realistic vehicle maintenance system to Farming Simulator 25.

Vehicles can be sent into service and cannot be used while maintenance work is in progress. The maintenance interval is based on the vehicle operating hours. The mod also adds realistic malfunction events, such as flat tires, engine issues, RPM/emergency-mode failures, hydraulic failures, brake failures and battery problems.

A battery simulation is included as well. Batteries can discharge when electrical consumers are active and recharge while the engine is running.

## Features

- Realistic vehicle maintenance system
- Maintenance based on operating hours
- Vehicles are locked while service is active
- Service modes for workshop, technician and self-repair
- Malfunction system with multiple failure types
- Battery charging and discharging simulation
- HUD for maintenance and vehicle condition information
- Configurable HUD size and position
- Multiplayer/server support
- Console commands for testing, debugging and recovery

## Console Commands

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

Resets the maintenance interval/pool of the current vehicle.

```txt
evmStatus
```

Shows the maintenance status of the current vehicle.

```txt
evmClearService
```

Clears the service lock from the current or nearby vehicle.

```txt
evmClearAllService
```

Clears all service locks from all vehicles.

```txt
evmFleetReset
```

Resets all vehicles: removes damage, restores maintenance intervals and clears failures. Useful when old versions created incorrect saved states.

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

Shows diagnostic information about available repair/damage functions on the current vehicle.

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

Starts or stops HUD edit mode. While enabled, the HUD can be positioned with the mouse. Disabling edit mode saves the position.

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

This mod is currently developed and tested for Farming Simulator 25 multiplayer/server use. Some functions are intended for debugging, testing and recovery and should only be used by server owners or trusted admins.

## Support

Support on: https://discord.gg/C9yRZmQ6M3

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
