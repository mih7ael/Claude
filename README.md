# MyGame

Roblox game synced into Studio with [Rojo](https://rojo.space).

## Folders

| Folder        | Goes to in Studio                                |
|---------------|--------------------------------------------------|
| `src/server`  | ServerScriptService → RojoServer                     |
| `src/client`  | StarterPlayer → StarterPlayerScripts → RojoClient    |
| `src/shared`  | ReplicatedStorage → RojoShared                       |

## Sync into Studio

1. `rojo serve` in this folder
2. In Studio: Plugins → Rojo → Connect
