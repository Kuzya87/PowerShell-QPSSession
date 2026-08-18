# PowerShell-QPSSession

A PowerShell module that wraps `New-PSSession` / `Enter-PSSession` / `Import-PSSession` behind a unified `QPSSession` class and three convenience functions. Targets Windows environments with Kerberos authentication and WinRM over SSL.

## Requirements

- PowerShell 7.4 or later
- WinRM enabled on remote computers
- Kerberos authentication available between client and target
- Remote endpoint configured:
  - `microsoft.powershell` — built-in Windows PowerShell 5.1 (always present)
  - `PowerShell.7` — PowerShell 7 endpoint (must be registered manually on the remote if needed)

## Installation

```powershell
Import-Module -Name ".\PowerShell-QPSSession.psd1"
```

## Presets

Every function resolves its connection settings (`Credential`, `AuthMode`, `ConfigurationName`, `UseSSL`, `SkipCertCheck`) using the same order of precedence:

1. An explicit parameter passed to the function — always wins.
2. The corresponding value from a matching preset in `$global:QPSSession_Preset` — used when the parameter is not supplied.
3. A built-in default (`AuthMode = "Kerberos"`, `ConfigurationName = "microsoft.powershell"`, `UseSSL = $false`, `SkipCertCheck = $false`; if no credential is available at all, the user is prompted).

Presets are entirely optional — omit `$global:QPSSession_Preset` and pass `-Credential` explicitly if you don't need per-computer defaults.

Define `$global:QPSSession_Preset` as an array of hashtables **before** calling any of the three functions (typically right before importing the module):

```powershell
$admaccountkz = Get-Credential "DOMAIN\admin_kz"
$admaccountac = Get-Credential "DOMAIN\admin_ac"

$global:QPSSession_Preset = @(
    @{
        Description         = "Kazakhstan domain"
        ComputerNamePattern = @("^kz", "\.kz$")
        CredentialName      = "admaccountkz"
        UseSSL              = "true"
    },
    @{
        Description         = "Everything else"
        ComputerNamePattern = @(".*")
        CredentialName      = "admaccountac"
    }
)

Import-Module -Name ".\PowerShell-QPSSession.psd1"
```

**Preset hashtable keys:**

| Key | Type | Required | Description |
|---|---|---|---|
| `Description` | `string` | No | Free-text label, for readability only |
| `ComputerNamePattern` | `string[]` | Yes | One or more regex patterns (case-insensitive), matched against the target computer name |
| `CredentialName` | `string` | No | Name of a variable (resolved with `Get-Variable`) holding a `pscredential` |
| `AuthMode` | `string` | No | Authentication mechanism, e.g. `"Kerberos"`, `"Negotiate"`, `"Basic"` |
| `ConfigurationName` | `string` | No | Remote session configuration/endpoint name |
| `UseSSL` | `string` | No | `"true"` or `"false"` (parsed with `[bool]::Parse` — no other values are accepted) |
| `SkipCertCheck` | `string` | No | `"true"` or `"false"` (parsed with `[bool]::Parse` — no other values are accepted) |

Presets are checked in array order; the **first** entry whose `ComputerNamePattern` matches the target computer name is used, so put more specific patterns before catch-all ones.

## Functions

### `New-QPSSession`

Creates one or more `QPSSession` objects and returns them as a list. Used internally by `Enter-QPSSession` and `Import-QPSSession`, but can also be called directly when you need a session object for further use. A computer that fails to connect produces a warning and is omitted from the result instead of stopping the whole call.

**Alias:** `newpssession`

```powershell
# Single session, settings resolved from a matching preset (or defaults)
$sessions = New-QPSSession -ComputerName "dc01.kz"

# Multiple computers
$sessions = New-QPSSession -ComputerName "srv01", "srv02", "srv03"

# PowerShell 7 endpoint
$sessions = New-QPSSession -ComputerName "srv01" -PS7

# Explicit credentials over SSL
$sessions = New-QPSSession -ComputerName "srv01" -Credential (Get-Credential) -UseSSL
```

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ComputerName` | `string[]` | Yes | One or more target computer names or FQDNs |
| `Credential` | `pscredential` | No | Explicit credentials; overrides any preset, prompts if omitted and no preset supplies one |
| `AuthMode` | `string` | No | Explicit authentication mechanism; overrides any preset, defaults to `"Kerberos"` |
| `PS7` | `switch` | No | Use the `"PowerShell.7"` endpoint instead of `"microsoft.powershell"`; overrides any preset |
| `UseSSL` | `switch` | No | Use SSL for the connection; overrides any preset |
| `SkipCertCheck` | `switch` | No | Skip CA / CN / revocation checks for the SSL certificate; overrides any preset |

**Returns:** `System.Collections.Generic.List[QPSSession]`

---

### `Enter-QPSSession`

Creates a single `QPSSession` to the specified computer (via `New-QPSSession`) and enters it interactively. The session remains open until you exit it with `exit`. Throws if the session could not be created.

**Alias:** `enter`

```powershell
# Basic interactive session
Enter-QPSSession -ComputerName "srv01"

# Alias form
enter "srv01"

# Using the PowerShell 7 endpoint
Enter-QPSSession -ComputerName "dc01.kz" -PS7

# Explicit credentials over SSL, skipping certificate checks
Enter-QPSSession -ComputerName "srv01" -Credential (Get-Credential) -UseSSL -SkipCertCheck
```

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ComputerName` | `string` | Yes | Target computer name or FQDN |
| `Credential` | `pscredential` | No | Explicit credentials; overrides any preset, prompts if omitted and no preset supplies one |
| `AuthMode` | `string` | No | Explicit authentication mechanism; overrides any preset, defaults to `"Kerberos"` |
| `PS7` | `switch` | No | Use the `"PowerShell.7"` endpoint instead of `"microsoft.powershell"`; overrides any preset |
| `UseSSL` | `switch` | No | Use SSL for the connection; overrides any preset |
| `SkipCertCheck` | `switch` | No | Skip CA / CN / revocation checks for the SSL certificate; overrides any preset |

---

### `Import-QPSSession`

Creates a single `QPSSession` to the specified computer (via `New-QPSSession`) and imports individual commands or entire modules from it into the current local session using implicit remoting. The imported commands run on the remote computer but are callable locally as if they were native commands. Throws if the session could not be created.

The session is kept open after the import and is accessible via `Get-PSSession`. Close it manually when done.

**Alias:** `import`

```powershell
# Import specific commands from a domain controller
Import-QPSSession -ComputerName "dc01.kz" -Cmdlets "Get-ADUser", "Get-ADGroup", "Set-ADUser"

# Import an entire module
Import-QPSSession -ComputerName "dc01.kz" -Modules "ActiveDirectory"

# Use the alias
import "dc01.kz" -Modules "ActiveDirectory"

# PowerShell 7 endpoint with explicit credentials
Import-QPSSession -ComputerName "srv01" -Modules "DhcpServer" -Credential (Get-Credential) -PS7
```

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ComputerName` | `string` | Yes | Target computer name or FQDN |
| `Credential` | `pscredential` | No | Explicit credentials; overrides any preset, prompts if omitted and no preset supplies one |
| `AuthMode` | `string` | No | Explicit authentication mechanism; overrides any preset, defaults to `"Kerberos"` |
| `PS7` | `switch` | No | Use the `"PowerShell.7"` endpoint instead of `"microsoft.powershell"`; overrides any preset |
| `UseSSL` | `switch` | No | Use SSL for the connection; overrides any preset |
| `SkipCertCheck` | `switch` | No | Skip CA / CN / revocation checks for the SSL certificate; overrides any preset |
| `Cmdlets` | `string[]` | Yes (set 1) | Command names to import. Mutually exclusive with `-Modules` |
| `Modules` | `string[]` | Yes (set 2) | Module names to import in full. Mutually exclusive with `-Cmdlets` |

## QPSSession class

`New-QPSSession` returns `QPSSession` objects. You can also instantiate the class directly — the parameterized constructors call `Create()` automatically.

**Properties:**

| Property | Type | Description |
|---|---|---|
| `ComputerName` | `string` | Remote computer name |
| `Id` | `int` | PSSession ID assigned by PowerShell |
| `State` | `string` | Current session state (`Opened`, `Closed`, `Disconnected`, …) |
| `Credential` | `pscredential` | Credentials used for the session |
| `AuthMode` | `string` | Authentication mode (default: `Kerberos`) |
| `ConfigurationName` | `string` | Remote endpoint name (default: `microsoft.powershell`) |
| `UseSSL` | `bool` | Whether SSL is used for the connection |
| `SkipCertCheck` | `bool` | Skip CA / CN / revocation checks |
| `RemotePSVersion` | `version` | PowerShell version running on the remote |
| `PSSessionObject` | `PSSession` | The underlying `System.Management.Automation.Runspaces.PSSession` |

**Methods:**

| Method | Description |
|---|---|
| `Create()` | Opens the PSSession. Called automatically by parameterized constructors |
| `Enter()` | Enters an interactive remote session |
| `ImportCmdlets([string[]]$Cmdlets)` | Imports the specified commands via implicit remoting into the global scope |
| `ImportModules([string[]]$Modules)` | Imports the specified modules via implicit remoting into the global scope |
| `Disconnect()` | Disconnects the session (keeps it alive for later reconnect) |
| `Connect()` | Reconnects a previously disconnected session |
| `Remove()` | Closes and removes the session |
| `UpdateState()` | Refreshes the `State` property from the underlying PSSession object |

**Direct usage example:**

```powershell
$s = [QPSSession]::new()
$s.ComputerName      = "srv01"
$s.Credential        = $admaccountac
$s.AuthMode          = "Kerberos"
$s.ConfigurationName = "microsoft.powershell"
$s.UseSSL            = $true
$s.SkipCertCheck     = $false
$s.Create()

Invoke-Command -Session $s.PSSessionObject -ScriptBlock { hostname }

$s.Remove()
```

## QPSSessionPreset class

Backs the [preset resolution](#presets) described above. Instances are built automatically from `$global:QPSSession_Preset` — you normally don't need to use it directly, but it's exported (as a type accelerator, alongside `QPSSession`) for advanced scenarios.

**Properties:**

| Property | Type | Description |
|---|---|---|
| `Description` | `string` | Free-text label |
| `ComputerNamePattern` | `regex[]` | Regex patterns matched against a computer name |
| `Credential` | `pscredential` | Resolved from the hashtable's `CredentialName` |
| `AuthMode` | `string` | Authentication mode |
| `ConfigurationName` | `string` | Remote endpoint name |
| `UseSSL` | `bool` | Whether SSL is used |
| `SkipCertCheck` | `bool` | Skip CA / CN / revocation checks |

**Methods:**

| Method | Description |
|---|---|
| `IsMatch([string]$ComputerName)` | Returns `$true` if any pattern in `ComputerNamePattern` matches the given name |
| `static ParseHashtable([hashtable]$Hashtable)` | Builds a `QPSSessionPreset` from one entry of `$global:QPSSession_Preset` |
| `static GetPresetList()` | Parses all of `$global:QPSSession_Preset` into `QPSSessionPreset[]` |
| `static FindPresetToUse([string]$ComputerName)` | Returns the first preset matching the given computer name, or `$null` |
