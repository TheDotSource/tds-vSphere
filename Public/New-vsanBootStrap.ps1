function New-vsanBootStrap {
    <#
    .SYNOPSIS
        Initialise a new vSAN cluster on a single host with a specified cache and capacity disk.

    .DESCRIPTION
        Connect to a host and prepare vsan bootstrap.
        The function will initialise a vSAN cluster on a single host.
        The function will filter cache and capacity disks based on thier specified size.

    .PARAMETER esxHost
        The host on which to create the vSAN bootstrap.

    .PARAMETER cacheDiskSize
        The cache disk size to use in GB.

    .PARAMETER capacityDiskSize
        The capacity disk size to use in GB.

    .INPUTS
        System.String. ESXi hostname or IP.

    .OUTPUTS
        None.

    .EXAMPLE
        New-vsanBootStrap -esxHost 10.10.1.10 -cacheDiskSize 30 -capacityDiskSize 180 -Verbose

        Bootstrap vSAN on 10.10.1.10 using a 30GB cache disk and a 180GB capacity disk.

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
        [int]$cacheDiskSize,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [int]$capacityDiskSize
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
            $vsanDisks = $esxcli.storage.core.device.list.invoke() | Where-Object {$_.isremovable -eq "false"}
            Write-Verbose ("Got vSAN disks.")
        } # try
        catch {
            Write-Debug ("Failed to get vSAN disks.")
            throw ("Failed to get vSAN disks. " + $_.exception.message)
        } # catch

        ## Select cache and caapcity based on specified sizes
        Write-Verbose ("Selecting cache disk.")

        $vsanCache = $vsanDisks | Where-Object {([int]$_.size / 1024) -eq $cacheDiskSize }

        if (!$vsanCache) {
            Write-Debug ("Failed to find cache disk.")
            throw ("Failed to find vSan cache disk of specified size (" + $cacheDiskSize + ")")
        } # if

        Write-Verbose ("Using device " + $vsanCache.device + " for vSan cache.")


        Write-Verbose ("Selecting capacity disk.")
        $vsanCapacity = $vsanDisks | Where-Object {([int]$_.size / 1024) -eq $capacityDiskSize}

        if (!$vsanCapacity) {
            Write-Debug ("Failed to find capacity disk.")
            throw ("Failed to find vSan capacity disk of specified size (" + $cacheDiskSize + ")")
        } # if

        Write-Verbose ("Using device " + $vsanCapacity.device + " for vSan capacity.")


        ## Apply should process
        if ($PSCmdlet.ShouldProcess($esxHost)) {

            Write-Verbose ("Tagging capacity disk.")

            ## Tag capacity disk
            try {
                $capacityTag = $esxcli.vsan.storage.tag.add.CreateArgs()
                $capacityTag.disk = $vsanCapacity.Device
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
                $addVsanStorage.ssd = $vsanCache.Device
                $addVsanStorage.disks = $vsanCapacity.Device
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