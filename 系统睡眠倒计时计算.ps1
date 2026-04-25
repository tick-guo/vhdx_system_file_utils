# 中文字符
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class UserInput {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
}
"@
 
function Get-IdleTime {
    $l = New-Object UserInput+LASTINPUTINFO
    $l.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($l)
    [UserInput]::GetLastInputInfo([ref]$l) | Out-Null
    $tick = [Environment]::TickCount
    $idleMs = $tick - $l.dwTime
    return [math]::Floor($idleMs / 1000)
}


# 如果没有电池（台式机），默认使用 AC 模式; 暂固定台式机
$isBattery = $false


# 使用 powercfg 获取睡眠超时设置（最可靠的方式）
try {
    $planOutput = powercfg /getactivescheme
    $plan = ($planOutput -split ':')[1].Trim()
    $plan = ($plan -split ' ')[0].Trim()
    
    if ($isBattery) {
        $timeoutOutput = powercfg /query $plan SUB_SLEEP STANDBYIDLE
        $timeoutLine = $timeoutOutput | Where-Object { $_ -match '直流电源' }
        $sleepTimeout = [int]($timeoutLine -split ':')[1].Trim()
    } else {
        $timeoutOutput = powercfg /query $plan SUB_SLEEP STANDBYIDLE
        $timeoutLine = $timeoutOutput | Where-Object { $_ -match '交流电源' }
        # 单位秒
        $sleepTimeout = [int]($timeoutLine -split ':')[1].Trim()
    }
} catch {
    # 如果获取失败，默认为 0
    $sleepTimeout = 0
}

while ($true) {
    # 单位秒
    $idle = Get-IdleTime 
    # 单位秒 
    $remain = $sleepTimeout - $idle
    if ($remain -lt 0) { $remain = 0 }
    #cls
    Write-Host "当前空闲时间: $idle 秒"
    Write-Host "睡眠超时设定: $($sleepTimeout/60) 分钟"
    Write-Host "剩余睡眠倒计时: $remain 秒 ($([math]::Floor($remain/60)) 分 $($remain%60) 秒)"
    Write-Host "---------------------------------------------------"
    Start-Sleep 1
}

