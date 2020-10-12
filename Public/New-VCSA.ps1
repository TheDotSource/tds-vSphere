function New-VCSA {
    <#
    .SYNOPSIS
        Deploy a new VCSA appliance from ISO media to an ESXi host.

    .DESCRIPTION
        Deploy a new VCSA appliance from ISO media to an ESXi host.
        Deploys an appliance with embedded PSC.


    .PARAMETER deploymentSize
        The appliance size to deploy.

    .PARAMETER esxiHost
        The hostname or IP of the host to deploy to.

    .PARAMETER network
        The network to connect the appliance to.

    .PARAMETER datastore
        The datastore to deploy thr appliance to.

    .PARAMETER systemName
        The appliance system name.

    .PARAMETER dns
        The DNS server the appliance should use.

    .PARAMETER gateway
        The default gateway the appliance should use.

    .PARAMETER ip
        The IP address to assign to the appliance.

    .PARAMETER maskLength
        The subnet mask legth to configure.

    .PARAMETER ntp
        The NTP server the appliance should use.

    .PARAMETER ssoDomain
        The name of the SSO domain.

    .PARAMETER vmName
        The name of the virtual machine object.

    .PARAMETER esxiCredential
        The credential for the target ESXi host.

    .PARAMETER osCredential
        The appliance root password.

    .PARAMETER ssoCredential
        The administrator SSO password to configure.

    .PARAMETER Force
        Attempt a deployment even if the supplied media is not a supported version.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-VCSA -deploymentSize small -esxiHost 192.168.0.200 -network "VM Network" -datastore localDS -systemName vcsa.lab.local
        -dns 192.168.0.100 -gateway 192.168.0.1 -ip 192.168.0.201 -netMask 255.255.255.0 -ntp 10.10.2.1 -ssoDomain vsphere.local
        -vmName VCSA01 -logDir c:\logs -esxiCredential $esxCreds -osCredential $osCreds -ssoCredential $ssoCreds

        Deploy a small appliance to ESXi host 192.168.0.200 with the specified options.

    .LINK

    .NOTES
        01       06/05/20     Initial version.           A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("tiny","small","medium","large")]
        [string]$deploymentSize,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$esxiHost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$network,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$datastore,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$systemName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$dns,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$gateway,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$ip,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$netMask,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$ntp,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$ssoDomain,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$logDir,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$esxiCredential,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$osCredential,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$ssoCredential,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [Switch]$force
    )


    begin {
        Write-Verbose ("Function start.")
    } # begin

    process {

        ## Set supported versions, this is based on vcsa\version.txt
        $supportedVersions = @(
                "VMware-vCenter-Server-Appliance-6.7.0.40000-14367737",
                "VMware-vCenter-Server-Appliance-7.0.0.10100-15952498",
                "VMware-vCenter-Server-Appliance-7.0.0.10300-16189094",
                "VMware-vCenter-Server-Appliance-7.0.1.00000-16860138"
                )

        ## Trim any trailing \ on the log directory
        $logDir = $logDir.Trim("\")

        ## Determine where VCSA media is mounted
        Write-Verbose ("Detecting mounted VCSA media.")

        $possibleDrives = @("D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z")
        $cliPath = $null
        $templatePath = $null

        foreach ($possibleDrive in $possibleDrives) {

            if (Test-Path -Path ($possibleDrive + ":\vcsa-cli-installer\win32\vcsa-deploy.exe")) {
                Write-Verbose ("Found VCSA media mounted at " + $possibleDrive + ":\")
                Write-Verbose ("Querying media version.")

                ## Read version string from version.txt
                if (Test-Path -Path ($possibleDrive + ":\vcsa\version.txt")) {

                    try {
                        $isoVersion = Get-Content -Path ($possibleDrive + ":\vcsa\version.txt") -ErrorAction Stop
                        Write-Verbose ("Media version is " + $isoVersion)
                    } # try
                    catch {
                        Write-Warning ("Failed to read contents of version.txt. Deployment will still be attempted.")
                    } # catch

                } # if
                else {
                    Write-Warning ("Failed to locate version.txt on VCSA media, build will attempt to continue.")
                } # else

                ## Set paths to CLI installer executable and the template we will be using
                $cliPath = ($possibleDrive + ":\vcsa-cli-installer\win32\vcsa-deploy.exe")
                $templatePath = ($possibleDrive + ":\vcsa-cli-installer\templates\install\embedded_vCSA_on_ESXi.json")

                ## Break out of this so we don't query all possible drives
                Break
            } # if

        } # foreach

        ## Verify this is a supported version
        if ($supportedVersions -contains $isoVersion) {

            ## Version is supported
            Write-Verbose ("Media is a supported version.")

        } # if
        else {

            ## Not a supported version, check for -force switch
            if ($force) {
                Write-Warning ("VCSA version " + $isoVersion + " is not supported by this function. The -Force parameter has been specified so a deployment will be attempted.")
            } # if
            else {
                throw ("VCSA version " + $isoVersion + " is not supported by this function. Review the function synopsis for a list of supported versions. The -Force switch can be used to attempt a deployment anyway (not recommended).")
            } # else

        } # else

        ## Check CLI installer was found
        if (!$cliPath) {
                Write-Debug ("Failed to locate media.")
                throw ("Failed to located VCSA media.")
        } # if


        ## Open JSON template file from install media
        Write-Verbose ("Opening JSON deployment template.")

        try {
            $vcsaTemplate = Get-Content -Path $templatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose ("Template file was opened.")
        } # try
        catch {
            Write-Debug ("Failed to open JSON template file.")
            throw ("Failed to open install template file on ISO media. " + $_.exception.message)
        } # catch


        ## Convert input subnet mask dotted notation to bit length format
        [IPAddress]$maskDotted = $netMask

        $octets = $maskDotted.IPAddressToString.Split('.')
        foreach($octet in $octets) {

            while(0 -ne $octet) {
                $octet = ($octet -shl 1) -band [byte]::MaxValue
                $maskLength++
            } # while

        } # foreach

        Write-Verbose ("Mask length is " + $maskLength)

        ## Populate required values to JSON config
        $vcsaTemplate.new_vcsa.appliance.deployment_option = $deploymentSize
        $vcsaTemplate.new_vcsa.appliance.name = $vmName
        $vcsaTemplate.new_vcsa.esxi.hostname = $esxiHost
        $vcsaTemplate.new_vcsa.esxi.username = $esxiCredential.UserName
        $vcsaTemplate.new_vcsa.esxi.password = $esxiCredential.GetNetworkCredential().Password
        $vcsaTemplate.new_vcsa.esxi.deployment_network = $network
        $vcsaTemplate.new_vcsa.esxi.datastore = $datastore
        $vcsaTemplate.new_vcsa.network.system_name = $systemName
        $vcsaTemplate.new_vcsa.network.dns_servers = $dns
        $vcsaTemplate.new_vcsa.network.gateway = $gateway
        $vcsaTemplate.new_vcsa.network.ip = $ip
        $vcsaTemplate.new_vcsa.network.prefix = [string]$maskLength
        $vcsaTemplate.new_vcsa.os.password = $osCredential.GetNetworkCredential().Password
        $vcsaTemplate.new_vcsa.os.ntp_servers = $ntp
        $vcsaTemplate.new_vcsa.sso.password = $ssoCredential.GetNetworkCredential().Password
        $vcsaTemplate.new_vcsa.sso.domain_name = $ssoDomain
        $vcsaTemplate.ceip.settings.ceip_enabled = $false
        $vcsaTemplate.ceip.description.__comments = @(" ")
        $vcsaTemplate.new_vcsa.appliance.__comments = @(" ")

        ## Create UTF8 without BOM encoder
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False


        ## Generate populated JSON template file for CLI installer
        Write-Verbose ("Generating JSON template file at " + ($logDir + "\vcsaDeploy.json"))

        try {
            $deployJson = $vcsaTemplate | ConvertTo-Json -Depth 5 -ErrorAction Stop
            [System.IO.File]::WriteAllLines(($logDir + "\vcsaDeploy.json"),$deployJson, $Utf8NoBomEncoding)
            Write-Verbose ("Template file created.")
        } # try
        catch {
            Write-Debug ("Failed to generate template.")
            throw ("Failed to generate JSON template " + $_.exception.message)
        } # catch

        ## Prepare command string
        $deployCmd = ($cliPath + " install -t --accept-eula " + ($logDir + "\vcsaDeploy.json") + " --no-ssl-certificate-verification --log-dir " + $logDir)
        Write-Verbose ("Appliance will be deployed using CLI installer command: " + $deployCmd)

        ## Deploy VCSA with vcsa-deploy.exe
        Write-Verbose ("Invoking deployment.")

        try {

            ## Support should process
            if ($PSCmdlet.ShouldProcess($esxiHost)) {
                Start-Process -NoNewWindow -FilePath $cliPath -ArgumentList ("install -t --accept-eula " + ($logDir + "\vcsaDeploy.json") + " --no-ssl-certificate-verification --log-dir " + $logDir) -Wait -ErrorAction Stop
            } # if

                Write-Verbose ("CLI installer has completed.")
        } # try
        catch {
            Write-Debug ("Deployment failed.")
            throw ("Appliance deployment failed. " + $_.exception.message)
        } # catch

        ## Get the VCSA status json file, the folder name is generated at run time so we need to pattern match on workflow_
        $vcsaStatusJson = ((Get-ChildItem -Path $logDir| Where-Object {$_.name -like "workflow_*"}).FullName + "\vcsa-cli-installer-status.json")

        ## Check we have the file
        if (!(Test-Path -Path $vcsaStatusJson)) {
            throw ("The CLI installer completed but the vcsa-cli-installer-status.json was not found. This is required to verify deployment.")
        } # if


        ## Open the status JSON
        Write-Verbose ("Opening " + $vcsaStatusJson + " to determine build status.")

        try {
            $vcsaStatus = Get-Content -Path $vcsaStatusJson | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose ("Log file opened.")
        } # try
        catch {
            throw ("Failed to open vcsa-cli-installer-status.json. " + $_.exception.message)
        } # catch


        ## Check the status
        if ($vcsaStatus.vcsaDeploy.status -ne "SUCCEEDED") {
            throw ("vcsa-cli-installer-status.json has not reported a SUCCEEDED status. The returned status was " + $vcsaStatus.vcsaDeploy.status + ". Examine the VCSA deployment logs in the log directory for more information.")
        } # if

        Write-Verbose ("Log file indicates deployment has succeeded.")

    } # process


    end {
        Write-Verbose ("Function end.")

    } # end

} # function