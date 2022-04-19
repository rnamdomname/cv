$ErrorActionPreference = "Stop"
$CONFIGDRIVE = "D:"
$INSTALLDIR = "${CONFIGDRIVE}\toinstall"

function Main() {
    $installJson = Get-Content "${CONFIGDRIVE}\install.json"
    $installJson = [JSON]::Sort([JSON]::Deserialize($installJson))
    Enable-RDP
    foreach ($item in $installJson) {
        _execute($item)
    }
    Stop-Computer -Force
}

function _execute($item) {
    if ($item.pass){
        return #WinPE
    }
    $ext = Get-ext($item)
    if ( $ext -eq "msi") {
        _Msi($item)
    }
    if ( $ext -eq "exe") {
        _Exe($item)
    }
    if ( $ext -eq "msu") {
        _Dism($item)
    }
    if ( $ext -eq "cab") {
        _Dism($item)
    }
    if ( $ext -eq "zip") {
        _Zip($item)
    }
    if ($item.sourceDir.length -gt 0) {
        _Copy($item)
    }
    if ($item.autoStart) {
        _AutoStart($item)
    }
    if ($item.addToPath) {
        _AddToPath($item)
    }
}

$code = @"
using System;
using System.Collections.Generic;
using _JSON=System.Web.Script.Serialization.JavaScriptSerializer; // keep FullName, otherwise - undefined reference
using Dict = System.Collections.Generic.Dictionary<string, object>;
public class JSON
{
    public static object[] Deserialize(string data)
    {
        _JSON serializer = new _JSON();
        return serializer.Deserialize<object[]>(data);
    }
    public static object[] Sort(object[] array)
    {
        IComparer<Object> jsonComparer = new JSONComparer();
        Array.Sort(array, jsonComparer);
        return array;
    }

}
public class JSONComparer : IComparer<object>
{
    public int Compare(object a, object b)
    {
        Int32 _a = (Int32)((Dict)a)["order"];
        Int32 _b = (Int32)((Dict)b)["order"];
        return (_a.CompareTo(_b));
    }
}
"@
#[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") .FullName
$scriptAssembly = "System.Web.Extensions, Version=3.5.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"
Add-Type -ReferencedAssemblies $scriptAssembly -TypeDefinition $code -Language CSharp


Function unzip([string]$file, [string]$destination) {
    $shell = New-Object -ComObject Shell.Application
    $zip_src = $shell.NameSpace($file)
    if (!$zip_src) {
        throw "Cannot find file: $file"
    }
    $zip_dest = $shell.NameSpace($destination)
    $zip_dest.CopyHere($zip_src.Items(), 1044)
}
Function Wait-Process($name) {
    Do {
        Start-Sleep 2
        $instanceCount = (Get-Process | Where-Object { $_.Name -eq $name } | Measure-Object).Count
    } while ($instanceCount -gt 0)
}


Function Add-ToPath ([string]$path) {
    $old = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name path).path
    $new = "$old;$path"
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name path -Value $new
}

Function Add-ToStartup([string]$name, [string]$value) {
    New-ItemProperty -Force -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" `
        -PropertyType String -Name $name -Value $value
}

function Enable-RDP() {
    Write-Host -ForegroundColor DarkGreen  "Enabling Remote desktop"
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
    Start-Process netsh -ArgumentList "advfirewall firewall set rule group=`"remote desktop`" new enable=yes"
}

function Get-Ext($item) {
    $item.name.split(".")[-1];
}

function mkdir_-p($dest){
    if (Test-Path $dest){
        return
    }
    Write-Host -ForegroundColor DarkGreen  "Creating path: $dest"
    New-Item -Force -ItemType File -Path "$dest\file"
    Remove-Item -Force -Path "$dest\file"
}
Function _ExpandString($str) {
    return $ExecutionContext.InvokeCommand.ExpandString($str)
}
Function _Copy($item) {
    if ($item.sourceDir -eq $item.destination) { return }
    $name = $item.name
    Write-Host -ForegroundColor DarkGreen  "Copying: $name"
    $s = $item.sourceDir;
    $d = $item.destination
    $s = _ExpandString("$s\$name");
    $d = _ExpandString("$d");
    mkdir_-p($d)
    Copy-Item -Force -Path $s -Destination $d
}

function _Msi($item) {
    $path = $item.name
    Write-Host -ForegroundColor DarkGreen  "Installing: $path"
    $path = "$INSTALLDIR\$path"
    $_args = $item.args
    Start-Process msiexec.exe -Wait -ArgumentList "/I $path $_args"
}
function _Dism($pkg) {
    Write-Host -ForegroundColor DarkGreen  "Installing updates: $pkg"
    $pkg = $pkg.split(" ") -join ' /PackagePath:'
    Wait-Process -name dism
    Start-Process dism -Wait -ArgumentList "/Online /Add-Package /PackagePath:$pkg /NoRestart"
    Wait-Process -name dism
}

function _AutoStart($item) {
    if ($item.start){
        $entry = $item.start
    } else {
        $entry = $item.name
    }
    $interpreter = $item.interpreter
    $_args = $item.args
    $dest = $item.destination
    $dest = _ExpandString($dest)
    Add-ToStartup -name $entry -value "cmd /C $interpreter `"${dest}\${entry}`" $_args"
}
function _AddToPath($item) {
    $p = $item.destination;
    $p = _ExpandString($p);
    Add-ToPath -Path $p
}

function _Zip($item) {
    $path = $item.name
    Write-Host -ForegroundColor DarkGreen  "Extracting: $path"
    $dest = $item.destination
    $path = "$INSTALLDIR\$path"
    $dest = _ExpandString($dest)
    mkdir_-p($dest)
    unzip -file $path -destination $dest
}
function _Exe($item){
    if ($item.destination){ # Installed by Copying
        return
    }
    $path = $item.name
    $path = "$INSTALLDIR\$path"
    $_args = $item.args
    Start-Process $path -Wait -ArgumentList " $_args"
}


Main



#_____________________________________________________________________________________________

<#

Function RunAsIEUser($path, $arg) {
    $User = "\IEUser"
    $PWord = ConvertTo-SecureString -String "Passw0rd!" -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    Start-Process $path -Credential $Credential -ArgumentList $arg
}
Function Spawn($path, $arg, $log) {
    #do not want to use Start-Process, it cannot redirect outputs: 2>&1, etc
    $ars = $arg.split()
    $output = &$path $ars 2>&1
    if ($LastExitCode) {
        throw "Error process failed: $output"
    }
    return $output
}

Function Setup($path, $ar){
    Start-Process msiexec.exe -Wait -ArgumentList "/I $path /passive /norestart $ar"
}

Function Wait-Process($name) {
    Do {
        Start-Sleep 2
        $instanceCount = (Get-Process | Where-Object { $_.Name -eq $name } | Measure-Object).Count
    } while ($instanceCount -gt 0)
}


Function Wait-Net($TestAddress) {
    Write-Host -ForegroundColor Yellow "Waiting for network to become online"
    do {
        try {
            $ping = test-connection -comp $TestAddress -count 1 -Quiet
        }
        catch {
        }
    } until ($ping)
    Write-Host -ForegroundColor Yellow  "Connected"
}
Function unzip([string]$file, [string]$destination) {
    $shell = New-Object -ComObject Shell.Application
    $zip_src = $shell.NameSpace($file)
    if (!$zip_src) {
        throw "Cannot find file: $file"
    }
    $zip_dest = $shell.NameSpace($destination)
    $zip_dest.CopyHere($zip_src.Items(), 1044)
}

#Function Download-File($url, $path) {
 #   $client = New-Object -TypeName System.Net.WebClient
 #  Write-Host $client.ResponseHeaders
 #   $client.DownloadFile($url, $path)
#}
function Disable-Updates() {
    Write-Host -ForegroundColor DarkGreen  "Disabling Windows Update"
    New-Item -Force HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name WindowsUpdate
    New-Item -Force HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name AU
    New-ItemProperty -Force HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoUpdate -Value 1
    New-ItemProperty -Force HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name `
        NoAutoRebootWithLoggedOnUsers -Value 1
    #net stop wuauserv
    Set-Service -Name wuauserv -StartupType Disabled
    netsh advfirewall firewall add rule name=\"WindowsUpdateBlock\" dir=out interface=any action=block service=wuauserv
}
function Run-WUSA ($FilePath) {
    Wait-Process -name wusa
    Spawn -path wusa.exe -arg "$FilePath /quiet /norestart" -log $PWD/log.txt
    Wait-Process -name wusa
}

#Function Check-sha1sum ($path, $hash) {
#    if ( (Get-FileHash -Algorithm SHA1 $path).hash -eq $hash) {
#        return !!1
#    }
#    else {
#        throw "Error: Sha sum mismatch: $path, $hash"
#    }
#}


Function ApplyTLSv12PartFix() {
    Write-Host -ForegroundColor DarkGreen "Applying TLS 1.2 fix"
    #$downloadPath = "$INSTALLDIR\windows6.1-kb3140245-x86_cdafb409afbe28db07e2254f40047774a0654f18.msu"
    #Run-WUSA -FilePath $downloadPath
    Setup -path "$INSTALLDIR\MicrosoftEasyFix51044.msi"
}
Function Make-NetworksPrivate {
    Write-Host -ForegroundColor DarkGreen  "Set network location to Private for all networks "
    $networkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}"))
    $connections = $networkListManager.GetNetworkConnections()
    $connections | ForEach-Object { $_.GetNetwork().SetCategory(1) }
}
Function Upgrade-PowerShellV5() {
    #Write-Host -ForegroundColor DarkGreen  "Upgrading PowerShell (KB3191566)"
    #$zip_file = "$INSTALLDIR\Win7-KB3191566-x86.zip"
    #unzip -file $zip_file -destination "$TMP_DIR"
    #Run-WUSA -FilePath "$TMP_DIR\Win7-KB3191566-x86.msu"
}
function Install-Drivers() {
    Write-Host -ForegroundColor DarkGreen "Installing drivers and Redhat certificates"
    Spawn -path certutil.exe -arg "-addstore TrustedPublisher ${DRIVERS_DIR}\redhatcodesign.cer" -log $PWD/log.txt
    Spawn -path certutil.exe -arg "-addstore TrustedPublisher ${DRIVERS_DIR}\redhatcodesign1.cer" -log $PWD/log.txt
    $files = Get-ChildItem -Path $DRIVERS_DIR -Recurse -Include *.inf
    for ($i=0; $i -lt $files.Count; $i++) {
        Write-Output  $files[$i].FullName
        $inf=$files[$i].FullName
        Spawn -path PnPutil.exe  -arg "-a $inf" -log $PWD/log.txt
    }
}
function Enable-RDP() {
    Write-Host -ForegroundColor DarkGreen  "Enabling Remote desktop"
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
    Spawn -path netsh -arg "advfirewall firewall set rule group=`"remote desktop`" new enable=yes" -log $PWD/log.txt
}

Function Install-GuestAdditions {
    Write-Host -ForegroundColor DarkGreen  "Installing qemu guest additions"
    Setup -path "$INSTALLDIR\ga.msi"
}

function Install-Java() {
    Write-Host -ForegroundColor DarkGreen  "Installing Java"
    $MSI = "$INSTALLDIR\java.msi"
    $ADDLOCAL="ADDLOCAL=FeatureEnvironment,FeatureMain,FeatureJarFileRunWith,FeatureJavaHome"
    Setup -path $MSI -ar $ADDLOCAL
}


Function Add-ToPath ([string]$path) {
    $old = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name path).path
    $new = "$old;$path"
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name path -Value $new
}

Function Add-ToStartup([string]$name, [string]$value) {
    New-ItemProperty -Force -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" `
        -PropertyType String -Name $name -Value $value
}

Function Create-Shortcut ([string]$file, [string]$destination, [string]$arguments) {
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$destination.lnk")
    $Shortcut.TargetPath = $file
    $Shortcut.Arguments = $arguments
    $Shortcut.Save()
}


Function Install-IEDriver() {
    Write-Host -ForegroundColor DarkGreen  "Installing IEDriver"
    New-Item -ItemType directory $env:ProgramFiles\Selenium
    unzip -file  $INSTALLDIR\iedriver.zip -destination $env:ProgramFiles\Selenium
    Add-ToPath -path $env:ProgramFiles\Selenium
}

Function Install-SelemiumNode() {
    Write-Host -ForegroundColor DarkGreen  "Installing Selenium server"
    $path = "$env:ProgramFiles\Selenium\selenium-server.jar"
    Copy-Item -Path $INSTALLDIR\selenium-server.jar -Destination $path
    Write-Host -ForegroundColor DarkGreen "Adding Selenium Node to startup"
    $srct="$env:ProgramFiles\Selenium\seleniumnode.ps1"
    Copy-Item -Path $CONFIGDRIVE\seleniumnode.ps1 -Destination $srct
    Add-ToStartup -name seleniumnode -value "$PWSH -ExecutionPolicy Bypass -File `"$srct`" "
    Write-Host -ForegroundColor DarkGreen  "Allowing Selenium for incoming connections port: $port"
    $port=$(Get-ExternalIP).port
    netsh advfirewall firewall add rule name=selenium action=allow dir=in localport=$port protocol=TCP
}

Function Install-SP1(){
    Write-Host -ForegroundColor DarkGreen  "Installing SP1"
    Start-process -Wait -Path D:\toinstall\sp1-x86.exe  -ArgumentList "/unattend /norestart"
}

Function Get-ExternalIP(){
    $namespace = 'root\CIMV2'
    $obj= Get-WmiObject -class Win32_Bios -computername 'LocalHost' -namespace $namespace
    $split=$obj.SerialNumber.split('_')
    $ret=New-Object -TypeName PSObject | Select-Object ip, port
    $ret.ip=$split[0]
    $ret.port=$split[1]
    if (!$ret.ip.Length -or !$ret.port.Length) {
        throw "Error: Cannot get External (Qemu host) IP address or Port"
    }
    return $ret
}

Function Preconfig() {
    if (!$(Test-Path "C:\preconfigured")) {
        #Install-Drivers
        Enable-RDP
        Install-GuestAdditions
        #Wait-Net
        # Make-NetworksPrivate #needs more time after configuration to run suceessfully
        #Install-SP1
        ApplyTLSv12PartFix # also needs KB3191566 to work
        #Upgrade-PowerShellV5 # KB3191566
        Add-ToStartup -name "Setup" -value "$PWSH -ExecutionPolicy Bypass -File D:\start.ps1"
        New-Item -Path "C:\preconfigured" -ItemType File
        Restart-Computer
        Exit
    }
}

$CONFIGDRIVE="D:"
Set-Location "D:\"
$INSTALLDIR="D:\toinstall"
$TMP_DIR = "$env:SystemRoot\toinstall"
$DRIVERS_DIR="D:\drivers"
$PWSH="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

New-Item -Force -Path $TMP_DIR -type directory
#Copy-Item -Force -Recurse -Path "${CONFIGDRIVE}/*" -Destination "C:\config_iso\"
Start-Transcript -Append -Force -Path C:\log1.txt
Preconfig 2>&1 >> C:\log.txt
#Wait-Net
Install-Java 2>&1 >> C:\log.txt
Install-IEDriver 2>&1 >> C:\log.txt
Install-SelemiumNode 2>&1 >> C:\log.txt
#Disable-Updates
#Stop-Computer -Force



Function Install-Chrome() {
    Write-Host -ForegroundColor DarkGreen "Installing chrome browser and chrome driver"
    RunAsIEUser -path "$TMP_DIR\chromeinstaller.exe" -arg " "
    #Move-Item -Force  "$env:LOCALAPPDATA\Google\Update"  "$env:LOCALAPPDATA\Google\UpdateRemoved"
}
#Install-Chrome
#>
