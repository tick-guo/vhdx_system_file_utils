# 创建一个子vhdx , 子一个入参为 原始a.vhdx, 创建 a_child.vhdx,  脚本末尾要暂停,让用户查看到结果信息.
# 创建一个子vhdx , 子一个入参为 原始a.vhdx, 创建 a_child.vhdx,  脚本末尾要暂停,让用户查看到结果信息.

# 检查是否提供了参数
if ($args.Count -eq 0) {
    Write-Host "请将 VHDX 文件拖拽到此脚本上执行" -ForegroundColor Yellow
    Write-Host "用法: .\VHDX_拖入创建一个子vhdx.ps1 <父VHDX文件路径>" -ForegroundColor Cyan
    pause
    exit 1
}

# 获取父 VHDX 文件路径
$ParentVhdx = $args[0]

# 验证文件是否存在
if (-not (Test-Path $ParentVhdx)) {
    Write-Host "错误: 文件不存在 - $ParentVhdx" -ForegroundColor Red
    pause
    exit 1
}

# 验证文件扩展名
$Extension = [System.IO.Path]::GetExtension($ParentVhdx).ToLower()
if ($Extension -ne ".vhdx") {
    Write-Host "错误: 请选择 .vhdx 格式的文件" -ForegroundColor Red
    pause
    exit 1
}

# 生成子 VHDX 文件路径
$Directory = [System.IO.Path]::GetDirectoryName($ParentVhdx)
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($ParentVhdx)
$ChildVhdx = Join-Path $Directory "${BaseName}_child.vhdx"

# 检查子 VHDX 是否已存在
if (Test-Path $ChildVhdx) {
    Write-Host "警告: 子 VHDX 文件已存在 - $ChildVhdx" -ForegroundColor Yellow
    $Overwrite = Read-Host "是否覆盖? (Y/N)"
    if ($Overwrite -ne 'Y' -and $Overwrite -ne 'y') {
        Write-Host "操作已取消" -ForegroundColor Cyan
        pause
        exit 0
    }
    Remove-Item $ChildVhdx -Force
}

Write-Host "==============================================" -ForegroundColor Green
Write-Host "开始创建子 VHDX" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host "父 VHDX: $ParentVhdx" -ForegroundColor White
Write-Host "子 VHDX: $ChildVhdx" -ForegroundColor Cyan
Write-Host ""

try {
    # 检查 Hyper-V 模块是否可用
    $HyperVModule = Get-Module -ListAvailable -Name Hyper-V
    if (-not $HyperVModule) {
        Write-Host "错误: 未找到 Hyper-V PowerShell 模块" -ForegroundColor Red
        Write-Host "请确保已启用 Hyper-V 功能" -ForegroundColor Yellow
        pause
        exit 1
    }

    # 导入 Hyper-V 模块
    Import-Module Hyper-V -ErrorAction Stop

    Write-Host "[1/2] 正在创建差异 VHDX..." -ForegroundColor Yellow

    # 使用 New-VHD 创建差异磁盘
    New-VHD -Path $ChildVhdx -ParentPath $ParentVhdx -Differencing -ErrorAction Stop | Out-Null

    Write-Host "[2/2] 子 VHDX 创建成功!" -ForegroundColor Green
    Write-Host ""

    # 显示创建的子 VHDX 文件信息
    $ChildFileInfo = Get-Item $ChildVhdx
    Write-Host "文件信息:" -ForegroundColor Cyan
    Write-Host "  文件名: $($ChildFileInfo.Name)" -ForegroundColor White
    Write-Host "  路径: $($ChildFileInfo.FullName)" -ForegroundColor White
    Write-Host "  大小: $([math]::Round($ChildFileInfo.Length / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "  创建时间: $($ChildFileInfo.CreationTime)" -ForegroundColor White
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "操作完成!" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
}
catch [System.Management.Automation.CommandNotFoundException] {
    Write-Host "错误: New-VHD 命令不可用" -ForegroundColor Red
    Write-Host "请确保已安装 Hyper-V 角色或 Windows 功能" -ForegroundColor Yellow
    pause
    exit 1
}
catch {
    Write-Host "发生异常: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "详细信息: $($_.Exception.InnerException.Message)" -ForegroundColor Gray
    }
    pause
    exit 1
}

pause




