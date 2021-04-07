function Invoke-localToDSCopy {
    <#
    .SYNOPSIS
        Copy a local file to a target datastore and folder.

    .DESCRIPTION
        Copy a local file to a target datastore and folder.
        Map a PS drive and copy the local file to the desried folder on the datastore.

    .PARAMETER localFile
        Full path to the local file to copy.

    .PARAMETER datastore
        Name of the target datastore. Must be accessible on the current connection.

    .PARAMETER targetFolder
        The name of the folder on the datastore to copy the file to, e.g. "ISOS"

    .INPUTS
        None.

    .OUTPUTS
        None.

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
        Write-Verbose ("Fetching datastore object.")

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


        ## Check that destination folder exists
        if(!(Test-Path -Path "remoteDs:/$($targetFolder)")){
            New-Item -ItemType Directory -Path "remoteDs:/$($targetFolder)" | Out-Null
        } # if

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