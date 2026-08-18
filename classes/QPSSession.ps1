class QPSSession {
    [string]$ComputerName
    [int]$Id
    [string]$State
    [pscredential]$Credential
    [string]$AuthMode
    [string]$ConfigurationName
    [bool]$UseSSL
    [bool]$SkipCertCheck
    [version]$RemotePSVersion
    [System.Management.Automation.Runspaces.PSSession]$PSSessionObject

    ################
    # CONSTRUCTORS #
    ################

    # Constructor for empty object
    QPSSession() {
        $this.AuthMode = "Kerberos"
        $this.ConfigurationName = "microsoft.powershell"
    }

    # Constructor with minimal parameters
    QPSSession([string]$ComputerName, [pscredential]$Credential) {
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = "Kerberos"
        $this.ConfigurationName = "microsoft.powershell"
        $this.Create()
    }

    # Constructor with auth mode
    QPSSession([string]$ComputerName, [pscredential]$Credential, [string]$AuthMode) {
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = "microsoft.powershell"
        $this.Create()
    }

    # Constructor with auth mode and SSL parameters
    QPSSession([string]$ComputerName,
        [pscredential]$Credential,
        [string]$AuthMode,
        [bool]$UseSSL,
        [bool]$SkipCertCheck) {
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = "microsoft.powershell"
        $this.UseSSL = $UseSSL
        $this.SkipCertCheck = $SkipCertCheck
        $this.Create()
    }

    # Constructor with additional parameters
    QPSSession([string]$ComputerName,
        [pscredential]$Credential,
        [string]$AuthMode,
        [string]$ConfigurationName,
        [bool]$UseSSL,
        [bool]$SkipCertCheck) {
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = $ConfigurationName
        $this.UseSSL = $UseSSL
        $this.SkipCertCheck = $SkipCertCheck
        $this.Create()
    }

    ###########
    # METHODS #
    ###########

    # Creates/recreates PSSession
    [void] Create() {
        [hashtable]$PSSessionOptionParams = @{
            SkipCACheck         = $this.SkipCertCheck
            SkipCNCheck         = $this.SkipCertCheck
            SkipRevocationCheck = $this.SkipCertCheck
        }
        [System.Management.Automation.Remoting.PSSessionOption]$SessionOption = New-PSSessionOption @PSSessionOptionParams
        [hashtable]$NewPSSessionParams = @{
            ComputerName      = $this.ComputerName
            Credential        = $this.Credential
            Authentication    = $this.AuthMode
            UseSSL            = $this.UseSSL
            ConfigurationName = $this.ConfigurationName
            SessionOption     = $SessionOption
        }
        $this.PSSessionObject = New-PSSession @NewPSSessionParams
        $this.Id = $this.PSSessionObject.Id
        $this.State = $this.PSSessionObject.State
        $PSVersion = $this.PSSessionObject.ApplicationPrivateData["PSVersionTable"]?["PSVersion"]
        $this.RemotePSVersion = if ($PSVersion) { [version]$PSVersion } else { $null }
    }

    # Connects to interactive remote PSSession
    [void] Enter() {
        Enter-PSSession -Session $this.PSSessionObject
    }

    # Imports list of cmdlets into current local session
    [void] ImportCmdlets([string[]]$Cmdlets) {
        [psmoduleinfo[]]$ImportedModules = Import-PSSession -Session $this.PSSessionObject -CommandName $Cmdlets
        $ImportedModules | Import-Module -Global
    }

    # Imports list of modules into current local session
    [void] ImportModules([string[]]$Modules) {
        [psmoduleinfo[]]$ImportedModules = Import-PSSession -Session $this.PSSessionObject -Module $Modules
        $ImportedModules | Import-Module -Global
    }

    # Disconnects opened PSSession
    [void] Disconnect() {
        Disconnect-PSSession -Session $this.PSSessionObject
        $this.State = $this.PSSessionObject.State
    }

    # Connects disconnected PSSession
    [void] Connect() {
        Connect-PSSession -Session $this.PSSessionObject
        $this.State = $this.PSSessionObject.State
    }

    # Closes PSSession
    [void] Remove() {
        Remove-PSSession -Session $this.PSSessionObject
        $this.State = $this.PSSessionObject.State
    }

    # Updates PSSession state
    [void] UpdateState() {
        $this.State = $this.PSSessionObject.State
    }
}
