function Set-esxiRoot {
#Requires -Modules @{"ModuleName" = "VMware.VimAutomation.Core"; "ModuleVersion" = "11.0.0.10336080"}
    <#
    .SYNOPSIS
        Set the root password on an ESXi instance.

    .DESCRIPTION
        Set the root password on an ESXi instance.
        Requires an existing connection to the target ESXi instance.

    .PARAMETER esxHost
        The ESXi host to set the password on.

    .PARAMETER Credential
        A credential object containing the new root password.

    .INPUTS
        System.String. ESXi host name.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-esxiRoot -esxHost 10.10.1.10 -Credential $newCreds

        Change the root password to the password contained in $newCreds

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
        [System.Management.Automation.PSCredential]$Credential
    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing host " + $esxHost)

        ## Get connection object for this host
        $hostCon = $defaultVIservers | Where-Object {$_.name -eq $esxHost}

        ## Check a connection was found
        if (!$hostCon) {
            throw ("No connection for host " + $esxHost + " was found. Connect to this host and try again.")
        } # if

        Write-Verbose ("Setting root password.")

        ## Prepare object for new root account
        $rootAccount = New-Object VMware.Vim.HostPosixAccountSpec
        $rootAccount.id = "root"
        $rootAccount.password = $Credential.GetNetworkCredential().password
        $rootAccount.shellAccess = "/bin/bash"


        ## Change host password
        if ($PSCmdlet.ShouldProcess($esxiHost)) {

            try {
                $serviceInstance = Get-View ServiceInstance -Verbose:$false
                $accountManager = Get-View -Id $serviceInstance.content.accountManager -Verbose:$false
                $accountManager.UpdateUser($rootAccount)
                Write-Verbose ("Root password changed.")
            } # try
            catch {
                Write-Debug ("Failed to set root password.")
                throw ("Failed to set root password. " + $_.exception.message)
            } # catch
            
        } # if

        Write-Verbose ("Completed host.")

    } # process

    end {

        Write-Verbose ("Function complete.")

    } # end

} # function