#!/bin/bash

# =========================================================
# WRT-CI 统一视觉引擎 (Ui.sh) - V6.0 最终稳定版
# =========================================================

R='\033[0;31m';  BR='\033[1;31m'
G='\033[0;32m';  BG='\033[1;32m'
Y='\033[0;33m';  BY='\033[1;33m'
B='\033[0;34m';  BB='\033[1;34m'
P='\033[0;35m';  BP='\033[1;35m'
C='\033[0;36m';  BC='\033[1;36m'
W='\033[0;37m';  BW='\033[1;37m'
NC='\033[0m';    BOLD='\033[1m'

LANG_CONF="${HOME}/.wrt_ci_lang"
[ -f "$LANG_CONF" ] && CURRENT_LANG=$(cat "$LANG_CONF") || CURRENT_LANG="zh"

RET_IDX=0
RET_VAL=""

T() {
    local key=$1
    case "$CURRENT_LANG" in
        "en")
            case "$key" in
                "main_menu") echo "Main Dashboard :" ;;
                "build") echo "Launch Build Workflow" ;;
                "rebuild") echo "Rebuild Last Model" ;;
                "sync") echo "Sync Assets & Feeds" ;;
                "timer") echo "Timer & Automation" ;;
                "pkg") echo "Package Manager" ;;
                "lang") echo "Language (中文)" ;;
                "exit") echo "Exit Console" ;;
                "source") echo "Source Repo" ;;
                "branch") echo "Build Branch" ;;
                "model") echo "Target Model" ;;
                "strategy") echo "Strategy" ;;
                "back") echo "Back" ;;
                "manual") echo "Manual Input" ;;
                "info") echo "INFO" ;;
                "done") echo "DONE" ;;
                "fail") echo "FAIL" ;;
                "warn") echo "WARN" ;;
                "load") echo "LOAD" ;;
                "mem") echo "MEM" ;;
                "disk") echo "DISK" ;;
                "hour") echo "Hour (0-23)" ;;
                "min") echo "Min (0-59)" ;;
                "step1") echo "Source Sync" ;;
                "step2") echo "Feeds Sync" ;;
                "step3") echo "Package Sync" ;;
                "step4") echo "Config Injection" ;;
                "step5") echo "Core Building" ;;
                "dl_msg") echo "Downloading dependencies..." ;;
                "build_msg") echo "Building core..." ;;
                *) echo "$key" ;;
            esac ;;
        *)
            case "$key" in
                "main_menu") echo "主菜单控制台 :" ;;
                "build") echo "启动交互编译流程" ;;
                "rebuild") echo "再次编译上个机型" ;;
                "sync") echo "仅同步代码与插件" ;;
                "timer") echo "自动化调度管理" ;;
                "pkg") echo "自定义插件中心" ;;
                "lang") echo "切换显示语言 (English)" ;;
                "exit") echo "结束当前会话" ;;
                "source") echo "源码仓库" ;;
                "branch") echo "目标分支" ;;
                "model") echo "目标机型" ;;
                "strategy") echo "编译策略" ;;
                "back") echo "返回" ;;
                "manual") echo "手动输入" ;;
                "info") echo "信息" ;;
                "done") echo "完成" ;;
                "fail") echo "失败" ;;
                "warn") echo "警告" ;;
                "load") echo "负载" ;;
                "mem") echo "内存" ;;
                "disk") echo "磁盘" ;;
                "hour") echo "时 (0-23)" ;;
                "min") echo "分 (0-59)" ;;
                "step1") echo "源码环境同步" ;;
                "step2") echo "更新插件源 (Feeds)" ;;
                "step3") echo "载入自定义补丁与包" ;;
                "step4") echo "生成固件编译配置" ;;
                "step5") echo "启动核心编译引擎" ;;
                "dl_msg") echo "正在下载软件包依赖..." ;;
                "build_msg") echo "核心引擎正在全力运转..." ;;
                *) echo "$key" ;;
            esac ;;
    esac
}

msg_info() { echo -e " ${BC}[$(T info)]${NC} ${BW}$1${NC}"; }
msg_ok()   { echo -e " ${BG}[$(T done)]${NC} ${BW}$1${NC}"; }
msg_warn() { echo -e " ${BY}[$(T warn)]${NC} ${BW}$1${NC}"; }
msg_err()  { echo -e " ${BR}[$(T fail)]${NC} ${BW}$1${NC}"; }
msg_step() { local k="step$1"; echo -e "\n ${BP}--- STEP $1 : $(T $k) ---${NC}"; }
draw_line() { echo -e " ${BW}-----------------------------------------------------${NC}"; }

get_sys_info() {
    local l=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
    local t=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local f=$(grep MemFree /proc/meminfo | awk '{print $2}')
    local b=$(grep ^Buffers /proc/meminfo | awk '{print $2}')
    local c=$(grep ^Cached /proc/meminfo | awk '{print $2}')
    local mem_pct=$(((t-f-b-c)*100/t))
    local disk=$(df -h / | awk '/\// {print $(NF-1)}' | head -n 1)
    echo -e " ${BC}$(T load): ${BY}$l ${BC}$(T mem): ${BY}$mem_pct% ${BC}$(T disk): ${BY}$disk${NC}"
}

select_menu() {
    local title=$1; shift; local options=("$@"); local selected=0; local key=""
    RET_IDX=0; tput civis >&2
    while true; do
        echo -e "  ${BOLD}${title}${NC}" >&2
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then echo -e "  ${BC}>> ${BOLD}${options[$i]}${NC}" >&2
            else echo -e "     ${W}${options[$i]}${NC}" >&2; fi
        done
        IFS= read -rsn1 key
        if [[ $key == $'\e' ]]; then
            read -rsn2 -t 0.1 n; [[ $n == "[A" ]] && ((selected--)); [[ $n == "[B" ]] && ((selected++))
            [ $selected -lt 0 ] && selected=$((${#options[@]} - 1)); [ $selected -ge ${#options[@]} ] && selected=0
        elif [[ $key =~ [1-9] ]] && [ "$key" -le "${#options[@]}" ]; then selected=$((key - 1)); break
        elif [[ $key == "q" ]]; then selected=255; break
        elif [[ $key == "" ]]; then break; fi
        tput cuu $((${#options[@]} + 1)) >&2; tput ed >&2
    done
    tput cuu $((${#options[@]} + 1)) >&2; tput ed >&2; tput cnorm >&2; RET_IDX=$selected
}

multi_select_menu() {
    local title=$1; shift; local options=("$@"); local selected=0; local active=(); for i in "${!options[@]}"; do active[$i]=0; done
    RET_VAL=""; tput civis >&2
    while true; do
        echo -ne "  ${BOLD}${title}${NC} " >&2; [ "$CURRENT_LANG" == "en" ] && echo -e "${W}(Space:Toggle, Enter:Done, q:Back)${NC}" >&2 || echo -e "${W}(空格:勾选, Enter:确定, q:返回)${NC}" >&2
        for i in "${!options[@]}"; do
            local m="[ ]"; [ "${active[$i]}" -eq 1 ] && m="[${BG}X${NC}]"
            [ $i -eq $selected ] && echo -e "  ${BC}>> $m ${BOLD}${options[$i]}${NC}" >&2 || echo -e "     $m ${W}${options[$i]}${NC}" >&2
        done
        IFS= read -rsn1 key
        case "$key" in
            $'\e') read -rsn2 -t 0.1 n; [[ $n == "[A" ]] && ((selected--)); [[ $n == "[B" ]] && ((selected++)); [ $selected -lt 0 ] && selected=$((${#options[@]} - 1)); [ $selected -ge ${#options[@]} ] && selected=0 ;;
            " ") [ "${active[$selected]}" -eq 1 ] && active[$selected]=0 || active[$selected]=1 ;;
            "q") RET_VAL="BACK"; tput cuu $((${#options[@]} + 1)) >&2; tput ed >&2; tput cnorm >&2; return ;;
            "") break ;;
        esac
        tput cuu $((${#options[@]} + 1)) >&2; tput ed >&2
    done
    tput cuu $((${#options[@]} + 1)) >&2; tput ed >&2; tput cnorm >&2; local res=""
    for i in "${!active[@]}"; do [ "${active[$i]}" -eq 1 ] && res+="$i "; done; RET_VAL="$res"
}
