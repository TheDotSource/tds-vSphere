function Rename-wildcardDatastore {
    <#
    .SYNOPSIS
        Rename a datastore matching a wildcard and prefix it with hostname.

    .DESCRIPTION
        Rename a datastore matching a wildcard and prefix it with hostname.
        Developed as a way to rename duplicated datastore names that get appended with numbers to make them unique.
        For example, SCRATCH(1), SCRATCH(2) would become esxi01Scratch, esxi02Scratch etc.

    .PARAMETER vmHost
        The target host.

    .PARAMETER wildcard
        The wildcard to match the intended datastore.

    .INPUTS
        VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl. VMhost object.

    .OUTPUTS
        None.

    .EXAMPLE
        Rename-wildcardDatastore -vmHost testhost.lab.local -wildcard SCRATCH

        Rename the "SCRATCH (1)" datastore on testhost.lab.local to testhostScratch

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$wildcard
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing host " + $vmHost)

        ## Get datastore from host.
        Write-Verbose ("Fetching datastore from host matching *" + $wildcard + "*")

        try {
            $datastoreObj = $vmHost  | Get-Datastore -ErrorAction Stop | Where-Object {$_.name -like ("*" + $wildcard + "*")} | Select-Object -First 1
        } # try
        catch {
            throw ("Failed to get host datastore. " + $_.exception.message)
        } # catch


        ## Check we have a datastore matched.
        if (!$datastoreObj) {
            throw ("No datastore was found matching " + $wildcard)
        } # if

        Write-Verbose ("Datastore " + $datastoreObj.name + " was found.")

        ## Rename this datastore, capatise the first letter of the wildcard for sweet sweet camelCase
        Write-Verbose ("Renaming datastore to " + ($vmHost.name.split(".")[0] + $wildcard.substring(0,1).toupper() + $wildcard.substring(1).tolower()))
        try {
            $datastoreObj | Set-Datastore -Name ($vmHost.name.split(".")[0] + $wildcard.substring(0,1).toupper() + $wildcard.substring(1).tolower()) -ErrorAction Stop | Out-Null
            Write-Verbose ("Rename complete.")
        } # try
        catch {
            throw ("Failed to rename datastore " + $_.exception.message)
        } # catch

        Write-Verbose ("Host complete.")

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function