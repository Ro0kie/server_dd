#!/bin/sh

if [[ $EUID -ne 0 ]]; then
    clear
    echo "Error: This script must be run as root!" 1>&2
    exit 1
fi


function isValidIp() {
  local ip=$1
  local ret=1
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    ip=(${ip//\./ })
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    ret=$?
  fi
  return $ret
}

function ipCheck() {
  isLegal=0
  for add in $MAINIP $GATEWAYIP $NETMASK; do
    isValidIp $add
    if [ $? -eq 1 ]; then
      isLegal=1
    fi
  done
  return $isLegal
}

function GetIp() {
  MAINIP=$(ip route get 1 | awk -F 'src ' '{print $2}' | awk '{print $1}')
  GATEWAYIP=$(ip route | grep default | awk '{print $3}' | head -1)
  SUBNET=$(ip -o -f inet addr show | awk '/scope global/{sub(/[^.]+\//,"0/",$4);print $4}' | head -1 | awk -F '/' '{print $2}')
  value=$(( 0xffffffff ^ ((1 << (32 - $SUBNET)) - 1) ))
  NETMASK="$(( (value >> 24) & 0xff )).$(( (value >> 16) & 0xff )).$(( (value >> 8) & 0xff )).$(( value & 0xff ))"
}

function UpdateIp() {
  read -r -p "Your IP: " MAINIP
  read -r -p "Your Gateway: " GATEWAYIP
  read -r -p "Your Netmask: " NETMASK
}

function SetNetwork() {
  isAuto='0'
  if [[ -f '/etc/network/interfaces' ]];then
    [[ ! -z "$(sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && isAuto='1'
    [[ -d /etc/network/interfaces.d ]] && {
      cfgNum="$(find /etc/network/interfaces.d -name '*.cfg' |wc -l)" || cfgNum='0'
      [[ "$cfgNum" -ne '0' ]] && {
        for netConfig in `ls -1 /etc/network/interfaces.d/*.cfg`
        do 
          [[ ! -z "$(cat $netConfig | sed -n '/iface.*inet static/p')" ]] && isAuto='1'
        done
      }
    }
  fi
  
  if [[ -d '/etc/sysconfig/network-scripts' ]];then
    cfgNum="$(find /etc/network/interfaces.d -name '*.cfg' |wc -l)" || cfgNum='0'
    [[ "$cfgNum" -ne '0' ]] && {
      for netConfig in `ls -1 /etc/sysconfig/network-scripts/ifcfg-* | grep -v 'lo$' | grep -v ':[0-9]\{1,\}'`
      do 
        [[ ! -z "$(cat $netConfig | sed -n '/BOOTPROTO.*[sS][tT][aA][tT][iI][cC]/p')" ]] && isAuto='1'
      done
    }
  fi
}

function NetMode() {

  if [ "$isAuto" == '0' ]; then
    read -r -p "Using DHCP to configure network automatically? [Y/n]:" input
    case $input in
      [yY][eE][sS]|[yY]) NETSTR='' ;;
      [nN][oO]|[nN]) isAuto='1' ;;
      *) clear; echo "Canceled by user!"; exit 1;;
    esac
  fi

  if [ "$isAuto" == '1' ]; then
    GetIp
    ipCheck
    if [ $? -ne 0 ]; then
      echo -e "Error occurred when detecting ip. Please input manually.\n"
      UpdateIp
    else
      echo "IP: $MAINIP"
      echo "Gateway: $GATEWAYIP"
      echo "Netmask: $NETMASK"
      echo -e "\n"
      read -r -p "Confirm? [Y/n]:" input
      case $input in
        [yY][eE][sS]|[yY]) ;;
        [nN][oO]|[nN])
          echo -e "\n"
          UpdateIp
          ipCheck
          [[ $? -ne 0 ]] && {
            clear
            echo -e "Input error!\n"
            exit 1
          }
        ;;
        *) clear; echo "Canceled by user!"; exit 1;;
      esac
    fi
    NETSTR="--ip-addr ${MAINIP} --ip-gate ${GATEWAYIP} --ip-mask ${NETMASK}"
  fi
}

function Start() {
  
  isCN='0'
  geoip=$(wget --no-check-certificate -qO- https://api.ip.sb/geoip -T 10 | grep "\"country_code\":\"CN\"")
  if [[ "$geoip" != "" ]];then
    isCN='1'
  fi

  if [ "$isAuto" == '0' ]; then
    echo "Using DHCP mode."
  else
    echo "IP: $MAINIP"
    echo "Gateway: $GATEWAYIP"
    echo "Netmask: $NETMASK"
  fi

  [[ "$isCN" == '1' ]] && echo "Using domestic mode."

  if [ -f "/tmp/InstallNET.sh" ]; then
    rm -f /tmp/InstallNET.sh
  fi
  wget --no-check-certificate -qO /tmp/InstallNET.sh 'https://moeclub.org/attachment/LinuxShell/InstallNET.sh' && chmod a+x /tmp/InstallNET.sh
  
  DMIRROR=''
  UMIRROR=''
  if [[ "$isCN" == '1' ]];then
    sed -i 's#https://moeclub.org/get/wget_udeb_amd64#https://api.moetools.net/get/wget_udeb_amd64#' /tmp/InstallNET.sh
    DMIRROR="--mirror http://mirrors.aliyun.com/debian/"
    UMIRROR="--mirror http://mirrors.aliyun.com/ubuntu/"
  fi
  
  sed -i 's/$1$4BJZaD0A$y1QykUnJ6mXprENfwpseH0/$1$7R4IuxQb$J8gcq7u9K0fNSsDNFEfr90/' /tmp/InstallNET.sh
  sed -i '/force-efi-extra-removable/d' /tmp/InstallNET.sh

  echo -e "\nPlease input the password:"
  read P

  echo -e "\nPlease select an OS:  "
  echo "  5) CentOS 7.7 (DD Image)"
  echo "  6) CentOS 7.6 (ServerSpeeder Avaliable)"
  echo "  7) CentOS 6"
  echo "  1) Debian 9"
  echo "  2) Debian 10     !!! aws  cloud will be lost if you choose  debian10  ,  azure is ok for all OS"
  echo "  3) Ubuntu 16.04"
  echo "  4) Ubuntu 18.04"
  echo "  0) Exit"
  echo -ne "\nYour option: "
  read N
  case $N in
    5)  read -s -n1 -p "Press any key to continue..." ; bash /tmp/InstallNET.sh $NETSTR -dd 'https://api.moetools.net/get/centos-7-image' $DMIRROR  -p $P ;;
    6)  read -s -n1 -p "Press any key to continue..." ; bash /tmp/InstallNET.sh $NETSTR -dd 'https://api.moetools.net/get/centos-76-image' $DMIRROR  -p $P ;;
    7)  read -s -n1 -p "Press any key to continue..." ; bash /tmp/InstallNET.sh -c 6.10 -v 64 -a $NETSTR $CMIRROR  -p $P ;;
    1)  read -s -n1 -p "Press any key to continue..." ; bash /tmp/InstallNET.sh -d 9 -v 64 -a $NETSTR $DMIRROR -p $P;;
    2)  read -s -n1 -p "Press any key to continue..." ; bash /tmp/InstallNET.sh -d 10 -v 64 -a $NETSTR $DMIRROR -p $P;;
    3)  read -s -n1 -p "Press any key to continue..." ; bash /tmp/InstallNET.sh -u 16.04 -v 64 -a $NETSTR $UMIRROR -p $P ;;
    4)  read -s -n1 -p "Press any key to continue..." ; bash /tmp/InstallNET.sh -u 18.04 -v 64 -a $NETSTR $UMIRROR -p $P;;
    0) exit 0;;
    *) echo "Wrong input!"; exit 1;;
  esac
}

SetNetwork
NetMode
Start
