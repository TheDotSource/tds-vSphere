function Invoke-localToDSCopy {
    <#
    .SYNOPSIS
        Copy a local file to a target datastore and folder.

    .DESCRIPTION
        Copy a local file to a target datastore and folder.
        Map a PS drive and copy the local file to the desried folder on the datastore.

        A complication arrises copying files to a vSan datastore. The UI folder names are not available when using PS Drive.
        Instead we need to do some conversion to the vSan backend GUID for the folder.
        This uses Get-vSanFolderNames function.

    .PARAMETER localFile
        Full path to the local file to copy.

    .PARAMETER datastore
        Name of the target datastore. Must be accessible on the current connection.

    .PARAMETER targetFolder
        The name of the folder on the datastore to copy the file to, e.g. "ISOS"

    .INPUTS
        System.String. The path to the source file.

    .OUTPUTS
        System.String. The full datastore path of the target file.

    .EXAMPLE
        Invoke-localToDSCopy -localFile C:\DML\sample.iso -datastore DATASTORE01 -targetFolder ISOs

        Copy sample.iso to the ISOs directory on DATASTORE01

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$localFile,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$datastore,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$targetFolder
    )

    begin {

        Write-Verbose ("Function start.")

        ## Fetch datastore object to be used as target
        Write-Verbose ("Fetching datastore object for " + $datastore)

        try {
            $targetDs = Get-Datastore -Name $datastore -ErrorAction Stop
            Write-Verbose ("Got datastore.")
        } # try
        catch {
            throw ("Failed to get datastore object for " + $datastore + ". " + $_.exception.message)
        } # catch


        ## Create PS drive to datastore
        Write-Verbose ("Creating PS drive to datastore.")

        try {
            New-PSDrive -Location $targetDs -Name remoteDs -PSProvider VimDatastore -Root "\" -ErrorAction Stop | Out-Null
            Write-Verbose ("Created PS drive.")
        } # try
        catch {
            throw ("Failed to create PS drive for " + $datastore + ". " + $_.exception.message)
        } # catch


        ## Check if this is a vSAN datastore. If so, we need to resolve the top level folder to its guid path.
        if ($targetDs.type -eq "vsan") {
            Write-Verbose ("Datastore is of type vSAN. Converting folder name to vSAN GUID.")

            ## This is a little bit messy. New-Item does create the desired folder, but throws as it's not able to verify creation due to vSAN guids
            ## We will fire this CMDlet and silently continue.
            New-Item -ItemType Directory -Path "remoteDs:/$($targetFolder)" -ErrorAction SilentlyContinue | Out-Null

            try {
                $guid = Get-vSanFolderNames -datastore $targetDs -ErrorAction Stop | Where-Object {$_.name -eq $targetFolder}

                ## Check we got a single result back, if not then the folder does not exist on this vSAN datastore.
                ## Likely something went wrong with New-Item.
                if (!$guid) {
                    throw ("Failed to get GUID for " + $targetFolder)
                } # if

                ## Spit out GUID portion of returned path
                $targetFolder = $guid.path.split("] ")[1]

                Write-Verbose ("GUID for folder is " + $targetFolder)
            } # try
            catch {
                throw ("Could not resolve GUID for folder name " + $targetFolder + ". " + $_.exception.message)
            } # catch

        } # if
        else {
            ## Life is easier on a standard datastore.
            if(!(Test-Path -Path "remoteDs:/$($targetFolder)")){
                New-Item -ItemType Directory -Path "remoteDs:/$($targetFolder)" | Out-Null
            } # if
        } # else

    } # begin


    process {

        Write-Verbose ("Processing local file " + $localFile)

        ## Test if local file exists
        if (!(Test-Path -Path $localFile)) {
            throw ("File " + $localFile + " does not exist.")
        } # if

        ## Perform file copy
        Write-Verbose ("Copying file to target datastore.")

        try {
            $prObj = Copy-DatastoreItem -Item $localFile -Destination "remoteDs:/$($targetFolder)" -PassThru -ErrorAction Stop
            Write-Verbose ("File has been copied.")
        } # try
        catch {
            throw ("Failed to copy file. " + $_.exception.message)
        } # catch

        ## Return the full datastore path to the copied item
        return $prObj.DatastoreFullPath

    } # process

    end {

        ## Remove PS drive
        Write-Verbose ("Removing PS drive.")

        try {
            Remove-PSDrive -Name remoteDs -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Verbose ("PS drive removed.")
        } # try
        catch {
            throw ("Failed to remove PS drive for " + $datastore + ". " + $_.exception.message)
        } # catch

    } # end

} # function