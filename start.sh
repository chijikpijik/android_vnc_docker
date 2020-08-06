#!/usr/bin/env bash
console_port=$CONSOLE_PORT
adb_port=$ADB_PORT
adb_server_port=$ADB_SERVER_PORT
emulator_opts=$EMULATOR_OPTS

if [ -z "$console_port" ]
then
  console_port="5554"
fi
if [ -z "$adb_port" ]
then
  adb_port="5555"
fi
if [ -z "$adb_server_port" ]
then
  adb_server_port="5037"
fi
if [ -z "$emulator_opts" ]
then
  emulator_opts="-screen multi-touch -no-boot-anim -noaudio -nojni -netfast -verbose -camera-back emulated -camera-front none -skip-adb-auth -snapshot default -no-snapshot-save"
fi

# Detect ip and forward ADB ports outside to outside interface
ip=$(ip addr list eth0|grep "inet "|cut -d' ' -f6|cut -d/ -f1)
redir --laddr=$ip --lport=$adb_server_port --caddr=127.0.0.1 --cport=$adb_server_port &
redir --laddr=$ip --lport=$console_port --caddr=127.0.0.1 --cport=$console_port &
redir --laddr=$ip --lport=$adb_port --caddr=127.0.0.1 --cport=$adb_port &

function clean_up {
    echo "Cleaning up"
    rm /tmp/.X1-lock

    # kill $XVFB_PID
    # kill $FLUXBOX_PID
    kill $VNC_PID
    exit
}

trap clean_up SIGHUP SIGINT SIGTERM
export DISPLAY=:2
export USER=root
password="android"
password_view_only="docker"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/android-sdk-linux/emulator/lib64/qt/lib:/opt/android-sdk-linux/emulator/lib64/libstdc++:/opt/android-sdk-linux/emulator/lib64:/opt/android-sdk-linux/emulator/lib64/gles_swiftshader
# Xvfb :1 +extension GLX +extension RANDR +extension RENDER +extension XFIXES -screen 0 1024x768x24 &
# XVFB_PID=$!
# sleep 1 && fluxbox -display ":1.0" &
# FLUXBOX_PID=$!
/usr/bin/expect <<EOF
spawn vncpasswd
expect "Password:"
send "$password\r"
expect "Verify:"
send "$password\r"
expect "Would you like to enter a view-only password (y/n)?"
send "y\r"
expect "Password:"
send "$password_view_only\r"
expect "Verify:"
send "$password_view_only\r"
expect eof
exit
EOF
vncserver :2
VNC_PID=$!

# qemu references bios by relative path
cd /opt/android-sdk-linux/emulator

CONFIG="/root/.android/avd/Pixel2.avd/config.ini"
CONFIGTMP=${CONFIG}.tmp

if [ -n "$ANDROID_CONFIG" ];
then
  IFS=';' read -ra OPTS <<< "$ANDROID_CONFIG"
  for OPT in "${OPTS[@]}"; do
    IFS='=' read -ra KV <<< "$OPT"
    KEY=${KV[0]}
    VALUE=${KV[1]}
    mv ${CONFIG} ${CONFIGTMP}
    cat ${CONFIGTMP} | grep -v ${KEY}= > ${CONFIG}
    echo ${OPT} >> ${CONFIG}
  done
fi

echo "emulator_opts NEW: $emulator_opts" 

# LIBGL_DEBUG=verbose ./qemu/linux-x86_64/qemu-system-x86_64 -avd Pixel2 -ports $console_port,$adb_port $emulator_opts -qemu $QEMU_OPTS
/bin/bash
