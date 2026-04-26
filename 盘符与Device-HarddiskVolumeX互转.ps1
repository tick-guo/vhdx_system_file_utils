Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Kernel32 {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern bool GetVolumeNameForVolumeMountPoint(
        string lpszVolumeMountPoint,
        char[] lpszVolumeName,
        int cchBufferLength
    );

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern bool QueryDosDevice(
        string lpDeviceName,
        char[] lpTargetPath,
        int ucchMax
    );
}
"@

# ==============================================
# 函数1：盘符 → \Device\HarddiskVolumeXX
# ==============================================
function Get-DevicePath {
    param([string]$DriveLetter)  # 例如 J:
    $buf = New-Object char[] 260
    $ok = [Kernel32]::QueryDosDevice($DriveLetter, $buf, $buf.Length)
    if (-not $ok) { return $null }
    return [string]::Join("", $buf).TrimEnd("`0")
}

# ==============================================
# 函数2：\Device\HarddiskVolumeXX → 盘符
# ==============================================
function Get-DriveLetterFromDevice {
    param([string]$DevicePath)  # 例如 \Device\HarddiskVolume14

    Get-WmiObject Win32_Volume | ForEach-Object {
        $dl = $_.DriveLetter
        if (-not $dl) { return }
        $dev = Get-DevicePath $dl
        if ($dev -eq $DevicePath) { $dl }
    }
}

# 转换你的设备路径 → 盘符
Get-DriveLetterFromDevice -DevicePath "\Device\HarddiskVolume14"

# 反向：J: → \Device\HarddiskVolume14
Get-DevicePath -DriveLetter "J:"

pause 

