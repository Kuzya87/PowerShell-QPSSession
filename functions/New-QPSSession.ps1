<#
.SYNOPSIS
    Creates new PSRemoting sessions to one or more remote computers.

.DESCRIPTION
    Creates a QPSSession (a wrapper around a PSSession) for each computer name supplied.
    For every computer, connection parameters (Credential, AuthMode, ConfigurationName, UseSSL, SkipCertCheck)
    are resolved in the following order of precedence: an explicit parameter to this function, then the
    corresponding value from a matching QPSSessionPreset (see $global:QPSSession_Preset), then a built-in default.
    If a connection to a given computer fails, a warning is written and processing continues with the remaining
    computers.

.PARAMETER ComputerName
    Names of the remote computers to connect to.

.PARAMETER Credential
    Credentials to use for the connection. Takes precedence over any credential supplied by a matching preset.
    If omitted and no preset supplies one, the user is prompted for credentials.

.PARAMETER AuthMode
    Authentication mechanism to use (e.g. "Kerberos", "Negotiate", "Basic"). Takes precedence over any AuthMode
    supplied by a matching preset. Defaults to "Kerberos".

.PARAMETER PS7
    Connects to the "PowerShell.7" session configuration instead of the default "microsoft.powershell".
    Takes precedence over the ConfigurationName supplied by a matching preset.

.PARAMETER UseSSL
    Uses SSL for the connection. Takes precedence over the UseSSL value supplied by a matching preset.

.PARAMETER SkipCertCheck
    Skips CA, CN and revocation checks for the SSL certificate. Takes precedence over the SkipCertCheck value
    supplied by a matching preset.

.OUTPUTS
    QPSSession[]
    One object per computer that was connected to successfully. Computers that failed to connect are omitted.

.EXAMPLE
    New-QPSSession -ComputerName "server1", "server2"

    Creates PSSessions to server1 and server2, using matching presets or default settings.

.EXAMPLE
    New-QPSSession -ComputerName "server1" -Credential $cred -PS7 -UseSSL

    Creates a PSSession to server1 over SSL using PowerShell 7 remoting and the supplied credential.
#>
function New-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrWhiteSpace()]
        [string[]]$ComputerName,
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
        $QPSSessions = [System.Collections.Generic.List[QPSSession]]::new()
        foreach ($computer in $ComputerName) {
            # Search for QPSSessionPreset
            $PresetToUse = [QPSSessionPreset]::FindPresetToUse($computer)

            [pscredential]$CredentialToUse = [QPSSessionPreset]::ResolveValue(
                $Credential,
                $PresetToUse.Credential,
                { Get-Credential -Message "Credentials for '$computer'" }
            )
            [string]$AuthModeToUse = [QPSSessionPreset]::ResolveValue(
                $AuthMode,
                $PresetToUse.AuthMode,
                { "Kerberos" }
            )
            [string]$ConfigurationNameToUse = [QPSSessionPreset]::ResolveValue(
                $(if ($PS7) { "PowerShell.7" }),
                $PresetToUse.ConfigurationName,
                { "microsoft.powershell" }
            )
            [bool]$UseSSLToUse = [QPSSessionPreset]::ResolveValue(
                $(if ($UseSSL) { $true }),
                $PresetToUse.UseSSL,
                { $false }
            )
            [bool]$SkipCertCheckToUse = [QPSSessionPreset]::ResolveValue(
                $(if ($SkipCertCheck) { $true }),
                $PresetToUse.SkipCertCheck,
                { $false }
            )

            $QPSSession = [QPSSession]::new()
            $QPSSession.ComputerName = $computer
            $QPSSession.Credential = $CredentialToUse
            $QPSSession.AuthMode = $AuthModeToUse
            $QPSSession.ConfigurationName = $ConfigurationNameToUse
            $QPSSession.UseSSL = $UseSSLToUse
            $QPSSession.SkipCertCheck = $SkipCertCheckToUse
            try {
                $QPSSession.Create()
                $QPSSessions.Add($QPSSession)
            }
            catch {
                Write-Warning -Message $_.Exception.Message
            }
        }

        return $QPSSessions
    }

    end {}
}
