@{
    RootModule        = 'Root.psm1'
    ModuleVersion     = '0.2.1'
    GUID              = '45e0b374-7fc8-4a1d-80bc-0b28a21ba847'
    Author            = 'Юрий Кузьмин'
    Copyright         = '(c) Юрий Кузьмин. Все права защищены.'
    Description       = 'Обёртки над New-PSSession, Enter-PSSession и Import-PSSession с автоматическим выбором учётных данных, режима аутентификации и конечной точки по пресетам.'
    PowerShellVersion = '7.6'

    RequiredModules   = @('PowerShell-QCommon')

    FunctionsToExport = @(
        'Enter-QPSSession',
        'Import-QPSSession',
        'New-QPSSession'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @(
        'enter',
        'import',
        'newpssession'
    )

    PrivateData       = @{
        PSData = @{
            Tags       = @(
                'PowerShell',
                'PSRemoting',
                'PSSession',
                'WinRM'
            )
            ProjectUri = 'https://github.com/Kuzya87/PowerShell-QPSSession'
        }
    }
}
