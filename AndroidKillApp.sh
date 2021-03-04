#/bin/bash

#
# 用途：
#     用于杀死运行中 Android 应用
#

function showHelp() {
    echo ""
    echo "用法：[-s][-h][-p]"
    echo "    -s: 设置要操作的设备ID"
    echo "    -h: 输出帮助信息"
    echo "    -p: 应用包名"
    echo ""
}

function main() {
    # 设备
    device=""
    # 应用包名
    packageName=""
    # 上一个参数
    lastArg=""
    # 解析脚本参数
    for arg in $@
    do
        case $arg in
            -h | --help)
                showHelp
                return 0
                ;;
            -*)
                lastArg=$arg
                ;;
            *)
                case $lastArg in
                    -s)
                        device=$arg
                        ;;
                    -p)
                        packageName=$arg
                        ;;
                    *)
                        echo -e "\[1;31m错误：未知参数$arg\e[0m"
                        return 1
                esac
                lastArg=""
                ;;
        esac
    done

    if [[ -z $packageName ]];then
        echo -e "\e[1;31m参数错误：没有设置应用包名\e[0m"
        return 2
    fi

    title="List of devices attached"
    devices=`adb devices`
    devices=${devices:${#title}}
    echo "devices: $devices"
    if [[ ! $devices =~ "device" ]];then
        echo -e "\e[1;31m错误：没有找到已连接的设备\e[0m"
        return 3
    elif [[ -n $device ]];then
        if [[ ! $devices =~ $device ]];then
            echo -e "\e[1;31m错误：没有找到指定设备\e[0m"
        return 4
        fi
    fi

    if [[ -z $device ]];then
        # 获取应用进程信息
        process=`adb shell ps | grep $packageName`
        echo "process info: $process"
        if [[ -n $process ]];then
            # 获取进程ID
            pid=`echo $process | awk '{ print $2 }'`
            echo "PID: $pid"
            # 杀死进程
            adb shell kill $pids
        else
            echo "应用未运行"
        fi
    else
        # 获取应用进程信息
        process=`adb -s $device shell ps | grep $packageName`
        echo "process info: $process"
        if [[ -n $process ]];then
            # 获取进程ID
            pid=`echo $process | awk '{ print $2 }'`
            echo "PID: $pid"
            # 杀死进程
            adb -s $device shell kill $pid
        else
            echo "应用未运行"
        fi
    fi
}

main $@
