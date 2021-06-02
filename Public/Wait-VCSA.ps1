function Wait-VCSA {
    <#
    .SYNOPSIS
       Wait for VCSA services to become ready after a restart or deployment.

    .DESCRIPTION
       Wait for VCSA services to become ready after a restart or deployment.
       Wait for the CIS health to turn green.
       Wait for PowerCLI connectivity.

       In the event of a VCSA 7.x, some special sauce applied to wait for cluster enablement.

    .PARAMETER vcsa
        The hostname or IP of the target VCSA.

    .PARAMETER Credential
        A credential object to log into VCSA CIS.

    .PARAMETER timeOut
        Timeout in seconds.

    .INPUTS
        System.String. Target VCSA VM.

    .OUTPUTS
        None.

    .EXAMPLE
        Wait-VCSA -vcsa vcsa.lab.local -Credential $creds -timeOut 600

        Restart vcsa.pod.local using $creds.

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vcsa,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [int]$timeOut
    )

    begin {
        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing VCSA " + $vcsa)

        $startTime = Get-Date

        ## Poll CIS
        Write-Verbose ("Waiting for appliance CIS connectivty.")

        while(!(Connect-CisServer -Server $vcsa -Credential $Credential -ErrorAction SilentlyContinue)){
            Start-Sleep 10
            Write-Verbose ("Waiting for appliance CIS connectivty.")

            ## Check if timeout has been exceeded
            if ($startTime -lt (Get-Date).AddSeconds(-$timeout)) {
                throw ("Failed to get a response from " + $vcsa + " within the specified timeout period - (" + $timeout + ") seconds.")
            } # if

        } # while


        ## Wait for appliance health object
        while(!(Get-CisService -Name com.vmware.appliance.health.system -ErrorAction SilentlyContinue)){
            Write-Verbose ("Waiting for health system to become available.")
            Start-Sleep 10

            ## Check if timeout has been exceeded
            if ($startTime -lt (Get-Date).AddSeconds(-$timeout)) {
                throw ("Failed to get a response from " + $vcsa + " within the specified timeout period - (" + $timeout + ") seconds.")
            } # if

        } # while


        ## Get CIS object for system health
        Write-Verbose ("Getting system health object via CIS.")

        try {
            $health = Get-CisService -Name com.vmware.appliance.health.system -ErrorAction Stop
            Write-Verbose ("Got system health object.")
        } # try
        catch {
            Write-Debug ("Failed to get system health object.")
            throw ("Failed to get CIS health object. " + $_.exception.message)
        } # catch


        ## Wait for health to go green
        Write-Verbose ("Waiting for system health GREEN status.")

        while($health.get() -ne "green"){
            Start-Sleep 10
            Write-Verbose ("Appliance health status is " + $health.get())

            ## Check if timeout has been exceeded
            if ($startTime -lt (Get-Date).AddSeconds(-$timeout)) {
                throw ("Failed to get a response from " + $vcsa + " within the specified timeout period - (" + $timeout + ") seconds.")
            } # if

        } # while

        Write-Verbose ("Appliance health status is " + $health.get())


        ## Wait for PowerCLI connectivity
        Write-Verbose ("Waiting for PowerCLI connectivity.")

        while(!(Connect-VIServer -Server $vcsa -Credential $Credential -ErrorAction SilentlyContinue)){
            Start-Sleep 10
            Write-Verbose ("Waiting for PowerCLI connectivity.")

            ## Check if timeout has been exceeded
            if ($startTime -lt (Get-Date).AddSeconds(-$timeout)) {
                throw ("Failed to get a response from " + $vcsa + " within the specified timeout period - (" + $timeout + ") seconds.")
            } # if

        } # while

        Write-Verbose ("PowerCLI connectivity available.")

        ## Disconnect this session
        Disconnect-VIServer -Server $vcsa -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null


        ## Get VCSA version
        Write-Verbose ("Querying VCSA version.")

        try {
            $vcsaVerObj = Get-CisService -Name com.vmware.appliance.system.version -ErrorAction Stop
            $vcsaVer = $vcsaVerObj.Get().version

            Write-Verbose ("VCSA version is " + $vcsaVer)
        } # try
        catch {
            Write-Debug ("Failed to get system version object.")
            throw ("Failed to get system version object. " + $_.exception.message)
        } # catch


        ## If appliance version is 7.x test Cluster Enablement availability. This seems to have odd effects if it's not ready.
        if ($vcsaVer -like "7*") {

            Write-Verbose ("Appliance is version 7, waiting for Cluster Enablement.")

            while(!(Get-CisService -Name com.vmware.esx.settings.clusters.enablement.software -ErrorAction SilentlyContinue)) {
                Write-Verbose ("Waiting for Cluster Enablement....")
                Start-Sleep 10

                ## For some reason we need to connect each time
                Connect-CisServer -Server $vcsa -Credential $Credential | Out-Null

                ## Check if timeout has been exceeded
                if ($startTime -lt (Get-Date).AddSeconds(-$timeout)) {
                    throw ("Failed to get a response from " + $vcsa + " within the specified timeout period - (" + $timeout + ") seconds.")
                } # if

            } # while

            Write-Verbose ("Cluster Enablement is available.")
        } # if

        Write-Verbose ("Appliance restart complete.")

    } # process

    end {
        Write-Verbose ("Function complete.")

    }  #end

} # function