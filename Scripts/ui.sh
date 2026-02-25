#!/bin/bash

# =========================================================
# WRT-CI 统一视觉引擎 (ui.sh) - V3.9 i18n Fix
# =========================================================

# --- 核心色彩 ---
R='\033[0;31m';  BR='\033[1;31m'
G='\033[0;32m';  BG='\033[1;32m'
Y='\033[0;33m';  BY='\033[1;33m'
B='\033[0;34m';  BB='\033[1;34m'
P='\033[0;35m';  BP='\033[1;35m'
C='\033[0;36m';  BC='\033[1;36m'
W='\033[0;37m';  BW='\033[1;37m'
NC='\033[0m';    BOLD='\033[1m'

# --- 语言检测 ---
LANG_CONF="${HOME}/.wrt_ci_lang"
[ -f "$LANG_CONF" ] && CURRENT_LANG=$(cat "$LANG_CONF") || CURRENT_LANG="zh"

# --- 翻译字典 ---
T() {
    local key=$1
    case "$CURRENT_LANG" in
        "en")
            case "$key" in
                "main_menu") echo "Main Menu :" ;;
                "build") echo "Launch Build Workflow" ;;
                "sync") echo "Sync Assets Only" ;;
                "timer") echo "Timer & Pipeline" ;;
                "pkg") echo "Package Manager" ;;
                "lang") echo "Switch Language (中文)" ;;
                "exit") echo "Exit Console" ;;
                "source") echo "Select Source :" ;;
                "branch") echo "➤ Branch (Default: master, q to back): " ;;
                "model") echo "Select Target Model :" ;;
                "strategy") echo "Build Strategy :" ;;
                "fast") echo "Incremental (Fast)" ;;
                "stable") echo "Standard (Stable)" ;;
                "clean") echo "Full Clean" ;;
                "back") echo "Back" ;;
                "cancel") echo "Cancel" ;;
                "manual") echo "Manual Input" ;;
                "info") echo "INFO" ;;
                "done") echo "DONE" ;;
                "fail") echo "FAIL" ;;
                "warn") echo "WARN" ;;
                "view_list") echo "View Complete List" ;;
                "add_pkg") echo "Add Custom Package" ;;
                "del_pkg") echo "Delete Custom Package" ;;
                "edit_file") echo "Edit Config File" ;;
                "set_sched") echo "Set Periodic Schedule" ;;
                "check_task") echo "Check Active Tasks" ;;
                "term_sched") echo "Terminate Schedule" ;;
                "config_pipe") echo "Config Pipeline Center" ;;
                "view_logs") echo "View Process Logs" ;;
                "keep_cache") echo "Keep (Accel Build)" ;;
                "clean_cache") echo "Clean (Free Space)" ;;
                "save_exit") echo "Save and Return" ;;
                "discard") echo "Discard Changes" ;;
                "mod_source") echo "Modify Source/Branch" ;;
                "manage_model") echo "Manage Build Models" ;;
                "config_cache") echo "Config Cache Policy" ;;
                "hour") echo "Hour (0-23)" ;;
                "min") echo "Min (0-59)" ;;
                "no_task_warn") echo "No active timer tasks found." ;;
                *) echo "$key" ;;
            esac ;;
        *) # 中文
            case "$key" in
                "main_menu") echo "主菜单控制台 :" ;;
                "build") echo "启动交互编译流程" ;;
                "sync") echo "仅同步代码与插件" ;;
                "timer") echo "自动化调度管理" ;;
                "pkg") echo "自定义插件中心" ;;
                "lang") echo "切换显示语言 (English)" ;;
                "exit") echo "结束当前会话" ;;
                "source") echo "选择源码仓库源 :" ;;
                "branch") echo "➤ 编译分支 (默认 master, 输入 q 返回): " ;;
                "model") echo "选择目标编译机型 :" ;;
                "strategy") echo "选择编译策略 :" ;;
                "fast") echo "增量快编 (极速)" ;;
                "stable") echo "标准更新 (稳健)" ;;
                "clean") echo "深度清理 (彻底)" ;;
                "back") echo "返回" ;;
                "cancel") echo "取消并返回" ;;
                "manual") echo "手动输入" ;;
                "info") echo "信息" ;;
                "done") echo "完成" ;;
                "fail") echo "失败" ;;
                "warn") echo "警告" ;;
                "view_list") echo "查看当前完整清单" ;;
                "add_pkg") echo "交互添加自定义插件" ;;
                "del_pkg") echo "删除已有自定义插件" ;;
                "edit_file") echo "手动编辑配置文件" ;;
                "set_sched") echo "设定周期执行计划" ;;
                "check_task") echo "检查当前活跃计划" ;;
                "term_sched") echo "终止所有计划任务" ;;
                "config_pipe") echo "配置自动化流水线" ;;
                "view_logs") echo "查看实时进程日志" ;;
                "keep_cache") echo "保留 (加速下次编译)" ;;
                "clean_cache") echo "清理 (释放磁盘空间)" ;;
                "save_exit") echo "保存配置并返回" ;;
                "discard") echo "放弃修改并返回" ;;
                "mod_source") echo "修改远程仓库与分支" ;;
                "manage_model") echo "管理待编译机型" ;;
                "config_cache") echo "配置缓存保留策略" ;;
                "hour") echo "时 (0-23)" ;;
                "min") echo "分 (0-59)" ;;
                "no_task_warn") echo "当前没有任何活跃的定时计划。" ;;
                *) echo "$key" ;;
            esac ;;
    esac
}

# --- 后续 UI 逻辑不变 ---
msg_info() { echo -e " ${BC}[$(T info)]${NC} ${BW}$1${NC}"; }
msg_ok()   { echo -e " ${BG}[$(T done)]${NC} ${BW}$1${NC}"; }
msg_warn() { echo -e " ${BY}[$(T warn)]${NC} ${BW}$1${NC}"; }
msg_err()  { echo -e " ${BR}[$(T fail)]${NC} ${BW}$1${NC}"; }
msg_step() { echo -e "\n ${BP}--------------------------------------------------${NC}"; echo -e "  ${BW}${BOLD}STEP $1${NC} : ${BC}$2${NC}"; echo -e " ${BP}--------------------------------------------------${NC}"; }
draw_line() { echo -e " ${BW}-----------------------------------------------------${NC}"; }
get_sys_info() { local cpu=$(uptime | awk -F'load average:' '{ print $2 }' | awk -F',' '{ print $1 }' | xargs); local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}'); local mem_avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}'); local mem_used=$((mem_total - mem_avail)); local mem_pct=$(awk "BEGIN {printf \"%.1f%%\", ($mem_used/$mem_total)*100}"); local disk=$(df -h / | awk '/\// {print $(NF-1)}' | head -n 1); echo -e " ${BC}负载: ${BY}$cpu ${BC}内存: ${BY}$mem_pct ${BC}磁盘: ${BY}$disk${NC}"; }
select_menu() { local title=$1; shift; local options=("$@"); local selected=0; local key=""; tput civis >&2; while true; do echo -e "  ${BOLD}${title}${NC}" >&2; for i in "${!options[@]}"; do if [ $i -eq $selected ]; then echo -e "  ${BC}>> ${BOLD}${options[$i]}${NC}" >&2; else echo -e "     ${W}${options[$i]}${NC}" >&2; fi; done; IFS= read -rsn1 key; if [[ $key == $'\e' ]]; then read -rsn2 -t 0.1 next_chars; if [[ $next_chars == "[A" ]]; then ((selected--)); [ $selected -lt 0 ] && selected=$((${#options[@]} - 1)); elif [[ $next_chars == "[B" ]]; then ((selected++)); [ $selected -ge ${#options[@]} ] && selected=0; fi; elif [[ $key =~ [1-9] ]]; then [ "$key" -le "${#options[@]}" ] && selected=$((key - 1)) && break; elif [[ $key == "q" ]]; then selected=255; break; elif [[ $key == "" ]]; then break; fi; tput cuu $((${#options[@]} + 1)) >&2; tput ed >&2; done; tput cnorm >&2; return $selected; }
multi_select_menu() { local title=$1; shift; local options=("$@"); local selected=0; local active_list=(); for i in "${!options[@]}"; do active_list[$i]=0; done; tput civis >&2; while true; do echo -ne "  ${BOLD}${title}${NC} " >&2; [ "$CURRENT_LANG" == "en" ] && echo -e "${W}(Space:Toggle, Enter:Confirm, q:Back)${NC}" >&2 || echo -e "${W}(空格:勾选, Enter:确定, q:返回)${NC}" >&2; for i in "${!options[@]}"; do local marker="[ ]"; [ "${active_list[$i]}" -eq 1 ] && marker="[${BG}X${NC}]"; if [ $i -eq $selected ]; then echo -e "  ${BC}>> $marker ${BOLD}${options[$i]}${NC}" >&2; else echo -e "     $marker ${W}${options[$i]}${NC}" >&2; fi; done; IFS= read -rsn1 key; case "$key" in $'\e') read -rsn2 -t 0.1 next_chars; if [[ $next_chars == "[A" ]]; then ((selected--)); [ $selected -lt 0 ] && selected=$((${#options[@]} - 1)); elif [[ $next_chars == "[B" ]]; then ((selected++)); [ $selected -ge ${#options[@]} ] && selected=0; fi ;; " ") [ "${active_list[$selected]}" -eq 1 ] && active_list[$selected]=0 || active_list[$selected]=1 ;; "q") echo "BACK"; tput cnorm >&2; return 0 ;; "") break ;; esac; tput cuu $((${#options[@]} + 1)) >&2; tput ed >&2; done; tput cnorm >&2; local result=""; for i in "${!active_list[@]}"; do [ "${active_list[$i]}" -eq 1 ] && result+="$i "; done; echo "$result"; }
