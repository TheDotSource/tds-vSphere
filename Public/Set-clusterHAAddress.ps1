function Set-clusterHAAddress {
    <#
    .SYNOPSIS
        Configure the HA address for a cluster.

    .DESCRIPTION
        Configure the HA address for a cluster.
        HA will be disabled and re-enabled as a result of running this function.

    .PARAMETER clusterName
        The cluster to set the HA address on.

    .PARAMETER haAddress
        The HA address to configure.

    .INPUTS
        System.String. Target cluster name.

    .OUTPUTS
        None.

    .EXAMPLE
        set-clusterHAAddress -clusterName testcluster -haAddress 10.10.1.100

        Set the HA address on cluster testcluster to 10.10.1.100

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$clusterName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$haAddress
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing cluster " + $clusterName)

        ## Get target cluster object
        Write-Verbose ("Getting target cluster object.")

        try {
            $clusterObj = Get-Cluster -Name $clusterName -ErrorAction Stop
            Write-Verbose ("Got target cluster.")
        } # try
        catch {
            Write-Debug ("Failed to get cluster object.")
            throw ("Failed to get target cluster. " + $_.exception.message)
        } # catch


        ## Apply shouldProcess
        if ($PSCmdlet.ShouldProcess($clusterName)) {

            ## Set advanced setting
            Write-Verbose ("Configuring HA address to " + $haAddress)

            try {
                New-AdvancedSetting -Entity $clusterObj -Name "das.isolationaddress0" -Type ClusterHA -Value $haAddress -Confirm:$false -Force -ErrorAction Stop | Out-Null
                Write-Verbose ("HA address has been configured.")
            } # try
            catch {
                Write-Debug ("Failed to set HA address.")
                throw ("Failed to set cluster HA address. " + $_.exception.message)
            } # catch

        } # if

        Write-Verbose ("Completed cluster.")

    } # process


    end {
        Write-Verbose ("Function complete.")

    } # end

} # function