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

echo ==============================================
echo 子磁盘B: %ChildDisk%
echo ==============================================

:: 1.强制分离磁盘，防止占用
echo [1/5] 强制分离虚拟磁盘...
(
echo select vdisk file="%ChildDisk%"
echo detach vdisk  
) | diskpart  
if !errorlevel! neq 0 (
    echo 【警告】分离磁盘异常，继续执行...
)

:: 2.导出子盘信息，提取【父盘A路径】
echo [2/5] 读取父磁盘A信息...
(
echo select vdisk file="%ChildDisk%"
echo detail vdisk
) | diskpart > "%WorkTmp%"

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

:: 3.执行合并上一层 depth=1  —— 修复：使用 diskpart /s 捕获真实错误
echo [3/5] 开始合并 B → A (depth=1)...

set "mergeScript=%temp%\merge_tmp_%random%.txt"
echo select vdisk file="%ChildDisk%" > "%mergeScript%"
echo merge vdisk depth=1 >> "%mergeScript%"

diskpart /s "%mergeScript%"

if !errorlevel! neq 0 (
    echo 【致命错误】合并失败！立即终止，防止数据损坏
    del /f /q "%mergeScript%" 2>nul
    pause>nul
    exit /b 3
)

del /f /q "%mergeScript%" 2>nul
echo 合并执行成功

:: STEP
echo [1/5] 收缩被压缩的磁盘 %ChildDisk% ...
dir %ChildDisk%
(
echo select vdisk file="%ChildDisk%"
echo COMPACT vdisk
) | diskpart  

if !errorlevel! neq 0 (
    echo 【警告】 收缩失败

)
echo 收缩执行成功
dir %ChildDisk%


:: 5.完成
echo ==============================================
echo 【全部完成】
echo 1.已合并：%ChildName% 合并至上层父盘 %ParentFull%
echo 2.两个文件名都不动
echo ==============================================
pause>nul
