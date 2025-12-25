#!/bin/bash

# ==================================================
# REAGENS VPN PRO - SETUP ULTIMATE (BASH ONLY)
# PROTOCOLO SMART FORCE - 101 CUSTOM - MEGA BANNER
# ==================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
NC='\033[0m'

# CONFIGURACION
REPO_URL="https://raw.githubusercontent.com/Configuracao/HirvipHB/main"
MENU_URL="${REPO_URL}/menu"
REPARADOR_URL="${REPO_URL}/reparador.sh"
MASTER_IP4="34.69.99.5"

# --- FUNCIONES DE SOPORTE ---
conectar_master() {
  local params=$1
  local ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
  curl -s -L -k --connect-timeout 5 -A "$ua" "http://${MASTER_IP4}/validar.php${params}"
}

msg_center() {
  local text="$1"
  local clean_text=$(echo -e "$text" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")
  local len=${#clean_text}
  local cols=53
  local space=$(( ($cols - $len) / 2 ))
  [[ $space -lt 0 ]] && space=0
  printf "%${space}s" " "
  echo -e "$text"
}

fun_save_iptables() {
    if [[ -f /etc/redhat-release ]]; then
        service iptables save >/dev/null 2>&1
    else
        netfilter-persistent save >/dev/null 2>&1
    fi
}

fun_salir_script() {
    clear
    echo ""
    msg_center "${BLUE} ______  _____   ___   _____  _____  _   _  _____${NC}"
    msg_center "${BLUE}| ___ \ |  ___| / _ \ |  __ \ |  ___|| \ | |/  ___|${NC}"
    msg_center "${BLUE}| |_/ / | |__  / /_\ \| |  \/ | |__  |  \| |\ \`--. ${NC}"
    msg_center "${BLUE}|    /  |  __| |  _  || | __  |  __| | . \` | \`--. \\\\${NC}"
    msg_center "${BLUE}| |\ \  | |___ | | | || |_\ \ | |___ | |\  |/\__/ /${NC}"
    msg_center "${BLUE}\_| \_| \____/ \_| |_/ \____/ \____/ \_| \_/\____/ ${NC}"
    echo ""
    msg_center "${YELLOW}CREATOR : REAGENS JEAN${NC}"
    echo ""
    msg_center "${CYAN}Para iniciar REAGENS VPN PRO MANAGER escriba: menu${NC}"
    echo ""
    exit 0
}

# ==================================================
# 0. DETECCION DE SO E INSTALACION DE DEPENDENCIAS
# ==================================================
clear
echo -e "${YELLOW}[!] Identificando Sistema Operativo y Preparando Entorno...${NC}"

if [[ -f /etc/redhat-release ]]; then
    PM="yum"
    yum install -y epel-release >/dev/null 2>&1
    yum install -y curl jq bc wget net-tools psmisc nano git socat cronie iptables-services unzip zip bind-utils openssl python3 python3-pip lsof >/dev/null 2>&1
    systemctl enable crond >/dev/null 2>&1 && systemctl start crond >/dev/null 2>&1
else
    PM="apt-get"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1
    apt-get install -y curl jq bc wget net-tools python3 python3-pip psmisc nano git socat cron iptables-persistent netfilter-persistent dnsutils zip unzip certbot openssl zram-tools lsof >/dev/null 2>&1
fi

mkdir -p /etc/reagens/bin /etc/reagens/users /etc/reagens/bot

# ==========================================
# OPTIMIZACIÓN DE RED REAGENS PRO (TCP BBR)
# ==========================================
echo -e "\n[*] Optimizando Kernel para baja latencia y alta velocidad..."

# 1. Copiar parámetros al archivo de configuración del sistema
cat <<EOF >> /etc/sysctl.conf
# Optimizaciones de Red Reagens
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
EOF

# 2. Aplicar los cambios inmediatamente sin reiniciar
sysctl -p > /dev/null 2>&1

echo -e "[*] ¡Optimización aplicada exitosamente!"
# ==========================================

# ==========================================================
# 2. SISTEMA DE EMERGENCIA & ANCLAJE PUERTO 80 (OPTIMIZADO)
# ==========================================================
echo -e "${YELLOW}[!] Liberando puerto 80 y activando WebSocket Ultra-Speed...${NC}"

fuser -k 80/tcp >/dev/null 2>&1
systemctl stop nginx apache2 httpd 2>/dev/null
sleep 1

# --- AQUÍ EMPIEZA EL NUEVO CÓDIGO OPTIMIZADO ---
cat <<'EOF' > /etc/reagens/bin/ws-fix.py
import socket, threading, select, sys

BIND, DEST = ('0.0.0.0', 80), ('127.0.0.1', 22)
BUFFER_SIZE = 16384  # Buffer aumentado para velocidad fibra
MSG_101 = b'HTTP/1.1 101 REAGENS VPN PRO\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n'

def handler(c_sock):
    c_sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1) # Latencia Cero
    t_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    t_sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    try:
        t_sock.connect(DEST)
        c_sock.send(MSG_101)
        while True:
            r, w, x = select.select([c_sock, t_sock], [], [])
            if c_sock in r:
                d = c_sock.recv(BUFFER_SIZE)
                if not d: break
                t_sock.send(d)
            if t_sock in r:
                d = t_sock.recv(BUFFER_SIZE)
                if not d: break
                c_sock.send(d)
    except: pass
    finally: c_sock.close(); t_sock.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    try: 
        server.bind(BIND)
        server.listen(200) # Soporte para más usuarios simultáneos
    except: sys.exit(1)
    while True:
        try: 
            conn, addr = server.accept()
            threading.Thread(target=handler, args=(conn,), daemon=True).start()
        except: pass

if __name__ == '__main__': main()
EOF
# --- AQUÍ TERMINA EL NUEVO CÓDIGO ---

cat <<EOF > /etc/systemd/system/ws-reagens.service
[Unit]
Description=Reagens Python WS Optimized
After=network.target
[Service]
ExecStart=/usr/bin/python3 /etc/reagens/bin/ws-fix.py
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ws-reagens >/dev/null 2>&1
systemctl restart ws-reagens

# ==================================================
# 3. INSTALACION DE MENU Y BANNERS UNIFICADOS
# ==================================================
echo -e "${YELLOW}[!] Finalizando Banners y Menú...${NC}"
wget -q -O /usr/local/bin/menu "$MENU_URL"
chmod +x /usr/local/bin/menu
ln -sf /usr/local/bin/menu /usr/bin/menu

# --- BANNER SSH (ISSUE.NET) ---
cat <<'EOF' > /etc/issue.net
<p style="text-align:center"><font color="white">
███████████████████████████<br>
███████▀▀▀░░░░░░░▀▀▀███████<br>
████▀░░░░░░░░░░░░░░░░░▀████<br>
███│░░░░░░░░░░░░░░░░░░░│███<br>
██▌│░░░░░░░░░░░░░░░░░░░│▐██<br>
██░└┐░░░░░░░░░░░░░░░░░┌┘░██<br>
██░░└┐░░░░░░░░░░░░░░░┌┘░░██<br>
██░░┌┘▄▄▄▄▄░░░░░▄▄▄▄▄└┐░░██<br>
██▌░│██████▌░░░▐██████│░▐██<br>
███░│▐███▀▀░░▄░░▀▀███▌│░███<br>
██▀─┘░░░░░░░▐█▌░░░░░░░└─▀██<br>
██▄░░░▄▄▄▓░░▀█▀░░▓▄▄▄░░░▄██<br>
████▄─┘██▌░░░░░░░▐██└─▄████<br>
█████░░▐█─┬┬┬┬┬┬┬─█▌░░█████<br>
████▌░░░▀┬┼┼┼┼┼┼┼┬▀░░░▐████<br>
█████▄░░░└┴┴┴┴┴┴┴┘░░░▄█████<br>
███████▄░░░░░░░░░░░▄███████<br>
██████████▄▄▄▄▄▄▄██████████<br>
███████████████████████████<br>
</font></p>
<h4 style="text-align:center"><font color="red">❢◥ ▬▬▬▬▬▬ ◆ ▬▬▬▬▬▬ ◤❢</font><h1 style="text-align:center"><font color="#338AFF"> REAGENS VPN PRO </font><h4 style="text-align:center"><Font color="red">❢◥ ▬▬▬▬▬▬ ◆ ▬▬▬▬▬▬ ◤❢<h4><BR></font><h4 style="text-align:center"></font><h5 style="text-align:center"><font color="blue">----CLARO, ALTICE & VIVA----</font> <h5style="text-align:center"><font color="#338AFF"> | ᴠɪᴅᴇᴏ ʟʟᴀᴍᴀᴅᴀs | ʀᴇᴅᴇs sᴏᴄɪᴀʟᴇs | ɴᴇᴛғʟɪx ʜᴅ | ʏᴏᴜᴛᴜʙᴇ 1440 | ᴅᴇsᴄᴀʀɢᴀs ɪʟɪᴍɪᴛᴀᴅᴀs | xuper |</font><h5 style="text-align:center"></Font><br></h1></font><h4 style="text-align:center"><font color="purple">P‌A‌R‌A‌ ‌M‌A‌Y‌O‌R‌ ‌I‌N‌F‌O‌R‌M‌A‌C‌I‌Ó‌N‌</font><h4 style="text-align:center"><font color="#EF7F1A">ESCRIBE AL WHATSAPP</font> https://wa.me/qr/HNJMIAQ46N4HF1</font><h4 style="text-align:center"><font color="#EF7F1A"> O AL TELEGRAM</font> https://t.me/reagensjp<h4 style="text-align:center"><font color="violet"> CREADO POR REAGENS JEAN </font>
EOF

# --- BANNER MOTD (CONSOLA) ---
cat <<'EOF' > /etc/motd
███████████████████████████
███████▀▀▀░░░░░░░▀▀▀███████
████▀░░░░░░░░░░░░░░░░░▀████
███│░░░░░░░░░░░░░░░░░░░│███
██▌│░░░░░░░░░░░░░░░░░░░│▐██
██░└┐░░░░░░░░░░░░░░░░░┌┘░██
██░░└┐░░░░░░░░░░░░░░░┌┘░░██
██░░┌┘▄▄▄▄▄░░░░░▄▄▄▄▄└┐░░██
██▌░│██████▌░░░▐██████│░▐██
███░│▐███▀▀░░▄░░▀▀███▌│░███
██▀─┘░░░░░░░▐█▌░░░░░░░└─▀██
██▄░░░▄▄▄▓░░▀█▀░░▓▄▄▄░░░▄██
████▄─┘██▌░░░░░░░▐██└─▄████
█████░░▐█─┬┬┬┬┬┬┬─█▌░░█████
████▌░░░▀┬┼┼┼┼┼┼┼┬▀░░░▐████
█████▄░░░└┴┴┴┴┴┴┴┘░░░▄█████
███████▄░░░░░░░░░░░▄███████
██████████▄▄▄▄▄▄▄██████████
███████████████████████████
EOF

sed -i '/^Banner/d' /etc/ssh/sshd_config
echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
systemctl restart ssh >/dev/null 2>&1

# ==================================================
# 4. MENSAJE FINAL
# ==================================================
clear
echo -e "${BLUE}=====================================================${NC}"
msg_center "${GREEN}FELICIDADES TU SISTEMA YA TIENE INSTALADO${NC}"
msg_center "${GREEN}REAGENS VPN PRO MANAGER FOR VPS${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo ""
msg_center "DENTRO DE UNOS SEGUNDOS TU SISTEMA SE REINICIARA"
msg_center "AL INICIAR, ESCRIBE 'menu' PARA ENTRAR"
echo ""
msg_center "${YELLOW}GRACIAS POR USAR ESTE SERVICIO${NC}"
msg_center "${YELLOW}PARA ADMINISTRAR SU VPS${NC}"
echo ""
msg_center "${CYAN}FELIZ RESTO DEL DIA${NC}"
echo ""
echo -e "${BLUE}=====================================================${NC}"

for i in {10..1}; do
  echo -ne "    \r    ${RED}[!]${NC} REINICIANDO VPS EN: ${RED}$i${NC} "
  sleep 1
done
reboot