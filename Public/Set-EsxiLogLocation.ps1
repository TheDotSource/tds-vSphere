function Set-EsxiLogLocation {
    <#
    .SYNOPSIS
        Set ESXi system log location.

    .DESCRIPTION
        Set ESXi system log location, matching datastore name based on a wildcard, for example, *scratch
        This allows hostnames to be piped in and a common wildcard to be used.
        For example, datastores esx01Scratch, esxi02Scratch, esxi03Scratch could all configured using *scratch as the wildcard.

    .PARAMETER vmHost
        The host to set the log location on.

    .PARAMETER datastoreName
        A specific datastore name to use for log location.

    .PARAMETER datastoreWildcard
        Match a datastore name by wildcard. Useful to configure a batch of hosts with similar datastore names.

    .INPUTS
        System.String. Target host name.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-EsxiLogLocation -vmHost testhost01.lab.local -dataStoreName SCRATCH

        Set the host log location to the SCRATCH datastore.

    .EXAMPLE
        @("testhost01.lab.local","testhost02.lab.local","testhost03.lab.local") | Set-EsxiLogLocation -dataStoreWildcard SCRATCH

        Set the datastore for logs on testhost01/02/03 to a datastore matching the name SCRATCH, e.g. testHost01Scratch, testHost02Scratch etc

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vmHost,
        [Parameter(ParameterSetName="specific")]
        [string]$datastoreName,
        [Parameter(ParameterSetName="wildcard")]
        [string]$datastoreWildcard
    )

    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Porcessing host " + $vmHost)

        ## Get VM host object
        Write-Verbose ("Getting host object.")

        try {
            $vmHostObj = Get-VMHost -Name $vmHost -ErrorAction Stop
            Write-Verbose ("Got host object.")
        } # try
        catch {
            Write-Debug ("Failed to get host object.")
            throw ("Failed to get host object. " + $_.exception.message)
        } # catch


        ## Get datastore object using specified method
        try {
            if ($datastoreName) {

                Write-Verbose ("Getting datastore with specific name: " + $datastoreName)
                $logDs = $vmHostObj | Get-Datastore -Name $datastoreName -ErrorAction Stop

            } # if
            else {

                Write-Verbose ("Matching datastore using wildcard: " + $datastoreWildcard)
                $logDs = $vmHostObj | Get-Datastore -ErrorAction Stop | Where-Object {$_.name -like ("*" + $datastoreWildcard + "*")}

            } # else

        } # try
        catch {
            Write-Debug ("Failed to get datastore.")
            throw ("Failed to get datastore. " + $_.exception.message)
        } # catch


        ## Verify 1 datastore returned
        if (!$logDs) {
            throw ("No matching datastores found.")
        } # if

        if ($logDs.count -gt 1) {
            throw ("More than one datastore matched the wildcard.")
        } # if


        Write-Verbose ("Got datastore " + $logDs.Name)


        ## Set advanced setting
        Write-Verbose ("Applying new log location")

        try {
            if ($PSCmdlet.ShouldProcess($vmHost)) {
                Get-AdvancedSetting -Entity $vmHostObj -Name "Syslog.global.logDir" -ErrorAction Stop | Set-AdvancedSetting -Value ("[" + $logDs.Name +"] /") -Confirm:$false -ErrorAction Stop | Out-Null
                Write-Verbose ("Log location set.")
            } # if
        } # try
        catch {
            Write-Debug ("Failed to set log location.")
            throw ("Failed to set log location. " + $_.exception.message)
        } # catch


        Write-Verbose ("Completed host " + $vmHost)

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function