function New-localDataStore {
#Requires -Modules @{"ModuleName" = "VMware.VimAutomation.Core"; "ModuleVersion" = "11.0.0.10336080"}
    <#
    .SYNOPSIS
        Create a datastore on an ESXi host.

    .DESCRIPTION
        Create a datastore on an ESXi host.

    .PARAMETER esxHost
        The host on which to create the datastore.

    .PARAMETER targetLUN
        The LUN on which to create the datastore, for example vmhba1:C0:T1:L0

    .PARAMETER datastoreName
        The name of the datastore to create

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-localDataStore -esxHost 10.10.1.10 -targetLUN vmhba1:C0:T1:L0 -datastoreName "dataStore01"

        Create a datastore called "dataStore01" on LUN ID vmhba1:C0:T1:L0

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$esxHost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$targetLUN,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$datastoreName
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing host " + $esxHost)


        Write-Verbose ("Getting canonical name for LUN ID " + $targetLUN)


        ## Get Canonical Name for this resource
        try {
            $canonicalName = (Get-ScsiLun -VmHost $esxHost -Verbose:$false | Where-Object {$_.RuntimeName -eq $targetLUN}).CanonicalName
            Write-Verbose ("Canonical name for LUN is " + $canonicalName)
        } # try
        catch {
            Write-Debug ("Failed to get canonical name.")
            throw ("Failed to get canonical name for device. " + $_.exception.message)
        } # catch


        Write-Verbose ("Creating datastore " + $datastoreName)


        ## Create the datastore
        try {
            if ($PSCmdlet.ShouldProcess($datastoreName)) {
                New-Datastore -VMHost $esxHost -Path $canonicalName -Name $datastoreName -Vmfs -Verbose:$false -ErrorAction Stop | Out-Null
            } # if

            Write-Verbose ("Datastore created.")
        } # try
        catch {
            Write-Debug ("Failed to created datastore.")
            throw ("Failed to create datastore. " + $_.exception.message)
        } # catch


        Write-Verbose ("Completed host.")

    } # process

    end {

        Write-Verbose ("Function complete.")
    } # end

} # function