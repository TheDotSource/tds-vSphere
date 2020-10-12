function Set-VMPortGroup {
    <#
    .SYNOPSIS
        Set the port group for all virtual adapters on a virtual machine.

    .DESCRIPTION
        Set the port group for all virtual adapters on a virtual machine.

    .PARAMETER vmname
        The VM to set the port group on.

    .PARAMETER portGroup
        The port group to set.

    .INPUTS
        System.String. Target VM name.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-VMPortGroup -vmName testvm01 -portGroup testPg01

        Move all adapters on testvm01 to portgorup testPg01

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vmname,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$portGroup
    )

    begin {

        Write-Verbose ("Function start.")

        ## Get port group
        Write-Verbose ("Getting target portgroup.")

        try {
            $portGroupObj = Get-VDPortgroup -name $portGroup -ErrorAction Stop
            Write-Verbose ("Got portgroup.")
        } # try
        catch {
            Write-Debug ("Failed to get portgroup.")
            throw ("Failed to get target portgroup. " + $_.exception.message)
        } # catch

    } # begin

    process {

       ## Get VM object
       Write-Verbose ("Getting target VM object.")

        try {
            $vm = Get-VM -Name $vmname -ErrorAction Stop
            Write-Verbose ("Got target VM.")
        } # try
        catch {
            Write-Debug ("Failed to get VM object.")
            throw ("Failed to get target VM. " + $_.exception.message)
        } # catch


        ## Reconfigure VM network adapters
        Write-Verbose ("Configuring VM port group.")

        try {
            if ($PSCmdlet.ShouldProcess($vm)) {
                Get-NetworkAdapter -VM $vm -ErrorAction Stop | Set-NetworkAdapter -Portgroup $portGroupObj -Confirm:$false -ErrorAction Stop
                Write-Verbose ("Portgroup set.")
            }
        } # try
        catch {
            Write-Debug ("Failed to set port group.")
            throw ("Failed to set VM port group. " + $_.exception.message)
        } # catch


        Write-Verbose ("Completed VM.")

    } # process

    end {
        Write-Verbose ("Function end.")
    } # end

} # function