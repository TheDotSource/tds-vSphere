function New-simpleVsanDiskGroup {
    <#
    .SYNOPSIS
        Create a vsan disk group on a host, using the smallest volume as a cache device, and the remaining as capacity.

    .DESCRIPTION
        Create a vsan disk group on a host, using the smallest volume as a cache device, and the remaining as capacity.

    .PARAMETER vmHost
        The host to create the disk group on.

    .INPUTS
        VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl. Target host name.

    .OUTPUTS
        None.

    .EXAMPLE
        New-simpleVsanDiskGroup -vmHost $vmHost -Verbose

        Create a vsan disk group on esx01, using the smallest vsan eligible disk as cache and all others as capacity.

    .LINK

    .NOTES
        01       11/05/20     Initial version.                            A McNair
        02       21/03/22     Added some additional verbose output.       A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost
    )


    begin {
        Write-Verbose ("Function start.")
    } # begin


    process {

        Write-Verbose ("Processing host " + $vmHost.name)

        ## Create array for capacity disks
        $capacityDisk = @()


        ## Get all vSAN eligible disks on this host
        Write-Verbose ("Fetching elegible disks on this host.")

        try {
            $vsanDisks = $vmHost | Get-VMHostHba -ErrorAction Stop | Get-ScsiLun -ErrorAction Stop | Where-Object {$_.VsanStatus -eq "Eligible"}
            Write-Verbose ("Got disks.")
        } # try
        catch {
            throw ("Failed to get vSan disks. " + $_.exception.message)
        } # catch


        ## Determine which disk is cache tier
        $cacheDisk = ($vsanDisks | Sort-Object -Property CapacityGB | Select-Object -First 1).CanonicalName
        Write-Verbose ("Target cache disk is " + $cacheDisk)

        ## Add remaining disks to capacity disk array
        $capacityDisk += ($vsanDisks | Where-Object {$_.CanonicalName -ne $cacheDisk}).CanonicalName
        Write-Verbose ("Target capacity disks are " + ($capacityDisk -join ","))


        ## Create the vSAN disk group
        Write-Verbose ("Creating vSan disk group.")

        try {
            if ($PSCmdlet.ShouldProcess($vmHost)) {
                New-VsanDiskGroup -VMHost $vmHost -SsdCanonicalName $cacheDisk -DataDiskCanonicalName $capacityDisk -ErrorAction Stop | Out-Null
                Write-Verbose ("Disk group created.")
            } # if

        } # try
        catch {
            throw ("Failed to create vSan disk group. " + $_.exception.message)
        } # catch


        Write-Verbose ("Completed host.")

    } # process

    end {

            Write-Verbose ("Function complete.")
    } # end

} # function