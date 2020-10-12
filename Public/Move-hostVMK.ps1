function Move-hostVMK {
    <#
    .SYNOPSIS
        Move a VM kernel port to another switch.

    .DESCRIPTION

    .PARAMETER vmhost
        The esxi host to configure.

    .PARAMETER dvSwitch

    .PARAMETER portGroup

    .PARAMETER vmk

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
        [string]$portGroup,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmk
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


        ## Get port group
        Write-Verbose ("Getting port group object.")

        try {
            $portGroup = Get-VDPortgroup -name $portGroup -VDSwitch $vds -ErrorAction Stop
            Write-Verbose ("Got port group object.")
        } # try
        catch {
            Write-Debug ("Failed to get port group object.")
            throw ("Failed to get port group object. " + $_.exception.message)
        } # catch

    } # begin

    process {

        Write-Verbose ("Processing host " + $vmhost)

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


        ## Move VMK
        Write-Verbose ("Migrating VMK")

        try {
            Get-VMHostNetworkAdapter -Name $vmk -VMHost $vmhost -ErrorAction Stop | Set-VMHostNetworkAdapter -PortGroup $portGroup -confirm:$false -ErrorAction Stop
            Write-Verbose ("VMK has been moved.")
        } # try
        catch {
            Write-Debug ("Failed to move VMK")
            throw ("Failed to get reassign target VMK. " + $_.exception.message)
        } # catch


    } # process

    end {

        Write-Verbose ("Function end.")
    } # end

} # function