function New-VMTools {
    <#
    .SYNOPSIS
        Perform a new install of VMware Tools on a Windows system.

    .DESCRIPTION
        Perform a new install of VMware Tools on a Windows system.

        Use PS Remoting to perform remote install.

        Tools must be mounted prior to running this function.

    .PARAMETER Computername
        The Windows system on which to install tools.

    .PARAMETER Credential
        An administrative Windows credential to install tools with.

    .INPUTS
        System.String. The name or IP of the remote Windows system.

    .OUTPUTS
        None.

    .EXAMPLE
        New-VMTools -Computername 10.10.1.100 -Credential $winCreds

        Install tools on 10.10.1.100 via PS Remoting.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$Computername,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
      )

    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing remote system " + $Computername)

        ## Create script block to detect tools drive letter
        $toolsPathBlock = {

            $possibleDrives = @("D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z")

            foreach ($possibleDrive in $possibleDrives) {

                if (Test-Path -Path ($possibleDrive + ":\VMwareToolsUpgrader.exe")) {

                    ## Return out of this so we don't query all possible drives
                    return $possibleDrive
                } # if

            } # foreach

        } # scriptblock


        ## Execute script block to get tools drive letter
        Write-Verbose ("Finding tools drive letter on remote system.")

        try {
            $driveLetter = Invoke-Command -ComputerName $Computername -Credential $Credential -ScriptBlock $toolsPathBlock

            if (!$driveLetter) {
                throw ("Failed to located VMware Tools mounted on the remote system. Verify the tools ISO has been mounted.")
            } # if

            Write-Verbose ("Located tools at drive letter " + $driveLetter)
        } # try
        catch {
            throw ("Failed to execute script block. " + $_.exception.message)
        } # catch


        ## Create command script block for remote installation
        $toolsInstall = {
            param($driveLetter)

            $cmdString = ("cmd /c " + $driveLetter + ":\setup64.exe /S /v '/qn REBOOT=R'")
            Invoke-Expression -Command $cmdString -ErrorAction Stop
        } # scriptBlock


        ## Execute command in remote session
        Write-Verbose ("Beginning remote installation of tools.")

        ## Support should process
        if ($PSCmdlet.ShouldProcess($Computername)) {
            try {
                Invoke-Command -ComputerName $Computername -ScriptBlock $toolsInstall -ArgumentList $driveLetter -Credential $Credential -ErrorAction Stop
                Write-Verbose ("Installation complete.")
            } # try
            catch {
                throw ("Failed to install tools. " + $_.exception.message)
            } # catch
        } # if


        ## Restart target system
        Write-Verbose ("Restarting system.")

        try {
            Restart-Computer -ComputerName $Computername -Credential $Credential -Force -Wait -For Wmi
            Write-Verbose ("Restart complete.")
        } # try
        catch {
            throw ("Failed to restart target system. " + $_.exception.message)
        } # catch


        Write-Verbose ("Completed.")

    } # process

    end {
        Write-Verbose ("Function end.")
    } # end

} # function