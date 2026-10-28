class QPSSessionPreset {
    [string]$Description
    [regex[]]$ComputerNamePattern
    [pscredential]$Credential
    [string]$AuthMode
    [string]$ConfigurationName
    [bool]$UseSSL
    [bool]$SkipCertCheck

    ################
    # КОНСТРУКТОРЫ #
    ################

    # Конструктор пустого объекта
    QPSSessionPreset() {}

    ###########
    # МЕТОДЫ #
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
        if ($null -eq $Hashtable) {
            throw [System.ArgumentNullException]::new("Hashtable")
        }

        $QPSSessionPreset = [QPSSessionPreset]::new()

        # Разобрать свойство Description
        if (-not $Hashtable.ContainsKey("Description") -or [string]::IsNullOrWhiteSpace($Hashtable.Description)) {
            throw [System.ArgumentException]::new(
                "Для ключа 'Description' требуется непустое значение.",
                "Hashtable"
            )
        }
        $QPSSessionPreset.Description = $Hashtable.Description.ToString()

        # Разобрать свойство ComputerNamePattern
        $RegexList = [System.Collections.Generic.List[regex]]::new()
        $RegexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        if (-not $Hashtable.ContainsKey("ComputerNamePattern") -or $null -eq $Hashtable.ComputerNamePattern) {
            throw [System.ArgumentException]::new(
                "Для ключа 'ComputerNamePattern' пресета '$($Hashtable.Description)' требуется непустое значение.",
                "Hashtable"
            )
        }
        foreach ($pattern in @($Hashtable.ComputerNamePattern)) {
            if ($pattern -isnot [string] -or [string]::IsNullOrWhiteSpace($pattern)) {
                throw [System.ArgumentException]::new(
                    "Каждое значение ключа 'ComputerNamePattern' пресета '$($Hashtable.Description)' должно быть непустой строкой.",
                    "ComputerNamePattern"
                )
            }
            $RegexList.Add([regex]::new($pattern, $RegexOptions))
        }
        if ($RegexList.Count -eq 0) {
            throw [System.ArgumentException]::new(
                "Для ключа 'ComputerNamePattern' пресета '$($Hashtable.Description)' требуется непустое значение.",
                "ComputerNamePattern"
            )
        }
        $QPSSessionPreset.ComputerNamePattern = $RegexList

        # Разобрать свойство Credential
        if ($Hashtable.CredentialName) {
            [string]$CredentialName = $Hashtable.CredentialName
            $CredentialVariable = Get-Variable -Name $CredentialName -ErrorAction SilentlyContinue
            if ($null -eq $CredentialVariable) {
                Write-Verbose -Message "Не найдена переменная '$CredentialName', указанная в ключе 'CredentialName' пресета '$($Hashtable.Description)'."
            }
            elseif ($CredentialVariable.Value -isnot [pscredential]) {
                Write-Verbose -Message "Переменная '$CredentialName', указанная в ключе 'CredentialName' пресета '$($Hashtable.Description)', должна содержать объект PSCredential."
            }
            else {
                $QPSSessionPreset.Credential = $CredentialVariable.Value
            }
        }

        # Разобрать свойство AuthMode
        if ($Hashtable.ContainsKey("AuthMode")) {
            try {
                [QPSSession]::ValidateAuthMode($Hashtable.AuthMode)
                $QPSSessionPreset.AuthMode = $Hashtable.AuthMode.ToString()
            }
            catch {
                Write-Warning -Message "Недопустимое значение 'AuthMode' в пресете '$($Hashtable.Description)'; значение будет проигнорировано: $($_.Exception.Message)"
            }
        }

        # Разобрать свойство ConfigurationName
        if ($Hashtable.ConfigurationName) {
            if ([string]::IsNullOrWhiteSpace($Hashtable.ConfigurationName)) {
                Write-Verbose -Message "Недопустимое значение 'ConfigurationName' в пресете '$($Hashtable.Description)'; значение будет проигнорировано."
            }
            else {
                $QPSSessionPreset.ConfigurationName = $Hashtable.ConfigurationName.ToString()
            }
        }

        # Разобрать свойство UseSSL
        if ($Hashtable.ContainsKey("UseSSL")) {
            try {
                $QPSSessionPreset.UseSSL = [bool]::Parse($Hashtable.UseSSL.ToString())
            }
            catch {
                Write-Warning -Message "Недопустимое значение 'UseSSL' в пресете '$($Hashtable.Description)'; значение будет проигнорировано: $($_.Exception.Message)"
            }
        }

        # Разобрать свойство SkipCertCheck
        if ($Hashtable.ContainsKey("SkipCertCheck")) {
            try {
                $QPSSessionPreset.SkipCertCheck = [bool]::Parse($Hashtable.SkipCertCheck.ToString())
            }
            catch {
                Write-Warning -Message "Недопустимое значение 'SkipCertCheck' в пресете '$($Hashtable.Description)'; значение будет проигнорировано: $($_.Exception.Message)"
            }
        }

        return $QPSSessionPreset
    }

    static [QPSSessionPreset[]] GetPresetList() {
        if ($null -eq $global:QPSSession_Preset) {
            return @()
        }

        $QPSSessionPresetList = [System.Collections.Generic.List[QPSSessionPreset]]::new()
        foreach ($preset in @($global:QPSSession_Preset)) {
            if ($preset -isnot [hashtable]) {
                throw [System.ArgumentException]::new(
                    "Каждый элемент `$global:QPSSession_Preset должен быть хеш-таблицей.",
                    "QPSSession_Preset"
                )
            }
            $QPSSessionPresetList.Add([QPSSessionPreset]::ParseHashtable($preset))
        }

        return $QPSSessionPresetList.ToArray()
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
        if ($null -ne $ExplicitValue) {
            return $ExplicitValue
        }
        if ($null -ne $PresetValue) {
            return $PresetValue
        }
        return $Default.InvokeReturnAsIs()
    }
}
