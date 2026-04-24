@echo off
rem chcp 65001 >nul
setlocal enabledelayedexpansion

:: ==============================================
::  使用说明：直接拖拽 .vhdx 文件到bat图标
::  功能：自动合并上一层、压缩文件，失败则终止
:: ==============================================

:: 检查是否传入文件参数
if "%~1"=="" (
    echo 请将需要处理的VHDX文件拖拽到本批处理文件上！
    pause>nul
    exit /b 1
)

set "ChildDisk=%~f1"
set "ChildName=%~nx1"
set "WorkTmp=%temp%\vdisk_detail_%random%.txt"
:: 统一使用一个带随机数的diskpart临时脚本文件
set "DiskPartScript=%temp%\diskpart_script_%random%.txt"

echo ==============================================
echo 处理目标: %ChildDisk%
echo ==============================================

:: 1.强制分离虚拟磁盘（终止占用）
echo [1/5] 强制分离虚拟磁盘...
:: 清空并写入第一步diskpart指令
echo select vdisk file="%ChildDisk%" > "%DiskPartScript%"
echo detach vdisk >> "%DiskPartScript%"
:: 执行diskpart脚本
diskpart /s "%DiskPartScript%"  
if !errorlevel! neq 0 (
    echo 警告：分离虚拟磁盘失败 ...
    rem goto Cleanup
)

:: 2.获取父磁盘信息（提取父盘路径）
echo [2/5] 提取父磁盘A的信息...
:: 清空并写入第二步diskpart指令
echo select vdisk file="%ChildDisk%" > "%DiskPartScript%"
echo detail vdisk >> "%DiskPartScript%"
:: 执行并输出到临时详情文件
diskpart /s "%DiskPartScript%" > "%WorkTmp%"

:: 解析父盘路径（匹配"父文件名"  ）
set "ParentDisk="
for /f "tokens=1,* delims=:" %%a in (%WorkTmp%) do (
    echo "%%a" | findstr /i "父文件名" >nul
    if !errorlevel! equ 0 (
        set "ParentDisk=%%b"
        set "ParentDisk=!ParentDisk:~1!"  :: 去除开头空格
    )
)

:: 删除详情临时文件
del /f /q "%WorkTmp%" >nul 2>&1

if not defined ParentDisk (
    echo 错误：未提取到合并源盘信息，当前已是根磁盘，终止！
    goto Cleanup
)
echo 合并源盘A: !ParentDisk!

:: 3.执行合并操作（depth=1）
echo [3/5] 开始合并 B 到 A (depth=1)...
:: 清空并写入第三步diskpart指令
echo select vdisk file="%ChildDisk%" > "%DiskPartScript%"
echo merge vdisk depth=1 >> "%DiskPartScript%"
:: 执行合并
diskpart /s "%DiskPartScript%"

if !errorlevel! neq 0 (
    echo 严重错误：合并失败，终止操作！
    goto Cleanup
)
echo 合并执行成功

:: 4.压缩虚拟磁盘
echo [4/5] 正在压缩磁盘 %ChildDisk% ...
dir %ChildDisk%
:: 清空并写入第四步diskpart指令
echo select vdisk file="%ChildDisk%" > "%DiskPartScript%"
echo COMPACT vdisk >> "%DiskPartScript%"
:: 执行压缩
diskpart /s "%DiskPartScript%"  

if !errorlevel! neq 0 (
    echo 警告：压缩操作失败
)
echo 压缩执行完成
dir %ChildDisk%

:: 5.完成提示
echo ==============================================
echo 全部操作完成！
echo 1.已将子盘 %ChildName% 合并至源盘 %ParentDisk%
echo 2.子盘已完成压缩优化
echo ==============================================

:: 清理临时文件
:Cleanup
if exist "%DiskPartScript%" del /f /q "%DiskPartScript%" 2>nul
if exist "%WorkTmp%" del /f /q "%WorkTmp%" 2>nul
pause>nul
exit /b 0

