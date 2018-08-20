# Recipe 1.1 - Installing RSAT Tools
#
# Uses: DC1, SRV1, CL1

# Run From CL1


#  Step 0 - Setup CL1 for first time
#0.1  Set execution Policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force
# 0.2 Create Local Foo folder
New-Item c:\foo -ItemType Directory -Force
# 0.3 Create profile
New-Item $profile -Force
'# Profile file created by recipes'  | OUT-File $profile
"# Profile for [$($host.name)]"      | OUT-File $profile -Append
''                                   | OUT-File $profile -Append
'#  CD to C:\Foo'                    | OUT-File $profile -Append
'Set-Location -Path C:\Foo'          | OUT-File $profile -Append
''                                   | OUT-File $profile -Append
'# Set an alias'                     | Out-File $Profile -Append
'Set-Alias gh get-help'              | Out-File $Profile -Append
Notepad $Profile
# 0.4 Update Help
Update-Help -Force

# 1. Get all available PowerShell commands
$CommandsBeforeRSAT = Get-Command -Module *
$CountBeforeRSAT    = $CommandsBeforeRSAT.Count
Write-Output "On Host: [$(hostname)]"
"Commands available before RSAT installed: [$CountBeforeRSAT]"

# 2. Examine the types of commands returned by Get-Command
$CommandsBeforeRSAT | Get-Member |
    Select-Object -ExpandProperty TypeName -Unique


# 3. Get the collection of PowerShell modules and a count of 
#    modules beore adding the RSAT tools
$ModulesBeforeRSAT = Get-Module -ListAvailable 
$CountOfModulesBeforeRSAT = $ModulesBeforeRSAT.count
"$CountOfModulesBeforeRSAT modules are installed prior to adding RSAT"

# 4. Get Windows Client Version and Hardware platform
$Key      = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$CliVer   = (Get-ItemProperty -Path $Key).ReleaseId
$Platform = $ENV:PROCESSOR_ARCHITECTURE
"Windows Client Version : $CliVer"
"Hardware Platform      : $Platform"


# 5. Create URL for download file
#    NB: only works with 1709 and 1803.
$LP1 = 'https://download.microsoft.com/download/1/D/8/1D8B5022-5477-4B9A-8104-6A71FF9D98AB/'
$Lp180364 = 'WindowsTH-RSAT_WS_1803-x64.msu'
$Lp170964 = 'WindowsTH-RSAT_WS_1709-x64.msu'
$Lp180332 = 'WindowsTH-RSAT_WS_1803-x86.msu'
$Lp170932 = 'WindowsTH-RSAT_WS_1709-x86.msu'
If     ($CliVer -eq 1803 -and $Platform -eq 'AMD64') {$DLPath = $Lp1 + $lp180364}
ELSEIf ($CliVer -eq 1709 -and $Platform -eq 'AMD64') {$DLPath = $Lp1 + $lp170964}
ElseIf ($CliVer -eq 1803 -and $Platform -eq 'X86')   {$DLPath = $Lp1 + $lp180332}
ElseIf ($CliVer -eq 1709 -and $platform -eq 'x86')   {$DLPath = $Lp1 + $lp170932}
Else {"Version $cliver - unknown"; return}
"RSAT MSU file to be downloaded:"
$DLPath

# 6. Use BITs to download the file
$DLFile = 'C:\foo\Rsat.msu'
Start-BitsTransfer -Source $DLPath -Destination $DLFile

# 7. Check authenticode signature
$Authenticatefile = Get-AuthenticodeSignature $DLFile
If ($Authenticatefile.status -NE "Valid")
  {'File downloaded fails authenticode check'}
Else
  {'Downloaded file passes authenticode check'}

# 8. Install the RSAT tools
$WusaArguments = $DLFile + " /quiet"
"Installing RSAT for Windows 10 - please wait"
Start-Process -FilePath "C:\Windows\System32\wusa.exe" -ArgumentList $WusaArguments -Wait

# 9. Now that RSAT features are installed, see what commands are available on the client:
$CommandsAfterRSAT        = Get-Command -Module *
$COHT1 = @{
  ReferenceObject  = $CommandsBeforeRSAT
  DifferenceObject = $CommandsAfterRSAT
}
# NB: This is quite slow
$DiffC = Compare-Object @COHT1
"$($DiffC.count) Commands added with RSAT"

  
# 10. Check how many modules are now available:
$ModulesAfterRSAT        = Get-Module -ListAvailable 
$CountOfModulesAfterRsat = $ModulesAfterRSAT.count
$COHT2 = @{
  ReferenceObject  = $ModulesBeforeRSAT
  DifferenceObject = $ModulesAfterRSAT
}
$DiffM = Compare-Object @COHT2
"$($DiffM.count) Modules added with RSAT to CL1"
"$CountOfModulesAfterRsat modules now available on CL1"

# 11. Display modules added to CL1
"$($DiffM.count) modules added With RSAT tools to CL1"
$DiffM | Format-Table InputObject -HideTableHeaders

###  NOW Add RSAT to Server

# 12. Get Before CountS
$FSB1 = {Get-WindowsFeature}
$FeaturesSRV1 = Invoke-Command -ComputerName SRV1 -ScriptBlock $FSB1
$FeaturesSRV2 = Invoke-Command -ComputerName SRV2 -ScriptBlock $FSB1
$FeaturesDC1  = Invoke-Command -ComputerName DC1  -ScriptBlock $FSB1
$IFSrv1 = $FeaturesSRV1 | where installed
$IFSrv2 = $FeaturesSRV2 | where installed
$IFDC1  = $FeaturesDC1  | where installed 
$RSFSrv1 = $FeaturesSRV1 | where installed | where name -match 'RSAT'
$RFSSrv2 = $FeaturesSRV2 | where installed | where name -match 'RSAT'
$RFSDC1  = $FeaturesDC1  | where installed | where name -match 'RSAT'

# 13. Display results
"Before Installat
ion of RSAT tools on DC1, SRV1"
"$($IFDC1.count) features installed on DC1"
"$($RFSDC1.count) RSAT features installed on DC1"
"$($IFSRV1.count) features installed on SRV1"
"$($RFSSRV1.count) RSAT features installed on SRV1"
"$($IFSRV2.count) features installed on SRV2"
"$($RFSSRV2.count) RSAT features installed on SRV2"

# 14.  Just add the RSAT tools to Servers DC1, SRV1
$InstallSB = {
  Get-WindowsFeature -Name *RSAT* | Install-WindowsFeature
}
Invoke-Command -ComputerName DC1, SRV1 -ScriptBlock $InstallSB

# 15 restart DC1, SRV1
Restart-Computer -ComputerName DC1, SRV1 -Force -Wait -for PowerShell

# 16. Look at RSAT tools on SRV1 vs DC1, SRV2
$FSB2 = {Get-WindowsFeature}
$FeaturesSRV1 = Invoke-Command -ComputerName SRV1 -ScriptBlock $FSB2
$FeaturesSRV2 = Invoke-Command -ComputerName SRV2 -ScriptBlock $FSB2
$FeaturesDC1  = Invoke-Command -ComputerName DC1  -ScriptBlock $FSB2
$IFSrv1 = $FeaturesSRV1 | where installed
$IFSrv2 = $FeaturesSRV2 | where installed
$IFDC1  = $FeaturesDC1  | where installed 
$RSFSrv1 = $FeaturesSRV1 | where installed | where name -match 'RSAT'
$RFSSrv2 = $FeaturesSRV2 | where installed | where name -match 'RSAT'
$RFSDC1  = $FeaturesDC1  | where installed | where name -match 'RSAT'
"After Installation of RSAT tools on DC1, SRV1"
"$($IFDC1.count) features installed on DC1"
"$($RFSDC1.count) RSAT features installed on DC1"
"$($IFSRV1.count) features installed on SRV1"
"$($RFSSRV1.count) RSAT features installed on SRV1"
"$($IFSRV2.count) features installed on SRV2"
"$($RFSSRV2.count) RSAT features installed on SRV2"

# Display features added to DC1 that are not added to SRV2

Compare-Object -ReferenceObject $FeaturesDC1 -DifferenceObject $FeaturesSRV2 |
 Select -Expand Inputobject
