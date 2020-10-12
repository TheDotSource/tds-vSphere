function New-vsanBootStrap {
#Requires -Modules @{"ModuleName" = "VMware.VimAutomation.Core"; "ModuleVersion" = "11.0.0.10336080"}
    <#
    .SYNOPSIS
        Initialise a new vSAN cluster on a single host.

    .DESCRIPTION
        Connect to a host and prepare vsan bootstrap.
        The function will initialise a vSAN cluster on a single host.
        It is assumed that the smallest available disk will be the cache disk, with an additional disk for capacity.
        Disks must be over 8GB in size.

    .PARAMETER esxHost
        The host on which to create the vSAN bootstrap.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-vsanBootStrap -esxHost 10.10.1.10 -Verbose

        Bootstrap vSAN on 10.10.1.10 using 1 cache disk and 1 capacity disk.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$esxHost
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {


        Write-Verbose ("Processing host " + $esxHost)

        Write-Verbose ("Connecting to host with ESXCLI")


        ## Get esxCli object for host
        try {
            $esxcli = Get-EsxCli -V2 -VMHost $esxHost -Verbose:$false -ErrorAction Stop
            Write-Verbose ("ESXCLI established.")
        } # try
        catch {
            Write-Debug ("Failed to establish ESXCLI connection.")
            throw ("Failed to create ESXCLI object. " + $_.exception.message)
        } # catch


        Write-Verbose ("Creating vSAN policy object.")


        ## Set vSAN policy string
        $vsanPolicy = '(("hostFailuresToTolerate" i1) ("forceProvisioning" i1))'

        ## Configure vSAN bootstrap
        try {
            $vsanPolicyDefaults = $esxcli.vsan.policy.setdefault.CreateArgs()
            $vsanPolicyDefaults.policy = $vsanPolicy
            $vsanPolicyDefaults.policyclass = "vdisk"
            $esxcli.vsan.policy.setdefault.Invoke($vsanPolicyDefaults) | Out-Null
            $vsanPolicyDefaults.policyclass = "vmnamespace"
            Write-Verbose ("Created vSAN policy object.")
        } # try
        catch {
            Write-Debug ("Failed to create vSAN policy object.")
            throw ("Failed to create policy object. " + $_.exception.message)
        } # catch


        try {
            $esxcli.vsan.policy.setdefault.Invoke($vsanPolicyDefaults) | Out-Null
            Write-Verbose ("Configured vSAN policy on host.")
        } # try
        catch {
            Write-Debug ("Failed to configure vSAN policy on host.")
            throw ("Failed to configure vSAN policy on host. " + $_.exception.message)
        } # catch


        Write-Verbose ("Creating new vSAN.")


        ## Create new vSAN
        try {
            $esxcli.vsan.cluster.new.Invoke() | Out-Null
            Write-Verbose ("Created new vSAN.")
        } # try
        catch {
            Write-Debug ("Failed to create vSAN.")
            throw ("Failed to create vSAN cluster. " + $_.exception.message)
        } # catch


        Write-Verbose ("Fetching vSAN eligible disks.")


        ## Get vSAN cache and capacity disks
        try {
            $vsanDisks = $esxcli.storage.core.device.list.invoke() | Where-Object {$_.isremovable -eq "false" -and [int]$_.size -gt 8192} | Sort-Object -Property Size -Descending
            Write-Verbose ("Got vSAN disks.")
        } # try
        catch {
            Write-Debug ("Failed to get vSAN disks.")
            throw ("Failed to get vSAN disks. " + $_.exception.message)
        } # catch


        ## Appky should process
        if ($PSCmdlet.ShouldProcess($esxHost)) {


            Write-Verbose ("Tagging capacity disk.")


            ## Tag capacity disk
            try {
                $capacityTag = $esxcli.vsan.storage.tag.add.CreateArgs()
                $capacityTag.disk = $vsanDisks[0].Device
                $capacityTag.tag = "capacityFlash"
                $esxcli.vsan.storage.tag.add.Invoke($capacityTag) | Out-Null
                Write-Verbose ("Tagged capacity disk.")
            } # try
            catch {
                Write-Debug ("Failed to tag capacity disk.")
                throw ("Failed to tag vSAN capacity disk. " + $_.exception.message)
            } # catch


            Write-Verbose ("Adding cache disk and creating vSAN datastore.")


            ## Create datastore
            try {
                $addVsanStorage = $esxcli.vsan.storage.add.CreateArgs()
                $addVsanStorage.ssd = $vsanDisks[1].Device
                $addVsanStorage.disks = $vsanDisks[0].Device
                Write-Verbose ("Capacity disk of capacity " + $vsanDisks[0].size + " added.")
                Write-Verbose ("Cache disk of capacity " + $vsanDisks[1].size + " added.")
                Write-Verbose ("Configured datastore object.")
            } #try
            catch {
                Write-Debug ("Failed to configure datastore object.")
                throw ("Failed to configure datastore object")
            } # catch


            Write-Verbose ("Applying configuration.")


            try {
                $esxcli.vsan.storage.add.Invoke($addvsanstorage) | Out-Null
                Write-Verbose ("vSAN datastore created.")
            } # try
            catch {
                Write-Debug ("Failed to create vSAN datastore.")
                throw ("Failed to create vSAN datastore. " + $_.exception.message)
            } # catch

        } # if

        Write-Verbose ("Completed host.")

    } # process

    end {

        Write-Verbose ("Function complete.")
    } # end

} # function