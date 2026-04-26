@echo off
rem 4. VHDX 信息查看
rem 显示VHDX详细信息（大小、类型、父磁盘等）
rem 查看VHDX层级关系树
rem 检查VHDX健康状态
setlocal enabledelayedexpansion

:: 检查是否传入文件
if "%~1"=="" (
    echo 请将源VHDX文件拖拽到本脚本上运行
    pause>nul
    exit /b 1
)

set "TargetVHDX=%~f1"
set "WorkTmp=%temp%\vhdx_info_%random%.txt"
set "DiskPartScript=%temp%\diskpart_info_%random%.txt"

echo ==============================================
echo VHDX 信息查看工具
echo ==============================================
echo 目标文件: %TargetVHDX%
echo.

:: 1. 检查文件是否存在
echo [1/4] 检查文件存在性...
if not exist "%TargetVHDX%" (
    echo 【错误】文件不存在！
    goto Cleanup
)
echo 文件存在
echo.

:: 2. 获取文件基本信息
echo [2/4] 文件基本信息...
for %%F in ("%TargetVHDX%") do (
    echo   文件名: %%~nxF
    echo   完整路径: %%~fF
    echo   文件大小: %%~zF 字节
    call :FormatFileSize %%~zF
    echo   创建时间: %%~tF
    echo   驱动器: %%~dF
    echo   目录: %%~dpF
)
echo.

:: 3. 使用diskpart获取VHDX详细信息
echo [3/4] VHDX 磁盘详细信息...
echo select vdisk file="%TargetVHDX%" > "%DiskPartScript%"
echo detail vdisk >> "%DiskPartScript%"
diskpart /s "%DiskPartScript%" > "%WorkTmp%" 2>&1

if !errorlevel! neq 0 (
    echo 【警告】无法读取VHDX详细信息（可能文件损坏或格式不支持）
    type "%WorkTmp%"
    goto CheckHealth
)

:: 解析并显示diskpart输出
set "ParentPath="
set "AttachState="
set "DiskType="
set "FileSize="
set "MaxSize="

echo --- DiskPart 详细信息 ---
type "%WorkTmp%"
echo.

:: 提取父磁盘路径
for /f "tokens=1,* delims=:" %%a in (%WorkTmp%) do (
    echo "%%a" | findstr /i "父" >nul
    if !errorlevel! equ 0 (
        set "ParentPath=%%b"
        set "ParentPath=!ParentPath:~1!"
    )
)

echo.

:: 4. 检查VHDX层级关系
:CheckHealth
echo [4/4] VHDX 层级关系分析...
echo.

if defined ParentPath (
    echo 当前磁盘类型: 子差异磁盘 !TargetVHDX!
    echo.
    call :ShowHierarchy "!TargetVHDX!" 1

) else (
    echo 当前磁盘类型: 基础磁盘（无父磁盘）
    echo.
)

echo.
echo ==============================================
echo 信息查看完成
echo ==============================================

goto Cleanup

:: 显示层级关系的递归函数
:ShowHierarchy
set "CurrentDisk=%~1"
set "IndentLevel=%~2"
set "Indent="

:: 生成缩进
for /l %%i in (1,1,%IndentLevel%) do set "Indent=  !Indent!"

:: 构建临时脚本查询当前磁盘的父磁盘
set "TempScript=%temp%\vhdx_hierarchy_%random%.txt"
set "TempOutput=%temp%\vhdx_hierarchy_out_%random%.txt"

echo select vdisk file="%CurrentDisk%" > "!TempScript!"
echo detail vdisk >> "!TempScript!"
diskpart /s "!TempScript!" > "!TempOutput!" 2>&1

set "NextParent="
for /f "tokens=1,* delims=:" %%a in (!TempOutput!) do (
    echo "%%a" | findstr /i "父" >nul
    if !errorlevel! equ 0 (
        set "NextParent=%%b"
        set "NextParent=!NextParent:~1!"
    )
)

del /f /q "!TempScript!" 2>nul
del /f /q "!TempOutput!" 2>nul

if defined NextParent (
    :: 检查是否为设备路径，如果是则转换为盘符路径
    echo "!NextParent!" | findstr /i "\\Device\\HarddiskVolume" >nul
    if !errorlevel! equ 0 (
        call :ConvertDevicePath "!NextParent!" NextParent
    )

    echo !Indent!└─ 父磁盘: !NextParent!
    if exist "!NextParent!" (
        call :ShowHierarchy "!NextParent!" !IndentLevel!+1
    ) else (
        echo !Indent!   x 【断裂】父磁盘不存在: !NextParent!
    )
) else (
    echo !Indent!└─ [根磁盘]
)

goto :eof

:: 将设备路径转换为盘符路径（使用PowerShell）
:ConvertDevicePath
setlocal
set "DevicePath=%~1"

:: 从设备路径提取 HarddiskVolumeXX 部分
set "VolPattern="
for /f "tokens=2 delims=\" %%a in ("!DevicePath!") do (
    set "VolPattern=%%a"
)

if not defined VolPattern (
    endlocal & set "%~2=%DevicePath%"
    goto :eof
)

:: 创建临时PowerShell脚本
set "PsScript=%temp%\convert_devpath_%random%.ps1"

:: echo "%PsScript%"


echo Add-Type @' > "%PsScript%"
echo using System; >> "%PsScript%"
echo using System.Runtime.InteropServices; >> "%PsScript%"
echo public class Kernel32 { >> "%PsScript%"
echo     [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] >> "%PsScript%"
echo     public static extern bool QueryDosDevice(string lpDeviceName, char[] lpTargetPath, int ucchMax); >> "%PsScript%"
echo } >> "%PsScript%"
echo '@ >> "%PsScript%"
echo. >> "%PsScript%"
echo function Get-DevicePath { >> "%PsScript%"
echo     param([string]$DriveLetter) >> "%PsScript%"
echo     $buf = New-Object char[] 260 >> "%PsScript%"
echo     $ok = [Kernel32]::QueryDosDevice($DriveLetter, $buf, $buf.Length) >> "%PsScript%"
echo     if (-not $ok) { return $null } >> "%PsScript%"
echo     return [string]::Join("", $buf).TrimEnd("`0") >> "%PsScript%"
echo } >> "%PsScript%"
echo. >> "%PsScript%"
echo function Get-DriveLetterFromDevice { >> "%PsScript%"
echo     param([string]$DevicePath) >> "%PsScript%"
echo     Get-WmiObject Win32_Volume ^| ForEach-Object { >> "%PsScript%"
echo         $dl = $_.DriveLetter >> "%PsScript%"
echo         if (-not $dl) { return } >> "%PsScript%"
echo         $dev = Get-DevicePath $dl >> "%PsScript%"
echo         if ($dev -eq $DevicePath) { $dl } >> "%PsScript%"
echo     } >> "%PsScript%"
echo } >> "%PsScript%"
echo. >> "%PsScript%"
:: VolPattern=HarddiskVolumeolume14
echo $targetDevice = "\Device\%VolPattern%" >> "%PsScript%"
echo $result = Get-DriveLetterFromDevice -DevicePath $targetDevice >> "%PsScript%"
echo if ($result) { >> "%PsScript%"
echo     $converted = '%DevicePath%' -replace [regex]::Escape($targetDevice), $result >> "%PsScript%"
echo     Write-Output $converted >> "%PsScript%"
echo } else { >> "%PsScript%"
echo     Write-Output '%DevicePath%' >> "%PsScript%"
echo } >> "%PsScript%"


:: 执行PowerShell脚本并获取结果
for /f "usebackq delims=" %%p in (`powershell -ExecutionPolicy Bypass -File "%PsScript%" 2^>nul`) do (
    set "ConvertedPath=%%p"
)

:: 清理临时文件
del /f /q "%PsScript%" 2>nul

if defined ConvertedPath (
    endlocal & set "%~2=%ConvertedPath%"
) else (
    endlocal & set "%~2=%DevicePath%"
)
goto :eof

:: 格式化文件大小
:FormatFileSize
setlocal
set /a SizeBytes=%1
if %SizeBytes% LSS 1024 (
    echo   文件大小: %SizeBytes% B
    goto :FormatFileSizeEnd
)
if %SizeBytes% LSS 1048576 (
    set /a SizeKB=%SizeBytes%/1024
    echo   文件大小: !SizeKB! KB
    goto :FormatFileSizeEnd
)
if %SizeBytes% LSS 1073741824 (
    set /a SizeMB=%SizeBytes%/1048576
    echo   文件大小: !SizeMB! MB
    goto :FormatFileSizeEnd
)
set /a SizeGB=%SizeBytes%/1073741824
set /a "Remainder=(%SizeBytes% %% 1073741824) * 100 / 1073741824"
echo   文件大小: !SizeGB!.!Remainder! GB
:FormatFileSizeEnd
endlocal
goto :eof


:: 清理临时文件
:Cleanup
if exist "%DiskPartScript%" del /f /q "%DiskPartScript%" 2>nul
if exist "%WorkTmp%" del /f /q "%WorkTmp%" 2>nul
pause>nul
exit /b 0
