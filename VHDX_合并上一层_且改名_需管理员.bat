@echo off
rem chcp 65001 >nul
setlocal enabledelayedexpansion

:: ==============================================
::  使用方法：直接把 差分子盘.vhdx 拖入本bat图标
::  功能：自动合并上一层、改名续链、失败立即终止
:: ==============================================

:: 检查是否拖入文件
if "%~1"=="" (
    echo 【错误】请将差分VHDX文件拖入此脚本！
    pause>nul
    exit /b 1
)

set "ChildDisk=%~f1"
set "ChildName=%~nx1"
set "WorkTmp=%temp%\vdisk_tmp_%random%.txt"
:: 统一使用一个带随机数的diskpart临时脚本文件
set "DiskPartScript=%temp%\diskpart_script_%random%.txt"

echo ==============================================
echo 子磁盘B: %ChildDisk%
echo ==============================================

:: 1.强制分离磁盘，防止占用
echo [1/5] 强制分离虚拟磁盘...

echo select vdisk file="%ChildDisk%" > "%DiskPartScript%"
echo detach vdisk   >> "%DiskPartScript%"
diskpart /s "%DiskPartScript%"   
if !errorlevel! neq 0 (
    echo 【警告】分离磁盘异常，继续执行...
)

:: 2.导出子盘信息，提取【父盘A路径】
echo [2/5] 读取父磁盘A信息...

echo select vdisk file="%ChildDisk%" > "%DiskPartScript%"
echo detail vdisk >> "%DiskPartScript%"
diskpart /s "%DiskPartScript%" > "%WorkTmp%"

:: 解析父路径：查找 "父虚拟磁盘" / "Parent virtual disk"
set "ParentDisk="
for /f "tokens=1,* delims=:" %%a in (%WorkTmp%) do (
    echo "%%a" | findstr /i "父文件名" >nul
    if !errorlevel! equ 0 (
        set "ParentDisk=%%b"
        set "ParentDisk=!ParentDisk:~1!"
    )
)

del /f /q "%WorkTmp%" >nul 2>&1

if not defined ParentDisk (
    echo 【致命错误】未读取到上层父磁盘，当前已是基础盘，终止！
    pause>nul
    exit /b 2
)
echo 上层父磁盘A: !ParentDisk!

:: 3.执行合并上一层 depth=1
echo [3/5] 开始合并 B → A (depth=1)...

echo select vdisk file="%ChildDisk%" > "%DiskPartScript%"
echo merge vdisk depth=1 >> "%DiskPartScript%"
diskpart /s "%DiskPartScript%"
if !errorlevel! neq 0 (
    echo 【致命错误】合并失败！立即终止，防止数据损坏
    pause>nul
    exit /b 3
)
echo 合并执行成功

:: 4.改名逻辑：
:: 原A → 改为 原B名称
:: 原B → 改为 B-已合并可删除.vhdx
echo [4/5] 执行续链改名...
set "ParentFull=!ParentDisk!"
set "ChildFull=%ChildDisk%"
set "ChildDir=%~dp1"
set "ChildNoExt=%~n1"
set "ChildExt=%~x1"

:: 原子盘B 改名 加后缀
ren "%ChildFull%" "%ChildNoExt%-已合并可删除%ChildExt%"
if !errorlevel! neq 0 (
    echo 【致命错误】子盘标记改名失败，终止！
    pause>nul
    exit /b 5
)

:: 父盘A 改名成 子盘B原名
ren "!ParentFull!" "%ChildName%"
if !errorlevel! neq 0 (
    echo 【致命错误】父盘改名失败，终止！
    pause>nul
    exit /b 4
)

:: 5.完成
echo ==============================================
echo 【全部完成】
echo 1.已合并：%ChildName% 合并至上层父盘 %ParentFull%
echo 2.原父盘A %ParentFull% 已顶替为：%ChildName% （下级链自动续接）
echo 3.原子盘B 已标记：%ChildNoExt%-已合并可删除%ChildExt%
echo 可确认虚拟机正常启动后，删除带【已合并可删除】文件
echo ==============================================
pause>nul
