#Automatically implements the Account Policies -> Password Policies CIS recommended configuration for Windows 10 1809

#1.1 Password Policies
#1.1.1 Ensure 'Enforce password history' is set to '24 or more password(s)’
#1.1.2 Ensure 'Maximum password age' is set to '60 or fewer days, but not 0’
#1.1.3 Ensure 'Minimum password age' is set to '1 or more day(s)’
#1.1.4 Ensure 'Minimum password length' is set to '14 or more character(s)’
#1.1.5 Ensure 'Password must meet complexity requirements' is set to 'Enabled'
#1.1.6 Ensure 'Store passwords using reversible encryption' is set to 'Disabled'

#AUTHOR 
#Adam Whitman


#change the password history to 24. Users cannot use the previous passwords used for user login
#the recommnded setting is 24 passwords logged by the password history 
	$pwhistory = 24
    net accounts /uniquepw:$pwhistory
    
#changes the password age in days before a new password must be configured by the user.
#The recommended state for this setting is 60 or fewer days, but not 0
    $maxpwagedays = 30
	net accounts /maxpwage:$maxpwagedays

#determines the number of days that you must use a password before you can change it.
#The recommended state for this setting is: 1 or more day(s).
    $minpwagedays = 1
    net accounts /minpwage:$minpwagedays


#determines the least number of characters that make up a password for a user account.
#The recommended state for this setting is: 14 or more character(s).
    $minpwlenchar = 14
    net accounts /minpwlen:$minpwlenchar


#enables password complexity requirements when user created new password 
    secedit /export /cfg c:\secpol.cfg
    (gc C:\secpol.cfg).replace("PasswordComplexity", "PasswordComplexity = 1") | Out-File C:\secpol.cfg
    secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
    rm -force c:\secpol.cfg -confirm:$false


#disables Passwords that are stored with reversible encryption are essentially the same as plaintext versions of the passwords.
    secedit /export /cfg c:\secpol.cfg
    (gc C:\secpol.cfg).replace("ClearTextPassword", "ClearTextPassword = 0") | Out-File C:\secpol.cfg
    secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
    rm -force c:\secpol.cfg -confirm:$false
