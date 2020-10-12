function Remove-hostSwitch {
#Requires -Modules @{"ModuleName" = "VMware.VimAutomation.Core"; "ModuleVersion" = "11.0.0.10336080"}
    <#
    .SYNOPSIS
        Remove a standard switch from a host.

    .DESCRIPTION
        Remove a standard switch from a host.

    .PARAMETER vmHost
        The ESXi host to remove the switch from.

    .PARAMETER vSwitch
        The name of the standard switch to remove.

    .INPUTS
        System.String. ESXi host name.

    .OUTPUTS
        None.

    .EXAMPLE
        Remove-hostSwitch -vmHost host01.lab.local -vSwitch vSwitch1

        Remove vSwitch1 from host01.lab.local

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vmHost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vSwitch
    )


    begin {

        Write-Verbose ("Function start.")
    } # begin

    process {

        Write-Verbose ("Processing host " + $vmHost)


        ## Get VM host object
        Write-Verbose ("Getting VM host object.")

        try {
            $vmHost = Get-VMHost -Name $vmhost -ErrorAction Stop
            Write-Verbose ("Got VM host object.")
        } # try
        catch {
            Write-Debug ("Failed to get host object.")
            throw ("Failed to get host object. " + $_.exception.message)
        } # catch

        ## Get switch object from host
        Write-Verbose ("Getting standard switch object from host.")

        try {
            $vSwitchObj = Get-VirtualSwitch -VMHost $vmHost -Name $vSwitch
            Write-Verbose ("Got switch object.")
        } # try
        catch {
            Write-Debug ("Failed to get standard switch.")
            throw ("Failed to get switch object. " + $_.exception.message)
        } # catch


        ## Remove specified switch
        Write-Verbose ("Removing switch from host.")

        try {
            Remove-VirtualSwitch -VirtualSwitch $vSwitchObj -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Verbose ("Standard switch was removed.")
        } # try
        catch {
            Write-Debug ("Failed to remove switch.")
            throw ("Failed to remove switch. " + $_.exception.message)
        } # catch


        Write-Verbose ("Host complete.")

    } # process

    end {

        Write-Verbose ("Function complete.")
    } # end

} # function