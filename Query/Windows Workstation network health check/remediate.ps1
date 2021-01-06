###########################
#Script developed to get a basic understanding of a remote machine for helpdesk to look at and preemptively troubleshoot issues
#wifi signal test
$wifi = @()
For ($i=0; $i -le 5; $i++) {
$wifiloop =(netsh wlan show interfaces) -Match '^\s+Signal' -Replace '^\s+Signal\s+:\s+',''
    $wifi += $wifiloop
Start-Sleep -s 2
    }
###########################
#ping test to googles DNS, looking for packet drop and latency
$ping = Ping -n 10 8.8.8.8  | Select-String -Pattern 'Packets' -Context 0,3
$ping = $ping -replace ":", ""
$ping = $ping -replace "Approximate round trip times in milli-seconds", ""

###########################
#Trace route to googles DNS, looking for high latency at what hop
$trace = tracert 8.8.8.8 | Select-String -Pattern {\d{2,4} ms}
$tracert = if (!$trace) {echo "Trace: All under 10ms, OK"}
else {echo "Slow Trace Routes: $trace"}

###########################
#Total machine uptime over days
$uptime = (get-date) - (gcim Win32_OperatingSystem).LastBootUpTime
$totaluptime = $uptime.TotalDays.ToString("#,0.00")
###########################
#Amount of free RAM available and CPU usage over 10 seconds
$totalRam = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum
$a = 1
$RamCPU = 
	while($a -le 2) 
    {
    $cpuTime = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $availMem = (Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue
    $availMem2 = ($availMem / 1048)
    ' AVG CPU: ' + $cpuTime.ToString("#,0.0") + '%, Avail. Mem.: ' + $availMem2.ToString("#,0.00") + 'GB (' + (104857600 * $availMem / $totalRam).ToString("#,0.0") + '%)'
    $a++
    Start-Sleep -s 5
	}
###########################
#results writing to activity log
Write-Output "Days of Uptime: $totaluptime" '~'
Write-Output "Wifi signal over time: $wifi" '~'
Write-Output "$ping" '~'
Write-Output "$RamCPU" '~'
Write-Output "$tracert"
