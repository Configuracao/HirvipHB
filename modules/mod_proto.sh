#!/bin/bash

# --- PYTHON WEBSOCKET ---
fun_python_sock() {
    clear
    echo -e "${C_BARRA}=====================================================${C_RESET}"
    msg_center " AJUSTES PYTHON WEBSOCKET "
    if systemctl is-active --quiet ws-reagens; then
        echo -e " Estado: ${C_VERDE}ACTIVO${C_RESET} | Puerto: $(netstat -tlpn | grep "python3" | awk '{print $4}' | awk -F: '{print $NF}')"
        echo -e " [1] Desactivar"
        echo -e " [2] Cambiar Puerto"
    else
        echo -e " Estado: ${C_ROJO}OFF${C_RESET}"
        echo -e " [1] Activar"
    fi
    echo -n " Opcion: "; read op
    if [[ "$op" == "1" ]]; then
        if systemctl is-active --quiet ws-reagens; then systemctl stop ws-reagens; systemctl disable ws-reagens; echo "Detenido."; sleep 2; return; fi
        echo -n " Puerto (80): "; read p; [[ -z "$p" ]] && p=80
        fuser -k $p/tcp >/dev/null 2>&1
        
        # RE-ESCRIBIR CON PUERTO
        mkdir -p /etc/reagens/bin
        cat <<EOF > /etc/reagens/bin/ws-fix.py
import socket, threading, select, sys
BIND = ('0.0.0.0', $p)
DEST = ('127.0.0.1', 22)
def handler(c):
    t = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try: t.connect(DEST)
    except: c.close(); return
    try:
        c.recv(4096)
        c.send(b'HTTP/1.1 101 REAGENS VPN PRO\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: foo\r\n\r\n')
        while True:
            r, w, x = select.select([c, t], [], [])
            if c in r: d = c.recv(4096); 
                if not d: break
                t.send(d)
            if t in r: d = t.recv(4096); 
                if not d: break
                c.send(d)
    except: pass
    finally: c.close(); t.close()
def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try: s.bind(BIND); s.listen(0); except: sys.exit(1)
    while True: try: c, a = s.accept(); threading.Thread(target=handler, args=(c,)).start(); except: pass
if __name__ == '__main__': main()
EOF
        sed -i "s/BIND = ('0.0.0.0', [0-9]*)/BIND = ('0.0.0.0', $p)/" /etc/reagens/bin/ws-fix.py
        systemctl restart ws-reagens
        iptables -I INPUT -p tcp --dport $p -j ACCEPT; netfilter-persistent save >/dev/null 2>&1
        echo "Activado."; sleep 2
    fi
}

# --- BADVPN ---
fun_badvpn_menu() {
    clear
    msg_center " BADVPN UDP "
    if systemctl is-active --quiet badvpn; then echo -e " Estado: ${C_VERDE}ON${C_RESET}"; else echo -e " Estado: ${C_ROJO}OFF${C_RESET}"; fi
    echo -e " [1] Activar/Reiniciar"
    echo -e " [2] Detener"
    echo -n " Op: "; read op
    if [[ "$op" == "1" ]]; then
        echo -n " Puerto (7300): "; read p; [[ -z "$p" ]] && p=7300
        # DESCARGA BINARIO SI NO EXISTE
        if [ ! -f /usr/bin/badvpn-udpgw ]; then
            wget -q -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/prem/master/badvpn-udpgw64"
            chmod +x /usr/bin/badvpn-udpgw
        fi
        cat <<EOF > /etc/systemd/system/badvpn.service
[Unit]
Description=BadVPN
After=network.target
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:$p --max-clients 1000
Restart=always
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload; systemctl enable badvpn; systemctl restart badvpn
        iptables -I INPUT -p udp --dport $p -j ACCEPT; netfilter-persistent save >/dev/null 2>&1
        echo "Activado."; sleep 2
    elif [[ "$op" == "2" ]]; then
        systemctl stop badvpn; rm /etc/systemd/system/badvpn.service; echo "Detenido."; sleep 2
    fi
}

# --- FORCE SMART ---
fun_force_smart() {
    clear; msg_center " FORCE EMERGENCIA (SMART) "
    fuser -k 80/tcp >/dev/null 2>&1
    DETECTED="NO"
    # Check V2ray
    if [[ -f "$V2RAY_CONF" ]]; then
        if [[ $(jq -r '.inbounds[0].port' "$V2RAY_CONF") == "80" ]]; then
            systemctl restart v2ray; echo "Reiniciado V2Ray en 80."; DETECTED="YES"
        fi
    fi
    # Check Python Fallback
    if [[ "$DETECTED" == "NO" ]]; then
        systemctl restart ws-reagens; echo "Reiniciado Python WS en 80."
    fi
    sleep 2
}

# --- MENUS WRAPPER ---
menu_ajustes_puertos() {
    while true; do
        clear
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        msg_center "${C_TITULO} AJUSTES DE PUERTOS Y PROTOCOLOS ${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_TEXTO}[1] > PYTHON WEBSOCKET${C_RESET}"
        echo -e " ${C_TEXTO}[2] > SSL / STUNNEL4${C_RESET}"
        echo -e " ${C_TEXTO}[3] > BADVPN UDP GATEWAY${C_RESET}"
        echo -e " ${C_TEXTO}[4] > DROPBEAR SSH${C_RESET}"
        echo -e "${C_BARRA}-----------------------------------------------------${C_RESET}"
        echo -e " ${C_TEXTO}[5] > INSTALADOR V2RAY / XRAY${C_RESET}"
        echo -e " ${C_DATO}[6] > FORCE EMERGENCIA (Smart Recovery)${C_RESET}"
        echo -e "${C_BARRA}=====================================================${C_RESET}"
        echo -e " ${C_TEXTO}0) VOLVER AL MENU ANTERIOR${C_RESET}"
        echo -n " Opcion: "; read op_proto
        case $op_proto in 
            1) fun_python_sock ;; 
            2) fun_ssl_menu ;; # Usar funcion original si existe o agregar
            3) fun_badvpn_menu ;; 
            4) fun_dropbear_menu ;; # Usar funcion original si existe o agregar
            5) proto_v2ray_manager ;; 
            6) fun_force_smart ;;
            0) break ;; 
        esac
    done
}

# --- STUBS PARA SSL Y DROPBEAR (SI NO ESTABAN EN TU CODIGO, AQUI ESTAN BASICOS) ---
fun_ssl_menu() {
    clear; echo "Instalando SSL Stunnel..."; apt-get install stunnel4 -y
    echo -n "Puerto SSL: "; read p
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj "/CN=Reagens" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem >/dev/null 2>&1
    echo -e "[ssh]\naccept=$p\nconnect=127.0.0.1:22\ncert=/etc/stunnel/stunnel.pem" > /etc/stunnel/stunnel.conf
    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
    service stunnel4 restart; echo "Hecho."; sleep 2
}

fun_dropbear_menu() {
    clear; echo "Instalando Dropbear..."; apt-get install dropbear -y
    echo -n "Puerto Dropbear: "; read p
    sed -i "s/NO_START=1/NO_START=0/" /etc/default/dropbear
    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$p/" /etc/default/dropbear
    service dropbear restart; echo "Hecho."; sleep 2
}