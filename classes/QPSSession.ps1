class QPSSession {
    [string]$ComputerName
    [int]$Id
    [string]$State
    [pscredential]$Credential
    [string]$AuthMode
    [string]$ConfigurationName
    [bool]$SSL
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

    # Constructor with additional parameters
    QPSSession([string]$ComputerName, [pscredential]$Credential, [string]$AuthMode, [string]$ConfigurationName, [bool]$SSL) {
        $this.ComputerName = $ComputerName
        $this.Credential = $Credential
        $this.AuthMode = $AuthMode
        $this.ConfigurationName = $ConfigurationName
        $this.SSL = $SSL
        $this.Create()
    }

    ###########
    # METHODS #
    ###########

    # Method for create/recreate PSSession
    [void] Create() {
        $NewPSSessionParams = @{
            ComputerName      = $this.ComputerName
            Credential        = $this.Credential
            Authentication    = $this.AuthMode
            ConfigurationName = $this.ConfigurationName
            UseSSL            = $this.SSL
            SessionOption     = New-PSSessionOption -SkipCACheck:$this.SkipCertCheck -SkipCNCheck:$this.SkipCertCheck -SkipRevocationCheck:$this.SkipCertCheck
        }
        $this.PSSessionObject = New-PSSession @NewPSSessionParams
        $this.Id = $this.PSSessionObject.Id
        $this.State = $this.PSSessionObject.State
        $PSVersion = $this.PSSessionObject.ApplicationPrivateData["PSVersionTable"]?["PSVersion"]
        $this.RemotePSVersion = if ($PSVersion) { [version]$PSVersion } else { $null }
        # $this.RemotePSVersion = $this.PSSessionObject.ApplicationPrivateData["PSVersionTable"].PSVersion.ToString()
    }

    # Method for connect to interactive remote PSSession
    [void] Enter() {
        Enter-PSSession -Session $this.PSSessionObject
    }

    # Method for import list of cmdlets into current local session
    [void] ImportCmdlets([string[]]$Cmdlets) {
        $ImportedModules = Import-PSSession -Session $this.PSSessionObject -CommandName $Cmdlets
        $ImportedModules | Import-Module -Global
    }

    # Method for import list of modules into current local session
    [void] ImportModules([string[]]$Modules) {
        $ImportedModules = Import-PSSession -Session $this.PSSessionObject -Module $Modules
        $ImportedModules | Import-Module -Global
    }

    # Method for disconnect opened PSSession
    [void] Disconnect() {
        Disconnect-PSSession -Session $this.PSSessionObject
        $this.State = $this.PSSessionObject.State
    }

    # Method for connect disconnected PSSession
    [void] Connect() {
        Connect-PSSession -Session $this.PSSessionObject
        $this.State = $this.PSSessionObject.State
    }

    # Method for close PSSession
    [void] Remove() {
        Remove-PSSession -Session $this.PSSessionObject
        $this.State = $this.PSSessionObject.State
    }

    # Method for update PSSession state
    [void] UpdateState() {
        $this.State = $this.PSSessionObject.State
    }
}
