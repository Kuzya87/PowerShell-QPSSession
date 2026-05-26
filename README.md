# PowerShell-QPSSession

A PowerShell module that wraps `New-PSSession` / `Enter-PSSession` / `Import-PSSession` behind a unified `QPSSession` class and three convenience functions. Targets Windows environments with Kerberos authentication and WinRM over SSL.

## Requirements

- PowerShell 7.4 or later
- WinRM enabled on remote computers
- Kerberos authentication available between client and target
- Remote endpoint configured:
  - `microsoft.powershell` — built-in Windows PowerShell 5.1 (always present)
  - `PowerShell.7` — PowerShell 7 endpoint (must be registered manually on the remote if needed)

## Credential convention

The module auto-selects credentials from session variables when `-Credential` is not provided:

| Computer name pattern | Variable used |
|---|---|
| Starts with `kz` or ends with `.kz` | `$admaccountkz` |
| Everything else | `$admaccountac` |

These variables must be defined in the calling session before calling any function without explicit `-Credential`. If neither variable is set and `-Credential` is omitted, the functions throw a descriptive error.

```powershell
$admaccountkz = Get-Credential "DOMAIN\admin_kz"
$admaccountac = Get-Credential "DOMAIN\admin_ac"
```

## Installation

```powershell
Import-Module -Name ".\PowerShell-QPSSession.psd1"
```

## Functions

### `New-QPSSession`

Creates one or more `QPSSession` objects and returns them as a list. Used internally by `Enter-QPSSession` and `Import-QPSSession`, but can also be called directly when you need a session object for further use.

```powershell
# Single session with auto-selected credentials
$sessions = New-QPSSession -ComputerName "dc01.kz"

# Multiple computers
$sessions = New-QPSSession -ComputerName "srv01", "srv02", "srv03"

# PowerShell 7 endpoint
$sessions = New-QPSSession -ComputerName "srv01" -PowerShellVersion "PowerShell7"

# Explicit credentials
$sessions = New-QPSSession -ComputerName "srv01" -Credential (Get-Credential)
```

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ComputerName` | `string[]` | Yes | One or more target computer names or FQDNs |
| `PowerShellVersion` | `string` | No | `WindowsPowerShell` (default) or `PowerShell7` |
| `Credential` | `pscredential` | No | Explicit credentials; auto-selected if omitted |

**Returns:** `System.Collections.Generic.List[QPSSession]`

---

### `Enter-QPSSession`

Creates a PSSession to the specified computer and enters it interactively. The session remains open until you exit it with `exit`.

**Alias:** `enter`

```powershell
# Basic interactive session
Enter-QPSSession -ComputerName "srv01"

# Alias form
enter "srv01"

# Using PowerShell 7 endpoint
Enter-QPSSession -ComputerName "dc01.kz" -PowerShellVersion "PowerShell7"

# Explicit credentials
Enter-QPSSession -ComputerName "srv01" -Credential (Get-Credential)
```

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ComputerName` | `string` | Yes | Target computer name or FQDN |
| `PowerShellVersion` | `string` | No | `WindowsPowerShell` (default) or `PowerShell7` |
| `Credential` | `pscredential` | No | Explicit credentials; auto-selected if omitted |

---

### `Import-QPSSession`

Creates a PSSession to the specified computer and imports individual cmdlets or entire modules from it into the current local session using implicit remoting. The imported commands run on the remote computer but are callable locally as if they were native commands.

The session is kept open after the import and is accessible via `Get-PSSession`. Close it manually when done.

**Alias:** `import`

```powershell
# Import specific cmdlets from a domain controller
Import-QPSSession -ComputerName "dc01.kz" -Cmdlets "Get-ADUser", "Get-ADGroup", "Set-ADUser"

# Import an entire module
Import-QPSSession -ComputerName "dc01.kz" -Modules "ActiveDirectory"

# Use the alias
import "dc01.kz" -Modules "ActiveDirectory"

# PowerShell 7 endpoint with explicit credentials
$cred = Get-Credential
Import-QPSSession -ComputerName "srv01" -Modules "DhcpServer" -Credential $cred -PowerShellVersion "PowerShell7"
```

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `ComputerName` | `string` | Yes | Target computer name or FQDN |
| `PowerShellVersion` | `string` | No | `WindowsPowerShell` (default) or `PowerShell7` |
| `Credential` | `pscredential` | No | Explicit credentials; auto-selected if omitted |
| `Cmdlets` | `string[]` | Yes (set 1) | Cmdlet names to import. Mutually exclusive with `-Modules` |
| `Modules` | `string[]` | Yes (set 2) | Module names to import. Mutually exclusive with `-Cmdlets` |

---

## QPSSession class

`New-QPSSession` returns `QPSSession` objects. You can also instantiate the class directly.

**Properties:**

| Property | Type | Description |
|---|---|---|
| `ComputerName` | `string` | Remote computer name |
| `Id` | `int` | PSSession ID assigned by PowerShell |
| `State` | `string` | Current session state (`Opened`, `Closed`, `Disconnected`, …) |
| `Credential` | `pscredential` | Credentials used for the session |
| `AuthMode` | `string` | Authentication mode (default: `Kerberos`) |
| `ConfigurationName` | `string` | Remote endpoint name |
| `SSL` | `bool` | Whether SSL is used for the connection |
| `SkipCertCheck` | `bool` | Skip CA / CN / revocation checks |
| `RemotePSVersion` | `version` | PowerShell version running on the remote |
| `PSSessionObject` | `PSSession` | The underlying `System.Management.Automation.Runspaces.PSSession` |

**Methods:**

| Method | Description |
|---|---|
| `Create()` | Opens the PSSession. Called automatically by parameterized constructors |
| `Enter()` | Enters an interactive remote session |
| `ImportCmdlets([string[]]$Cmdlets)` | Imports the specified cmdlets via implicit remoting into the global scope |
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
$s.SSL               = $true
$s.SkipCertCheck     = $false
$s.Create()

Invoke-Command -Session $s.PSSessionObject -ScriptBlock { hostname }

$s.Remove()
```

## Module variable

`$QPSSession_PowerShell_Version` controls the default value of the `-PowerShellVersion` parameter across all three functions. Set it before importing the module to change the default endpoint for the entire session:

```powershell
$QPSSession_PowerShell_Version = "PowerShell7"
Import-Module -Name ".\PowerShell-QPSSession.psd1"
```

If the variable is not set when the module loads, it defaults to `"WindowsPowerShell"`.
