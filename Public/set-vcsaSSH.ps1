function Set-vcsaSSH {
    <#
    .SYNOPSIS
        Enable or disable SSH on a VCSA appliance.

    .DESCRIPTION
        Use CIS to enable or disable SSH access to a VCSA appliance.

    .PARAMETER vcsa
        The hostname or IP of the target VCSA.

    .PARAMETER Credential
        A credential object to log into VCSA CIS.

    .PARAMETER sshEnable
        True or false, enable or disable SSH access.

    .INPUTS
        System.String. Target VCSA.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-vcsaSSH -vcsa vcsa.lab.local -sshEnable $true -Credential $creds

        Enable SSH on vcsa.lab.local

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vcsa,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [bool]$sshEnable,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    begin {

        Write-Verbose ("Function start.")
    } # begin

    process {

        Write-Verbose ("Porcessing VCSA " + $vcsa)

        ## Get CIS service
        Write-Verbose ("Connecting to VCSA CIS.")

        try {
            Connect-CisServer -Server $vcsa -Credential $Credential -ErrorAction Stop | Out-Null
            Write-Verbose ("Connected to service.")
        } # try
        catch {
            Write-Debug ("Failed to connect to CIS.")
            throw ("Failed to get CIS service. " + $_.exception.message)
        } # catch


        ## Get CIS object for SSH
        Write-Verbose ("Getting SSH config via CIS.")

        try {
            $ssh = Get-CisService -Name com.vmware.appliance.access.ssh -ErrorAction Stop
            Write-Verbose ("Got SSH config.")
        } # try
        catch {
            Write-Debug ("Failed to get SSH config.")
            throw ("Failed to get CIS SSH object. " + $_.exception.message)
        } # catch


        ## Set SSH access
        Write-Verbose ("Configuring SSH access to enabled = " + $sshEnable)

        try {
            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($vcsa)) {
                $ssh.set($sshEnable) | Out-Null
                Write-Verbose ("SSH config set.")
            } # if

        } # try
        catch {
            Write-Debug ("Failed to set SSH.")
            throw ("Failed to set SSH. " + $_.exception.message)
        } # catch


    } # process

    end {

        Write-Verbose ("Function end.")
    } # end

} # function