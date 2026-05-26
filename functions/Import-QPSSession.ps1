function Import-QPSSession {
    <#
    .SYNOPSIS
        Import cmdlets or modules from a remote PowerShell session into the current local session.
    .DESCRIPTION
        Creates a PSSession to the specified computer and imports the specified cmdlets or modules
        into the current local session using implicit remoting. The imported commands run remotely
        but are callable locally as if they were native commands.
        Use -Cmdlets to import individual commands, or -Modules to import entire modules.
        The user will close the PSSession session himself when he sees fit. Access to the session
        is only possible via Get-PSSession.
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
    .PARAMETER Cmdlets
        One or more cmdlet names to import from the remote session into the current local session.
        Mutually exclusive with -Modules.
    .PARAMETER Modules
        One or more module names to import from the remote session into the current local session.
        Mutually exclusive with -Cmdlets.
    .EXAMPLE
        PS C:\> Import-QPSSession -ComputerName "dc01" -Cmdlets "Get-ADUser", "Get-ADGroup"

        Imports the Get-ADUser and Get-ADGroup cmdlets from the remote computer dc01 into the
        current session using auto-selected credentials.
    .EXAMPLE
        PS C:\> Import-QPSSession -ComputerName "dc01" -Modules "ActiveDirectory"

        Imports the entire ActiveDirectory module from dc01 into the current local session.
    .EXAMPLE
        PS C:\> $cred = Get-Credential
        PS C:\> Import-QPSSession -ComputerName "srv01" -Modules "ActiveDirectory" -Credential $cred -PowerShellVersion "PowerShell7"

        Imports the ActiveDirectory module via the PowerShell 7 endpoint using explicit credentials.
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
        [pscredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = "byCommand")]
        [string[]]$Cmdlets,
        [Parameter(Mandatory = $true, ParameterSetName = "byModule")]
        [string[]]$Modules
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
            switch ($PSCmdlet.ParameterSetName) {
                "byCommand" { $QPSSession.ImportCmdlets($Cmdlets) }
                "byModule" { $QPSSession.ImportModules($Modules) }
            }
        }
        else {
            throw "Failed to create PSSession to $ComputerName."
        }
    }

    end {}
}
