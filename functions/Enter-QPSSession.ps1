<#
.SYNOPSIS
    Creates a PSSession to a remote computer and enters an interactive session with it.

.DESCRIPTION
    Calls New-QPSSession to create a single QPSSession to the specified computer, then opens an interactive
    session to it via Enter-PSSession. Throws if the session could not be created.

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

.EXAMPLE
    Enter-QPSSession -ComputerName "server1"

    Connects to server1 and enters an interactive session.
#>
function Enter-QPSSession {
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
        [switch]$SkipCertCheck
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
            $QPSSession.Enter()
        }
        else {
            throw "Failed to create PSSession to '$ComputerName'."
        }
    }

    end {}
}
