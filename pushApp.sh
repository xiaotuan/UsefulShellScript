#!/bin/bash

#
# 脚本用途：
#     用于将Android系统编译出来的 apk 文件导入到设备中
#

# 版本号
version="1.0.0"
# 应用安装位置，可以是 app 或 priv-app 值
installLocation="app"
# 最终要操作的设备
device=""
# 设备 ID，执行 adb devices 命令显示的设备 ID
deviceId=""
# 设备的 IP 地址
deviceIP=""
# 应用名称
appName=""
# 应用包名
packageName=""
# Activity名称
activityName=""
# 是否需要杀死应用
needKillApp=0
# 是否需要重启应用
needRestartApp=0

# 显示帮助文档
function showHelper() {
    echo ""
    echo "当前版本 $version"
    echo ""
    echo "使用方法： pushApp.sh [-i][-s][-a][-n][-p][-k][-r][-h]"
    echo "        -i: 设置应用安装位置，可以是 app 或 priv-app，默认 app"
    echo "        -s: 设置要操作的Android设备"
    echo "        -a: 设置WiFi连接的设备IP地址"
    echo "        -n: 设置安装应用的名字, 执行该脚本的目录下必须存在以应用名称命名的文件夹，该文件夹包含要导入的内容"
    echo "        -p: 设置应用的包名"
    echo "        -k: 是否杀死应用"
    echo "        -r: 是否重启应用，后面是启动应用的activity类的全名，需要 -p 参数"
    echo "        -h or --help: 显示帮助信息"
    echo ""
    echo "示例:"
    echo ""
    echo "    -i priv-app -s 0070015947d30e4b -n Settings -p com.android.settings -k -r"
    echo "    -i app -a 192.168.1.31 -n Settings -p com.android.settings -k -r"
    echo ""
}

# remount 设备
function remount() {
    if [[ -n $device ]];then
        adb -s $device root
        if [ $? -eq 0 ]; then
            adb -s $device remount
            return $?
        else 
            return 1
        fi
    else 
        adb root
        if [ $? -eq 0 ]; then
            adb remount
            return $?
        else 
            return 1
        fi
    fi
}

# 连接 WiFi 设备
function connectWiFiDevice() {
    # 不管当前是否已经连接该设备都先断开
    adb disconnect "$deviceIP:5555"
    result=`adb connect $deviceIP`
    echo "result: $result"
    # 连接成功后，休眠 5 秒，避免在执行 adb devices 命令时显示设备是离线状态
    sleep 5
    if [[ $result =~ "cannot connect to" ]];then
        return 1
    else 
        return 0
    fi
}

# push 应用文件
function pushFile() {
    ls $1
    for file in `ls $1`
    do
        echo "file: $file"
        filePath="$1/$file"
        if [ -d $filePath ];then
            echo "$filePath is dirctory"
            pushFile $filePath
            if [ $? -ne 0 ];then
                return 1
            fi
        else
            echo "$filePath is file"
            path=$(dirname $filePath)
            if [[ -n $device ]];then
                if [[ $installLocation == "app" ]];then
                    adb -s $device push $filePath system/app/$path
                    if [[ $? -ne 0 ]];then
                        return 1
                    fi
                else 
                    adb -s $device push $filePath system/priv-app/$path
                    if [[ $? -ne 0 ]];then
                        return 1
                    fi
                fi
            else
                if [[ $installLocation == "app" ]];then
                    adb push $filePath system/app/$path/
                    if [[ $? -ne 0 ]];then
                        return 1
                    fi
                else 
                    adb push $filePath system/priv-app/$path
                    if [[ $? -ne 0 ]];then
                        return 1
                    fi
                fi 
            fi
        fi     
    done
}


# 杀死应用，需要传递应用
function killApp() {
    if [[ -z $packageName ]];then
        echo -e "\e[1;31m错误：包名未设置\e[0m"
        return 1
    fi
    if [[ -n $device ]];then
        # 获取应用的进程信息
        value=`adb -s $device shell ps | grep $packageName`
        echo "result: $value"
        if [[ -n $value ]];then
            # 获取应用进程ID
            pid=`echo $value | awk '{ print $2 }'`
            echo "PID: $pid"
            # 杀死进程
            adb -s $device shell kill $pid
            return $?
        else
            echo -e "\e[1;33m警告：应用未启动，无法杀死应用\e[0m"
        fi
    else
        # 获取应用的进程信息
        value=`adb shell ps -A | grep $packageName`
        echo "result: $value"
        if [[ -n $value ]];then
            # 获取应用进程ID
            pid=`echo $value | awk '{ print $3 }'`
            echo "PID: $pid"
            # 杀死进程
            adb shell kill $pid
            return $?
        else
            echo -e "\e[1;33m警告：应用未启动，无法杀死应用\e[0m"
        fi
    fi
}

# 重启应用
function restartApp() {
    if [[ -n $device ]];then
        result=`adb -s $device shell am start -n $packageName/$activityName 2>&1`
        if [[ $result =~ "Error type" ]];then
            return 1
        fi
    else
        result=`adb shell am start -n $packageName/$activityName 2>&1`
        if [[ $result =~ "Error type" ]];then
            return 1
        fi
    fi
    return $?
}

# 主脚本
function main() {
    # 上一个参数
    lastArg=""
    # 遍历脚本参数
    for arg in $@
    do
        # 解析脚本参数
        case $arg in
            # 适配所有以 --开头的字符串
            --*)
                if [[ $arg = "--help" ]];then
                    showHelper
                    lastArg="-h"
                else 
                    echo "错误：未知参数 $arg"
                    return 1
                fi
                ;;

            -k)
                needKillApp=1
                lastArg=""
                ;;

            # 适配所有以 - 开头的字符串
            -*)
                if [[ $arg = "-h" ]];then
                    showHelper
                fi
                lastArg=$arg
                ;;

            # 适配所有不以 - 或 -- 开头的字符串
            *)
                # echo "arg: $arg, lastArg: $lastArg"
                case $lastArg in
                    -i)
                        if [[ $arg == "app" ]] || [[ $arg == "priv-app" ]];then
                            installLocation=$arg
                        else
                            echo "错误：-i 参数必须是 app 或 priv-app"
                            return 2
                        fi
                        ;;

                    -s)
                        deviceId=$arg
                        ;;
                    
                    -a)
                        deviceIP=$arg
                        ;;
                    
                    -n)
                        appName=$arg
                        ;;

                    -p)
                        packageName=$arg
                        ;;

                    -r)
                        needRestartApp=1
                        activityName=$arg
                        ;;
                esac
                lastArg=""
                ;;
        esac
    done

    if [[ -n $deviceId ]];then
        device=$deviceId
    elif [[ -n $deviceIP ]];then
        device="$deviceIP:5555"
    fi

    echo "installLocation: $installLocation"
    echo "device: $device"
    echo "deviceId: $deviceId"
    echo "deviceIP: $deviceIP"
    echo "appName: $appName"
    echo "packageName: $packageName"
    echo "activityName: $activityName"
    echo "needKillApp: $needKillApp"
    echo "needRestartApp: $needRestartApp"

    # 连接 WiFi 设备
    if [[ -n $deviceIP ]];then
        echo "正在连接 WiFi 设备..."
        connectWiFiDevice
        if [ $? != 0 ];then
            echo -e "\e[1;31m错误：无法连接 WiFi 设备\e[0m"
            return 3
        fi
    fi

    # remount 设备
    echo "正在 Remound 设备..."
    remount
    if [ $? -ne 0 ];then
        echo -e "\e[1;31m错误：Remount 设备失败"
        return 4
    fi

    # push 应用文件
    echo "正在导入应用文件..."
    pushFile "./$appName"
    if [ $? -ne 0 ];then
        echo -e "\e[1;31m错误：Push 文件失败"
        return 5
    fi

    # 杀死应用
    if [ $needKillApp -eq 1 ];then
        echo "正在杀死应用..."
        killApp
        if [ $? -ne 0 ];then
            echo -e "\e[1;31m错误：无法杀死应用\e[0m"
            return 6
        fi
    fi

    # 重启应用
    if [ $needRestartApp -eq 1 ];then
        echo "正在重启应用..."
        restartApp
        if [ $? -ne 0 ];then
            echo -e "\e[1;31m错误：无法重启应用\e[0m"
            return 7
        fi
    fi
}

# 开始执行脚本，并将脚本参数传递给 main 函数
main $@

result=$?
echo ""
if [ $result -eq 0 ];then
    echo -e "\e[1;32m========================================= 执行成功 =========================================\e[0m"
else
    echo -e "\e[1;31m========================================= 执行失败 =========================================\e[0m"
fi