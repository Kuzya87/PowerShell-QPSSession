############################
# ИМПОРТ КЛАССОВ И ФУНКЦИЙ #
############################

# Импорт классов для внутреннего использования
[string]$private:PrivateClassesPath = Join-Path -Path $PSScriptRoot -ChildPath "Private" -AdditionalChildPath "Classes"
if (-not (Test-Path -LiteralPath $private:PrivateClassesPath -PathType Container)) {
    throw [System.IO.DirectoryNotFoundException]::new("Указанный путь к каталогу классов '$($private:PrivateClassesPath)' не существует или не является каталогом.")
}
[System.IO.FileInfo[]]$private:PrivateClassesFiles = Get-ChildItem `
    -LiteralPath $private:PrivateClassesPath `
    -Filter "*.ps1" `
    -File `
    -ErrorAction Stop |
Sort-Object -Property Name
foreach ($PrivateClassFile in $private:PrivateClassesFiles) {
    $private:PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Stop"
        . $PrivateClassFile.FullName
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Не удалось загрузить файл класса '$($PrivateClassFile.FullName)': $($_.Exception.Message)",
            $_.Exception
        )
    }
    finally {
        $ErrorActionPreference = $private:PreviousErrorActionPreference
    }
}

# Импорт публичных классов
[string]$private:PublicClassesPath = Join-Path -Path $PSScriptRoot -ChildPath "Classes"
if (-not (Test-Path -LiteralPath $private:PublicClassesPath -PathType Container)) {
    throw [System.IO.DirectoryNotFoundException]::new("Каталог классов '$($private:PublicClassesPath)' не существует или не является каталогом.")
}
[System.IO.FileInfo[]]$private:PublicClassesFiles = Get-ChildItem `
    -LiteralPath $private:PublicClassesPath `
    -Filter "*.ps1" `
    -File `
    -ErrorAction Stop |
Sort-Object -Property Name
$private:ExportableTypeNames = [System.Collections.Generic.List[string]]::new()
foreach ($PublicClassFile in $private:PublicClassesFiles) {
    try {
        $private:Tokens = $null
        $private:ParseErrors = $null

        $private:Ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $PublicClassFile.FullName,
            [ref]$private:Tokens,
            [ref]$private:ParseErrors
        )

        if ($private:ParseErrors.Count -gt 0) {
            throw [System.Management.Automation.ParseException]::new(
                ($private:ParseErrors | ForEach-Object -MemberName "Message") -join [System.Environment]::NewLine
            )
        }

        $private:TypeDefinitions = $private:Ast.FindAll(
            { param($Node) $Node -is [System.Management.Automation.Language.TypeDefinitionAst] },
            $false
        )

        foreach ($TypeDefinition in $TypeDefinitions) {
            $private:ExportableTypeNames.Add($TypeDefinition.Name)
        }

        $private:PreviousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Stop"
            . $PublicClassFile.FullName
        }
        finally {
            $ErrorActionPreference = $private:PreviousErrorActionPreference
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Не удалось загрузить файл класса '$($PublicClassFile.FullName)': $($_.Exception.Message)",
            $_.Exception
        )
    }
}

# Импорт функций для внутреннего использования, не экспортируемых из модуля
[string]$private:PrivateFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath "Private" -AdditionalChildPath "Functions"
if (-not (Test-Path -LiteralPath $private:PrivateFunctionsPath -PathType Container)) {
    throw [System.IO.DirectoryNotFoundException]::new("Каталог функций '$($private:PrivateFunctionsPath)' не существует или не является каталогом.")
}
[System.IO.FileInfo[]]$private:PrivateFunctionsFiles = Get-ChildItem `
    -LiteralPath $private:PrivateFunctionsPath `
    -Filter "*.ps1" `
    -File `
    -ErrorAction Stop |
Sort-Object -Property Name
foreach ($PrivateFunctionFile in $private:PrivateFunctionsFiles) {
    try {
        $PreviousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Stop"
            . $PrivateFunctionFile.FullName
        }
        finally {
            $ErrorActionPreference = $PreviousErrorActionPreference
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Не удалось загрузить файл функции '$($PrivateFunctionFile.FullName)': $($_.Exception.Message)",
            $_.Exception
        )
    }
}

# Импорт публичных функций, экспортируемых из модуля
[string]$private:PublicFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath "Functions"
if (-not (Test-Path -LiteralPath $private:PublicFunctionsPath -PathType Container)) {
    throw [System.IO.DirectoryNotFoundException]::new("Каталог функций '$($private:PublicFunctionsPath)' не существует или не является каталогом.")
}
[System.IO.FileInfo[]]$private:PublicFunctionsFiles = Get-ChildItem `
    -LiteralPath $private:PublicFunctionsPath `
    -Filter "*.ps1" `
    -File `
    -ErrorAction Stop |
Sort-Object -Property Name
foreach ($PublicFunctionFile in $private:PublicFunctionsFiles) {
    try {
        $PreviousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Stop"
            . $PublicFunctionFile.FullName
        }
        finally {
            $ErrorActionPreference = $PreviousErrorActionPreference
        }
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Не удалось загрузить файл функции '$($PublicFunctionFile.FullName)': $($_.Exception.Message)",
            $_.Exception
        )
    }
}

####################
# СОЗДАНИЕ АЛИАСОВ #
####################

New-Alias -Name "newpssession" -Value "New-QPSSession" -Force
New-Alias -Name "enter" -Value "Enter-QPSSession" -Force
New-Alias -Name "import" -Value "Import-QPSSession" -Force

#################################
# РЕГИСТРАЦИЯ TYPE ACCELERATORS #
#################################

# О type accelerators и их экспорте:
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes?view=powershell-7.4#export-classes-with-type-accelerators

# Определить типы, экспортируемые через type accelerators.
[type[]]$ExportableTypes = foreach ($TypeName in $private:ExportableTypeNames) {
    [type]$TypeName
}

# Получить внутренний класс TypeAccelerators для вызова статических методов.
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)

# Проверить, что ни один тип не заменит существующий type accelerators.
# Если type accelerators с таким именем уже зарегистрирован, прервать загрузку.
$private:ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
foreach ($Type in $ExportableTypes) {
    if ($Type.FullName -in $private:ExistingTypeAccelerators.Keys) {
        $private:Message = @(
            "Не удалось зарегистрировать type accelerators '$($Type.FullName)'"
            'Type accelerators с таким именем уже существует.'
        ) -join ' - '

        throw [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($private:Message),
            'TypeAcceleratorAlreadyExists',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $Type.FullName
        )
    }
}

# Зарегистрировать type accelerators для всех экспортируемых типов.
foreach ($Type in $ExportableTypes) {
    $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}

# Удалить type accelerators при выгрузке модуля.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Type in $ExportableTypes) {
        [void]$TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()
