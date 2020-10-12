function Rename-vsanDatastore {
    <#
    .SYNOPSIS
        Rename the vSan datastore on a cluster.

    .DESCRIPTION
        Rename the vSan datastore on a cluster.

    .PARAMETER clusterName
        The target vSan cluster.

    .PARAMETER datastoreName
        The new vsan datastore name to configure.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Rename-vsanDatastore -Cluster testcluster.lab.local -datastoreName testVsan

        Rename the vsan datastore on testcluster to testVsan.

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$clusterName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$datastoreName
    )


    begin {

        Write-Verbose ("Function start.")
    } # begin

    process {


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


        ## Get vSan datastore from this cluster
        if ($clusterObj.VsanEnabled) {

            Write-Verbose ("Getting vsan datastore object from cluster.")

            try {
                $vsanDatastore = $clusterObj | Get-Datastore -ErrorAction Stop | Where-Object {$_.type -eq "vsan"}
                Write-Verbose ("Got vsan object.")
            } # try
            catch {
                Write-Debug ("Failed to get vsan datastore.")
                throw ("Failed to get vSAN datastore " + $_.exception.message)
            } # catch

        } # if
        else {

            ## This cluster is not a vSan cluster
            throw ("This cluster is not a vSan cluster.")
        } # else


        ## Rename the datastore
        Write-Verbose ("Renaming datastore " + $vsanDatastore.name + " to " + $datastoreName)

        try {
            $vsanDatastore | Set-Datastore -Name $datastoreName -ErrorAction Stop
            Write-Verbose ("Rename complete.")
        } # try
        catch {
            Write-Debug ("Failed to rename datastore.")
            throw ("Failed to rename datastore " + $_.Exception.Message)
        } # catch


    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function