#!/usr/bin/env bash
set -e
set -u
set -o pipefail

# ------------share--------------
invocation='echo "" && say_verbose "Calling: ${yellow:-}${FUNCNAME[0]} ${green:-}$*${normal:-}"'
exec 3>&1
if [ -t 1 ] && command -v tput >/dev/null; then
    ncolors=$(tput colors || echo 0)
    if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
        bold="$(tput bold || echo)"
        normal="$(tput sgr0 || echo)"
        black="$(tput setaf 0 || echo)"
        red="$(tput setaf 1 || echo)"
        green="$(tput setaf 2 || echo)"
        yellow="$(tput setaf 3 || echo)"
        blue="$(tput setaf 4 || echo)"
        magenta="$(tput setaf 5 || echo)"
        cyan="$(tput setaf 6 || echo)"
        white="$(tput setaf 7 || echo)"
    fi
fi

say_warning() {
    printf "%b\n" "${yellow:-}ray_naive_install: Warning: $1${normal:-}" >&3
}

say_err() {
    printf "%b\n" "${red:-}ray_naive_install: Error: $1${normal:-}" >&2
}

say() {
    # using stream 3 (defined in the beginning) to not interfere with stdout of functions
    # which may be used as return value
    printf "%b\n" "${cyan:-}ray_naive_install:${normal:-} $1" >&3
}

say_verbose() {
    if [ "$verbose" = true ]; then
        say "$1"
    fi
}

machine_has() {
    eval $invocation

    command -v "$1" >/dev/null 2>&1
    return $?
}

check_docker() {
    eval $invocation

    if ! machine_has "docker"; then
        echo "Docker 没有安装，是否要安装？ [y/N]"
        read -r install_docker
        if [[ $install_docker =~ ^([yY][eE][sS]|[yY])$ ]]; then
           echo "正在更新软件包列表..."
            apt update
            echo "正在安装 Docker..."
            apt install -y docker.io
            echo "Docker 安装完成。"
         else
            say_err "Missing dependency: docker was not found, please install it first."
            exit 1
        fi
    fi
     docker --version

    if ! command -v docker-compose &> /dev/null
    then
       echo "Docker Compose 没有安装，是否要安装？ [y/N]"
       read -r install_docker_compose
       if [[ $install_docker_compose =~ ^([yY][eE][sS]|[yY])$ ]]; then
           echo "正在安装 Docker Compose..."
           apt install -y docker-compose
           echo "Docker Compose 安装完成。"
        else
            say_err "Missing dependency: docker-compose was not found, please install it first."
            exit 1
         fi
    fi
}

# args:
# remote_path - $1
get_http_header_curl() {
    eval $invocation

    local remote_path="$1"

    curl_options="-I -sSL --retry 5 --retry-delay 2 --connect-timeout 15 "
    curl $curl_options "$remote_path" 2>&1 || return 1
    return 0
}

# args:
# remote_path - $1
get_http_header_wget() {
    eval $invocation

    local remote_path="$1"
    local wget_options="-q -S --spider --tries 5 "
    # Store options that aren't supported on all wget implementations separately.
    local wget_options_extra="--waitretry 2 --connect-timeout 15 "
    local wget_result=''

    wget $wget_options $wget_options_extra "$remote_path" 2>&1
    wget_result=$?

    if [[ $wget_result == 2 ]]; then
        # Parsing of the command has failed. Exclude potentially unrecognized options and retry.
        wget $wget_options "$remote_path" 2>&1
        return $?
    fi

    return $wget_result
}

# Updates global variables $http_code and $download_error_msg
downloadcurl() {
    eval $invocation

    unset http_code
    unset download_error_msg
    local remote_path="$1"
    local out_path="${2:-}"
    local remote_path_with_credential="${remote_path}"
    local curl_options="--retry 20 --retry-delay 2 --connect-timeout 15 -sSL -f --create-dirs "
    local failed=false
    if [ -z "$out_path" ]; then
        curl $curl_options "$remote_path_with_credential" 2>&1 || failed=true
    else
        curl $curl_options -o "$out_path" "$remote_path_with_credential" 2>&1 || failed=true
    fi
    if [ "$failed" = true ]; then
        local response=$(get_http_header_curl $remote_path)
        http_code=$(echo "$response" | awk '/^HTTP/{print $2}' | tail -1)
        download_error_msg="Unable to download $remote_path."
        if [[ $http_code != 2* ]]; then
            download_error_msg+=" Returned HTTP status code: $http_code."
        fi
        say_verbose "$download_error_msg"
        return 1
    fi
    return 0
}

# Updates global variables $http_code and $download_error_msg
downloadwget() {
    eval $invocation

    unset http_code
    unset download_error_msg
    local remote_path="$1"
    local out_path="${2:-}"
    local remote_path_with_credential="${remote_path}"
    local wget_options="--tries 20 "
    # Store options that aren't supported on all wget implementations separately.
    local wget_options_extra="--waitretry 2 --connect-timeout 15 "
    local wget_result=''

    if [ -z "$out_path" ]; then
        wget -q $wget_options $wget_options_extra -O - "$remote_path_with_credential" 2>&1
        wget_result=$?
    else
        wget $wget_options $wget_options_extra -O "$out_path" "$remote_path_with_credential" 2>&1
        wget_result=$?
    fi

    if [[ $wget_result == 2 ]]; then
        # Parsing of the command has failed. Exclude potentially unrecognized options and retry.
        if [ -z "$out_path" ]; then
            wget -q $wget_options -O - "$remote_path_with_credential" 2>&1
            wget_result=$?
        else
            wget $wget_options -O "$out_path" "$remote_path_with_credential" 2>&1
            wget_result=$?
        fi
    fi

    if [[ $wget_result != 0 ]]; then
        local disable_feed_credential=false
        local response=$(get_http_header_wget $remote_path $disable_feed_credential)
        http_code=$(echo "$response" | awk '/^  HTTP/{print $2}' | tail -1)
        download_error_msg="Unable to download $remote_path."
        if [[ $http_code != 2* ]]; then
            download_error_msg+=" Returned HTTP status code: $http_code."
        fi
        say_verbose "$download_error_msg"
        return 1
    fi

    return 0
}

# args:
# remote_path - $1
# [out_path] - $2 - stdout if not provided
download() {
    eval $invocation

    local remote_path="$1"
    local out_path="${2:-}"

    if [[ "$remote_path" != "http"* ]]; then
        cp "$remote_path" "$out_path"
        return $?
    fi

    local failed=false
    local attempts=0
    while [ $attempts -lt 3 ]; do
        attempts=$((attempts + 1))
        failed=false
        if machine_has "curl"; then
            downloadcurl "$remote_path" "$out_path" || failed=true
        elif machine_has "wget"; then
            downloadwget "$remote_path" "$out_path" || failed=true
        else
            say_err "Missing dependency: neither curl nor wget was found."
            exit 1
        fi

        if [ "$failed" = false ] || [ $attempts -ge 3 ] || { [ ! -z $http_code ] && [ $http_code = "404" ]; }; then
            break
        fi

        say "Download attempt #$attempts has failed: $http_code $download_error_msg"
        say "Attempt #$((attempts + 1)) will start in $((attempts * 10)) seconds."
        sleep $((attempts * 10))
    done

    if [ "$failed" = true ]; then
        say_verbose "Download failed: $remote_path"
        return 1
    fi
    return 0
}
# ---------------------------------

echo '  ____               _   _       _   _            '
echo ' |  _ \ __ _ _   _  | \ | | __ _(_)_(_)_   _____  '
echo ' | |_) / _` | | | | |  \| |/ _` | | | \ \ / / _ \ '
echo ' |  _ < (_| | |_| | | |\  | (_| | | |  \ V /  __/ '
echo ' |_| \_\__,_|\__, | |_| \_|\__,_| |_|   \_/ \___| '
echo '             |___/                                '

# ------------vars-----------、
gitRowUrl="https://raw.githubusercontent.com/RayWangQvQ/naiveproxy-docker/main"

host=""

certMode=""
certFile=""
certKeyFile=""
autoHttps=""

mail=""

httpPort=""
httpsPort=""

user=""
pwd=""

fakeHostDefault="baidu.com"
fakeHost=""

verbose=false
# --------------------------

# read params from init cmd
while [ $# -ne 0 ]; do
    name="$1"
    case "$name" in
    -t | --host | -[Hh]ost)
        shift
        host="$1"
        ;;
    -o | --cert-mode | -[Cc]ert[Mm]ode)
        shift
        certMode="$1"
        ;;
    -c | --cert-file | -[Cc]ert[Ff]ile)
        shift
        certFile="$1"
        ;;
    -k | --cert-key-file | -[Cc]ert[Kk]ey[Ff]ile)
        shift
        certKeyFile="$1"
        ;;
    -m | --mail | -[Mm]ail)
        shift
        mail="$1"
        ;;
    -w | --http-port | -[Hh]ttp[Pp]ort)
        shift
        httpPort="$1"
        ;;
    -s | --http-port | -[Hh]ttp[Pp]ort)
        shift
        httpsPort="$1"
        ;;
    -u | --user | -[Uu]ser)
        shift
        user="$1"
        ;;
    -p | --pwd | -[Pp]wd)
        shift
        pwd="$1"
        ;;
    -f | --fake-host | -[Ff]ake[Hh]ost)
        shift
        fakeHost="$1"
        ;;
    --verbose | -[Vv]erbose)
        verbose=true
        ;;
    -? | --? | -h | --help | -[Hh]elp)
        script_name="$(basename "$0")"
        echo "Ray Naiveproxy in Docker"
        echo "Usage: $script_name [-t|--host <HOST>] [-m|--mail <MAIL>]"
        echo "       $script_name -h|-?|--help"
        echo ""
        echo "$script_name is a simple command line interface to install naiveproxy in docker."
        echo ""
        echo "Options:"
        echo "  -t,--host <HOST>         Your host, Defaults to \`$host\`."
        echo "      -Host"
        echo "          Possible values:"
        echo "          - xui.test.com"
        echo "  -m,--mail <MAIL>         Your mail, Defaults to \`$mail\`."
        echo "      -Mail"
        echo "          Possible values:"
        echo "          - mail@qq.com"
        echo "  -u,--user <USER>         Your proxy user name, Defaults to \`$user\`."
        echo "      -User"
        echo "          Possible values:"
        echo "          - user"
        echo "  -p,--pwd <PWD>         Your proxy password, Defaults to \`$pwd\`."
        echo "      -Pwd"
        echo "          Possible values:"
        echo "          - 1qaz@wsx"
        echo "  -f,--fake-host <FAKEHOST>         Your fake host, Defaults to \`$fakeHost\`."
        echo "      -FakeHost"
        echo "          Possible values:"
        echo "          - https://demo.cloudreve.org"
        echo "  -?,--?,-h,--help,-Help             Shows this help message"
        echo ""
        exit 0
        ;;
    *)
        say_err "Unknown argument \`$name\`"
        exit 1
        ;;
    esac
    shift
done
default_domain="luckydorothy.com"
default_username="stallone"
default_password="198964"
default_email="stalloneiv@gmail.com"
default_fakeHost="baidu.com"
read_var_from_user() {
    eval $invocation

    # host
    if [ -z "$host" ]; then
        read -p "请输入域名(默认$default_domain):" host
        if [ -z "$host" ]; then
         host="$default_domain"
        fi
    else
        say "域名: $host"
    fi

   # cert
    if [ -z "$certMode" ]; then
        read -p "请输入证书模式(1.Caddy自动颁发；2.使用现有证书。默认1):" certMode
        if [ -z "$certMode" ]; then
            certMode="1"
        fi
    fi

    if [ "$certMode" == "1" ]; then
        # say "certMode: $certMode（由Caddy自动颁发）"
        say_warning "自动颁发证书需要开放80端口给Caddy使用，请确保80端口开放且未被占用"
        httpPort="80"
         # 检查是否已经存在证书
        if [ -d "/etc/letsencrypt/live/$host" ]; then
         echo "检测到已存在证书, 是否需要重新申请？ [y/N]"
          read -r renew_cert
         if [[ $renew_cert =~ ^([yY][eE][sS]|[yY])$ ]]; then
           say "重新申请证书"
         else
            say "使用已存在的证书"
            autoHttps="auto_https disable_certs"
           fi
        fi
        # email
        if [ -z "$mail" ]; then
            read -p "请输入邮箱(默认$default_email):" mail
         if [ -z "$mail" ]; then
             mail="$default_email"
           fi
       else
            say "邮箱: $mail"
        fi
    else
        # say "certMode: 2（使用现有证书）"
        autoHttps="auto_https disable_certs"
        if [ -z "$certKeyFile" ]; then
            read -p "请输入证书key文件路径:" certKeyFile
        else
            say "证书key: $certKeyFile"
        fi

        if [ -z "$certFile" ]; then
            read -p "请输入证书文件路径:" certFile
        else
            say "证书文件: $certFile"
        fi
    fi


    # port
    if [ -z "$httpPort" ]; then
        if [ $certMode == "2" ]; then
            say "使用现有证书模式允许使用非80的http端口"
            read -p "请输入Caddy的http端口(如8080, 默认80):" httpPort
            if [ -z "$httpPort" ]; then
                httpPort="80"
            fi
        else
            httpPort="80"
            say "Http端口: $httpPort"
        fi
    else
        say "httpPort: $httpPort"
    fi

    if [ -z "$httpsPort" ]; then
        read -p "请输入https端口(如8043, 默认443):" httpsPort
        if [ -z "$httpsPort" ]; then
            httpsPort="443"
        fi
    else
        say "Https端口: $httpsPort"
    fi

    if [ -z "$user" ]; then
        read -p "请输入节点用户名(默认$default_username):" user
        if [ -z "$user" ]; then
            user="$default_username"
        fi
    else
        say "节点用户名: $user"
    fi

    if [ -z "$pwd" ]; then
        read -p "请输入节点密码(默认$default_password):" pwd
         if [ -z "$pwd" ]; then
            pwd="$default_password"
        fi
   else
        say "节点密码: $pwd"
    fi

    if [ -z "$fakeHost" ]; then
        read -p "请输入伪装站点地址(默认$default_fakeHost):" fakeHost
      if [ -z "$fakeHost" ]; then
         fakeHost=$default_fakeHost
        fi
   else
        say "伪装站点地址: $fakeHost"
    fi
}

# 下载docker-compose文件
download_docker_compose_file() {
    eval $invocation

    rm -rf ./docker-compose.yml
    download $gitRowUrl/docker-compose.yml docker-compose.yml
}

# 配置docker-compose文件
replace_docker_compose_configs() {
    eval $invocation

    # replace httpPort
    sed -i 's|<httpPort>|'"$httpPort"'|g' ./docker-compose.yml

    # replace httpsPort
    sed -i 's|<httpsPort>|'"$httpsPort"'|g' ./docker-compose.yml

    # certs
    if [ "$certMode" == "2" ]; then
        sed -i 's|<certVolumes>|'-" $certFile":"$certFile"'|g' ./docker-compose.yml
        sed -i 's|<certKeyVolumes>|'-" $certKeyFile":"$certKeyFile"'|g' ./docker-compose.yml
    else
        sed -i 's|<certVolumes>| |g' ./docker-compose.yml
        sed -i 's|<certKeyVolumes>| |g' ./docker-compose.yml
    fi

    say "Docker compose file:"
    cat ./docker-compose.yml
}

# 下载data
download_data_files() {
    eval $invocation

    mkdir -p ./data

    # entry
    rm -rf ./data/entry.sh
    download $gitRowUrl/data/entry.sh ./data/entry.sh

    # Caddyfile
    rm -rf ./data/Caddyfile
    download $gitRowUrl/data/Caddyfile ./data/Caddyfile
}

# 配置Caddyfile
replace_caddyfile_configs() {
    eval $invocation

    # debug
    debug=""
    if [ $verbose = true ]; then
        debug="debug"
    fi
    sed -i 's|<debug>|'"$debug"'|g' ./data/Caddyfile

    # replace host
    sed -i 's|<host>|'"$host"'|g' ./data/Caddyfile

    # replace mail
    sed -i 's|<mail>|'"$mail"'|g' ./data/Caddyfile

    # cert_file
    sed -i 's|<cert_file>|'"$certFile"'|g' ./data/Caddyfile

    # cert_key_file
    sed -i 's|<cert_key_file>|'"$certKeyFile"'|g' ./data/Caddyfile

    # replace httpPort
    sed -i 's|<httpPort>|'"$httpPort"'|g' ./data/Caddyfile

    # replace httpsPort
    sed -i 's|<httpsPort>|'"$httpsPort"'|g' ./data/Caddyfile

    # auto_https
    sed -i 's|<autoHttps>|'"$autoHttps"'|g' ./data/Caddyfile

    # replace user
    sed -i 's|<user>|'"$user"'|g' ./data/Caddyfile

    # replace pwd
    sed -i 's|<pwd>|'"$pwd"'|g' ./data/Caddyfile

    # replace fakeHost
    sed -i 's|<fakeHost>|'"$fakeHost"'|g' ./data/Caddyfile

    say "Caddyfile:"
    cat ./data/Caddyfile
}

# 运行容器
runContainer() {
    eval $invocation

    say "Try to run docker container:"
    {
        docker compose version && docker compose up -d
    } || {
        docker-compose version && docker-compose up -d
    } || {
        certsV=""
        if [ "$certMode" == "2" ]; then
            certsV="-v $certFile:$certFile -v $certKeyFile:$certKeyFile"
        fi
        docker run -itd --name naiveproxy \
        --restart=unless-stopped \
        -p $httpPort:$httpPort \
        -p $httpsPort:$httpsPort \
        -v $PWD/data:/data \
        -v $PWD/share:/root/.local/share $certsV \
        zai7lou/naiveproxy-docker bash /data/entry.sh
    }
}

# 检查容器运行状态
check_result() {
    eval $invocation

    docker ps --filter "name=naiveproxy"

    containerId=$(docker ps -q --filter "name=^naiveproxy$")
    if [ -n "$containerId" ]; then
        echo ""
        echo "==============================================="
        echo "Congratulations! 恭喜！"
        echo "创建并运行naiveproxy容器成功。"
        echo ""
        echo "请使用浏览器访问'https://$host:$httpsPort'，验证是否可正常访问伪装站点"
        echo "如果异常，请运行'docker logs -f naiveproxy'来追踪容器运行日志, 随后可以点击 Ctrl+c 退出日志追踪"
        echo ""
        echo "然后你可以使用客户端连接你的节点了："
        echo "naive+https://$user:$pwd@$host:$httpsPort#naive"
        echo "Enjoy it~"
        echo "==============================================="
    else
        echo ""
        echo "请查看运行日志，确认容器是否正常运行，点击 Ctrl+c 退出日志追踪"
        echo ""
        docker logs -f naiveproxy
    fi
}

main() {
    check_docker
    read_var_from_user

    download_docker_compose_file
    replace_docker_compose_configs

    download_data_files
    replace_caddyfile_configs

    runContainer

    check_result
}

main