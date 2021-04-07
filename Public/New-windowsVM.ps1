function New-windowsVM {
#Requires -Modules @{"ModuleName" = "VMware.VimAutomation.Core"; "ModuleVersion" = "11.0.0.10336080"}
    <#
    .SYNOPSIS
        Deploy a Windows VM from OVF and apply a base configuration on a standalone ESXi host without vCenter.

    .DESCRIPTION
        Deploy a Windows VM from OVF and apply a base configuration:
            * Core count and RAM
            * Power on and wait for tools
            * Wait for sysprep to complete.
            * Configure IP, subnet mask and default gateway via VMTools.
            * Set a DNS server via VMTools.
            * Configure some basic fireall rules to allow remote management (done via VMTools)

        This function is designed to perform these actions on a standalone ESXi host without vCenter.
        This is useful in greenfield scenarios.

        The script requires a standard syspreped Windows OVF with "Ethernet0" as an available network connection.

        Note: VM must be packaged as an OVF and not an OVA. This is due to a documented bug in Import-vApp and standalone hosts.
        Attempting to import an OVA to a standalone host with Import-vApp will fail.

    .PARAMETER esxHost
        The target host to deploy the OVF to.

    .PARAMETER ovfPath
        The path to the OVF file to deploy.

    .PARAMETER vmName
        The name of the VM to create.

    .PARAMETER dataStore
        The datastore upon which to deploy the VM.

    .PARAMETER vCpu
        Optional. The number of cores to configure the VM with, default is 2 if not specified.

    .PARAMETER memGb
        Optional. The amount of RAM to configure in GB, default is 2 if not specified.

    .PARAMETER vmIp
        The system IP address to configure.

    .PARAMETER vmMaskLength
        The system subnet length to configure.

    .PARAMETER vmDns
        The system DNS to configure.

    .PARAMETER vmGateway
        The default gateway to configure.

    .PARAMETER Credential
        The credential object to authenticate to the guest OS.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-windowsVM -esxHost 192.168.0.20 -ovfPath C:\example\winVM.ovf -vmName TestVM -dataStore localDS -vmIp 10.10.1.200 -vmMaskLength 24 -vmGateway 10.10.1.1 -Credential $creds -vmDns 10.10.1.100

        Deploy a new VM TestVM from OVF template winVM. Use default 2 vCpu and 2GB RAM.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$esxHost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$ovfPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$dataStore,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [int]$vCpu = 2,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [int]$memGb = 2,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmIp,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmMaskLength,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmDns,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmGateway,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    begin {

        Write-Verbose ("Function start.")
    } # begin


    process {

        Write-Verbose ("Deploying OVF from " + $ovfPath)

        ## Deploy the OVF
        try {
            Import-VApp -Source $ovfPath -Name $vmName -Datastore $dataStore -VMHost $esxHost -DiskStorageFormat Thin -Verbose:$false -ErrorAction Stop | Out-Null
            Write-Verbose ("OVF deployment complete.")
        } # try
        catch {
            Write-Debug ("Failed to deploy OVF.")
            throw ("Failed to deploy OVF. " + $_.exception.message)
        } # catch


        Write-Verbose ("Getting VM object.")


        ## Get VM object
        try {
            $vm = Get-VM -Name $vmName -Verbose:$false -ErrorAction Stop
            Write-Verbose ("Got VM object.")
        } # try
        catch {
            Write-Debug ("Failed to get VM object.")
            throw ("Failed to get VM object. " + $_.exception.message)
        } # catch


        ## Configure CPU and RAM
        try {
            Set-VM -VM $vm -MemoryGB $memGb -NumCpu $vCpu -Confirm:$false | Out-Null
            Write-Verbose ("VM CPU and RAM set to 2GB and 2 cores.")
        } # try
        catch {
            Write-Debug ("Failed to configure VM.")
            throw ("Failed to configure RAM and CPU. " + $_.exception.message)
        } # catch

        Write-Verbose ("Powering on VM and waiting for VM tools.")

        ## Power up VM and wait for tools
        try {
            Start-VM -VM $vm -ErrorAction Stop | Wait-Tools | Out-Null
            Write-Verbose ("VM has powered on.")
        } # try
        catch {
            Write-Debug ("Failed to power on VM.")
            throw ("Failed to power on VM. " + $_.exception.message)
        } # catch


        ## Test authentication to guest OS. Initially this fails due to sysprep not being complete.
        ## This is a bit ugly as we don't have vcenter to help us detect this. Poll and wait until we are successful.
        $i = 0
        $sysprepComplete = $false
        $cmdString = ("echo Testing Authtication")

        do{

            try {
                Invoke-VMScript –VM $vm -GuestCredential $Credential -ScriptType Bat -ScriptText $cmdString -ErrorAction Stop | Out-Null
                $sysprepComplete = $true
                Write-Verbose ("Sysprep has completed.")
            } # try
            catch {
                Write-Verbose ("Waiting for sysprep to complete.")
                Start-Sleep 30
            } # catch

            $i++

            Start-Sleep 30

        } until (($i -eq 20) -or ($sysprepComplete))

        ## Check if authtication attempts were exceeded
        if ($i -eq 20) {
            throw ("Could not authenticate to the target system with the specified number of attempts. Either sysprep has not completed, or the wrong credential has been supplied.")
        } # if


        ## Run post deployment configuration via VM tools
        $vmCmds = [ordered]@{}
        $vmCmds.Add("Configure System Networking",("New-NetIPAddress –InterfaceAlias Ethernet0 –IPAddress " + $vmIP + " –PrefixLength " + $vmMaskLength + " -DefaultGateway " + $vmGateway))
        $vmCmds.Add("Configure System DNS",("Set-DnsClientServerAddress -InterfaceAlias Ethernet0 -ServerAddresses " + $vmDns))
        $vmCmds.Add("Enable Firewall Rule FPS-ICMP4-ERQ-In",("Get-NetFirewallRule -Name FPS-ICMP4-ERQ-In | Enable-NetFirewallRule"))
        $vmCmds.Add("Enable Firewall Rule WMI-RPCSS-In-TCP",("Get-NetFirewallRule -Name WMI-RPCSS-In-TCP | Enable-NetFirewallRule"))
        $vmCmds.Add("Enable Firewall Rule WMI-WINMGMT-In-TCP",("Get-NetFirewallRule -Name WMI-WINMGMT-In-TCP | Enable-NetFirewallRule"))

        foreach ($vmCmd in $vmCmds.GetEnumerator()) {

            Write-Verbose ("Starting post deployment task " + $vmCmd.key + " via VM tools.")

            try {
                Invoke-VMScript –VM $vm -GuestCredential $Credential -ScriptType Powershell -ScriptText $vmCmd.Value -ErrorAction Stop | Out-Null
            } # try
            catch {
                Write-Debug ("Post deployment task failed.")
                throw ("Post deployment task failed. " + $_.exception.message)
            } # catch

            Write-Verbose ("Completed post deployment task.")

        } # foreach


        ## Wait 5 seconds
        Start-Sleep 5

        ## Test system connectivity
        Write-Verbose ("Testing system connectivity.")

        if (!(Test-Connection -ComputerName $vmIP -Quiet -Count 2)) {
            throw ("System connectivity test failed. The system could not be reached on " + $vmIP)
        } # if

        Write-Verbose ("Connectivity test succeeded.")

    } # process

    end {

        Write-Verbose ("Function complete.")
    } # end

} # function