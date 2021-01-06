# Regex pattern for SIDs
$PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
 
# Get Username, SID, and location of ntuser.dat for all users
$ProfileList = gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object {$_.PSChildName -match $PatternSID} | 
    Select  @{name="SID";expression={$_.PSChildName}}, 
            @{name="UserHive";expression={"$($_.ProfileImagePath)\ntuser.dat"}}, 
            @{name="Username";expression={$_.ProfileImagePath -replace '^(.*[\\\/])', ''}}
 
# Get all user SIDs found in HKEY_USERS (ntuder.dat files that are loaded)
$LoadedHives = gci Registry::HKEY_USERS | ? {$_.PSChildname -match $PatternSID} | Select @{name="SID";expression={$_.PSChildName}}
 
# Get all users that are not currently logged
$UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select @{name="SID";expression={$_.InputObject}}, UserHive, Username
 
# Loop through each profile on the machine
Foreach ($item in $ProfileList) {
    # Load User ntuser.dat if it's not already loaded
    IF ($item.SID -in $UnloadedHives.SID) {
        reg load HKU\$($Item.SID) $($Item.UserHive) | Out-Null
    }
 
    #####################################################################
    # This is where you can read/modify a users portion of the registry 
 
    # Word
    New-Item -Path registry::HKEY_USERS\$($Item.SID)\Software\Policies\Microsoft\Office\16.0\Word\Security -Force
    Set-ItemProperty -Path registry::HKEY_USERS\$($Item.SID)\Software\Policies\Microsoft\Office\16.0\Word\Security -Name blockcontentexecutionfrominternet -Value 1 -Type DWord -Force
    
    # Excel
    New-Item -Path registry::HKEY_USERS\$($Item.SID)\Software\Policies\Microsoft\Office\16.0\Excel\Security -Force
    Set-ItemProperty -Path registry::HKEY_USERS\$($Item.SID)\Software\Policies\Microsoft\Office\16.0\Excel\Security -Name blockcontentexecutionfrominternet -Value 1 -Type DWord -Force
    
    # Powerpoint
    New-Item -Path registry::HKEY_USERS\$($Item.SID)\Software\Policies\Microsoft\Office\16.0\Powerpoint\Security -Force
    Set-ItemProperty -Path registry::HKEY_USERS\$($Item.SID)\Software\Policies\Microsoft\Office\16.0\Powerpoint\Security -Name blockcontentexecutionfrominternet -Value 1 -Type DWord -Force
    
    
    #####################################################################
 
    # Unload ntuser.dat        
    IF ($item.SID -in $UnloadedHives.SID) {
        ### Garbage collection and closing of ntuser.dat ###
        [gc]::Collect()
        reg unload HKU\$($Item.SID) | Out-Null
    }
}
