#!/vendor/bin/sh

config="$1"

function doStartDiagSocketLog {
    ip_address=`getprop vendor.oem.diag.socket.ip`
    port=`getprop vendor.oem.diag.socket.port`
    retry=`getprop vendor.oem.diag.socket.retry`
    channel=`getprop vendor.oem.diag.socket.channel`
    if [[ -z "${ip_address}" ]]; then
        ip_address=181.157.1.200
    fi
    if [[ -z "${port}" ]]; then
        port=2500
    fi
    if [[ -z "${retry}" ]]; then
        retry=10000
    fi
    if [[ -z "${channel}" ]]; then
        /system_ext/bin/diag_system_socket_log -a ${ip_address} -p ${port} -r ${retry}
    else
        /system_ext/bin/diag_system_socket_log -a ${ip_address} -p ${port} -r ${retry} -c ${channel}
    fi
}

function doStopDiagSocketLog {
    /system_ext/bin/diag_system_socket_log -k
}

case "$config" in
    "startDiagSocketLog")
    doStartDiagSocketLog
    ;;
    "stopDiagSocketLog")
    doStopDiagSocketLog
    ;;
esac
