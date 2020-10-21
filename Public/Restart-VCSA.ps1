function Restart-VCSA {
    <#
    .SYNOPSIS
       Initiaite a restart of a VCSA.

    .DESCRIPTION
       Initiaite a restart of a VCSA.
       Function will wait until restart has begun before returning.
       Restart is initiated via CIS.

    .PARAMETER vcsa
        The hostname or IP of the target VCSA.

    .PARAMETER Credential
        A credential object to log into VCSA CIS.

    .INPUTS
        System.String. Target VCSA VM.

    .OUTPUTS
        System.String. Target VCSA VM.

    .EXAMPLE
        Restart-VCSA -vcsa vcsa.lab.local -Credential $creds

        Restart vcsa.pod.local using $creds

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vcsa,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    begin {
        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing VCSA " + $vcsa)

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


        ## Get CIS object for appliance shutdown
        Write-Verbose ("Getting restart object via CIS.")

        try {
            $shutdown = Get-CisService -Name com.vmware.appliance.shutdown -ErrorAction Stop
            Write-Verbose ("Got restart object.")
        } # try
        catch {
            Write-Debug ("Failed to get restart object.")
            throw ("Failed to get CIS restart object. " + $_.exception.message)
        } # catch


        ## Reboot VCSA
        Write-Verbose ("Initiating appliance restart.")

        try {
            $shutdown.reboot(0,'Rebooted by script Restart-VCSA') | Out-Null
            Write-Verbose ("Restart initiated.")
        } # try
        catch {
            Write-Debug ("Failed to initiate restart.")
            throw ("Failed to initiate restart. " + $_.exception.message) 
        } # catch


        ## Wait for reboot to start
        Write-Verbose ("Waiting for restart to begin.")

        while (Test-Connection -ComputerName $vcsa -Quiet -Count 2 -ErrorAction SilentlyContinue) {
            Start-Sleep 5
        } # while

        Write-Verbose ("VCSA has restarted.")
      
    } # process

    end {
        Write-Verbose ("Function complete.")
        
    }  #end

} # function