class QPSSessionPreset {
    [string]$Description
    [regex[]]$ComputerNamePattern
    [pscredential]$Credential
    [string]$AuthMode
    [string]$ConfigurationName
    [bool]$UseSSL
    [bool]$SkipCertCheck

    ################
    # CONSTRUCTORS #
    ################

    # Constructor for empty object
    QPSSessionPreset() {}

    ###########
    # METHODS #
    ###########

    [bool] IsMatch([string]$ComputerName) {
        [bool]$Result = $false
        foreach ($pattern in $this.ComputerNamePattern) {
            if ($pattern.IsMatch($ComputerName)) {
                [bool]$Result = $true
                break
            }
        }

        return $Result
    }

    static [QPSSessionPreset] ParseHashtable([hashtable]$Hashtable) {
        $QPSSessionPreset = [QPSSessionPreset]::new()

        # Parse Description property
        if ($Hashtable.Description) {
            $QPSSessionPreset.Description = $Hashtable.Description.ToString()
        }

        # Parse ComputerNamePattern property
        $RegexList = [System.Collections.Generic.List[regex]]::new()
        $RegexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        foreach ($pattern in $Hashtable.ComputerNamePattern) {
            $RegexList.Add([regex]::new($pattern, $RegexOptions))
        }
        if ($RegexList.Count -eq 0) {
            throw "No value for key 'ComputerNamePattern' in hashtable"
        }
        $QPSSessionPreset.ComputerNamePattern = $RegexList

        # Parse Credential property
        if ($Hashtable.CredentialName) {
            $CredentialVariableValue = (Get-Variable -Name $Hashtable.CredentialName -ErrorAction "SilentlyContinue").Value
            if ($CredentialVariableValue -is [pscredential]) {
                $QPSSessionPreset.Credential = $CredentialVariableValue
            }
        }

        # Parse AuthMode property
        if ($Hashtable.AuthMode) {
            $QPSSessionPreset.AuthMode = $Hashtable.AuthMode.ToString()
        }

        # Parse ConfigurationName property
        if ($Hashtable.ConfigurationName) {
            $QPSSessionPreset.ConfigurationName = $Hashtable.ConfigurationName.ToString()
        }

        # Parse UseSSL property
        if ($Hashtable.UseSSL) {
            $QPSSessionPreset.UseSSL = [bool]::Parse($Hashtable.UseSSL)
        }

        # Parse SkipCertCheck property
        if ($Hashtable.SkipCertCheck) {
            $QPSSessionPreset.SkipCertCheck = [bool]::Parse($Hashtable.SkipCertCheck)
        }

        return $QPSSessionPreset
    }

    static [QPSSessionPreset[]] GetPresetList() {
        if ($global:QPSSession_Preset) {
            [QPSSessionPreset[]]$QPSSessionPresetList = $global:QPSSession_Preset | ForEach-Object -Process {
                [QPSSessionPreset]::ParseHashtable($_)
            }
        }
        else {
            [QPSSessionPreset[]]$QPSSessionPresetList = @()
        }

        return $QPSSessionPresetList
    }

    static [QPSSessionPreset] FindPresetToUse([string]$ComputerName) {
        [QPSSessionPreset]$PresetToUse = $null
        $QPSSessionPresetList = [QPSSessionPreset]::GetPresetList()
        foreach ($preset in $QPSSessionPresetList) {
            if ($preset.IsMatch($ComputerName)) {
                [QPSSessionPreset]$PresetToUse = $preset
                break
            }
        }

        return $PresetToUse
    }

    static [object] ResolveValue([object]$ExplicitValue, [object]$PresetValue, [scriptblock]$Default) {
        if ($ExplicitValue) {
            return $ExplicitValue
        }
        if ($PresetValue) {
            return $PresetValue
        }
        return $Default.InvokeReturnAsIs()
    }
}
