# PowerShell-QPSSession

Модуль PowerShell для создания и управления удалёнными сеансами `PSSession`. Предоставляет класс `QPSSession` и функции-обёртки над `New-PSSession`, `Enter-PSSession` и `Import-PSSession`. Параметры подключения можно задавать напрямую или через пресеты.

## Требования

- PowerShell 7.6 или новее.
- При использовании Kerberos в `ComputerName` указывайте короткое имя компьютера или полное доменное имя (FQDN). Для остальных режимов аутентификации также поддерживаются IPv4- и IPv6-адреса.
- На удалённых компьютерах должен быть настроен WinRM.
- Для Kerberos должна быть настроена аутентификация между клиентом и целевым компьютером.
- На удалённом компьютере должна быть зарегистрирована используемая конечная точка:
  - `microsoft.powershell` — встроенная конечная точка Windows PowerShell 5.1.
  - `PowerShell.7` — конечная точка PowerShell 7; при необходимости её нужно зарегистрировать на удалённом компьютере.

## Установка

```powershell
Import-Module -Name ".\PowerShell-QPSSession.psd1"
```

## Пресеты

Параметры подключения разрешаются в следующем порядке:

1. Значение, явно переданное функции.
2. Значение из первого подходящего пресета в `$global:QPSSession_Preset`.
3. Значение по умолчанию: `AuthMode = "Kerberos"`, `ConfigurationName = "microsoft.powershell"`, `UseSSL = $false`, `SkipCertCheck = $false`.

Если учётные данные не заданы явно и не получены из пресета, модуль использует текущие учётные данные пользователя, если выбранный режим аутентификации это поддерживает. Модуль не запрашивает учётные данные интерактивно.

Пресеты необязательны. Чтобы использовать значения по умолчанию, не задавайте `$global:QPSSession_Preset`.

Если пресеты нужны, задайте `$global:QPSSession_Preset` как массив хеш-таблиц до вызова функций. Значение `CredentialName` — это имя переменной, содержащей объект `PSCredential`; указывайте имя без префикса области видимости:

```powershell
$admaccountkz = Get-Credential "DOMAIN\admin_kz"
$admaccountac = Get-Credential "DOMAIN\admin_ac"

$global:QPSSession_Preset = @(
    @{
        Description         = "Домен Казахстана"
        ComputerNamePattern = @("^kz", "\.kz$")
        CredentialName     = "admaccountkz"
        UseSSL              = "true"
    },
    @{
        Description         = "Остальные компьютеры"
        ComputerNamePattern = @(".*")
        CredentialName     = "admaccountac"
    }
)

Import-Module -Name ".\PowerShell-QPSSession.psd1"
```

### Ключи пресета

| Ключ | Тип | Обязательный | Описание |
|---|---|---|---|
| `Description` | `string` | Да | Произвольное описание пресета. |
| `ComputerNamePattern` | `string[]` | Да | Один или несколько регулярных выражений для имени компьютера. Сопоставление не учитывает регистр. |
| `CredentialName` | `string` | Нет | Имя переменной с объектом `PSCredential`; переменная ищется командой `Get-Variable`. |
| `AuthMode` | `string` | Нет | Режим аутентификации: `Default`, `Basic`, `Negotiate`, `NegotiateWithImplicitCredential`, `Credssp`, `Digest` или `Kerberos`. |
| `ConfigurationName` | `string` | Нет | Имя удалённой конфигурации (конечной точки). |
| `UseSSL` | `string` или `bool` | Нет | `true` или `false`. |
| `SkipCertCheck` | `string` или `bool` | Нет | `true` или `false`; пропускает проверки центра сертификации, имени и отзыва сертификата. |

Пресеты проверяются по порядку. Используется первый пресет, регулярное выражение которого совпало с именем компьютера. Размещайте более конкретные шаблоны перед общими.

Некорректные значения `AuthMode`, `UseSSL` или `SkipCertCheck` приводят к предупреждению; такое значение игнорируется. Значения по умолчанию для этих параметров: `Kerberos`, `$false` и `$false` соответственно. Для `Basic`, `Credssp` и `Digest` требуются учётные данные — из параметра `-Credential` или из пресета. `NegotiateWithImplicitCredential` несовместим с любыми учётными данными, переданными параметром или найденными в пресете.

## Функции

### `New-QPSSession`

Создаёт удалённый сеанс для каждого имени компьютера и возвращает список успешно созданных объектов `QPSSession`. Если подключение к отдельному компьютеру не удалось, функция выдаёт предупреждение и продолжает обработку остальных имён.

**Псевдоним:** `newpssession`

```powershell
# Создать сеанс с параметрами из подходящего пресета или со значениями по умолчанию
$sessions = New-QPSSession -ComputerName "dc01.kz"

# Создать сеансы для нескольких компьютеров
$sessions = New-QPSSession -ComputerName "srv01", "srv02", "srv03"

# Использовать конечную точку PowerShell 7
$sessions = New-QPSSession -ComputerName "srv01" -PS7

# Передать учётные данные и использовать SSL
$sessions = New-QPSSession -ComputerName "srv01" -Credential (Get-Credential) -UseSSL
```

| Параметр | Тип | Обязательный | Описание |
|---|---|---|---|
| `ComputerName` | `string[]` | Да | Имена компьютеров или FQDN для подключения. |
| `Credential` | `PSCredential` | Нет | Учётные данные для подключения. Имеют приоритет над значением из пресета. Если параметр не задан, используются данные из подходящего пресета или текущие учётные данные пользователя, когда это поддерживается выбранным режимом аутентификации. |
| `AuthMode` | `string` | Нет | Режим аутентификации. Имеет приоритет над значением из пресета; по умолчанию — `Kerberos`. |
| `PS7` | `switch` | Нет | Использовать конечную точку `PowerShell.7` вместо `microsoft.powershell`. Имеет приоритет над `ConfigurationName` из пресета. |
| `UseSSL` | `switch` | Нет | Использовать SSL. Имеет приоритет над значением из пресета. |
| `SkipCertCheck` | `switch` | Нет | Пропустить проверки сертификата. Имеет приоритет над значением из пресета. |

Возвращаемое значение — `System.Collections.Generic.List[QPSSession]`.

### `Enter-QPSSession`

Создаёт удалённый сеанс для указанного компьютера и переходит в интерактивный режим. Сеанс остаётся открытым после штатного выхода из интерактивного режима; закройте его методом `Remove()` или командой `Remove-PSSession`. Если вход завершается ошибкой, модуль удаляет созданный сеанс.

**Псевдоним:** `enter`

```powershell
# Открыть интерактивный сеанс
Enter-QPSSession -ComputerName "srv01"

# Вызвать функцию через псевдоним
enter "srv01"

# Использовать конечную точку PowerShell 7
Enter-QPSSession -ComputerName "dc01.kz" -PS7

# Передать учётные данные и использовать SSL
Enter-QPSSession -ComputerName "srv01" -Credential (Get-Credential) -UseSSL -SkipCertCheck
```

| Параметр | Тип | Обязательный | Описание |
|---|---|---|---|
| `ComputerName` | `string` | Да | Имя компьютера или FQDN. |
| `Credential` | `PSCredential` | Нет | Учётные данные для подключения; если параметр не задан, используются данные из подходящего пресета или текущие учётные данные пользователя, когда это допускает режим аутентификации. |
| `AuthMode` | `string` | Нет | Режим аутентификации; по умолчанию — `Kerberos`. |
| `PS7` | `switch` | Нет | Использовать конечную точку `PowerShell.7`. |
| `UseSSL` | `switch` | Нет | Использовать SSL. |
| `SkipCertCheck` | `switch` | Нет | Пропустить проверки сертификата. |

### `Import-QPSSession`

Создаёт удалённый сеанс и импортирует из него указанные команды или целые модули с помощью неявного удалённого взаимодействия. Импортированные команды запускаются на удалённом компьютере, но вызываются из локального сеанса.

После успешного импорта сеанс остаётся открытым и доступен через `Get-PSSession`. Закройте его вручную, когда он больше не нужен. Если импорт завершается ошибкой, модуль удаляет созданный сеанс.

**Псевдоним:** `import`

```powershell
# Импортировать отдельные команды с контроллера домена
Import-QPSSession -ComputerName "dc01.kz" -Cmdlets "Get-ADUser", "Get-ADGroup", "Set-ADUser"

# Импортировать модуль целиком
Import-QPSSession -ComputerName "dc01.kz" -Modules "ActiveDirectory"

# Вызвать функцию через псевдоним
import "dc01.kz" -Modules "ActiveDirectory"

# Использовать конечную точку PowerShell 7 и явные учётные данные
Import-QPSSession -ComputerName "srv01" -Modules "DhcpServer" -Credential (Get-Credential) -PS7
```

| Параметр | Тип | Обязательный | Описание |
|---|---|---|---|
| `ComputerName` | `string` | Да | Имя компьютера или FQDN. |
| `Credential` | `PSCredential` | Нет | Учётные данные для подключения; если параметр не задан, используются данные из подходящего пресета или текущие учётные данные пользователя, когда это допускает режим аутентификации. |
| `AuthMode` | `string` | Нет | Режим аутентификации; по умолчанию — `Kerberos`. |
| `PS7` | `switch` | Нет | Использовать конечную точку `PowerShell.7`. |
| `UseSSL` | `switch` | Нет | Использовать SSL. |
| `SkipCertCheck` | `switch` | Нет | Пропустить проверки сертификата. |
| `Cmdlets` | `string[]` | Да, набор `byCommand` | Имена команд для импорта. Нельзя указывать одновременно с `Modules`. |
| `Modules` | `string[]` | Да, набор `byModule` | Имена модулей для импорта целиком. Нельзя указывать одновременно с `Cmdlets`. |

## Класс `QPSSession`

`New-QPSSession` возвращает объекты `QPSSession`. Их также можно создавать напрямую. Конструкторы с именем компьютера автоматически вызывают `Create()`. Конструкторы без `Credential` используют текущие учётные данные, если это поддерживается выбранным режимом аутентификации.

### Свойства

| Свойство | Тип | Описание |
|---|---|---|
| `ComputerName` | `string` | Имя удалённого компьютера. |
| `Id` | `int` | Идентификатор удалённого сеанса, назначенный PowerShell. |
| `State` | `string` | Текущее состояние сеанса, например `Opened`, `Closed` или `Disconnected`. |
| `Credential` | `PSCredential` | Учётные данные сеанса; `$null`, если используются текущие учётные данные пользователя. |
| `AuthMode` | `string` | Режим аутентификации; по умолчанию — `Kerberos`. |
| `ConfigurationName` | `string` | Имя удалённой конечной точки; по умолчанию — `microsoft.powershell`. |
| `UseSSL` | `bool` | Используется ли SSL. |
| `SkipCertCheck` | `bool` | Пропускаются ли проверки сертификата. |
| `RemotePSVersion` | `version` | Версия PowerShell на удалённом компьютере. |
| `PSSessionObject` | `PSSession` | Объект удалённого сеанса PowerShell. |

### Методы

| Метод | Описание |
|---|---|
| `Create()` | Создаёт удалённый сеанс. |
| `Enter()` | Переходит в интерактивный удалённый сеанс. |
| `ImportCmdlets([string[]]$Cmdlets)` | Импортирует указанные команды в глобальную область видимости. |
| `ImportModules([string[]]$Modules)` | Импортирует указанные модули в глобальную область видимости. |
| `Disconnect()` | Отключает сеанс, сохраняя возможность повторного подключения. |
| `Connect()` | Повторно подключает отключённый сеанс. |
| `Remove()` | Закрывает удалённый сеанс и очищает связанные свойства объекта. |
| `UpdateState()` | Обновляет свойство `State` по состоянию объекта `PSSession`. |

Пример прямого использования:

```powershell
$s = [QPSSession]::new()
$s.ComputerName      = "srv01"
$s.AuthMode          = "Kerberos"
$s.ConfigurationName = "microsoft.powershell"
$s.UseSSL            = $true
$s.SkipCertCheck     = $false
$s.Create()

Invoke-Command -Session $s.PSSessionObject -ScriptBlock { hostname }

$s.Remove()
```

## Класс `QPSSessionPreset`

Класс используется для разбора и выбора пресетов. Обычно создавать его вручную не требуется. Класс доступен через ускоритель типа PowerShell вместе с `QPSSession`.

### Свойства

| Свойство | Тип | Описание |
|---|---|---|
| `Description` | `string` | Описание пресета. |
| `ComputerNamePattern` | `regex[]` | Регулярные выражения для сопоставления с именем компьютера. |
| `Credential` | `PSCredential` | Учётные данные, найденные по имени переменной из `CredentialName`. |
| `AuthMode` | `string` | Режим аутентификации. |
| `ConfigurationName` | `string` | Имя удалённой конечной точки. |
| `UseSSL` | `bool` | Использовать ли SSL. |
| `SkipCertCheck` | `bool` | Пропускать ли проверки сертификата. |

### Методы

| Метод | Описание |
|---|---|
| `IsMatch([string]$ComputerName)` | Возвращает `$true`, если имя компьютера совпадает хотя бы с одним шаблоном. |
| `static ParseHashtable([hashtable]$Hashtable)` | Создаёт объект пресета из хеш-таблицы. |
| `static GetPresetList()` | Разбирает `$global:QPSSession_Preset` и возвращает список пресетов. |
| `static FindPresetToUse([string]$ComputerName)` | Возвращает первый подходящий пресет или `$null`, если совпадений нет. |
