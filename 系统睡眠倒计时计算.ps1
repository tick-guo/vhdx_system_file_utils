# 中文字符
# 检查是否具有管理员权限，如果没有则自动以管理员身份重新启动
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    # 不是管理员，重新启动脚本并请求提升权限
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit
    } else {
        Write-Host "错误: 此脚本需要管理员权限运行。" -ForegroundColor Red
        Write-Host "请右键点击脚本，选择'以管理员身份运行'" -ForegroundColor Yellow
        Read-Host "按回车键退出"
        exit
    }
}


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

# 设置控制台窗口大小
function Set-ConsoleSize {
    try {
        $ui = $Host.UI.RawUI

        # 设置窗口大小 (宽字符数, 高行数) - 可以根据需要调整
        $width = 40   # 宽度
        $height = 7   # 高度

        $newSize = New-Object System.Management.Automation.Host.Size($width, $height)
        $ui.WindowSize = $newSize

        # 设置缓冲区大小 (宽度必须大于或等于窗口宽度)
        $newBuffer = New-Object System.Management.Automation.Host.Size($width, 300)
        $ui.BufferSize = $newBuffer

        # 设置窗口标题
        $Host.UI.RawUI.WindowTitle = "系统睡眠倒计时监控"

        # 设置背景色和前景色（可选）
        # $ui.BackgroundColor = "Black"
        # $ui.ForegroundColor = "White"
    } catch {
        Write-Warning "无法设置控制台窗口大小: $_"
    }
}

# 添加窗口置顶功能的 API
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_SHOWWINDOW = 0x0040;

    public static void SetTopMost(bool topmost) {
        IntPtr hWnd = GetConsoleWindow();
        IntPtr pos = topmost ? HWND_TOPMOST : HWND_NOTOPMOST;
        SetWindowPos(hWnd, pos, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    }
}
"@

function Set-WindowTopMost {
    [WindowHelper]::SetTopMost($true)
}

function Test-MediaPlayWake {
    # 需要管理员权限
    $output = powercfg /requests
    $hasWake = $output | Where-Object { $_ -match 'Wake' }
    $hasAudio = $output | Where-Object { $_ -match 'Playing audio' }

    # 使用 -or 运算符
    if ($hasWake -or $hasAudio) {
        return $true
    }
    else {
        return $false
    }

}

Set-ConsoleSize
Set-WindowTopMost

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
    if (Test-MediaPlayWake) {
        $wakeMsg = "(有媒体播放,不会睡眠)"
    }
    else {
        $wakeMsg = "(无媒体播放)"
    }
    # 单位秒 
    $remain = $sleepTimeout - $idle
    if ($remain -lt 0) { $remain = 0 }
    cls
    Write-Host "当前空闲时间: $idle 秒 $wakeMsg"
    Write-Host "睡眠超时设定: $($sleepTimeout/60) 分钟"
    Write-Host "剩余睡眠倒计时: $remain 秒 ($([math]::Floor($remain/60)) 分 $($remain%60) 秒)"
    Write-Host "--------"
    Start-Sleep 1
}

