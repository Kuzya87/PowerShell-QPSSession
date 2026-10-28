<#
.SYNOPSIS
    Создаёт PSSession с удалённым компьютером и импортирует команды или модули в локальный сеанс.

.DESCRIPTION
    Вызывает New-QPSSession для создания QPSSession с указанным компьютером, затем импортирует из удалённого
    сеанса отдельные команды (-Cmdlets) или модули целиком (-Modules). Если создать сеанс не удалось,
    возникает ошибка. Если импорт завершается ошибкой, созданный сеанс удаляется.

.PARAMETER ComputerName
    Имя удалённого компьютера для подключения.

.PARAMETER Credential
    Учётные данные для подключения. Если параметр не задан, используются данные из подходящего пресета
    или текущие учётные данные пользователя, если это поддерживается режимом AuthMode.
    Режимы Basic, Credssp и Digest требуют учётные данные: их можно передать этим параметром или задать
    в подходящем пресете. Режим NegotiateWithImplicitCredential несовместим с учётными данными,
    переданными параметром или найденными в пресете.

.PARAMETER AuthMode
    Режим аутентификации: Default, Basic, Negotiate, NegotiateWithImplicitCredential, Credssp, Digest или Kerberos.
    Если параметр не задан, используется значение из подходящего пресета или "Kerberos".

.PARAMETER PS7
    Подключается к конечной точке "PowerShell.7" вместо "microsoft.powershell".

.PARAMETER UseSSL
    Использует SSL для подключения.

.PARAMETER SkipCertCheck
    Пропускает проверки центра сертификации, имени и отзыва SSL-сертификата.

.PARAMETER Cmdlets
    Имена удалённых команд для импорта. Нельзя указывать одновременно с -Modules.

.PARAMETER Modules
    Имена удалённых модулей для импорта целиком. Нельзя указывать одновременно с -Cmdlets.

.EXAMPLE
    Import-QPSSession -ComputerName "server1" -Cmdlets "Get-DhcpServerv4Scope"

    Импортирует команду Get-DhcpServerv4Scope с server1 в локальный сеанс.

.EXAMPLE
    Import-QPSSession -ComputerName "server1" -Modules "DhcpServer"

    Импортирует модуль DhcpServer целиком с server1 в локальный сеанс.
#>
function Import-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrWhiteSpace()]
        [string]$ComputerName,
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
        if ($PSBoundParameters.ContainsKey("Credential")) {
            $Params.Add("Credential", $Credential)
        }
        if ($PSBoundParameters.ContainsKey("AuthMode")) {
            $Params.Add("AuthMode", $AuthMode)
        }
        if ($PSBoundParameters.ContainsKey("PS7")) {
            $Params.Add("PS7", $PS7)
        }
        if ($PSBoundParameters.ContainsKey("UseSSL")) {
            $Params.Add("UseSSL", $UseSSL)
        }
        if ($PSBoundParameters.ContainsKey("SkipCertCheck")) {
            $Params.Add("SkipCertCheck", $SkipCertCheck)
        }
        
        # New-QPSSession возвращает массив объектов QPSSession
        [QPSSession[]]$QPSSessions = @(New-QPSSession @Params)
        if ($QPSSessions.Count -eq 0) {
            throw [System.InvalidOperationException]::new(
                "Не удалось создать PSSession для '$ComputerName'."
            )
        }
        [QPSSession]$QPSSession = $QPSSessions[0]

        if ($QPSSession) {
            switch ($PSCmdlet.ParameterSetName) {
                "byCommand" { $QPSSession.ImportCmdlets($Cmdlets) }
                "byModule" { $QPSSession.ImportModules($Modules) }
            }
        }
        else {
            throw [System.InvalidOperationException]::new(
                "Не удалось создать PSSession для '$ComputerName'."
            )
        }
    }

    end {}
}
