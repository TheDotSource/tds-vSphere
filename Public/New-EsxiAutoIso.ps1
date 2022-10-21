function New-EsxiAutoIso {
    <#
    .SYNOPSIS
        Build ESXi ISO media that will perform an unattanded install with a basic network configuration.

    .DESCRIPTION
        Build ESXi ISO media that will perform an unattanded install with a basic network configuration.
        The media path must be a writeable location as the function.
        The output ISO name is the same as the specified hostname.

            * Generate KS.CFG and inject network config.
            * Modify BOOT.CFG to point to custom KS.CFG
            * Build ISO media using New-IsoFile function (required)

        This function supports only UEFI boot mode media.

    .PARAMETER mediaPath
        An extracted copy of the desired ESXi ISO media.

    .PARAMETER outputPath
        The path to output the built ISO. The ISO will be named the same as the host name.

    .PARAMETER $rootCredential
        A credential object with the specified root password.

    .PARAMETER ip
        IP address to set on the management interface.

    .PARAMETER netmask
        The subnet mask to set on the management interface.

    .PARAMETER gateway
        The default gateway to set on the management interface.

    .PARAMETER nameserver
        The DNS server to set on the management interface.

    .PARAMETER hostname
        The hostname to configure on the ESXi instance.

    .PARAMETER resetVmk0
        Optional. Useful for nested virtualisation. VMK0 inherits a MAC address from the physical adapter, in a nested scenario this can cause issues.
        Use this switch to recreate VMK0 with a fresh MAC.

    .PARAMETER allowUnsupportedCPU
        Perform the installation even if the host CPU is not supported.

   .INPUTS
        None.

    .OUTPUTS
        System.IO.FileInfo. The completed ISO file.

    .EXAMPLE
        New-EsxiAutoIso -mediaPath D:\esximedia\ -outputPath D:\esxiIso -rootCredential $creds -ip 10.10.1.10 -netmask 255.255.255.0 -gateway 10.10.1.1 -nameserver 10.10.1.20 -hostname esxi01.lab.local

        Build media from the d:\esxiMedia folder (this will be extracted ESXi media).
        Save a bootable ISO called esxi01.lab.loca.iso with the specified parameters injected into the KS.CFG.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$mediaPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$outputPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$rootCredential,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [IPAddress]$ip,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [IPAddress]$netmask,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [IPAddress]$gateway,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [IPAddress]$nameserver,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$hostname,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [switch]$resetVmk0,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [switch]$allowLegacyCPU
    )


    begin {

        Write-Verbose ("Function start.")
    } # begin

    process {

        Write-Verbose ("Specified media path is " + $mediaPath)

        ## Strip trailing \ from paths, if specified
        $mediaPath = $mediaPath.Trim("\")
        $outputPath = $outputPath.Trim("\")

        ## Attempt to get disc info from media path
        try {
            [xml]$esxXml = Get-Content -Path ($mediaPath + "\UPGRADE\METADATA.XML") -ErrorAction Stop
            $esxVersion = [system.version]$esxXml.vum.product.esxVersion

            Write-Verbose ("Media version is " + $esxVersion.ToString())
        } # try
        catch {
            Write-Warning ("Failed to open ESXi \UPGRADE\METADATA.XML. Verify valid media has been extracted to the path specified.")
        } # catch


        ## Get contents of BOOT.CFG
        Write-Verbose ("Opening BOOT.CFG")
        try {
            $bootCfg = Get-Content -Path ($mediaPath + "\EFI\BOOT\BOOT.CFG") -ErrorAction Stop
            Write-Verbose ("BOOT.CFG opened.")
        } # try
        catch {
            throw ("Failed to open BOOT.CFG. " + $_.exception.message)
        } # catch

        ## Find kernelopt line and set appropriately
        $newBootCfg = $bootCfg | ForEach-Object -Process {

                if ($_ -match "kernelopt*") {

                    ## Replace this line to point to our new KS.CFG
                    return "kernelopt=runweasel ks=cdrom:/EFI/BOOT/KS.CFG allowLegacyCPU=true"
                } # if

                $_
        } # foreach

        ## Configure start of template
        Write-Verbose ("Processing ks.cfg with specified values.")

        ## If we are using allowLegacyCPU this needs some special parameters for ESXi 8.0 or above.
        ## ESXi 8.0 no longer appears to use the allowLegacyCPU boot option but relies on some install parameters
        if (($esxVersion.Major -ge 8) -and ($allowLegacyCPU)) {
            Write-Verbose ("Applying install parameters for ESXi 8.0 and above for unsupported CPU type.")
            $installString = "install --firstdisk --overwritevmfs --ignoreprereqwarnings --ignoreprereqerrors --forceunsupportedinstall"
        } # if
        else {
            ## Standard install string, previous versions work with allowLegacyCPU boot option
            $installString = "install --firstdisk --overwritevmfs"
        } # else


        $ksTemplate = @"
### Accept the VMware End User License Agreement
vmaccepteula

### The install media (priority: local / remote / USB)
{0}

### Reboot ESXi Host
reboot

### Set the network to  on the first network adapter
network --bootproto=static --device=vmnic0 --ip={1} --netmask={2} --gateway={3} --nameserver={4} --hostname={5} --addvmportgroup=0

### Set the root password for the DCUI and Tech Support Mode
rootpw {6}


#Firstboot section 1
%firstboot --interpreter=busybox
sleep 30

### Add default VM Network
esxcli network vswitch standard portgroup add -p "VM Network" -v vSwitch0
"@


        ## If -resetVmk0 is specified, add the following ESXCLI commands
        if ($resetVmk0) {

            Write-Verbose ("Adding ESXCLI for VMK0 reset.")

            $ksTemplate += @"

### Reset VMK0. By default, VMK0 inherits a MAC from the physical adapter which can cause anomalies with nested networking.
esxcli network ip interface remove --interface-name=vmk0
esxcli network ip interface add --interface-name=vmk0 --portgroup-name="Management Network"
esxcli network ip interface ipv4 set -i vmk0 --ipv4 {1} --netmask {2} --type static
"@
        } # if

        ## Append network config as the last thing we do
        $ksTemplate += @"

### Suppress Core Dump Warning
esxcli system settings advanced set -o /UserVars/SuppressCoredumpWarning -i 1
"@

        ## Inject template values
        try {
            $ksTemplate = $ksTemplate -f $installString, $ip, $netmask, $gateway, $nameserver, $hostname, $rootCredential.GetNetworkCredential().Password
            Write-Verbose ("Template values injected.")
        } # try
        catch {
            throw ("Failed to inject values. " + $_.exception.message)
        } # catch

        if (Test-Path -Path ($mediaPath + "\EFI\BOOT\KS.CFG")) {
            Write-Verbose ("Found existing KS.CFG, it will be removed.")
            Remove-Item -Path ($mediaPath + "\EFI\BOOT\KS.CFG") -Force
        }

        ## Inject new KS.CFG and BOOT.CFG
        Write-Verbose ("Saving template to " + $outputFile)
        try {
            $ksTemplate | Out-File -FilePath ($mediaPath + "\EFI\BOOT\KS.CFG") -Encoding utf8NoBOM -Force -ErrorAction Stop
            $newBootCfg | Out-File -FilePath ($mediaPath + "\EFI\BOOT\BOOT.CFG") -Encoding utf8NoBOM -Force -ErrorAction Stop
            Write-Verbose ("Files written to " + ($mediaPath + "\EFI\BOOT\KS.CFG") + " and " + ($mediaPath + "\EFI\BOOT\BOOT.CFG"))
        } # try
        catch {
            throw ("Failed to save output file. " + $_.exception.message)
        } # catch

        Write-Verbose $ksTemplate



        ## Build ISO image from scratch location, use hostname for the file name
        Write-Verbose ("Building ISO from scratch location.")
        try {
            $iso = New-ISOFile -source ($mediaPath) -destinationIso ($outputPath + "\" + $hostname + ".iso") -bootFile ($mediaPath + "\EFIBOOT.IMG") -media CDR -title esxi -force
            Write-Verbose ("ISO build complete.")
        } # try
        catch {
            throw ("Failed to build ISO " + $_.exception.message)
        } # catch

        return $iso

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function