function Set-vsanLabHealthChecks {
    <#
    .SYNOPSIS
        Enable or disable a set of vsan health checks that are not relevant to a lab envionment.

    .DESCRIPTION
        Enable or disable a set of vsan health checks that are not relevant to a lab envionment.
        The following vsan health checks will be disabled as they typically create noise in lab and nested environments:
            * hcldbuptodate
            * controlleronhcl
            * controllerfirmware
            * releasecataloguptodate
            * vumconfig

    .PARAMETER cluster
        The cluster to configure vsan health checks on.

    .PARAMETER labHealthCheckState
        Action to take on the specified health checks, enabled or disabled.

    .INPUTS
        System.String. Target cluster name.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-vsanLabHealthChecks -cluster cluster01.lab.local -labHealthCheckState disabled

        Disable vSan health checks not relevant to a lab envionment.

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
        [string]$labHealthCheckState
    )

    begin {

        Write-Verbose ("Function start.")

        ## Define health checks to disable
        $vsanChecks = @(
            "hcldbuptodate",
            "controlleronhcl",
            "controllerfirmware",
            "releasecataloguptodate",
            "vumconfig",
            "vsanenablesupportinsight",
            "smalldiskstest",
            "diskusage"
        )

    } # begin

    process {

        Write-Verbose ("Processing cluster " + $cluster)

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
            $vsanHealthSystem = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system" -ErrorAction Stop
            Write-Verbose ("Got vSan view object.")
        } # try
        catch {
            Write-Debug ("Failed to get vSan view object.")
            throw ("Failed to get vSAN view object. " + $_.exception.message)
        } # catch

        
        ## Get supported healthchecks for this version of vSan
        $supportedChecks = ($vsanHealthSystem.VsanQueryAllSupportedHealthChecks()).testId


        ## Initialise array to store target checks
        $targetChecks = @()


        ## Filter off only supported checks. The API will not allow configuration of invlaid test names
        foreach ($vsanCheck in $vsanChecks) {

            if ($supportedChecks -contains $vsanCheck) {

                Write-Verbose ($vsanCheck + " is supported on this version of vSan.")
                $targetChecks += $vsanCheck
            } # if
            else {
                Write-Verbose ($vsanCheck + " is not supported on this version of vSan.")
            } # else

        } # foreach


        ## Disable specified checks
        switch ($labHealthCheckState) {

                "enabled" {

                    Write-Verbose ("Enabling specified vsan health checks.")

                    if ($PSCmdlet.ShouldProcess($cluster)) {

                        if ($vsanHealthSystem.VsanHealthSetVsanClusterSilentChecks($clusterObj.ExtensionData.moref,$null,$targetChecks)) {

                            ## Command out was true
                            Write-Verbose ("Specified checks were enabled.")

                        } # if

                        else {

                            ## Command output was false, something went wrong
                            throw ("Attempt to enable the specified checks failed.")

                        } # else

                    } # if

                } # enabled

                "disabled" {

                    Write-Verbose ("Disabling specified vsan health checks.")

                    if ($PSCmdlet.ShouldProcess($cluster)) {

                        if ($vsanHealthSystem.VsanHealthSetVsanClusterSilentChecks($clusterObj.ExtensionData.moref,$targetChecks,$null)) {

                            ## Command out was true
                            Write-Verbose ("Specified checks were disbaled.")

                        } # if
                        else {

                            ## Command output was false, something went wrong
                            throw ("Attempt to disable the specified checks failed.")

                        } # else

                    } # if

                } # disabled

        } # switch

        Write-Verbose ("Completed cluster.")

    } # process


    end {

        Write-Verbose ("Function end.")
    } # end

} # function