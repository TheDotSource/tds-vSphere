function Set-vsanPerfService {
    <#
    .SYNOPSIS
        Enable or disable the vSan performance service on a cluster.

    .DESCRIPTION
        Enable or disable the vSan performance service on a cluster.

    .PARAMETER cluster
        The target cluster.

    .PARAMETER perfServiceState
        Enable or disable the performance service.

    .INPUTS
        System.String. Target cluster name.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-vsanPerfService -cluster labvsan -perfServiceState enabled

        Enable the performance service on vsan cluster labvsan.

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$cluster,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("enabled","disabled")]
        [string]$perfServiceState
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing target cluster " + $cluster)


        ## Get target cluster object
        Write-Verbose ("Getting target cluster object.")

        try {
            $clusterObj = Get-Cluster -Name $cluster -ErrorAction Stop
            Write-Verbose ("Got target cluster.")
        } # try
        catch {
            Write-Debug ("Failed to get cluster object.")
            throw ("Failed to get target cluster. " + $_.exception.message)
        } # catch


        ## Get vSAN view object
        Write-Verbose ("Getting vSan view object.")

        try {
            $vsanPerfMan = Get-VSANView -Id "VsanPerformanceManager-vsan-performance-manager" -ErrorAction Stop
            Write-Verbose ("Got vSan view object.")
        } # try
        catch {
            Write-Debug ("Failed to get vSan view object.")
            throw ("Failed to get vSAN view object. " + $_.exception.message)
        } # catch


        ## Enable the performance service
        switch ($perfServiceState) {

            "enabled" {

                Write-Verbose ("Enabling vSan performance service.")

                try {

                    if ($PSCmdlet.ShouldProcess($cluster)) {
                        $vsanPerfMan.VsanPerfCreateStatsObjectTask($clusterObj.ExtensionData.moRef,$null) | Out-Null
                        Write-Verbose ("Service was enabled.")
                    } # if

                } # try
                catch {
                    Write-Debug ("Failed to enable performance service.")
                    throw ("Failed to enable performance service. " +$_.exception.message)
                } # catch

            } # enabled

            "disabled" {

                Write-Verbose ("Disabling vSan performance service.")

                try {

                    if ($PSCmdlet.ShouldProcess($cluster)) {
                        $vsanPerfMan.VsanPerfDeleteStatsObject($clusterObj.ExtensionData.moRef) | Out-Null
                        Write-Verbose ("Service was disabled.")
                    } # if

                } # try
                catch {
                    Write-Debug ("Failed to disabled performance service.")
                    throw ("Failed to disable performance service. " +$_.exception.message)
                } # catch

            } # disabled

        } # switch

        Write-Verbose ("Completed cluster.")

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function