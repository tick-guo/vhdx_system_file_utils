@echo off
rem 创建一个子vhdx , 子一个入参为 原始a.vhdx, 创建 a_child.vhdx,
rem 脚本末尾要暂停,让用户查看到结果信息. 使用diskpart /s 命令

setlocal enabledelayedexpansion

:: ==============================================
::  使用说明：直接将 .vhdx 文件拖入本bat图标
::  功能：为指定的VHDX文件创建一个子差异磁盘
:: ==============================================

:: 检查是否传入文件
if "%~1"=="" (
    echo 请将源VHDX文件拖拽到本脚本上运行
    pause>nul
    exit /b 1
)

set "ParentDisk=%~f1"
set "ParentDir=%~dp1"
set "ParentName=%~n1"
set "ParentExt=%~x1"
set "ChildDisk=%ParentDir%%ParentName%_child%ParentExt%"
set "DiskPartScript=%temp%\diskpart_create_child_%random%.txt"

echo ==============================================
echo 父磁盘: %ParentDisk%
echo 子磁盘: %ChildDisk%
echo ==============================================

:: 1. 检查父磁盘是否存在
echo [1/3] 检查父磁盘文件...
if not exist "%ParentDisk%" (
    echo 【错误】父磁盘文件不存在！
    pause>nul
    exit /b 1
)
echo 父磁盘文件存在

:: 2. 检查子磁盘是否已存在
echo [2/3] 检查子磁盘是否已存在...
if exist "%ChildDisk%" (
    echo 【错误】子磁盘文件已存在，请先删除或重命名：%ChildDisk%
    pause>nul
    exit /b 2
)

:: 3. 使用diskpart创建子差异磁盘
echo [3/3] 创建子差异磁盘...

echo create vdisk file="%ChildDisk%" parent="%ParentDisk%" > "%DiskPartScript%"
diskpart /s "%DiskPartScript%"

if !errorlevel! neq 0 (
    echo 【错误】创建子磁盘失败！
    if exist "%DiskPartScript%" del /f /q "%DiskPartScript%" 2>nul
    pause>nul
    exit /b 3
)

echo 子磁盘创建成功！

:: 清理临时文件
if exist "%DiskPartScript%" del /f /q "%DiskPartScript%" 2>nul

:: 显示结果
echo ==============================================
echo 操作完成！
echo 父磁盘: %ParentDisk%
echo 子磁盘: %ChildDisk%
echo ==============================================
pause>nul
exit /b 0
