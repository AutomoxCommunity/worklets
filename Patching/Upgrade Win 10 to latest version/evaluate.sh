
if ((Test-Path $iso) -eq $true)
    {Remove-Item $iso
}

$osversion = (Get-Item "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue('ReleaseID')

if (($osversion -lt "2004")) 
	{exit 1
		}
else 
	{exit 0
		}
