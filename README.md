# Extended Vehicle Maintenance

Extended Vehicle Maintenance adds a more immersive maintenance system to Farming Simulator 25.

Instead of simply repairing machines instantly and moving on, this mod makes maintenance feel like part of everyday farm management. Drivable machines need service after operating hours, can be sent into maintenance, and remain unavailable while the work is being carried out.

The mod only affects machines that can be driven by the player, such as tractors, trucks, harvesters and other self-propelled vehicles. Implements and passive attachments are not part of the maintenance system.

Depending on the situation, different service options are available. You can send a machine to the workshop, call a technician, or repair it yourself. Each option has its own balance between cost and time: the technician is the most expensive option, while self-repair is the cheapest but takes the longest.

Extended Vehicle Maintenance also includes a malfunction system. Machines can suffer from issues such as engine problems, RPM/emergency-mode failures, flat tires or battery-related problems. Poorly maintained machines can become unreliable and may cause trouble during work.

A battery simulation is included as well. Batteries can discharge when electrical consumers are active and recharge while the engine is running.

## Features

- Realistic maintenance system for drivable machines
- Maintenance based on operating hours
- Vehicles are locked while service is active
- Different service options: workshop, technician and self-repair
- Malfunction system with multiple failure types
- Battery charging and discharging simulation
- HUD for maintenance and vehicle condition information
- Configurable HUD size and position
- Multiplayer/server support
- Console commands for testing, debugging and recovery

## Affected Machines

Extended Vehicle Maintenance is designed for machines that can be driven by the player.

Examples:

- Tractors
- Trucks
- Harvesters
- Wheel loaders
- Telehandlers
- Other self-propelled machines

Implements and passive attachments are not handled as separate maintenance targets.

## Service Options

### Workshop Service

The machine is sent to the workshop and cannot be used while service is active. This option takes longer than calling a technician.

### Technician

A technician comes to repair or maintain the machine. This is the most expensive option, but it is useful when you want the work done without using the self-repair option.

### Self-Repair

Self-repair is the cheapest option, but it takes the longest. It is intended as the budget-friendly choice when time is less important than money.

## Malfunctions

The mod can simulate different technical problems, including:

- Engine problems
- RPM/emergency-mode failures
- Flat tires
- Battery-related issues

Some malfunctions can limit how a machine behaves, reduce reliability or prevent normal operation until the problem has been repaired.

## Battery Simulation

The battery system simulates basic charging and discharging behavior.

Electrical consumers can slowly drain the battery when the engine is off, while running the engine can recharge it. This makes parked or poorly managed machines feel more realistic over time.

## Console Commands

Some commands are mainly intended for testing, debugging or recovery. They should usually only be used by server owners or trusted admins.

### Failure / Malfunction Commands

```txt
evmFailure engine
evmFailure flatTire
evmFailure rpm
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

This mod is currently developed and tested mainly for Farming Simulator 25 multiplayer/server use.

Some systems and commands are intended for debugging, testing and recovery. On public servers, these commands should only be used by trusted admins.

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
