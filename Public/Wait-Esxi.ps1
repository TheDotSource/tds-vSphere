function Wait-ESXi {
    <#
    .SYNOPSIS
       A simple function to wait for an ESXi host to boot.

    .DESCRIPTION
       A simple function to wait for an ESXi host to boot.
       Uses Connect-VIServer to wait for host connectivity.

    .PARAMETER esxiHost
        The hostname or IP address of the ESXi host to wait for.

    .PARAMETER timeout
        The timeout period in seconds, i.e. function will throw if the host does not start to respond within this time.

    .PARAMETER Credential
        The host root credential. This will be used to test connectivity.

    .INPUTS
        System.String. Hostname or IP.

    .OUTPUTS
        None.

    .EXAMPLE
        Wait-ESXi -esxiHost 10.10.1.10 -Credential $creds -timeout 120 -Verbose

        Wait for host 10.10.1.10 to become available with a 120 second timeout.

    .LINK

    .NOTES
        01       Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$esxiHost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [int]$timeout,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    begin {
        Write-Verbose ("Function start.")
    } # begin

    process {

        ## Get current time so we know when the timeout has been breached
        $startTime = Get-Date 

        ## Wait for a ping back from the specified host.
        Write-Verbose ("Waiting for " + $testHost + " to respond within the " + $timeout + " second timeout period.")

        do {
            Write-Verbose ("Waiting for host.....")

            $powercli = Connect-VIServer -Server $esxiHost -Credential $Credential -ErrorAction SilentlyContinue -verbose:$false

            if ((Get-Date).AddSeconds(-$timeout) -gt $startTime) {
                Write-Error ("Host did not respond within the specified timeout period.")
                Return
            }

        } until ($powercli)

        Write-Verbose ("Host is responding.")

        ## Disconnect host
        $powercli | Disconnect-VIServer -force -Confirm:$false -Verbose:$false

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function