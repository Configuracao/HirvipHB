#!/bin/bash

# DIRECTORIOS NECESARIOS
DB_USERS="/etc/reagens/users"
FILE_PASS="/etc/reagens/default_pass"
TOKEN_PASS_FILE="/etc/reagens_base_pass"
mkdir -p "$DB_USERS"

# --- HELPERS SSH ---
get_ssh_days() {
    local user=$1
    local exp_raw=$(LC_ALL=C chage -l "$user" | grep "Account expires" | cut -d: -f2)
    if [[ "$exp_raw" == *"never"* || -z "$exp_raw" ]]; then echo "Inf"; else
        echo $(( ($(date -d "$exp_raw" +%s) - $(date +%s)) / 86400 ))
    fi
}

obtener_clave_default() { 
    if [[ -f "$FILE_PASS" ]]; then cat "$FILE_PASS"; else echo ""; fi 
}

listar_usuarios_vpn() { 
    awk -F: '$3>=1000 {print $1}' /etc/passwd | grep -vE "^(ubuntu|debian|centos|fedora|opc|admin|ec2-user|nobody|root|syslog)$" 
}

seleccionar_usuario() {
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    msg_center "${C_TITULO} SELECCIONAR USUARIO ${C_RESET}"
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    i=1; declare -a users_array
    for u in $(listar_usuarios_vpn); do 
        echo -e " [${C_DATO}$i${C_RESET}] $u"; users_array[$i]=$u; let i++
    done
    if [[ $i -eq 1 ]]; then echo -e " ${C_ROJO}No hay usuarios.${C_RESET}"; return 1; fi
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    echo -n " Seleccione numero: "; read opt_user
    USER_SEL=${users_array[$opt_user]}
    if [[ -z "$USER_SEL" ]]; then echo -e " ${C_ROJO}Invalido.${C_RESET}"; return 1; fi
    return 0
}

# --- FUNCIONES SSH ---
fun_crear_usuario() {
    clear
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    msg_center "${C_TITULO} CREAR NUEVO USUARIO SSH ${C_RESET}"
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    echo -n " Nombre de Usuario: "; read u
    if [[ -z "$u" ]]; then return; fi
    if id "$u" >/dev/null 2>&1; then echo -e "${C_ROJO}Usuario ya existe.${C_RESET}"; sleep 2; return; fi
    
    def_pass=$(obtener_clave_default)
    if [[ ! -z "$def_pass" ]]; then 
        echo -e " Clave Default: ${C_DATO}$def_pass${C_RESET}"; echo -n " Contraseña (Enter para Default): "
    else echo -n " Contraseña: "; fi
    read p; [[ -z "$p" ]] && p="$def_pass"
    if [[ -z "$p" ]]; then echo -e "${C_ROJO}Clave vacia.${C_RESET}"; sleep 2; return; fi
    
    echo -n " Dias de Duracion (Ej: 30): "; read dias_input
    if [[ -z "$dias_input" || ! "$dias_input" =~ ^[0-9]+$ ]]; then echo -e "${C_ROJO}Numero invalido.${C_RESET}"; sleep 2; return; fi
    
    final_date=$(date -d "+$dias_input days" +%Y-%m-%d)
    echo -n " Limite Conexiones (Enter para Ilimitado): "; read lc; [[ -z "$lc" ]] && lc=0
    
    useradd -M -s /bin/false "$u"
    echo "$u:$p" | chpasswd
    chage -E "$final_date" "$u"
    iptables -I OUTPUT -m owner --uid-owner "$u" -j ACCEPT
    netfilter-persistent save > /dev/null 2>&1
    
    echo "PASSWORD=$p" > "$DB_USERS/$u"
    echo "LIMIT_CONN=$lc" >> "$DB_USERS/$u"
    echo "DURATION=$dias_input" >> "$DB_USERS/$u"
    
    echo -e "\n ${C_VERDE}Usuario $u creado. Vence: $final_date${C_RESET}"; sleep 3
}

fun_eliminar_usuario() { 
    clear
    seleccionar_usuario || return
    iptables -D OUTPUT -m owner --uid-owner "$USER_SEL" -j ACCEPT > /dev/null 2>&1
    netfilter-persistent save > /dev/null 2>&1
    userdel --force "$USER_SEL"
    rm -f "$DB_USERS/$USER_SEL"
    echo -e "${C_VERDE} Usuario eliminado.${C_RESET}"; sleep 2
}

fun_editar_usuario() {
    clear
    seleccionar_usuario || return
    echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
    echo -e " [1] Cambiar Contraseña"
    echo -e " [2] Editar Dias (Sumar/Restar)"
    echo -e " [3] Cambiar Limite Conexiones"
    echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
    echo -n " Opcion: "; read o
    case $o in
        1) echo -n " Nueva Clave: "; read p; echo "$USER_SEL:$p"|chpasswd; echo "PASSWORD=$p" >> "$DB_USERS/$USER_SEL"; echo "Hecho.";;
        2) echo -n " Nuevo total de dias: "; read d
           if [[ "$d" =~ ^[0-9]+$ ]]; then fd=$(date -d "+$d days" +%Y-%m-%d); chage -E "$fd" "$USER_SEL"; sed -i "/DURATION=/d" "$DB_USERS/$USER_SEL"; echo "DURATION=$d" >> "$DB_USERS/$USER_SEL"; echo "Vence: $fd"; else echo "Error num"; fi;;
        3) echo -n " Limite Conn: "; read lc; [[ -z "$lc" ]] && lc=0; echo "LIMIT_CONN=$lc" > "$DB_USERS/$USER_SEL"; echo "Hecho.";;
    esac
    sleep 2
}

fun_renovar_usuario() { 
    clear
    seleccionar_usuario || return
    if [[ -f "$DB_USERS/$USER_SEL" ]]; then source "$DB_USERS/$USER_SEL"; fi
    if [[ -z "$DURATION" ]]; then echo -n " Días a renovar: "; read DURATION; echo "DURATION=$DURATION" >> "$DB_USERS/$USER_SEL"; fi
    
    exp_raw=$(LC_ALL=C chage -l "$USER_SEL" | grep "Account expires" | cut -d: -f2)
    today_sec=$(date +%s)
    if [[ "$exp_raw" == *"never"* || -z "$exp_raw" ]]; then base_sec=$today_sec; else
        exp_sec=$(date -d "$exp_raw" +%s)
        if [[ $today_sec -gt $exp_sec ]]; then base_sec=$today_sec; else base_sec=$exp_sec; fi
    fi
    final_date=$(date -d "$(date -d "@$base_sec" +%Y-%m-%d) + $DURATION days" +%Y-%m-%d)
    passwd -u "$USER_SEL"; chage -E "$final_date" "$USER_SEL"
    echo -e "${C_VERDE}Renovado. Nuevo Vencimiento: $final_date${C_RESET}"; sleep 3
}

fun_bloqueo_usuario() { 
    clear; seleccionar_usuario || return
    if passwd -S "$USER_SEL" | grep -q "L"; then passwd -u "$USER_SEL"; echo -e "${C_VERDE}Desbloqueado.${C_RESET}"; else passwd -l "$USER_SEL"; echo -e "${C_ROJO}Bloqueado.${C_RESET}"; fi
    sleep 2
}

fun_detalles_usuarios() {
    clear
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    printf "${C_TEXTO}%-12s %-10s %-10s %-6s${C_RESET}\n" "USUARIO" "CLAVE" "DIAS" "CONN"
    echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
    for u in $(listar_usuarios_vpn); do
        pass="Oculta"; if [[ -f "$DB_USERS/$u" ]]; then source "$DB_USERS/$u"; [[ ! -z "$PASSWORD" ]] && pass=$PASSWORD; fi
        days=$(get_ssh_days "$u"); lc="Inf"; [[ "$LIMIT_CONN" != "0" ]] && lc=$LIMIT_CONN
        printf "%-12s %-10s %-10s %-6s\n" "${u:0:10}" "${pass:0:8}" "$days" "$lc"
    done
    echo -e "${C_BARRA}=====================================================${C_RESET}"; read -p " Enter para salir..."
}

fun_monitor_online() {
    while true; do
        clear
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        msg_center "${C_TITULO} MONITOR DE USUARIOS EN VIVO ${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        printf "${C_TEXTO}%-15s %-10s %-10s %s${C_RESET}\n" "USUARIO" "DIAS" "CONN" "ESTADO"
        echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
        for u in $(listar_usuarios_vpn); do
            if ! iptables -nL OUTPUT 2>/dev/null | grep -q "owner UID match $(id -u $u)"; then iptables -I OUTPUT -m owner --uid-owner "$u" -j ACCEPT >/dev/null 2>&1; fi
            con_count=$(ps -u "$u" 2>/dev/null | grep -E 'sshd|dropbear' | grep -v grep | wc -l)
            if [[ "$con_count" -ge 0 ]]; then
                 days=$(get_ssh_days "$u"); con_limit="Inf"
                 if [[ -f "$DB_USERS/$u" ]]; then source "$DB_USERS/$u"; [[ "$LIMIT_CONN" != "0" ]] && con_limit=$LIMIT_CONN; fi
                 if [[ "$con_count" -gt 0 ]]; then COLOR_USR="${C_VERDE}"; ESTADO="ONLINE"; else COLOR_USR="${C_TEXTO}"; ESTADO="OFFLINE"; fi
                 printf "${COLOR_USR}%-15s${C_RESET} %-10s %-10s %s\n" "${u:0:14}" "$days" "$con_count/$con_limit" "$ESTADO"
            fi
        done
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_DATO}Presiona 0 para Salir | Actualizando...${C_RESET}"
        read -t 2 -n 1 key; if [[ "$key" == "0" ]]; then break; fi
    done
}

fun_eliminar_vencidos() { 
    clear; echo "Limpiando..."; for u in $(listar_usuarios_vpn); do er=$(chage -l "$u"|grep Expires|cut -d: -f2); if [[ "$er" != *"never"* ]]; then if [[ $(date +%Y%m%d) -gt $(date -d "$er" +%Y%m%d) ]]; then userdel --force "$u"; rm -f "$DB_USERS/$u"; fi; fi; done; echo "OK"; sleep 2 
}

fun_eliminar_todos() { 
    clear; read -p "SI para borrar: " c; if [[ "$c" == "SI" ]]; then for u in $(listar_usuarios_vpn); do userdel --force "$u"; rm -f "$DB_USERS/$u"; done; fi 
}

fun_banner() { 
    clear
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    msg_center "${C_TITULO} CONFIGURAR BANNER SSH (HTML) ${C_RESET}"
    echo -e " ${C_TEXTO}[1] > EDITAR BANNER ACTUAL (NANO)${C_RESET}"
    echo -e " ${C_TEXTO}[2] > RESTAURAR BANNER REAGENS ORIGINAL${C_RESET}"
    echo -e " ${C_TEXTO}0) VOLVER${C_RESET}"
    echo -n " Opcion: "; read op_ban
    case $op_ban in
        1) if command -v nano &> /dev/null; then nano /etc/issue.net; else vi /etc/issue.net; fi; service ssh restart > /dev/null 2>&1; echo "Hecho."; sleep 2;;
        2) echo '<h1 style="text-align:center">REAGENS VPN PRO</h1>' > /etc/issue.net; service ssh restart > /dev/null 2>&1; echo "Restaurado."; sleep 2;;
    esac
}

fun_clave_default() { 
    clear; echo "Nueva Clave Default:"; read p; echo "$p" > "$FILE_PASS"
}

# --- TOKENS (APP ID) ---
check_base_pass() {
    if [ ! -f "$TOKEN_PASS_FILE" ]; then
        clear; echo -e "${C_DATO} ¡CONFIGURACION INICIAL TOKEN!${C_RESET}"
        read -p " Introduce la CONTRASEÑA BASE de la APK: " BASE_PASS
        if [[ -z "$BASE_PASS" ]]; then return; fi
        echo "$BASE_PASS" > "$TOKEN_PASS_FILE"; echo -e "${C_VERDE}Guardada.${C_RESET}"; sleep 2
    fi
}

change_base_pass() {
    clear; echo -e "${C_ROJO} CUIDADO: Afecta nuevos usuarios.${C_RESET}"
    read -p " Nueva contraseña base: " NUEVA_PASS
    if [[ -z "$NUEVA_PASS" ]]; then return; fi
    echo "$NUEVA_PASS" > "$TOKEN_PASS_FILE"; echo -e "${C_VERDE}Actualizada.${C_RESET}"; sleep 2
}

crear_token() {
    clear; check_base_pass; BASE_PASS=$(cat "$TOKEN_PASS_FILE")
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    msg_center "${C_TITULO} CREAR TOKEN ID (APP) ${C_RESET}"
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    echo -n " Cliente (Ref): "; read CLIENTE_NOMBRE
    echo -n " Token ID: "; read TOKEN_USER; if [[ -z "$TOKEN_USER" ]]; then return; fi
    if id "$TOKEN_USER" &>/dev/null; then echo -e "${C_ROJO}Existe.${C_RESET}"; sleep 2; return; fi
    echo -n " Dias: "; read DIAS
    
    useradd -M -s /bin/false -c "$CLIENTE_NOMBRE" "$TOKEN_USER"; echo "$TOKEN_USER:$BASE_PASS" | chpasswd
    chage -E "$(date -d "+$DIAS days" +%Y-%m-%d)" "$TOKEN_USER"
    iptables -I OUTPUT -m owner --uid-owner "$TOKEN_USER" -j ACCEPT; netfilter-persistent save > /dev/null 2>&1
    
    echo "PASSWORD=$BASE_PASS" > "$DB_USERS/$TOKEN_USER"
    echo "LIMIT_CONN=0" >> "$DB_USERS/$TOKEN_USER"
    echo "DURATION=$DIAS" >> "$DB_USERS/$TOKEN_USER"
    echo "CLIENT_REF=$CLIENTE_NOMBRE" >> "$DB_USERS/$TOKEN_USER"
    echo -e "\n ${C_VERDE}Token Generado.${C_RESET}"; sleep 2
}

listar_tokens() {
    clear
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    printf "${C_TEXTO}%-15s %-15s %-10s${C_RESET}\n" "TOKEN ID" "CLIENTE" "EXPIRA"
    echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
    for u in $(listar_usuarios_vpn); do
        ref=""; if [[ -f "$DB_USERS/$u" ]]; then source "$DB_USERS/$u"; ref=$CLIENTE_REF; fi
        if [[ -z "$ref" ]]; then ref=$(grep "^$u:" /etc/passwd | cut -d: -f5 | cut -d, -f1); fi
        printf "%-15s %-15s %-10s\n" "${u:0:14}" "${ref:0:14}" "$(get_ssh_days "$u")"
    done
    read -p " Enter..."
}

fun_monitor_tokens() {
    while true; do
        clear
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        msg_center " MONITOR DE TOKENS "
        printf "${C_TEXTO}%-16s %-16s %-10s${C_RESET}\n" "TOKEN" "CLIENTE" "ESTADO"
        echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
        for u in $(listar_usuarios_vpn); do
            if [[ -f "$DB_USERS/$u" ]] && grep -q "CLIENT_REF" "$DB_USERS/$u"; then
                source "$DB_USERS/$u"
                if ! iptables -nL OUTPUT 2>/dev/null | grep -q "owner UID match $(id -u $u)"; then iptables -I OUTPUT -m owner --uid-owner "$u" -j ACCEPT >/dev/null 2>&1; fi
                if [[ $(ps -u "$u" | grep -E 'sshd|dropbear' | wc -l) -gt 0 ]]; then printf "${C_VERDE}%-16s %-16s ON${C_RESET}\n" "${u:0:14}" "${CLIENT_REF:0:14}"; else printf "${C_TEXTO}%-16s %-16s OFF${C_RESET}\n" "${u:0:14}" "${CLIENT_REF:0:14}"; fi
            fi
        done
        echo -e " ${C_DATO}0 para Salir...${C_RESET}"; read -t 2 -n 1 key; if [[ "$key" == "0" ]]; then break; fi
    done
}

# --- MENUS ---
menu_ssh() {
    while true; do
        clear
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        msg_center "${C_TITULO} GESTION DE CUENTAS SSH / DROPBEAR ${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_TEXTO}[1]  > CREAR NUEVO USUARIO (POR DIAS)${C_RESET}"
        echo -e " ${C_TEXTO}[2]  > ELIMINAR USUARIO${C_RESET}"
        echo -e " ${C_TEXTO}[3]  > EDITAR USUARIO (Clave/Dias)${C_RESET}"
        echo -e " ${C_TEXTO}[4]  > RENOVAR USUARIO (Acumulativo)${C_RESET}"
        echo -e " ${C_TEXTO}[5]  > BLOQUEAR / DESBLOQUEAR${C_RESET}"
        echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
        echo -e " ${C_TEXTO}[6]  > DETALLES DE TODOS LOS USUARIOS${C_RESET}"
        echo -e " ${C_TEXTO}[7]  > MONITOR USUARIOS ONLINE (EN VIVO)${C_RESET}"
        echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
        echo -e " ${C_TEXTO}[8]  > ELIMINAR USUARIOS VENCIDOS${C_RESET}"
        echo -e " ${C_TEXTO}[9]  > [!] ELIMINAR TODOS LOS USUARIOS${C_RESET}"
        echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
        echo -e " ${C_DATO}[10] > CONFIGURAR BANNER SSH${C_RESET}"
        echo -e " ${C_DATO}[11] > CONFIGURAR CLAVE GENERAL${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_TEXTO}0)   VOLVER AL MENU ANTERIOR${C_RESET}"
        echo -n " Opcion: "; read op_ssh
        case $op_ssh in 
            1) fun_crear_usuario ;; 2) fun_eliminar_usuario ;; 3) fun_editar_usuario ;; 
            4) fun_renovar_usuario ;; 5) fun_bloqueo_usuario ;; 6) fun_detalles_usuarios ;; 
            7) fun_monitor_online ;; 8) fun_eliminar_vencidos ;; 9) fun_eliminar_todos ;; 
            10) fun_banner ;; 11) fun_clave_default ;; 0) break ;; 
        esac
    done
}

menu_tokens() {
    while true; do
        clear; check_base_pass
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        msg_center "${C_TITULO} GESTION DE TOKENS (APP ID) ${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_TEXTO}[1]  > CREAR NUEVO TOKEN${C_RESET}"
        echo -e " ${C_TEXTO}[2]  > ELIMINAR TOKEN${C_RESET}"
        echo -e " ${C_TEXTO}[3]  > EDITAR TOKEN (Renovar)${C_RESET}"
        echo -e " ${C_TEXTO}[4]  > BLOQUEAR / DESBLOQUEAR${C_RESET}"
        echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
        echo -e " ${C_TEXTO}[5]  > LISTA DE CLIENTES Y TOKENS${C_RESET}"
        echo -e " ${C_TEXTO}[6]  > CAMBIAR CONTRASEÑA BASE (APP)${C_RESET}"
        echo -e " ${C_TEXTO}[7]  > MONITOR DE TOKENS ONLINE${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_TEXTO}0)   VOLVER AL MENU ANTERIOR${C_RESET}"
        echo -n " Opcion: "; read op_t
        case $op_t in
            1) crear_token ;; 2) fun_eliminar_usuario ;; 3) fun_editar_usuario ;; 
            4) fun_bloqueo_usuario ;; 5) listar_tokens ;; 6) change_base_pass ;; 
            7) fun_monitor_tokens ;; 0) break ;;
        esac
    done
}

menu_conexiones() {
    while true; do
        clear
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        msg_center "${C_TITULO} ADMINISTRADOR DE CONEXIONES ${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_TEXTO}[1] > GESTION CUENTAS SSH / DROPBEAR${C_RESET}"
        echo -e " ${C_TEXTO}[2] > GESTION CUENTAS V2RAY / XRAY${C_RESET}"
        echo -e " ${C_DATO}[3] > GESTION TOKENS (APP ID)${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_TEXTO}0) VOLVER AL MENU PRINCIPAL${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -n " Opcion: "; read op_c
        case $op_c in
            1) menu_ssh ;; 2) menu_v2ray ;; 3) menu_tokens ;; 0) break ;;
        esac
    done
}