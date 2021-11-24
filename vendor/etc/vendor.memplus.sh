#! /vendor/bin/sh

# huangwen.chen@OPTI, 2020/05/18, add for zram writeback
function configure_zram_writeback() {
    # get backing storage size, unit: MB
    backing_dev_size=$(getprop persist.vendor.zwriteback.backing_dev_size)
    case $backing_dev_size in
        [1-9])
            ;;
        [1-9][0-9]*)
            ;;
        *)
            backing_dev_size=2048
            ;;
    esac

    # create backing storage
    # check if dd command success
    ret=$(dd if=/dev/zero of=/data/vendor/swap/zram_wb bs=1m count=$backing_dev_size 2>&1)
    if [ $? -ne 0 ];then
        rm -f /data/vendor/swap/zram_wb
        echo "memplus $ret" > /dev/kmsg
        return 1
    fi

    # check if attaching file success
    losetup -f
    loop_device=$(losetup -f -s /data/vendor/swap/zram_wb 2>&1)
    if [ $? -ne 0 ];then
        rm -f /data/vendor/swap/zram_wb
        echo "memplus $loop_device" > /dev/kmsg
        return 1
    fi
    echo $loop_device > /sys/block/zram0/backing_dev

    mem_limit=$(getprop persist.vendor.zwriteback.mem_limit)
    case $mem_limit in
        [1-9])
            mem_limit="${mem_limit}M"
            ;;
        [1-9][0-9]*)
            mem_limit="${mem_limit}M"
            ;;
        *)
            mem_limit="1G"
            ;;
    esac
    echo $mem_limit > /sys/block/zram0/mem_limit
}

function configure_memplus_parameters() {
    bootmode=`getprop ro.vendor.factory.mode`
    if [ "$bootmode" == "ftm" ] || [ "$bootmode" == "wlan" ] || [ "$bootmode" == "rf" ];then
        return
    fi
    # wait post_boot config to be done
    while :
    do
        postboot_running=`getprop vendor.sys.memplus.postboot`
        if [ "$postboot_running" == "2" ]; then
            setprop vendor.sys.memplus.postboot 3
            exit 0
        elif [ "$postboot_running" == "3" ]; then
            break
        fi
        sleep 1
    done
    memplus=`getprop persist.vendor.memplus.enable`
    case "$memplus" in
        "0")
            # disable swapspace
            # use original settings
            # remove swapfile to reclaim storage space
            # runtime disable, we don't remove swap
            # rm /data/vendor/swap/swapfile

            # huangwen.chen@OPTI, 2020/07/10 check if swapoff success
            echo "memplus swapoff start" > /dev/kmsg
            ret=$(swapoff /dev/block/zram0 2>&1)
            if [ $? -ne 0 ];then
                echo "memplus $ret" > /dev/kmsg
                return
            fi
            echo "memplus swapoff done" > /dev/kmsg

            # huangwen.chen@OPTI, 2020/06/11 add for zram writebak
            # detaching loop device and clear backing_dev file
            loop_device_file="/sys/block/zram0/backing_dev"
            if [ -f $loop_device_file ];then
                loop_device=$(cat /sys/block/zram0/backing_dev)
                if [ "$loop_device" != "none" ];then
                    losetup -d $loop_device
                    rm -f /data/vendor/swap/zram_wb
                fi
            fi
            echo 1 > /sys/block/zram0/reset

            #echo 2 > /sys/module/memplus_core/parameters/memory_plus_enabled
            ;;
        "1")
            # enable memplus
            # reset zram swapspace
            # huangwen.chen@OPTI, 2020/07/10 check if swapoff success
            echo "memplus swapoff start" > /dev/kmsg
            ret=$(swapoff /dev/block/zram0 2>&1)
            if [ $? -ne 0 ];then
                echo "memplus $ret" > /dev/kmsg
                return
            fi
            echo "memplus swapoff done" > /dev/kmsg

            # huangwen.chen@OPTI, 2020/06/11 add for zram writebak
            # detaching loop device before reset
            loop_device_file="/sys/block/zram0/backing_dev"
            if [ -f $loop_device_file ];then
                loop_device=$(cat /sys/block/zram0/backing_dev)
                if [ "$loop_device" != "none" ];then
                    losetup -d $loop_device
                fi
            fi

            echo 1 > /sys/block/zram0/reset

            # huangwen.chen@OPTI, 2020/05/21 set zram disksize by property
            disksize=$(getprop persist.vendor.zwriteback.disksize)
            case $disksize in
                [1-9])
                    disksize="${disksize}M"
                    ;;
                [1-9][0-9]*)
                    disksize="${disksize}M"
                    ;;
                *)
                    disksize="2100M"
                    ;;
            esac

            # huangwen.chen@OPTI, 2020/05/18 add for zram writeback
            # check if ZRAM_WRITEBACK_CONFIG enable
            writeback_file="/sys/block/zram0/writeback"
            zwriteback=$(getprop persist.vendor.zwriteback.enable)
            if [[ -f $writeback_file && $zwriteback == 1 ]];then
                configure_zram_writeback
                # check if configure_zram_writeback success
                if [ $? -ne 0 ];then
                    echo 0 > /sys/block/zram0/mem_limit
                fi
            else
                rm -f /data/vendor/swap/zram_wb
                disksize="2100M"
                echo 0 > /sys/block/zram0/mem_limit
            fi
            echo $disksize > /sys/block/zram0/disksize

            mkswap /dev/block/zram0
            echo "memplus swapon start" > /dev/kmsg
            swapon /dev/block/zram0 -p 32758
            echo "memplus swapon done" > /dev/kmsg
            if [ $? -eq 0 ]; then
                echo 1 > /sys/module/memplus_core/parameters/memory_plus_enabled
            fi
            ;;
        *)
            # reset zram swapspace
            # huangwen.chen@OPTI, 2020/07/10 check if swapoff success
            echo "memplus swapoff start" > /dev/kmsg
            ret=$(swapoff /dev/block/zram0 2>&1)
            if [ $? -ne 0 ];then
                echo "memplus $ret" > /dev/kmsg
                return
            fi
            echo "memplus swapoff done" > /dev/kmsg

            # huangwen.chen@OPTI, 2020/06/11 add for zram writebak
            # detaching loop device before reset
            loop_device_file="/sys/block/zram0/backing_dev"
            if [ -f $loop_device_file ];then
                loop_device=$(cat /sys/block/zram0/backing_dev)
                if [ "$loop_device" != "none" ];then
                    losetup -d $loop_device
                fi
            fi

            echo 1 > /sys/block/zram0/reset
            echo lz4 > /sys/block/zram0/comp_algorithm

            # huangwen.chen@OPTI, 2020/05/21 set zram disksize by property
            disksize=$(getprop persist.vendor.zwriteback.disksize)
            case $disksize in
                [1-9])
                    disksize="${disksize}M"
                    ;;
                [1-9][0-9]*)
                    disksize="${disksize}M"
                    ;;
                *)
                    disksize="2100M"
                    ;;
            esac

            # huangwen.chen@OPTI, 2020/05/18 add for zram writeback
            # check if ZRAM_WRITEBACK_CONFIG enable
            writeback_file="/sys/block/zram0/writeback"
            zwriteback=$(getprop persist.vendor.zwriteback.enable)
            if [[ -f $writeback_file && $zwriteback == 1 ]];then
                configure_zram_writeback
                # check if configure_zram_writeback success
                if [ $? -ne 0 ];then
                    echo 0 > /sys/block/zram0/mem_limit
                fi
            else
                rm -f /data/vendor/swap/zram_wb
                disksize="2100M"
                echo 0 > /sys/block/zram0/mem_limit
            fi
            echo $disksize > /sys/block/zram0/disksize

            mkswap /dev/block/zram0
            echo "memplus swapon start" > /dev/kmsg
            swapon /dev/block/zram0 -p 32758
            echo "memplus swapon done" > /dev/kmsg
            if [ $? -eq 0 ]; then
                echo 0 > /sys/module/memplus_core/parameters/memory_plus_enabled
            fi
            ;;
    esac

    # final check for consistency
    memplus_now=`getprop persist.vendor.memplus.enable`
    if [ "$memplus" == "$memplus_now" ]; then
        retry=0
    fi
}
retry=1
while :
do
    if [ "$retry" == "1" ]; then
        configure_memplus_parameters
    else
        break
    fi
done
