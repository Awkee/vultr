#!/bin/bash
#########################################################################
# File Name: ssr.sh
# Author: zwker
# mail: xiaoyu0720@gmail.com
# Created Time: 2018年11月26日 星期一 15时25分59秒
#########################################################################

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

## 突出显示内容
white_line()
{
	printf "\033[0;37m $@ \033[0m\n"
}
red_line()
{
	printf "\033[0;31;1m $@ \033[0m\n"
}
green_line()
{
	printf "\033[0;32;7m $@ \033[0m\n"
}

println()
{
	white_line ">-------------------------$@--------------------------------<"
}

blankln()
{
	white_line "<-------------------------------------------------------------------------->"
}

log_msg()
{
	echo "MSG:`date +%Y%m%d%H%M%S`:$@"
}

log_err()
{
	echo "ERR:`date +%Y%m%d%H%M%S`:$@" >&2
	return 1
}


os_check()
{
	OS_ARCH=`uname -p`
	if [ "${OS_ARCH}" != "x86_64" ] ; then
		log_err "CPU类型:[${OS_ARCH}],仅支持'x86_64'!"
		exit 1
	fi
	if [ -f /etc/os-release ];then
		OS_TYPE=`awk -F= '$1~/^ID$/{gsub(/"/,""); printf("%s",$2) }' /etc/os-release`
		OS_VER=`awk -F\" '$1~/^VERSION=/{ printf("%d", $2) }' /etc/os-release`
	elif [ ! -z "`cat /etc/issue | grep bian`" ];then
		OS_TYPE='debian'
	fi

	if [ "${OS_TYPE}" != "ubuntu" -a "${OS_TYPE}" != "centos" -a "${OS_TYPE}" != "rhel" ] ; then
		echo "仅支持 Ubuntu/Debian/centos/rhel 操作系统上自动安装!"
		exit 2
	fi
}

os_selinux_disable()
{
	local se_status=`getenforce`
	if [ "${se_status}" = "Disabled" ] ; then
		log_msg "Your OS is already disable selinux."
		return 0
	fi

	#禁用SELinux
	setenforce 0
	if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	fi
	se_status=`getenforce`
	if [ "${se_status}" != "Disabled"  ] ; then
		log_err "selinux is enabled, maybe you should reboot first."
		exit 1
	fi
}
install_python_centos()
{

}
install_python_ubuntu()
{

}

install_prepare()
{
	log_msg "依赖安装"
	#检查是否为Root
	[ $(id -u) != "0" ] && echo "必须以 root 用户执行此安装程序" && exit 1

	os_check
	case "$OS_TYPE" in
		centos)
			install_python_centos
		;;
		ubuntu)
			install_python_ubuntu
		;;
		*)
			log_err "未知的操作系统类型:[$OS_TYPE]"
			exit 1
		;;
	esac
}


main_jobs()
{
}
