function Add-HostVMNICToVDS {
    <#
    .SYNOPSIS
        Bind a physical vmnic on a host to a DVS uplink.

    .DESCRIPTION
        Bind a physical vmnic on a host to a DVS uplink.

    .PARAMETER vmhost
        The esxi host to configure.

    .PARAMETER dvSwitch
        The DVS to bind the vmnic to.

    .PARAMETER vmnic
        The vmnic on the host to bind to the DVS.

    .INPUTS
        System.String. Target esxi host.

    .OUTPUTS
        None.

    .EXAMPLE


    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vmhost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$dvSwitch,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmnic
    )


    begin {

        Write-Verbose ("Function start.")

        ## Get VDS object
        Write-Verbose ("Getting DVS object from vCenter.")

        try {
            $vds = Get-VDSwitch -Name $dvSwitch -ErrorAction Stop
            Write-Verbose ("Got DVS object.")
        } # try
        catch {
            Write-Debug ("Failed to get DVS object.")
            throw ("Failed to get DVS object. " + $_.exception.message)
        } # catch

    } # begin


    process {

        ## Get VM host object
        Write-Verbose ("Getting VM host object.")

        try {
            $vmHost = Get-VMHost -Name $vmhost -ErrorAction Stop
            Write-Verbose ("Got VM host object.")
        } # try
        catch {
            Write-Debug ("Failed to get host object.")
            throw ("Failed to get host object. " + $_.exception.message)
        } # catch


        ## Get vmnic object
        Write-Verbose ("Getting vmnic object for target physical host.")

        try {
            $vmnicObj = Get-VMHostNetworkAdapter -VMHost $vmHost -Physical -Name $vmnic -ErrorAction Stop
            Write-Verbose ("Got vmnic object.")
        } # try
        catch {
            Write-Debug ("Failed to get vmnic.")
            throw ("Failed to get target VMNIC. " + $_.exception.message)
        } # catch


        ## Assign uplink to VDS on this host
        Write-Verbose ("Assigning vmnic to DVS.")


        try {
            Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vmnicObj -DistributedSwitch $vds -Confirm:$false | Out-Null
            Write-Verbose ("Assigned vmnic.")
        } # try
        catch {
            Write-Debug ("Failed to assign uplink.")
            throw ("Failed to assign VMNIC. " + $_.exception.message)
        } # catch


    } # process


    end {

        Write-Verbose ("Function end.")
    } # end

} # function