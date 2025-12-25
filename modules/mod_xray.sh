#!/bin/bash

if [[ -f "/usr/local/etc/v2ray/config.json" ]]; then V2RAY_CONF="/usr/local/etc/v2ray/config.json"; else V2RAY_CONF="/etc/v2ray/config.json"; fi
if [[ -f "/usr/local/etc/xray/config.json" ]]; then V2RAY_CONF="/usr/local/etc/xray/config.json"; fi

get_v2_data() {
    if [[ ! -f "$V2RAY_CONF" ]]; then V2_PORT="Error"; return; fi
    V2_PORT=$(jq -r '.inbounds[0].port' "$V2RAY_CONF" 2>/dev/null)
    V2_PROTO=$(jq -r '.inbounds[0].protocol' "$V2RAY_CONF" 2>/dev/null)
    [[ -z "$V2_PORT" || "$V2_PORT" == "null" ]] && V2_PORT="Error"
}

get_v2_days() {
    local user=$1; local meta="$DB_USERS/v2ray/$user"
    if [[ -f "$meta" ]]; then source "$meta"; if [[ -z "$EXP" ]]; then echo "0"; return; fi; echo $(( ($(date -d "$EXP" +%s) - $(date +%s)) / 86400 )); else echo "0"; fi
}

seleccionar_usuario_v2() {
    echo -e "${C_BARRA} SELECCIONAR V2RAY ${C_BARRA}"
    if [[ ! -f "$V2RAY_CONF" ]]; then echo -e " ${C_ROJO}No instalado${C_RESET}"; return 1; fi
    i=1; declare -a v2_users; clients=$(jq -r '.inbounds[0].settings.clients[] | .email // .id' "$V2RAY_CONF")
    if [[ -z "$clients" ]]; then echo -e " ${C_ROJO}Vacio${C_RESET}"; return 1; fi
    for c in $clients; do echo -e " [${C_DATO}$i${C_RESET}] $c"; v2_users[$i]=$c; let i++; done
    echo -n " Numero: "; read opt_v; USER_V2=${v2_users[$opt_v]}
    if [[ -z "$USER_V2" ]]; then echo "Error"; return 1; fi; return 0
}

crear_usuario_v2ray() {
    clear
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    msg_center "${C_TITULO} CREAR USUARIO V2RAY ${C_RESET}"
    get_v2_data
    if [[ "$V2_PORT" == "Error" ]]; then echo "Instale V2Ray primero (Menu Ajustes)"; sleep 2; return; fi
    
    echo -n " Nombre: "; read user; [[ -z "$user" ]] && return
    if grep -q "$user" "$V2RAY_CONF"; then echo "Ya existe"; sleep 2; return; fi
    echo -n " Dias: "; read dias_input
    if [[ ! "$dias_input" =~ ^[0-9]+$ ]]; then echo -e "${C_ROJO}Invalido.${C_RESET}"; sleep 2; return; fi
    
    final_date=$(date -d "+$dias_input days" +%Y-%m-%d); uuid=$(cat /proc/sys/kernel/random/uuid)
    
    if [[ "$V2_PROTO" == "vmess" ]]; then
        jq --arg u "$uuid" --arg e "$user" '.inbounds[0].settings.clients += [{"id": $u, "alterId": 0, "email": $e}]' "$V2RAY_CONF" > "$V2RAY_CONF.tmp"
    else
        jq --arg u "$uuid" --arg e "$user" '.inbounds[0].settings.clients += [{"id": $u, "email": $e}]' "$V2RAY_CONF" > "$V2RAY_CONF.tmp"
    fi
    mv "$V2RAY_CONF.tmp" "$V2RAY_CONF"; systemctl restart v2ray
    
    mkdir -p "$DB_USERS/v2ray"; echo "EXP=$final_date" > "$DB_USERS/v2ray/$user"
    echo "UUID=$uuid" >> "$DB_USERS/v2ray/$user"; echo "DURATION=$dias_input" >> "$DB_USERS/v2ray/$user"
    echo -e "${C_VERDE}Creado.${C_RESET}"; sleep 2
}

eliminar_usuario_v2ray() { 
    clear; seleccionar_usuario_v2 || return
    jq --arg e "$USER_V2" 'del(.inbounds[0].settings.clients[] | select(.email == $e))' "$V2RAY_CONF" > "$V2RAY_CONF.tmp"
    mv "$V2RAY_CONF.tmp" "$V2RAY_CONF"; rm -f "$DB_USERS/v2ray/$USER_V2"
    systemctl restart v2ray; echo "Borrado."; sleep 2
}

detalles_usuario_v2ray() {
    clear; seleccionar_usuario_v2 || { sleep 2; return; }; get_v2_data
    meta_file="$DB_USERS/v2ray/$USER_V2"; uuid=$(jq -r --arg e "$USER_V2" '.inbounds[0].settings.clients[] | select(.email == $e) | .id' "$V2RAY_CONF")
    IP=$(curl -s ipv4.icanhazip.com); V2_NET=$(jq -r '.inbounds[0].streamSettings.network' "$V2RAY_CONF")
    V2_PATH=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' "$V2RAY_CONF"); [[ "$V2_PATH" == "null" ]] && V2_PATH="/"
    V2_HOST=$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host' "$V2RAY_CONF"); [[ "$V2_HOST" == "null" ]] && V2_HOST=""
    V2_TLS=$(jq -r '.inbounds[0].streamSettings.security' "$V2RAY_CONF")
    
    echo -e " Dias Restantes: $(get_v2_days "$USER_V2")"
    if [[ "$V2_PROTO" == "vmess" ]]; then
        tls_val=""; [[ "$V2_TLS" == "tls" ]] && tls_val="tls"
        vmess_json="{\"add\":\"$IP\",\"port\":$V2_PORT,\"id\":\"$uuid\",\"aid\":0,\"scy\":\"auto\",\"net\":\"$V2_NET\",\"type\":\"none\",\"host\":\"$V2_HOST\",\"path\":\"$V2_PATH\",\"tls\":\"$tls_val\",\"ps\":\"$USER_V2\"}"
        link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"
    else
        sec="none"; [[ "$V2_TLS" == "tls" ]] && sec="tls"
        link="vless://$uuid@$IP:$V2_PORT?security=$sec&encryption=none&type=$V2_NET&path=$V2_PATH&host=$V2_HOST#$USER_V2"
    fi
    echo -e "${C_TEXTO}LINK:${C_RESET}\n${C_DATO}$link${C_RESET}"; read p
}

proto_v2ray_manager() {
    clear
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    msg_center "${C_TITULO} V2RAY / XRAY SETUP ${C_RESET}"
    echo -n " [1] Puerto (8080): "; read port; [[ -z "$port" ]] && port=8080
    echo -e " [2] Proto: (1)VMess (2)VLess"; echo -n " Op: "; read pr; [[ "$pr" == "2" ]] && proto="vless" || proto="vmess"
    echo -e " [3] Net: (1)WS (2)TCP"; echo -n " Op: "; read tr; [[ "$tr" == "2" ]] && net="tcp" || net="ws"
    
    path="/"; host_sni=""
    if [[ "$net" == "ws" ]]; then 
        echo -n " [4] Path (/REAGENS): "; read pa; [[ -z "$pa" ]] && path="/REAGENS" || path="$pa"
        echo -n " [5] Host (SNI): "; read hs; host_sni="$hs"
    fi
    echo -e " [6] TLS: (1)No (2)Si"; echo -n " Op: "; read tl; [[ "$tl" == "2" ]] && sec="tls" || sec="none"
    
    echo -e " ${C_DATO}Instalando...${C_RESET}"
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) >/dev/null 2>&1
    mkdir -p /usr/local/etc/v2ray
    
cat <<EOF > "$V2RAY_CONF"
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $port,
      "protocol": "$proto",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "$net", "security": "$sec", "wsSettings": { "path": "$path", "headers": { "Host": "$host_sni" } } }
    }
  ],
  "outbounds": [{ "protocol": "freedom", "settings": {} }]
}
EOF
    systemctl enable v2ray; systemctl restart v2ray
    iptables -I INPUT -p tcp --dport $port -j ACCEPT; netfilter-persistent save >/dev/null 2>&1
    echo -e " ${C_VERDE}Instalado.${C_RESET}"; sleep 3
}

menu_v2ray() {
    while true; do
        clear; echo -e "${C_BARRA}=====================================================${C_RESET}"
        msg_center "${C_TITULO} GESTION V2RAY / XRAY ${C_RESET}"
        get_v2_data; if [[ "$V2_PORT" == "Error" ]]; then echo " No instalado."; else echo -e " ${C_DATO}PROTOCOLO: $V2_PROTO | PUERTO: $V2_PORT${C_RESET}"; fi
        echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
        echo -e " ${C_TEXTO}[1] > CREAR USUARIO${C_RESET}"
        echo -e " ${C_TEXTO}[2] > ELIMINAR USUARIO${C_RESET}"
        echo -e " ${C_TEXTO}[3] > VER LINK${C_RESET}"
        echo -e " ${C_TEXTO}0) VOLVER${C_RESET}"
        echo -n " Opcion: "; read op_v2
        case $op_v2 in 1) crear_usuario_v2ray ;; 2) eliminar_usuario_v2ray ;; 3) detalles_usuario_v2ray ;; 0) break ;; esac
    done
}