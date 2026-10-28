class QPSSession {
    [string]$ComputerName
    [Nullable[int]]$Id
    [string]$State
    [pscredential]$Credential
    [string]$AuthMode
    [string]$ConfigurationName
    [bool]$UseSSL
    [bool]$SkipCertCheck
    [version]$RemotePSVersion
    [System.Management.Automation.Runspaces.PSSession]$PSSessionObject

    ################
    # КОНСТРУКТОРЫ #
    ################

    # Конструктор без параметров
    QPSSession() {
        $this.AuthMode = "Kerberos"
        $this.ConfigurationName = "microsoft.powershell"
    }

    QPSSession([string]$ComputerName) {
        $this.ComputerName = $ComputerName
        $this.AuthMode = "Kerberos"
        $this.ConfigurationName = "microsoft.powershell"
        $this.Create()
    }

    # Конструктор с минимальным набором параметров
    QPSSession([string]$ComputerName, [pscredential]$Credential) {
        $DefaultAuthMode = "Kerberos"
        [QPSSession]::ValidateAuthMode($DefaultAuthMode)
        [QPSSession]::ValidateComputerName($ComputerName, $DefaultAuthMode)
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = $DefaultAuthMode
        $this.ConfigurationName = "microsoft.powershell"
        $this.Create()
    }

    # Конструктор с режимом аутентификации
    QPSSession([string]$ComputerName, [pscredential]$Credential, [string]$AuthMode) {
        [QPSSession]::ValidateAuthMode($AuthMode)
        [QPSSession]::ValidateComputerName($ComputerName, $AuthMode)
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = "microsoft.powershell"
        $this.Create()
    }

    QPSSession([string]$ComputerName, [string]$AuthMode) {
        [QPSSession]::ValidateAuthMode($AuthMode)
        [QPSSession]::ValidateComputerName($ComputerName, $AuthMode)
        $this.ComputerName = $ComputerName
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = "microsoft.powershell"
        $this.Create()
    }

    # Конструктор с режимом аутентификации и параметрами SSL
    QPSSession([string]$ComputerName,
        [pscredential]$Credential,
        [string]$AuthMode,
        [bool]$UseSSL,
        [bool]$SkipCertCheck) {
        [QPSSession]::ValidateAuthMode($AuthMode)
        [QPSSession]::ValidateComputerName($ComputerName, $AuthMode)
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = "microsoft.powershell"
        $this.UseSSL = $UseSSL
        $this.SkipCertCheck = $SkipCertCheck
        $this.Create()
    }

    QPSSession([string]$ComputerName,
        [string]$AuthMode,
        [bool]$UseSSL,
        [bool]$SkipCertCheck) {
        [QPSSession]::ValidateAuthMode($AuthMode)
        [QPSSession]::ValidateComputerName($ComputerName, $AuthMode)
        $this.ComputerName = $ComputerName
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = "microsoft.powershell"
        $this.UseSSL = $UseSSL
        $this.SkipCertCheck = $SkipCertCheck
        $this.Create()
    }

    # Конструктор с дополнительными параметрами
    QPSSession([string]$ComputerName,
        [pscredential]$Credential,
        [string]$AuthMode,
        [string]$ConfigurationName,
        [bool]$UseSSL,
        [bool]$SkipCertCheck) {
        [QPSSession]::ValidateAuthMode($AuthMode)
        [QPSSession]::ValidateComputerName($ComputerName, $AuthMode)
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = $ConfigurationName
        $this.UseSSL = $UseSSL
        $this.SkipCertCheck = $SkipCertCheck
        $this.Create()
    }

    QPSSession([string]$ComputerName,
        [string]$AuthMode,
        [string]$ConfigurationName,
        [bool]$UseSSL,
        [bool]$SkipCertCheck) {
        [QPSSession]::ValidateAuthMode($AuthMode)
        [QPSSession]::ValidateComputerName($ComputerName, $AuthMode)
        $this.ComputerName = $ComputerName
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = $ConfigurationName
        $this.UseSSL = $UseSSL
        $this.SkipCertCheck = $SkipCertCheck
        $this.Create()
    }

    ##########
    # МЕТОДЫ #
    ##########

    # Создание/обновление PSSession
    [void] Create() {
        [QPSSession]::ValidateCredential($this.AuthMode, $this.Credential)
        [QPSSession]::ValidateComputerName($this.ComputerName, $this.AuthMode)

        # Получение уже существующей PSSession, если она есть, для последующего закрытия
        [System.Management.Automation.Runspaces.PSSession]$PreviousPSSession = $this.PSSessionObject

        # Закрытие предыдущей PSSession, если она была
        if ($PreviousPSSession) {
            try {
                Remove-PSSession -Session $PreviousPSSession -ErrorAction Stop
            }
            catch {
                $Message = "Не удалось удалить существующую PSSession с ID $($PreviousPSSession.Id) для '$($PreviousPSSession.ComputerName)'. Создание новой сессии отменено: $($_.Exception.Message)"
                throw [System.InvalidOperationException]::new($Message, $_.Exception)
            }
            $this.PSSessionObject = $null
            $this.Id = $null
            $this.State = $null
            $this.RemotePSVersion = $null
        }

        # Создание новой PSSession
        try {
            [System.Management.Automation.Remoting.PSSessionOption]$SessionOption = New-PSSessionOption `
                -SkipCACheck:$($this.SkipCertCheck) `
                -SkipCNCheck:$($this.SkipCertCheck) `
                -SkipRevocationCheck:$($this.SkipCertCheck) `
                -ErrorAction Stop
            [hashtable]$NewPSSessionParameters = @{
                ComputerName      = $this.ComputerName
                Authentication    = $this.AuthMode
                UseSSL            = $this.UseSSL
                ConfigurationName = $this.ConfigurationName
                SessionOption     = $SessionOption
                ErrorAction       = "Stop"
            }
            if ($null -ne $this.Credential) {
                $NewPSSessionParameters.Credential = $this.Credential
            }
            [System.Management.Automation.Runspaces.PSSession]$NewPSSession = New-PSSession @NewPSSessionParameters
        }
        catch {
            $Message = "Не удалось создать PSSession для '$($this.ComputerName)': $($_.Exception.Message)"
            throw [System.InvalidOperationException]::new($Message, $_.Exception)
        }

        # Вычисление версии PowerShell на удаленной машине
        try {
            $RemotePSVersionRaw = $NewPSSession.ApplicationPrivateData["PSVersionTable"]?["PSVersion"]
            [version]$RemotePSVersionResult = if ($RemotePSVersionRaw) { [version]$RemotePSVersionRaw } else { $null }
        }
        catch {
            Write-Verbose -Message "Не удалось получить версию удалённого PowerShell в PSSession с ID $($NewPSSession.Id) для '$($NewPSSession.ComputerName)': $($_.Exception.Message)"
            $RemotePSVersionResult = $null
        }

        # Обновление свойств объекта
        $this.PSSessionObject = $NewPSSession
        $this.Id = $NewPSSession.Id
        $this.State = $NewPSSession.State
        $this.RemotePSVersion = $RemotePSVersionResult
    }

    # Подключается к интерактивной удалённой PSSession
    [void] Enter() {
        # Проверка существования PSSession в PSSessionObject
        if ($null -eq $this.PSSessionObject) {
            throw [System.InvalidOperationException]::new("Невозможно выполнить интерактивное подключение: PSSession не создана или уже удалена.")
        }

        try {
            Enter-PSSession -Session $this.PSSessionObject -ErrorAction Stop
        }
        catch {
            $this.CleanupAfterFailedOperation("интерактивное подключение", $_.Exception)
        }
    }

    # Импортирует указанные командлеты в текущий локальный сеанс
    [void] ImportCmdlets([string[]]$Cmdlets) {
        # Проверка существования PSSession в PSSessionObject
        if ($null -eq $this.PSSessionObject) {
            throw [System.InvalidOperationException]::new("Невозможно выполнить импорт командлетов: PSSession не создана или уже удалена.")
        }

        try {
            [psmoduleinfo[]]$ImportedModules = Import-PSSession -Session $this.PSSessionObject -CommandName $Cmdlets -ErrorAction Stop
            $ImportedModules | Import-Module -Global -ErrorAction Stop
        }
        catch {
            $this.CleanupAfterFailedOperation("импорт командлетов", $_.Exception)
        }
    }

    # Импортирует указанные модули в текущий локальный сеанс
    [void] ImportModules([string[]]$Modules) {
        # Проверка существования PSSession в PSSessionObject
        if ($null -eq $this.PSSessionObject) {
            throw [System.InvalidOperationException]::new("Невозможно выполнить импорт модулей: PSSession не создана или уже удалена.")
        }

        try {
            [psmoduleinfo[]]$ImportedModules = Import-PSSession -Session $this.PSSessionObject -Module $Modules -ErrorAction Stop
            $ImportedModules | Import-Module -Global -ErrorAction Stop
        }
        catch {
            $this.CleanupAfterFailedOperation("импорт модулей", $_.Exception)
        }
    }

    # Удаление PSSession после провала её использования
    [void] CleanupAfterFailedOperation([string]$Operation, [System.Exception]$OperationException) {
        try {
            $this.Remove()
        }
        catch {
            [System.Exception[]]$Exceptions = @($OperationException, $_.Exception)
            throw [System.AggregateException]::new(
                "Не удалось выполнить $Operation и удалить созданную PSSession.",
                $Exceptions
            )
        }

        throw [System.InvalidOperationException]::new(
            "Не удалось выполнить $Operation. Созданная PSSession удалена: $($OperationException.Message)",
            $OperationException
        )
    }

    # Отключает PSSession
    [void] Disconnect() {
        # Проверка существования PSSession в PSSessionObject
        if ($null -eq $this.PSSessionObject) {
            throw [System.InvalidOperationException]::new("Невозможно выполнить отключение: PSSession не создана или уже удалена.")
        }

        Disconnect-PSSession -Session $this.PSSessionObject -ErrorAction Stop

        $this.State = $this.PSSessionObject.State
    }

    # Подключает отключённую PSSession
    [void] Connect() {
        # Проверка существования PSSession в PSSessionObject
        if ($null -eq $this.PSSessionObject) {
            throw [System.InvalidOperationException]::new("Невозможно выполнить подключение: PSSession не создана или уже удалена.")
        }

        Connect-PSSession -Session $this.PSSessionObject -ErrorAction Stop

        $this.State = $this.PSSessionObject.State
    }

    # Закрывает PSSession
    [void] Remove() {
        # Проверка существования PSSession в PSSessionObject
        if ($null -eq $this.PSSessionObject) {
            throw [System.InvalidOperationException]::new("Невозможно выполнить удаление: PSSession не создана или уже удалена.")
        }

        Remove-PSSession -Session $this.PSSessionObject -ErrorAction Stop

        # Очистка атрибутов объекта, относящихся к PSSession
        $this.State = $null
        $this.PSSessionObject = $null
        $this.Id = $null
        $this.RemotePSVersion = $null
    }

    # Обновляет состояние PSSession
    [void] UpdateState() {
        # Проверка существования PSSession в PSSessionObject
        if ($null -eq $this.PSSessionObject) {
            throw [System.InvalidOperationException]::new("Невозможно обновить состояние: PSSession не создана или уже удалена.")
        }

        $this.State = $this.PSSessionObject.State
    }

    ######################
    # СТАТИЧЕСКИЕ МЕТОДЫ #
    ######################

    static [void] ValidateAuthMode([string]$AuthMode) {
        [string[]]$AllowedAuthModes = [System.Enum]::GetNames(
            [System.Management.Automation.Runspaces.AuthenticationMechanism]
        )
        if ($AuthMode -notin $AllowedAuthModes) {
            throw [System.ArgumentException]::new(
                "Недопустимое значение AuthMode '$AuthMode'. Допустимые значения: $($AllowedAuthModes -join ', ').",
                "AuthMode"
            )
        }
    }

    hidden static [void] ValidateCredential([string]$AuthMode, [pscredential]$Credential) {
        [QPSSession]::ValidateAuthMode($AuthMode)

        if ($AuthMode -ieq "NegotiateWithImplicitCredential" -and $null -ne $Credential) {
            throw [System.ArgumentException]::new(
                "Режим AuthMode 'NegotiateWithImplicitCredential' несовместим с заданными учётными данными. Удалите Credential из параметров или CredentialName из пресета.",
                "Credential"
            )
        }

        if ($AuthMode -in @("Basic", "Credssp", "Digest") -and $null -eq $Credential) {
            throw [System.ArgumentException]::new(
                "Режим AuthMode '$AuthMode' требует учётные данные PSCredential. Передайте их через Credential или задайте в пресете.",
                "Credential"
            )
        }
    }

    static [void] ValidateComputerName([string]$ComputerName, [string]$AuthMode) {
        if (
            [QCommonHostName]::ValidateShortHostName($ComputerName) -or
            [QCommonHostName]::ValidateFQDN($ComputerName)
        ) {
            return
        }

        if (
            $AuthMode -ine "Kerberos" -and
            (
                [QCommonHostName]::ValidateIPv4Address($ComputerName) -or
                [QCommonHostName]::ValidateIPv6Address($ComputerName)
            )
        ) {
            return
        }

        [string]$AcceptedFormats = if ($AuthMode -ieq "Kerberos") {
            "короткое имя компьютера или полное доменное имя при использовании Kerberos"
        }
        else {
            "короткое имя компьютера, полное доменное имя, IPv4- или IPv6-адрес"
        }

        throw [System.ArgumentException]::new(
            "Недопустимое значение ComputerName '$ComputerName': требуется $AcceptedFormats.",
            "ComputerName"
        )
    }
}
