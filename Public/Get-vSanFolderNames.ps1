function Get-vSanFolderNames {
    <#
    .SYNOPSIS
        vSAN folder names display as GUIDs. this script translates them to human readable format.

    .DESCRIPTION
        vSAN folder names display as GUIDs. this script translates them to human readable format.

        Adaptation of the William Lam function:

        https://code.vmware.com/samples/4622/list-folders-on-a-vsan-datastore-using-powercli

    .PARAMETER datastore
        The vSAN datastore to query.

    .INPUTS
        System.String. The name of the vSAN datastore.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. Collection of folder names and paths.

    .EXAMPLE
        Get-vSanFolderNames -datastore vsanDatastore

        Get all top level folders and their associated vSAN guid based paths from "vsanDatastore".

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$datastore
    )

    begin {

        Write-Verbose ("Function start.")

    } # begin


    process {

        Write-Verbose ("Processing vSAN datastore " + $datastore)

        ## Fetch datastore object to be used as target
        Write-Verbose ("Fetching datastore object for " + $datastore)

        try {
            $targetDs = Get-Datastore -Name $datastore -ErrorAction Stop
            Write-Verbose ("Got datastore.")
        } # try
        catch {
            throw ("Failed to get datastore object for " + $datastore + ". " + $_.exception.message)
        } # catch

        ## Check that supplied datastore is vSAN, if not, return
        if ($targetDs.type -ne "vsan") {
            Write-Warning ("Supplied datastore is not of type vSAN.")
            return
        } # if

        ## Get datastore browser object
        Write-Verbose ("Using Get-View to get datastore browser object.")
        try {
            $dsBrowser = Get-View -id $targetDs.ExtensionData.Browser -ErrorAction Stop
            Write-Verbose ("Got datastore browser.")
        } # try
        catch {
            throw ("Failed to get datastore browser for " + $datastore + ". " + $_.exception.message)
        } # catch


        ## Build query spec
        Write-Verbose ("Building query spec.")

        $spec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
        $folderFileQuery= New-Object Vmware.Vim.FolderFileQuery
        $spec.Query = $folderFileQuery
        $fileQueryFlags = New-Object VMware.Vim.FileQueryFlags
        $fileQueryFlags.fileOwner = $false
        $fileQueryFlags.fileSize = $false
        $fileQueryFlags.fileType = $true
        $fileQueryFlags.modification = $false
        $spec.details = $fileQueryFlags
        $spec.sortFoldersFirst = $true

        ## Execute query
        Write-Verbose ("Executing query.")
        try {
            $results = $dsBrowser.SearchDatastore("[" + $targetDs.Name + "]",  $spec)
            Write-Verbose ("Query completed.")
        } # try
        catch {
            throw ("Query failed for datastore " + $datastore + ". " + $_.exception.message)
        } # catch


        ## Filter off folders
        $folders = @()
        $files = $results.file

        foreach ($file in $files) {

            if ($file.getType().Name -eq "FolderFileInfo") {
                $folderPath = $results.FolderPath + " " + $file.Path

                $folders += [pscustomobject] @{
                    Datastore = $datastore
                    Name = $file.FriendlyName
                    Path = $folderPath
                } # object

            } # if

        } # foreach

        ## Return results
        return $folders

        Write-Verbose ("Completed.")

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function