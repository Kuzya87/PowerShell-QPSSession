function Enter-QPSSession {
    <#
    .SYNOPSIS
        Interactive enter into a remote PowerShell session.
    .DESCRIPTION
        Creates a PSSession session to the specified computer and enters it interactively.
        The user will close the PSSession session himself when he sees fit.
    .PARAMETER ComputerName
        Name of the remote computer to connect to.
    .PARAMETER PowerShellVersion
        PowerShell endpoint to use on the remote machine. "WindowsPowerShell" (default) uses the
        built-in Windows PowerShell 5.1 endpoint; "PowerShell7" uses the PowerShell 7 endpoint.
        Defaults to the module variable $QPSSession_PowerShell_Version.
    .PARAMETER Credential
        Credentials for the connection. If not specified, credentials are selected automatically
        based on the computer name: $admaccountkz for names starting with "kz" or ending with ".kz",
        $admaccountac for all others.
    .EXAMPLE
        PS C:\> Enter-QPSSession -ComputerName "server01"

        Enters an interactive remote session to server01 using the default PowerShell endpoint
        and auto-selected credentials.
    .EXAMPLE
        PS C:\> Enter-QPSSession "dc01.kz" -PowerShellVersion "PowerShell7"

        Connects to a .kz domain controller using the PowerShell 7 endpoint.
    .INPUTS
        None
    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ComputerName,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("WindowsPowerShell", "PowerShell7")]
        [string]$PowerShellVersion = $QPSSession_PowerShell_Version,
        [Parameter(Mandatory = $false, Position = 2)]
        [pscredential]$Credential
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        $Params = @{
            ComputerName      = $ComputerName
            PowerShellVersion = $PowerShellVersion
        }
        if ($Credential) {
            $Params.Add("Credential", $Credential)
        }
        $QPSSession = (New-QPSSession @Params)[0]

        if ($QPSSession) {
            $QPSSession.Enter()
        }
        else {
            throw "Failed to create PSSession to $ComputerName."
        }
    }

    end {}
}
