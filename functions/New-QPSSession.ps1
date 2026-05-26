function New-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,
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
        $QPSSessions = [System.Collections.Generic.List[QPSSession]]::new()
        foreach ($computer in $ComputerName) {
            if (-not $Credential) {
                if ($computer.StartsWith("kz") -or $computer.EndsWith(".kz")) {
                    $CredentialToUse = $admaccountkz
                }
                else {
                    $CredentialToUse = $admaccountac
                }
                if (-not $CredentialToUse) {
                    throw "Credential variable `$admaccountkz/`$admaccountac is not defined. Provide -Credential."
                }
            }
            else {
                $CredentialToUse = $Credential
            }

            if ($PowerShellVersion -eq "PowerShell7") {
                $ConfigurationName = "PowerShell.7"    # Use PowerShell 7
            }
            else {
                $ConfigurationName = "microsoft.powershell"    # Use builtin Windows PowerShell
            }

            $QPSSession = [QPSSession]::new()
            $QPSSession.ComputerName = $computer
            $QPSSession.Credential = $CredentialToUse
            $QPSSession.AuthMode = "Kerberos"
            $QPSSession.ConfigurationName = $ConfigurationName
            $QPSSession.SSL = $true
            $QPSSession.SkipCertCheck = $false
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
