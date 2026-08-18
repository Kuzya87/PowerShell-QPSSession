<#
.SYNOPSIS
    Creates a PSSession to a remote computer and imports remote commands or modules into the local session.

.DESCRIPTION
    Calls New-QPSSession to create a single QPSSession to the specified computer, then imports either
    specific commands (-Cmdlets) or entire modules (-Modules) from the remote session into the local session.
    Throws if the session could not be created.

.PARAMETER ComputerName
    Name of the remote computer to connect to.

.PARAMETER Credential
    Credentials to use for the connection. If omitted, falls back to a matching preset or prompts the user.

.PARAMETER AuthMode
    Authentication mechanism to use (e.g. "Kerberos", "Negotiate", "Basic"). If omitted, falls back to a
    matching preset or defaults to "Kerberos".

.PARAMETER PS7
    Connects to the "PowerShell.7" session configuration instead of the default "microsoft.powershell".

.PARAMETER UseSSL
    Uses SSL for the connection.

.PARAMETER SkipCertCheck
    Skips CA, CN and revocation checks for the SSL certificate.

.PARAMETER Cmdlets
    Names of the remote commands to import. Mutually exclusive with -Modules.

.PARAMETER Modules
    Names of the remote modules to import in full. Mutually exclusive with -Cmdlets.

.EXAMPLE
    Import-QPSSession -ComputerName "server1" -Cmdlets "Get-DhcpServerv4Scope"

    Imports the Get-DhcpServerv4Scope command from server1 into the local session.

.EXAMPLE
    Import-QPSSession -ComputerName "server1" -Modules "DhcpServer"

    Imports the entire DhcpServer module from server1 into the local session.
#>
function Import-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrWhiteSpace()]
        [string]$ComputerName,
        [Parameter(Mandatory = $false)]
        [pscredential]$Credential,
        [Parameter(Mandatory = $false)]
        [string]$AuthMode,
        [Parameter(Mandatory = $false)]
        [switch]$PS7,
        [Parameter(Mandatory = $false)]
        [switch]$UseSSL,
        [Parameter(Mandatory = $false)]
        [switch]$SkipCertCheck,
        [Parameter(Mandatory = $true, ParameterSetName = "byCommand")]
        [string[]]$Cmdlets,
        [Parameter(Mandatory = $true, ParameterSetName = "byModule")]
        [string[]]$Modules
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        [hashtable]$Params = @{
            ComputerName = $ComputerName
        }
        if ($Credential) {
            $Params.Add("Credential", $Credential)
        }
        if ($AuthMode) {
            $Params.Add("AuthMode", $AuthMode)
        }
        if ($PS7) {
            $Params.Add("PS7", $PS7)
        }
        if ($UseSSL) {
            $Params.Add("UseSSL", $UseSSL)
        }
        if ($SkipCertCheck) {
            $Params.Add("SkipCertCheck", $SkipCertCheck)
        }
        
        # New-QPSSession returns array of QPSSession objects
        [QPSSession]$QPSSession = (New-QPSSession @Params)[0]

        if ($QPSSession) {
            switch ($PSCmdlet.ParameterSetName) {
                "byCommand" { $QPSSession.ImportCmdlets($Cmdlets) }
                "byModule" { $QPSSession.ImportModules($Modules) }
            }
        }
        else {
            throw "Failed to create PSSession to '$ComputerName'."
        }
    }

    end {}
}
