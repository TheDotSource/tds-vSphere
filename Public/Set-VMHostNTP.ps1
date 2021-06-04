function Set-VMHostNTP {
    <#
    .SYNOPSIS
        Set the NTP configuration on an ESXi host.

    .DESCRIPTION
        Set the NTP configuration on an ESXi host.

        The function will perform the following NTP configuration:
            * Append to or replace existing NTP server list.
            * Set a firewall exception for the NTP service.
            * Set the service startup policy as specified.
            * Start or stop the service as specified (restart if already running).

    .PARAMETER vmHost
        The target host object to configure.

    .PARAMETER ntpServers
        One or more NTP time source to configure.

    .PARAMETER action
        Specifies if the existing NTP servers are to be replaced, or appended to.

    .PARAMETER servicePolicy
        Optional. Set the startup type of the NTP service, default is "On".

    .PARAMETER serviceState
        Optional. Set the running state of the NTP time service, default is "Started".

   .INPUTS
        VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl. ESXi host object.

    .OUTPUTS
        VMware.VimAutomation.ViCore.Impl.V1.Host.HostServiceImpl. VMHost service object for NTP.

    .EXAMPLE
        Set-vmHostNTP -vmHost $vmHost -ntpServers 10.10.2.10,10.10.1.200 -action Replace -servicePolicy On -serviceState Started

        Replace existing NTP servers with those specified, set the service policy to On and start the service.

    .EXAMPLE
        Set-vmHostNTP -vmHost $vmHost -ntpServers 10.10.2.10,10.10.1.200 -action Append -servicePolicy On -serviceState Started

        Append existing NTP servers with those specified, set the service policy to On and start the service.

    .EXAMPLE
        Get-VMHost | Set-vmHostNTP -ntpServers 10.10.1.20 -action Replace -servicePolicy On -serviceState Started

        Configure NTP for all hosts on the current connection.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string[]]$ntpServers,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("Append","Replace")]
        [string]$action,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [ValidateSet("On","Automatic","Off")]
        [string]$servicePolicy = "On",
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [ValidateSet("Stopped","Started")]
        [string]$serviceState = "Started"
    )


    begin {
        Write-Verbose ("Function start.")
    } # begin

    process {
        Write-Verbose ("Processing host " + $vmHost)

        ## Get existing list of NTP servers from this host.
        Write-Verbose ("Getting existing NTP servers.")

        try {
            $existingNtp = Get-VMHostNtpServer -VMHost $vmHost -ErrorAction Stop
            Write-Verbose ("Got config.")
        } # try
        catch {
            throw ("Failed to get host NTP servers. " + $_.exception.message)
        } # catch


        ## In the case of append, we need to add the new servers to the existing ensuring no duplicates.
        if (($existingNtp) -and ($action -eq "Append")) {
            Write-Verbose ("Append has been specified, new NTP servers will be added to existing.")

            $ntpServers = @($existingNtp) + @($ntpServers) | Select-Object -Unique

            Write-Verbose ("The new NTP server list will be "+ ($ntpServers -join ","))
        } # if

        ## Clear host NTP list before applying new one, if it has any
        if ($existingNtp) {
            Write-Verbose ("Clearing host NTP server list.")

            try {
                Remove-vmHostNtpServer -VMHost $vmHost -NtpServer $existingNtp -Confirm:$false -ErrorAction Stop
                Write-Verbose ("Cleared config.")
            } # try
            catch {
                throw ("Failed to clear host NTP servers. " + $_.exception.message)
            } # catch

        } # if

        ## Apply new list of NTP sources
        Write-Verbose ("Applying new NTP time sources to host.")

        try {
            Add-VMHostNtpServer -VMHost $vmHost -NtpServer $ntpServers -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Verbose ("Applied NTP config.")
        } # try
        catch {
            throw ("Failed to apply host NTP servers. " + $_.exception.message)
        } # catch

        ## Ensure firewall exception is configured
        Write-Verbose ("Configuring host firewall for NTP.")

        try {
            Get-VMHostFirewallException -VMHost $vmHost -ErrorAction Stop | Where-Object {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true -ErrorAction Stop | Out-Null
            Write-Verbose ("Configured firewall.")
        } # try
        catch {
            throw ("Failed to set host firewall. " + $_.exception.message)
        } # catch

        ## Get the current state of the NTP service
        Write-Verbose ("Fetching NTP service state.")

        try {
            $ntpService = Get-VmHostService -VMHost $vmHost -ErrorAction Stop | Where-Object {$_.key -eq "ntpd"}
            Write-Verbose ("Got NTP service.")
        } # try
        catch {
            throw ("Failed to set host firewall. " + $_.exception.message)
        } # catch


        ## Set service startup policy
        Write-Verbose ("Setting service startup policy.")

        try {

            switch ($servicePolicy) {
                "On" {
                    Set-VMHostService -Policy On -HostService $ntpService -ErrorAction Stop | Out-Null
                    Write-Verbose ("Service policy set to On.")
                    Break
                } # On

                "Automatic" {
                    Set-VMHostService -Policy Automatic -HostService $ntpService -ErrorAction Stop | Out-Null
                    Write-Verbose ("Service policy set to Automatic.")
                    Break
                } # Automatic

                "Off" {
                    Set-VMHostService -Policy Off -HostService $ntpService -ErrorAction Stop | Out-Null
                    Write-Verbose ("Service policy set to Off.")
                    Break
                } # Off

            } # switch

        } # try
        catch {
            throw ("Failed to set service startup policy. " + $_.exception.message)
        } # catch


        ## Set service state as per parameter. If the service is already started, it will be restarted to apply new config.
        Write-Verbose ("Setting service state.")

        try {
            switch ($serviceState) {
                "Started" {
                    Stop-VMHostService -HostService $ntpService -Confirm:$false -ErrorAction Stop | Start-VMHostService -ErrorAction Stop | Out-Null
                    Write-Verbose ("NTP service has been (re)started.")

                    Break
                } # Started

                "Stopped" {
                    Stop-VMHostService -HostService $ntpService -Confirm:$false -ErrorAction Stop | Out-Null
                    Write-Verbose ("NTP service has been stopped.")
                } # Stopped
            } # switch
        } # try
        catch {
            throw ("Failed to set service state. " + $_.exception.message)
        } # catch

        Write-Verbose ("Host NTP configuration completed.")

        ## Return service object
        return $ntpService

    } # process

    end {
        Write-Verbose ("Funciton complete.")
    } # end

} # process