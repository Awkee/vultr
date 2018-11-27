#!/bin/bash
#########################################################################
# File Name: ssr.sh
# Author: zwker
# mail: xiaoyu0720@gmail.com
# Created Time: 2018年11月26日 星期一 15时25分59秒
#########################################################################

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

sodium_ver="1.0.16"
libsodium_file="libsodium-${sodium_ver}"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/${sodium_ver}/${libsodium_file}.tar.gz"

ssr_ver="3.2.2"
ssr_file="manyuser-${ssr_ver}"
ssr_url="https://github.com/leitbogioro/SSR.Go/releases/download/${ssr_ver}/${ssr_file}.zip"

cmd_wget="wget --no-check-certificate "

## 突出显示内容
line_white()
{
	printf "\033[0;37m $@ \033[0m\n"
}
line_red()
{
	printf "\033[0;31;1m $@ \033[0m\n"
}
line_green()
{
	printf "\033[0;32;7m $@ \033[0m\n"
}

println()
{
	line_white ">-------------------------$@--------------------------------<"
}

blankln()
{
	line_white "<-------------------------------------------------------------------------->"
}

log_msg()
{
	echo "MSG:`date +%Y%m%d%H%M%S`:$@"
}

log_err()
{
	echo "ERR:`date +%Y%m%d%H%M%S`:$@" >&2
}

# 获得公共 IP 地址
get_ip(){
	local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
	[ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 api.ipify.org )
	[ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
	[ ! -z ${IP} ] && echo ${IP} || echo
}

########## 操作系统检查 ###
##  OS_TYPE  : 操作系统类型(centos/rhel/ubuntu/debian)
##  OS_VER   : 操作系统版本号
##  OS_ARCH  : CPU类型,仅支持:x86_64
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
	se_status='Enabled'
	[[ -x `which getenforce` ]] && se_status=`getenforce`
	if [ "${se_status}" = "Disabled" ] ; then
		log_msg "Your OS is already disable selinux."
		return 0
	fi

	#禁用SELinux
	setenforce 0
	se_status="Disabled"
	if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	fi
	[[ -x `which getenforce` ]] && se_status=`getenforce`
	if [ "${se_status}" != "Disabled"  ] ; then
		log_err "selinux is enabled, maybe you should reboot first."
		exit 1
	fi
}

# Python QRCode 依赖
py_qrcode(){
    pip install pillow
    pip install qrcode
}

install_dependency()
{
	case "$OS_TYPE" in
		centos)
			yum update -y
			yum install epel-release curl unzip git ntp ntpdate lrzsz -y
			install_centos
		;;
		ubuntu)
			apt-get update
			apt-get install curl unzip git ntp wget ntpdate python python-pip socat lrzsz -y
			install_ubuntu
		;;
		*)
	esac
	py_qrcode
}

prevent_yum()
{
	l_py_ver="${PY_OLD_VER_MAJOR}.${PY_OLD_VER_MINOR}"
	if [ "$l_py_ver" = "2.6" ] ; then
		sed -i "1s/python/python${l_py_ver}/1" /usr/bin/yum
		# 将旧版本python路径复制到新版本 Python 的路径 /usr/local/lib/python2.7/site-packages/ 下
		cp -r /usr/lib/python2.6/site-packages/yum /usr/local/lib/python2.7/site-packages/
		cp -r /usr/lib/python2.6/site-packages/rpmUtils /usr/local/lib/python2.7/site-packages/
		cp -r /usr/lib/python2.6/site-packages/iniparse /usr/local/lib/python2.7/site-packages/
		cp -r /usr/lib/python2.6/site-packages/urlgrabber /usr/local/lib/python2.7/site-packages/
		cp -r /usr/lib64/python2.6/site-packages/rpm /usr/local/lib/python2.7/site-packages/
		cp -r /usr/lib64/python2.6/site-packages/curl /usr/local/lib/python2.7/site-packages/
		cp -p /usr/lib64/python2.6/site-packages/pycurl.so /usr/local/lib/python2.7/site-packages/
		cp -p /usr/lib64/python2.6/site-packages/_sqlitecache.so /usr/local/lib/python2.7/site-packages/
		cp -p /usr/lib64/python2.6/site-packages/sqlitecachec.py /usr/local/lib/python2.7/site-packages/
		cp -p /usr/lib64/python2.6/site-packages/sqlitecachec.pyc /usr/local/lib/python2.7/site-packages/
		cp -p /usr/lib64/python2.6/site-packages/sqlitecachec.pyo /usr/local/lib/python2.7/site-packages/
	fi
}

python_version_check()
{
	[[ ! -x `which python` ]]  && return 1
	PY_VER_MAJOR=`python -V 2>&1 | awk '{ print substr($2,1,1) }'`
	PY_VER_MINOR=`python -V 2>&1 | awk '{ print substr($2,3,1) }'`
	[[ "${PY_VER_MAJOR}" = "2" && "${PY_VER_MINOR}" = "7"  ]] && return 0
	return 9 
}
pip_version_check()
{
	[[ ! -x `which python` ]]  && return 1
	PY_VER_MAJOR=`pip -V |  awk -F\( '{ print substr($2,8,1) }'`
	PY_VER_MINOR=`pip -V |  awk -F\( '{ print substr($2,10,1) }'`
	[[ "${PY_VER_MAJOR}" = "2" && "${PY_VER_MINOR}" = "7"  ]] && return 0
	return 9 
}

install_centos6_python2()
{
	## Python 版本检查
	if [ `python_version_check` = "0" ] ; then
		log_msg "Python 2.7 is already installed!"
		return 0 
	else
		# 安装 python-2.7.15
		PY_OLD_VER_MAJOR=${PY_VER_MAJOR}
		PY_OLD_VER_MINOR=${PY_VER_MINOR}
		python_url="https://www.python.org/ftp/python/2.7.15/Python-2.7.15.tgz"
		python_file="Python-2.7.15"
		# 安装所有的开发工具包
		yum groupinstall -y "Development tools"
		yum install -y update zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel wget
		wget ${python_url}
		[[ "$?" != "0" ]]  && log_err "下载${python_url}失败" && exit 1
		tar zxf ${python_file}.tgz && cd ${python_file} && ./configure && make && make install

		mv /usr/bin/python /usr/bin/python.old
		rm -f /usr/bin/python-config

		# 创建新版本的 Python 软链接
		ln -s /usr/local/bin/python /usr/bin/python
		ln -s /usr/local/bin/python-config /usr/bin/python-config
		ln -s /usr/local/include/python2.7/ /usr/include/python2.7
		if [ `python_version_check` = "0" ] ; then
			log_msg "${python_file} is installed successfully!"
			prevent_yum
		fi
		# 清理 python 安装包
		rm -rf /root/$python_file /root/$python_file.tgz
	fi

	if [ `pip_version_check` = "0" ] ; then
		log_msg "pip is already installed."
		return 0
	else
		# 为新版 Python 安装 setuptools
		wget https://bootstrap.pypa.io/ez_setup.py -O - | python
		# 为新版 Python 安装 pip
		easy_install pip
	fi
	# 为新版 Python 安装 distribute 包（可选） 
	pip install distribute
}

install_centos7_python2()
{
	pip_file="get-pip.py"
	pip_url="https://bootstrap.pypa.io/get-pip.py"
	yum install curl python -y
	[[ ! -x `which curl` ]] && log_err "curl 安装失败!" && return 1
	curl ${pip_url} -o ${pip_file} || return 2
	python ${pip_file} && rm -rf /root/${pip_file}
}

install_centos()
{
	if [ "$OS_TYPE" = "centos" ] ; then
		if [ "${OS_VER}" = "7" ] ; then
			install_centos7_python2
			[[ "$?" != "0" ]] && log_err "安装Python失败!请解决错误信息后重新安装." && exit 3
		elif [ "${OS_VER}" = "6" ] ; then 
			install_centos6_python2
			[[ "$?" != "0" ]] && log_err "安装Python失败!请解决错误信息后重新安装." && exit 6
		fi
	fi
}

install_ssr()
{
	curdir=`pwd`
	os_selinux_disable
	if [ "${OS_TYPE}" = "centos" ] ; then
		if [ "${OS_VER}" -le "5" ] ; then
			log_err "Doesn't support CentOS 5!"
			return 1
		fi
		yum install -y python python-devel python-setuptools openssl openssl-devel curl wget unzip gcc automake autoconf make libtool
		${cmd_wget} https://raw.githubusercontent.com/leitbogioro/SSR.Go/master/shadowsocksR-redhat -O /etc/init.d/shadowsocks

	elif [ "${OS_TYPE}" = "ubuntu"  || "${OS_TYPE}" = "debian" ] ; then
		apt-get -y update
		apt-get -y install python python-dev python-setuptools openssl libssl-dev curl wget unzip gcc automake autoconf make libtool
		${cmd_wget} https://raw.githubusercontent.com/leitbogioro/SSR.Go/master/shadowsocksR-debian -O /etc/init.d/shadowsocks
	fi
	if [ ! -f /usr/lib/libsodium.a ]; then
		${cmd_wget} -O ${libsodium_file}.tar.gz ${libsodium_url}
		[[ "$?" != "0" ]] && log_err "下载[$libsodium_file]失败!" && return 2
		tar zxf ${libsodium_file}.tar.gz && cd ${libsodium_file} && ./configure --prefix=/usr && make && make install
		[[ "$?" != "0" ]] && log_err "安装[$libsodium_file]失败!" && cd - && return 3
		rm -rf ${libsodium_file} ${libsodium_file}.tar.gz
	fi

	${cmd_wget} -O ${ssr_file}.zip ${ssr_url}
	[[ "$?" != "0" ]] && log_err "下载[$ssr_file]失败!" && return 4
	unzip -d ${ssr_file} -q ${ssr_file}.zip && mv ${ssr_file}/shadowsocksr*/shadowsocks /usr/local
	[[ "$?" != "0" ]] && log_err "安装[$ssr_file]失败!" && return 5
	rm -rf  ${ssr_file} ${ssr_file}.zip

	if [ -f /usr/local/shadowsocks/server.py ]; then
		chmod 777 /usr/local/shadowsocks/server.py
		chmod +x /etc/init.d/shadowsocks
		if check_sys packageManager yum; then
			chkconfig --add shadowsocks
			chkconfig shadowsocks on
		elif check_sys packageManager apt; then
			update-rc.d -f shadowsocks defaults
		fi
		log_msg "ssr主程序已安装完成！"
	else
		log_msg "ShadowsocksRR 安装失败，若要获得帮助，请通过以下链接联系我 <https://goo.gl/SjXFKi>"
		return 5
	fi


}

ssr_config_menu_method()
{
	println "SSR加密方式列表"
	menu_ssr_method[1]="none"
	menu_ssr_method[2]="rc4"
	menu_ssr_method[3]="rc4-md5"
	menu_ssr_method[4]="rc4-md5-6"
	menu_ssr_method[5]="aes-128-ctr"
	menu_ssr_method[6]="aes-192-ctr"
	menu_ssr_method[7]="aes-256-ctr"
	menu_ssr_method[8]="aes-128-cfb"
	menu_ssr_method[9]="aes-192-cfb"
	menu_ssr_method[10]="aes-256-cfb"
	menu_ssr_method[11]="aes-128-cfb8"
	menu_ssr_method[12]="aes-192-cfb8"
	menu_ssr_method[13]="aes-256-cfb8"
	menu_ssr_method[14]="salsa20"
	menu_ssr_method[15]="chacha20"
	menu_ssr_method[16]="chacha20-ietf"
	for i in {1..16}
	do
		line_red "$i. ${menu_ssr_method[$i]}"
	done
	echo -n "请选择要设置的ShadowsocksR账号 加密方式(默认: aes-256-cfb):"
	read str_choice
	[[ -z "$str_choice" ]] && str_choice=10
	echo "${str_choice}: ${menu_ssr_method[$str_choice]}"
	if [ "$str_choice" -gt 0 ] && [ "$str_choice" -le "16" ] ; then
		ssr_method="${menu_ssr_method[$str_choice]}"
	else
		log_err "加密方式选择无效!"
		return 1
	fi

}

ssr_config_menu_protocol()
{
	menu_ssr_proto[1]="plain"
	menu_ssr_proto[2]="auth_sha1_v4"
	menu_ssr_proto[3]="auth_aes128_md5"
	menu_ssr_proto[4]="auth_aes128_sha1"
	menu_ssr_proto[5]="auth_chain_a"
	menu_ssr_proto[6]="auth_chain_b"
	for i in {1..6}
	do
		line_red "$i. ${menu_ssr_proto[$i]}"
	done
	echo -n "请选择要设置的ShadowsocksR账号 协议类型(默认:plain): "
	read str_choice
	[[ -z "$str_choice" ]] && str_choice=1
	if [ "$str_choice" -gt 0 ] && [ "$str_choice" -le "6" ] ; then
		ssr_protocol="${menu_ssr_proto[$str_choice]}"
	else
		log_err "协议类型选择无效!"
		return 1
	fi

	line_green "如果使用 auth_chain_a 协议，请加密方式选择 none，混淆随意(建议 plain)" 
	if [ ${ssr_protocol} != "origin" ] ; then
		if [ ${ssr_protocol} == "auth_sha1_v4" ] ; then
			read -p "是否设置 协议插件兼容原版(_compatible)？[Y/n]" ssr_protocol_yn
			[[ -z "${ssr_protocol_yn}" ]] && ssr_protocol_yn="y"
			[[ $ssr_protocol_yn == [Yy] ]] && ssr_protocol=${ssr_protocol}"_compatible"
		fi
	fi
	echo "${str_choice}: ${menu_ssr_proto[$str_choice]}, ${ssr_protocol}"
}

ssr_config_menu_param()
{
	line_white "设备数限制：每个端口同一时间能链接的客户端数量(多端口模式，每个端口都是独立计算)，建议最少 2个。"
	line_red "请输入要设置的ShadowsocksR账号 欲限制的设备数(auth_* 系列协议 不兼容原版才有效,默认不限制):" 
	read str_choice
	[[ -z "$str_choice" ]] && str_choice="" && return 0
	if [ ${str_choice} -ge 1 ] && [ ${str_choice} -le 9999 ]; then
		ssr_param="$str_choice"
	else
		ssr_param=""
		"数字超过限制(1-9999).已经默认为无限."
	fi
}

ssr_config_menu_obfs()
{
	menu_ssr_obfs[1]="plain"
	menu_ssr_obfs[2]="http_simple"
	menu_ssr_obfs[3]="http_post"
	menu_ssr_obfs[4]="random_head"
	menu_ssr_obfs[5]="tls1.2_ticket_auth"

	for i in {1..5}
	do
		line_red "$i. ${menu_ssr_obfs[$i]}"
	done
	line_green "如果使用 ShadowsocksR 加速游戏，请选择 混淆兼容原版或 plain 混淆，然后客户端选择 plain，否则会增加延迟 !" 
	echo -n "请选择要设置的ShadowsocksR账号 混淆方式(默认:plain): "
	read str_choice
	[[ -z "$str_choice" ]]  && str_choice=1
	if [ "$str_choice" -gt 0 ] && [ "$str_choice" -le "5" ] ; then
		ssr_obfs="${menu_ssr_obfs[$str_choice]}"
	else
		log_err "混淆方式选择无效!"
		return 1
	fi
	if [[ ${ssr_obfs} != "plain" ]]; then
		read -p "是否设置 混淆插件兼容原版(_compatible)？[Y/n]" ssr_obfs_yn
		[[ -z "${ssr_obfs_yn}" ]] && ssr_obfs_yn="y"
		[[ $ssr_obfs_yn == [Yy] ]] && ssr_obfs=${ssr_obfs}"_compatible"
		echo
	fi
	echo "${str_choice}: ${menu_ssr_obfs[$str_choice]}, ${ssr_obfs}"
}

ssr_config_password()
{
	echo -n "请选择要设置的ShadowsocksR账号 密码(默认:随机16位): "
	read ssr_pass
	[[ -z "$ssr_pass" ]] && ssr_pass=`cat /dev/urandom | tr -dc "a-zA-Z0-9_+\~\!\@\#\$\%\^\&\*" | fold -w 16 | head -n 1`
}
ssr_config_port()
{
	echo -n "请选择要设置的ShadowsocksR账号 端口(默认:80): "
	read ssr_port
	[[ -z "$ssr_port" ]] && ssr_port="80"
	[[ "$ssr_port" -lt "1" || "$ssr_port" -gt "65535" ]]  && log_err "端口范围设置错误[1-65535],[$ssr_port],已经取默认值." && ssr_port="80"
}
ssr_config_menu_all()
{
	ssr_config_menu_method
	ssr_config_menu_obfs
	ssr_config_menu_protocol
	ssr_config_menu_params

}
# 配置 ShadowsocksRR
ssr_config()
{

	ssr_config_menu_method
    cat > /etc/shadowsocks.json<<-EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"[::]",
    "server_port":${ssr_port},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${ssr_pass}",
    "timeout":300,
    "method":"${ssr_method}",
    "protocol":"${ssr_protocol}",
    "protocol_param":"${ssr_param}",
    "obfs":"${ssr_obfs}",
    "obfs_param":"",
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":false,
    "workers":1
}
EOF
}

install()
{
	#检查是否为Root
	[ $(id -u) != "0" ] && echo "必须以 root 用户执行此安装程序" && exit 1

	case "$OS_TYPE" in
		centos)
			install_python_centos
		;;
		*)
			log_err "未知的操作系统类型:[$OS_TYPE]"
			exit 1
		;;
	esac
}


jobs_main()
{
	os_check
}


jobs_test()
{
	ssr_config_menu_all
}


jobs_test

