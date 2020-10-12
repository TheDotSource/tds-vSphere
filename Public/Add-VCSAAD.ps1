function Add-VCSAAD {
    <#
    .SYNOPSIS
       Add a VCSA appliance to an Active Directory.

    .DESCRIPTION
       Add a VCSA appliance to an Active Directory.
       There is no native API to do this, so this is accomplished via a VM tools shell script.
       There must be a connection to the vCenter that hosts the VCSA VM object.

    .PARAMETER vmName
        The VM name of the VCSA appliance.

    .PARAMETER adFQDN
        FQDN of the domain to join the VCSA to.

    .PARAMETER ADCredential
        PowerShell credential object with privleges to join systems to Active Directory.

    .PARAMETER VCSAOSCredential
        VCSA shell credential to run domain join script.

    .INPUTS
        System.String. Target VCSA VM.

    .OUTPUTS
        None.

    .EXAMPLE
        Add-VCSAAD -vmName LABVCSA -adFQDN lab.local -ADCredential $creds1 -VCSAOSCredential $creds2

        Add appliance LABVCSA to domain lab.local
        
    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vmName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$adFQDN,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$ADCredential,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$VCSAOSCredential
    )

    begin {

        Write-Verbose ("Function start.")
    } # begin

    process {

        Write-Verbose ("Processing appliance " + $vmName)

        ## Get VM object
        Write-Verbose ("Getting VM object for target appliance.")

        try {
            $vm = Get-VM -Name $vmname -ErrorAction Stop
            Write-Verbose ("Got VM object.")
        } # try
        catch {
            Write-Debug ("Failed to get VM object.")
            throw ("Failed to get target VM. " + $_.exception.message)
        } # catch

        ## set shell script for domain join
        $shellScript = ("/opt/likewise/bin/domainjoin-cli join " + $adFQDN + " " + $ADCredential.UserName + " " + $ADCredential.GetNetworkCredential().Password)

        ## Execute shell script via VM tools
        Write-Verbose ("Executing shell script via VM tools.")

        try {
            $result = Invoke-VMScript -VM $vm -ScriptText $shellScript -GuestCredential $VCSAOSCredential -ScriptType bash -ErrorAction Stop
            Write-Verbose ("Shell script execution complete.")
        } # try
        catch {
            Write-Debug ("Execution of shell script failed.")
            throw ("Failed to execute appliance shell script. " + $_.exception.message)
        } # catch

        ## Check result string contains "SUCCESS"
        if ($result.ScriptOutput -notlike "*SUCCESS*") {
            Write-Debug ("Script output indicates failure.")
            throw ("Shell script return did not indicate success. The script output was " + $result.ScriptOutput)
        } # if

        Write-Verbose ("Script output was " + $result.ScriptOutput)
        Write-Verbose ("Script output indicates success.")

    } # process

    end {

        Write-Verbose ("Function end.")
    } # end

} # function