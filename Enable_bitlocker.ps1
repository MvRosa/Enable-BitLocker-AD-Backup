Enable-PSRemoting -Force
Initialize-Tpm -AllowClear -AllowPhysicalPresence
Enable-TpmAutoProvisioning

$TPM = Get-WmiObject win32_tpm -Namespace root\cimv2\security\microsofttpm | Where-Object {$_.IsEnabled().Isenabled -eq 'True'} -ErrorAction SilentlyContinue
$WindowsVer = Get-WmiObject -Query 'select * from Win32_OperatingSystem where (Version like "6.2%" or Version like "6.3%" or Version like "10.0%") and ProductType = "1"' -ErrorAction SilentlyContinue
$BitLockerReadyDrive = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
#Check if bitlocker is already active
$bitCheck = Get-BitLockerVolume -MountPoint $env:SystemDrive | Where-Object {$_.ProtectionStatus -eq 'Off'} -ErrorAction SilentlyContinue

 
#If all of the above prequisites are met, then create the key protectors, then enable BitLocker and backup the Recovery key to AD.
if ($WindowsVer -and $TPM -and $BitLockerReadyDrive -and $bitCheck) {
 
    #Creating the recovery key
    Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector
    
    #Adding TPM key
    Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector
    Start-Sleep -Seconds 15 #This is to give sufficient time for the protectors to fully take effect.
    
    #Enabling Encryption
    Start-Process 'manage-bde.exe' -ArgumentList " -on $env:SystemDrive -em aes256" -Verb runas -Wait
    
    #Getting Recovery Key GUID
    $RecoveryKeyGUID = (Get-BitLockerVolume -MountPoint $env:SystemDrive).keyprotector | Where-Object {$_.Keyprotectortype -eq 'RecoveryPassword'} | Select-Object -ExpandProperty KeyProtectorID
    
    #Backing up the Recovery to AD.
    Start-Process 'manage-bde.exe' -ArgumentList " -protectors $env:SystemDrive -adbackup -id $RecoveryKeyGUID" -Verb RunAS
    
    #Restarting the computer, to begin the encryption process
    #Restart-Computer
}
