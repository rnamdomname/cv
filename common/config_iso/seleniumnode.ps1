$ErrorActionPreference = "Stop"
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

Function Wait-Net($Comp) {
    Write-Host -ForegroundColor Yellow "Waiting for network to become online"
    do {
        try {
            $ping = test-connection -comp $Comp -count 1 -Quiet
        }
        catch {
        }
    } until ($ping)
    Write-Host -ForegroundColor Yellow  "Connected"
}
Wait-Net -Comp 1.1.1.1 # bug with IPv6
Write-Host "Check network again (DNS)"
Wait-Net -Comp google.com
#Start-Transcript -Force -Path $env:USERPROFILE\Desktop\seleniumnodelog.txt
$java="$env:JAVA_HOME\bin\java.exe"
$path = "$env:ProgramFiles\Selenium\selenium-server.jar"
Write-Host -ForegroundColor Yellow "[ WARN ] Use FQDN: selenium-hub.grid, due to buggy QEMU SLIRP"
$hub = "selenium-hub.grid"

$e=$(Get-ExternalIP)
$ip=$e.ip
$port=$e.port
Start-Process $java -ArgumentList "-jar `"$path`" node --bind-host false --host $ip --port $port --hub $hub"



