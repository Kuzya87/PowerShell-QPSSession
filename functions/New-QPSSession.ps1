<#
.SYNOPSIS
    Создаёт удалённые сеансы для одного или нескольких компьютеров.

.DESCRIPTION
    Создаёт объект QPSSession (обёртку над PSSession) для каждого указанного компьютера.
    Параметры подключения разрешаются в таком порядке: явно переданное значение, значение из подходящего
    пресета в $global:QPSSession_Preset, затем значение по умолчанию. Если подключение к компьютеру не удалось,
    выдаётся предупреждение, после чего обработка продолжается для остальных компьютеров.

.PARAMETER ComputerName
    Имена удалённых компьютеров для подключения.

.PARAMETER Credential
    Учётные данные для подключения. Имеют приоритет над значением из пресета.
    Если параметр не задан и пресет не содержит учётных данных, используются текущие учётные данные пользователя,
    если это поддерживается режимом AuthMode. Режимы Basic, Credssp и Digest требуют учётные данные:
    их можно передать этим параметром или задать в подходящем пресете. Режим NegotiateWithImplicitCredential
    несовместим с учётными данными, переданными параметром или найденными в пресете.

.PARAMETER AuthMode
    Режим аутентификации: Default, Basic, Negotiate, NegotiateWithImplicitCredential, Credssp, Digest или Kerberos.
    Имеет приоритет над значением из пресета. По умолчанию используется "Kerberos".

.PARAMETER PS7
    Подключается к конечной точке "PowerShell.7" вместо "microsoft.powershell".
    Имеет приоритет над ConfigurationName из пресета.

.PARAMETER UseSSL
    Использует SSL для подключения. Имеет приоритет над значением UseSSL из пресета.

.PARAMETER SkipCertCheck
    Пропускает проверки центра сертификации, имени и отзыва SSL-сертификата.
    Имеет приоритет над значением SkipCertCheck из пресета.

.OUTPUTS
    QPSSession[]
    Содержит объекты успешно созданных сеансов. Для компьютеров, к которым подключиться не удалось,
    объекты не возвращаются.

.EXAMPLE
    New-QPSSession -ComputerName "server1", "server2"

    Создаёт сеансы для server1 и server2, используя подходящие пресеты или значения по умолчанию.

.EXAMPLE
    New-QPSSession -ComputerName "server1" -Credential $cred -PS7 -UseSSL

    Создаёт сеанс с server1 через SSL и конечную точку PowerShell 7, используя переданные учётные данные.
#>
function New-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrWhiteSpace()]
        [string[]]$ComputerName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
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

    $ErrorActionPreference = "Stop"

    $QPSSessionsList = [System.Collections.Generic.List[QPSSession]]::new()
    foreach ($computer in $ComputerName) {
        # Найти подходящий пресет QPSSessionPreset
        $PresetToUse = [QPSSessionPreset]::FindPresetToUse($computer)

        [pscredential]$CredentialToUse = [QPSSessionPreset]::ResolveValue(
            $Credential,
            $PresetToUse.Credential,
            { $null }
        )
        $AuthModeExplicit = if ($PSBoundParameters.ContainsKey("AuthMode")) { $AuthMode }
        [string]$AuthModeToUse = [QPSSessionPreset]::ResolveValue(
            $AuthModeExplicit,
            $PresetToUse.AuthMode,
            { "Kerberos" }
        )
        [string]$ConfigurationNameToUse = [QPSSessionPreset]::ResolveValue(
            $(if ($PSBoundParameters.ContainsKey("PS7")) {
                    if ($PS7) { "PowerShell.7" } else { "microsoft.powershell" }
                }),
            $PresetToUse.ConfigurationName,
            { "microsoft.powershell" }
        )
        [bool]$UseSSLToUse = [QPSSessionPreset]::ResolveValue(
            $(if ($PSBoundParameters.ContainsKey("UseSSL")) { [bool]$UseSSL }),
            $PresetToUse.UseSSL,
            { $false }
        )
        [bool]$SkipCertCheckToUse = [QPSSessionPreset]::ResolveValue(
            $(if ($PSBoundParameters.ContainsKey("SkipCertCheck")) { [bool]$SkipCertCheck }),
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
        }
        catch {
            if (
                $_.Exception -is [System.ArgumentException] -and
                $_.Exception.ParamName -in @("AuthMode", "Credential")
            ) {
                throw [System.ArgumentException]::new(
                    $_.Exception.Message,
                    $_.Exception.ParamName,
                    $_.Exception
                )
            }
            Write-Warning -Message "Не удалось создать сессию для '$computer': $($_.Exception.Message)"
            continue
        }

        $QPSSessionsList.Add($QPSSession)
    }

    return $QPSSessionsList
}
