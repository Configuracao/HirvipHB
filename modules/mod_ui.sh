#!/bin/bash

# --- COLORES Y ESTILOS ---
C_BARRA='\033[1;34m'      # Azul Fuerte
C_TITULO='\033[1;44;37m'  # Fondo Azul, Letra Blanca
C_TEXTO='\033[1;37m'      # Blanco
C_DATO='\033[1;33m'       # Amarillo
C_ROJO='\033[1;31m'       # Rojo
C_VERDE='\033[1;32m'      # Verde
C_RESET='\033[0m'         # Reset

# --- FUNCION PARA CENTRAR TITULOS ---
msg_center() {
    local text="$1"
    local clean_text=$(echo -e "$text" | sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g')
    local len=${#clean_text}
    local width=53
    local padding=$(( (width - len) / 2 ))
    if [[ $padding -lt 0 ]]; then padding=0; fi
    printf "%*s" $padding ""
    echo -e "$text"
}

# --- FUNCION DE SALIDA CON BANNER ---
fun_salir_script() {
    clear
    echo -e "${C_BARRA}  _____   ______           _____ ______ _   _  _____ ${C_RESET}"
    echo -e "${C_BARRA} |  __ \|  ____|    /\    / ____|  ____| \ | |/ ____|${C_RESET}"
    echo -e "${C_BARRA} | |__) | |__       /  \   | |  __| |__  |  \| | (___ ${C_RESET}"
    echo -e "${C_BARRA} |  _  /|  __|     / /\ \ | | |_ |  __| | . \` |\___ \ ${C_RESET}"
    echo -e "${C_BARRA} | | \ \| |____    / ____ \| |__| | |____| |\  |____) |${C_RESET}"
    echo -e "${C_BARRA} |_|  \_\______|/_/    \_\_____/|______|_| \_|_____/ ${C_RESET}"
    echo ""
    msg_center "${C_DATO}CREATOR : REAGENS  JEAN${C_RESET}"
    echo ""
    echo -e "    Para iniciar REAGENS VPN PRO MANAGER FOR VPS escriba:  menu "
    echo ""
    exit 0
}

# --- DATOS DEL SISTEMA ---
obtener_datos() {
    if [ -f /etc/os-release ]; then 
        OS_NAME=$(grep -w "PRETTY_NAME" /etc/os-release | cut -d= -f2 | tr -d '"')
    else 
        OS_NAME="Linux"
    fi
    OS_NAME=${OS_NAME:0:13}
    
    IP_PUB=$(curl -s ipv4.icanhazip.com)
    [[ ${#IP_PUB} -gt 15 ]] && IP_PUB=${IP_PUB:0:15}
    IP6_PUB=$(curl -s -6 ipv6.icanhazip.com)
    if [[ ! -z "$IP6_PUB" ]]; then 
        IP_DISP="${C_VERDE}v4/v6 ON${C_RESET}"
    else 
        IP_DISP="$IP_PUB"
    fi

    FECHA_ACT=$(date +%d/%m/%y)
    HORA_ACT=$(date +%H:%M:%S)
    
    RAM_TOTAL=$(free -h | grep Mem | awk '{print $2}')
    RAM_USED=$(free -h | grep Mem | awk '{print $3}')
    RAM_FREE=$(free -h | grep Mem | awk '{print $4}')
    RAM_TOTAL_MB=$(free -m | grep Mem | awk '{print $2}')
    RAM_USED_MB=$(free -m | grep Mem | awk '{print $3}')
    
    if [[ "$RAM_TOTAL_MB" -gt 0 ]]; then
        RAM_PERC=$(echo "scale=0; $RAM_USED_MB * 100 / $RAM_TOTAL_MB" | bc)%
    else
        RAM_PERC="0%"
    fi
    
    CPU_CORES=$(nproc)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    
    ONLI_USR=0
    EXP_USR=0
    LOK_USR=0
    TOTAL_USR=0
    user_list=$(awk -F: '$3>=1000 {print $1}' /etc/passwd | grep -vE "^(ubuntu|debian|centos|fedora|opc|admin|ec2-user|nobody|root|syslog)$")
    TOTAL_USR=$(echo "$user_list" | wc -w)
    today_sec=$(date +%s)
    
    for u in $user_list; do
         if ps -u "$u" | grep -E 'sshd|dropbear' | grep -v grep > /dev/null; then ((ONLI_USR++)); fi
         if passwd -S "$u" | grep -q " L "; then ((LOK_USR++)); fi
         exp_raw=$(chage -l "$u" | grep "Account expires" | cut -d: -f2)
         if [[ "$exp_raw" != *"never"* ]]; then
             exp_sec=$(date -d "$exp_raw" +%s)
             if [[ $today_sec -gt $exp_sec ]]; then ((EXP_USR++)); fi
         fi
    done
}

mostrar_menu_principal_ui() {
    tput cup 0 0
    echo -e "${C_BARRA}=====================================================${C_RESET}
$(msg_center "${C_TITULO} REAGENS VPN PRO MANAGER FOR VPS ${C_RESET}")
${C_BARRA}=====================================================${C_RESET}
${C_BARRA}| ${C_TEXTO}SISTEMA           ${C_BARRA}| ${C_TEXTO}MEMORIA       ${C_BARRA}| ${C_TEXTO}PROCESADOR  ${C_BARRA}|${C_RESET}
${C_BARRA}|-------------------|---------------|-------------|${C_RESET}
${C_BARRA}|${C_TEXTO} S.O: $(printf "%-13s" "$OS_NAME") ${C_BARRA}|${C_TEXTO} RAM: $(printf "%-8s" "$RAM_TOTAL") ${C_BARRA}|${C_TEXTO} CPU: $(printf "%-6s" "$CPU_CORES") ${C_BARRA}|${C_RESET}
${C_BARRA}|${C_TEXTO} IP:  $(printf "%-13s" "$IP_DISP") ${C_BARRA}|${C_TEXTO} USE: $(printf "%-8s" "$RAM_USED") ${C_BARRA}|${C_TEXTO} USE: $(printf "%-6s" "$CPU_USAGE") ${C_BARRA}|${C_RESET}
${C_BARRA}|${C_TEXTO} FEC: $(printf "%-13s" "$FECHA_ACT") ${C_BARRA}|${C_TEXTO} LIB: $(printf "%-8s" "$RAM_FREE") ${C_BARRA}|${C_TEXTO}             ${C_BARRA}|${C_RESET}
${C_BARRA}|${C_TEXTO} HOR: $(printf "%-13s" "$HORA_ACT") ${C_BARRA}|${C_TEXTO} TOT: $(printf "%-8s" "$RAM_PERC") ${C_BARRA}|${C_TEXTO}             ${C_BARRA}|${C_RESET}
${C_BARRA}=====================================================${C_RESET}
${C_BARRA}|${C_TEXTO} ONLI: ${C_VERDE}$ONLI_USR${C_TEXTO}    EXP: ${C_ROJO}$EXP_USR${C_TEXTO}    LOK: ${C_DATO}$LOK_USR${C_TEXTO}    TOTAL: ${C_TEXTO}$TOTAL_USR             ${C_BARRA}|${C_RESET}
${C_BARRA}=====================================================${C_RESET}
 ${C_TEXTO}[1] > ADMINISTRADOR DE CONEXIONES (SSH/V2/Tokens)${C_RESET}
 ${C_TEXTO}[2] > AJUSTES DEL SISTEMA (Puertos/Hora/Tools)${C_RESET}
${C_BARRA}-----------------------------------------------------${C_RESET}
 ${C_DATO}[3] > CREAR BOT TELEGRAM${C_RESET}
${C_BARRA}-----------------------------------------------------${C_RESET}
 ${C_ROJO}[4] > [!] DESINSTALAR SISTEMA REAGENS VPN PRO${C_RESET}
${C_BARRA}=====================================================${C_RESET}
 ${C_TEXTO}0) SALIR DEL VPS  8) SALIR DEL SCRIPT  9) REBOOT VPS${C_RESET}
${C_BARRA}=====================================================${C_RESET}
"
}