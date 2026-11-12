#!/usr/bin/env bash
# ============================================================
# XAMPP Control Panel - Aesthetic Terminal Edition
# Soporta: Fedora, Debian, Ubuntu, Arch, Termux
# ============================================================

set -e

# --- Paleta de Colores ---
ACCENT='\033[38;5;39m'
SUCCESS='\033[38;5;46m'
DANGER='\033[38;5;196m'
WARN='\033[38;5;220m'
MUTED='\033[38;5;240m'
FG='\033[38;5;255m'
NC='\033[0m'

# Variables de estado
WEB_PORT=80
DB_MODE="ROOT_SIN_PASS"
DB_USER="root"
DB_PASS=""
MARKER_LINUX="/var/www/html/.lamp_installed"
MARKER_TERMUX="$HOME/.lamp_installed"

detect_entorno() {
    ARCH=$(uname -m)
    if [ -n "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
        ENTORNO="termux"; DISTRO="termux"; WEB_PORT=8080
    elif [ -f /etc/os-release ]; then
        . /etc/os-release; DISTRO="$ID"; ENTORNO="linux"
    else
        echo -e "${DANGER}Entorno no soportado.${NC}"; exit 1
    fi

    case "$DISTRO" in
        ubuntu|linuxmint|pop|debian|kali) FAMILIA="debian" ;;
        fedora|rhel|centos)               FAMILIA="fedora" ;;
        arch|manjaro|endeavouros)         FAMILIA="arch" ;;
        termux)                           FAMILIA="termux" ;;
        *)                                FAMILIA="desconocida" ;;
    esac
}

get_db_service() {
    if systemctl list-unit-files | grep -q "^mariadb.service"; then echo "mariadb"; 
    elif systemctl list-unit-files | grep -q "^mysql.service"; then echo "mysql"; 
    else echo "mariadb"; fi
}

get_status() {
    local apache="OFF"; local mysql="OFF"; local php="OFF"
    
    if [ "$ENTORNO" = "termux" ]; then
        pgrep -x "httpd" >/dev/null && apache="ON"
        pgrep -x "mysqld" >/dev/null && mysql="ON"
        command -v php >/dev/null && php="ON"
    else
        local DB_SVC=$(get_db_service)
        local WEB_SVC="httpd"; [ "$FAMILIA" = "debian" ] && WEB_SVC="apache2"
        
        systemctl is-active --quiet $WEB_SVC 2>/dev/null && apache="ON"
        systemctl is-active --quiet $DB_SVC 2>/dev/null && mysql="ON"
        command -v php >/dev/null && php="ON"
    fi

    [ "$apache" = "ON" ] && apache="${SUCCESS}[ ONLINE ]${NC}" || apache="${DANGER}[ OFFLINE ]${NC}"
    [ "$mysql" = "ON" ] && mysql="${SUCCESS}[ ONLINE ]${NC}" || mysql="${DANGER}[ OFFLINE ]${NC}"
    [ "$php" = "ON" ] && php="${SUCCESS}[ ONLINE ]${NC}" || php="${DANGER}[ OFFLINE ]${NC}"

    echo -e " | Apache (Puerto $WEB_PORT) : $apache"
    echo -e " | MariaDB               : $mysql"
    echo -e " | PHP                   : $php"
}

check_installed() {
    if [ "$ENTORNO" = "termux" ]; then
        [ -f "$MARKER_TERMUX" ] && return 0
        command -v httpd &>/dev/null && command -v mysqld &>/dev/null && return 0
    else
        [ -f "$MARKER_LINUX" ] && return 0
        { command -v apache2 &>/dev/null || command -v httpd &>/dev/null; } && command -v php &>/dev/null && command -v mariadb &>/dev/null && return 0
    fi
    return 1
}

# ============================================================
# INSTALACION
# ============================================================
instalar_termux() {
    clear; echo -e "${WARN}Instalando en Termux...${NC}"
    read -p "Modo de seguridad (1: Root sin pass, 2: Usuario custom) [1]: " mode
    if [ "$mode" = "2" ]; then
        DB_MODE="CUSTOM"; DB_USER="admin"
        read -p "Contrasena para el usuario $DB_USER: " -s DB_PASS; echo ""
    else
        DB_MODE="ROOT_SIN_PASS"; DB_USER="root"; DB_PASS=""
    fi
    
    pkg update -y && pkg install -y apache2 php php-apache mariadb phpmyadmin whiptail
    pkill -9 httpd 2>/dev/null || true; pkill -9 mysqld 2>/dev/null || true; sleep 1

    if [ ! -d "$PREFIX/var/lib/mysql/mysql" ]; then
        mariadb-install-db --user="$(whoami)" >/dev/null 2>&1 || true
    fi

    mkdir -p "$PREFIX/var/log/apache2" "$PREFIX/etc/apache2/logs" "$PREFIX/var/run"
    PHP_INI="$PREFIX/lib/php.ini"
    [ ! -f "$PHP_INI" ] && cp "$PREFIX/lib/php.ini-development" "$PHP_INI" 2>/dev/null || true
    sed -i "s|;mysqli.default_socket =.*|mysqli.default_socket = $PREFIX/var/run/mysqld.sock|" "$PHP_INI" 2>/dev/null || true
    sed -i 's/;extension=mysqli/extension=mysqli/' "$PHP_INI" 2>/dev/null || true

    PMA_CONF="$PREFIX/share/phpmyadmin/config.inc.php"
    if [ -f "$PMA_CONF" ]; then
        if [ "$DB_MODE" = "ROOT_SIN_PASS" ]; then
            sed -i "s/\['AllowNoPassword'\] = false;/\['AllowNoPassword'\] = true;/g" "$PMA_CONF" 2>/dev/null || true
        fi
        sed -i "s/\['host'\] = 'localhost';/\['host'\] = '127.0.0.1';/g" "$PMA_CONF" 2>/dev/null || true
    fi

    cat > "$PREFIX/etc/apache2/httpd.conf" <<INNER
ServerRoot "$PREFIX"
ServerName localhost
Listen $WEB_PORT
LoadModule mpm_prefork_module libexec/apache2/mod_mpm_prefork.so
LoadModule authn_core_module libexec/apache2/mod_authn_core.so
LoadModule authz_host_module libexec/apache2/mod_authz_host.so
LoadModule authz_core_module libexec/apache2/mod_authz_core.so
LoadModule auth_basic_module libexec/apache2/mod_auth_basic.so
LoadModule mime_module libexec/apache2/mod_mime.so
LoadModule log_config_module libexec/apache2/mod_log_config.so
LoadModule env_module libexec/apache2/mod_env.so
LoadModule unixd_module libexec/apache2/mod_unixd.so
LoadModule dir_module libexec/apache2/mod_dir.so
LoadModule alias_module libexec/apache2/mod_alias.so
LoadModule php_module libexec/apache2/libphp.so

ErrorLog "var/log/apache2/error_log"
DocumentRoot "$PREFIX/share/apache2/default-site/htdocs"

<Directory "$PREFIX/share/apache2/default-site/htdocs">
    AllowOverride All
    Require all granted
</Directory>
<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>
Alias /phpmyadmin "$PREFIX/share/phpmyadmin"
<Directory "$PREFIX/share/phpmyadmin">
    AllowOverride All
    Require all granted
</Directory>
INNER

    local init_sql=$(mktemp)
    if [ "$DB_MODE" = "CUSTOM" ]; then
        echo "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" > "$init_sql"
        echo "GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost' WITH GRANT OPTION;" >> "$init_sql"
        echo "FLUSH PRIVILEGES;" >> "$init_sql"
    else
        echo "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('');" > "$init_sql"
        echo "FLUSH PRIVILEGES;" >> "$init_sql"
    fi
    mysqld_safe --datadir="$PREFIX/var/lib/mysql" --init-file="$init_sql" > /dev/null 2>&1 &
    sleep 6; rm -f "$init_sql"

    termux-setup-storage 2>/dev/null || true
    mkdir -p /sdcard/Documents/htdocs
    rm -rf "$PREFIX/share/apache2/default-site/htdocs"
    ln -s /sdcard/Documents/htdocs "$PREFIX/share/apache2/default-site/htdocs"
    touch "$MARKER_TERMUX"
    echo -e "${SUCCESS}Instalacion Termux completada.${NC}"; sleep 2
}

instalar_linux() {
    clear; echo -e "${WARN}Instalando/Reparando LAMP en $DISTRO...${NC}"
    
    echo "Selecciona el modo de acceso:"
    echo "  1) Modo XAMPP (Root sin contrasena - Entrar directo)"
    echo "  2) Modo Seguro (Usuario personalizado)"
    read -p "Opcion [1]: " mode
    
    if [ "$mode" = "2" ]; then
        DB_MODE="CUSTOM"; DB_USER="admin"
        read -p "Contrasena para el usuario $DB_USER: " -s DB_PASS; echo ""
    else
        DB_MODE="ROOT_SIN_PASS"; DB_USER="root"; DB_PASS=""
    fi

    if [ "$FAMILIA" = "debian" ]; then
        sudo apt update 
        sudo apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-zip phpmyadmin
        sudo ln -sf /usr/share/phpmyadmin /var/www/html/phpmyadmin 2>/dev/null || true
        
        if [ "$DB_MODE" = "ROOT_SIN_PASS" ]; then
            # Forzar a phpMyAdmin a entrar directo
            sudo sed -i "s/\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'cookie';/\$cfg['Servers'][\$i]['auth_type'] = 'config';/g" /etc/phpmyadmin/config.inc.php
            sudo sed -i "s/\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = false;/\$cfg['Servers'][\$i]['AllowNoPassword'] = true;/g" /etc/phpmyadmin/config.inc.php
            echo "\$cfg['Servers'][\$i]['user'] = 'root';" | sudo tee -a /etc/phpmyadmin/config.inc.php >/dev/null
            echo "\$cfg['Servers'][\$i]['password'] = '';" | sudo tee -a /etc/phpmyadmin/config.inc.php >/dev/null
            
            sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('');" 2>/dev/null || true
            sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
        fi

    elif [ "$FAMILIA" = "fedora" ]; then
        sudo dnf install -y httpd mariadb-server php php-mysqlnd php-gd php-mbstring php-xml php-zip
        sudo dnf install -y phpmyadmin || true
        
        # Configurar Apache para phpMyAdmin
        CONF="/etc/httpd/conf.d/phpMyAdmin.conf"
        if [ -f "$CONF" ]; then
            sudo bash -c "cat > $CONF" <<EOF
Alias /phpMyAdmin /usr/share/phpMyAdmin
Alias /phpmyadmin /usr/share/phpMyAdmin
<Directory /usr/share/phpMyAdmin/>
   AddDefaultCharset UTF-8
   <IfModule mod_authz_core.c>
     Require all granted
   </IfModule>
</Directory>
EOF
            if command -v chcon &>/dev/null; then
                sudo chcon -R -t httpd_sys_content_t /usr/share/phpMyAdmin 2>/dev/null || true
            fi
        fi
        
        if [ "$DB_MODE" = "ROOT_SIN_PASS" ]; then
            # Forzar a phpMyAdmin a entrar directo
            sudo sed -i "s/\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'cookie';/\$cfg['Servers'][\$i]['auth_type'] = 'config';/g" /etc/phpMyAdmin/config.inc.php
            sudo sed -i "s/\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = false;/\$cfg['Servers'][\$i]['AllowNoPassword'] = true;/g" /etc/phpMyAdmin/config.inc.php
            echo "\$cfg['Servers'][\$i]['user'] = 'root';" | sudo tee -a /etc/phpMyAdmin/config.inc.php >/dev/null
            echo "\$cfg['Servers'][\$i]['password'] = '';" | sudo tee -a /etc/phpMyAdmin/config.inc.php >/dev/null

            sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('');" 2>/dev/null || true
            sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
        fi

        sudo systemctl enable --now httpd mariadb
        sudo systemctl restart httpd

    elif [ "$FAMILIA" = "arch" ]; then
        sudo pacman -S --noconfirm apache mariadb php php-apache phpmyadmin
        sudo systemctl enable --now httpd mariadb
        sudo sed -i 's/^#LoadModule mpm_prefork_module/LoadModule mpm_prefork_module/' /etc/httpd/conf/httpd.conf || true
        sudo sed -i 's/^LoadModule mpm_event_module/#LoadModule mpm_event_module/' /etc/httpd/conf/httpd.conf || true
        grep -q "LoadModule php_module" /etc/httpd/conf/httpd.conf || echo "LoadModule php_module modules/libphp.so" | sudo tee -a /etc/httpd/conf/httpd.conf >/dev/null
        grep -q "AddHandler php-script" /etc/httpd/conf/httpd.conf || echo "AddHandler php-script .php" | sudo tee -a /etc/httpd/conf/httpd.conf >/dev/null
        
        if [ -d "/usr/share/webapps/phpMyAdmin" ]; then
            sudo ln -sf /usr/share/webapps/phpMyAdmin /usr/share/httpd/htdocs/phpmyadmin || true
        fi
        
        if [ "$DB_MODE" = "ROOT_SIN_PASS" ]; then
            # Forzar a phpMyAdmin a entrar directo
            sudo sed -i "s/\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'cookie';/\$cfg['Servers'][\$i]['auth_type'] = 'config';/g" /etc/webapps/phpmyadmin/config.inc.php
            sudo sed -i "s/\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = false;/\$cfg['Servers'][\$i]['AllowNoPassword'] = true;/g" /etc/webapps/phpmyadmin/config.inc.php
            echo "\$cfg['Servers'][\$i]['user'] = 'root';" | sudo tee -a /etc/webapps/phpmyadmin/config.inc.php >/dev/null
            echo "\$cfg['Servers'][\$i]['password'] = '';" | sudo tee -a /etc/webapps/phpmyadmin/config.inc.php >/dev/null

            sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('');" 2>/dev/null || true
            sudo mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
        fi
        sudo systemctl restart httpd
    fi

    if [ "$DB_MODE" = "CUSTOM" ]; then
        sudo mysql <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    fi

    sudo touch "$MARKER_LINUX"
    echo -e "${SUCCESS}Instalacion y configuracion completada.${NC}"; sleep 2
}

instalar_lamp() {
    if [ "$ENTORNO" = "termux" ]; then instalar_termux; else instalar_linux; fi
    read -p "Presiona Enter para continuar..."
}

# ============================================================
# FUNCIONES EXTRA (CAMBIAR PUERTO)
# ============================================================
cambiar_puerto() {
    clear
    echo -e "${ACCENT}--- CONFIGURACION DE PUERTO APACHE ---${NC}"
    echo -e " Puerto actual: ${FG}$WEB_PORT${NC}"
    read -p " Ingresa el nuevo puerto (ej. 80, 8080, 8000): " nuevo_puerto
    
    if ! [[ "$nuevo_puerto" =~ ^[0-9]+$ ]]; then
        echo -e "${DANGER}Puerto invalido. Debe ser un numero.${NC}"; sleep 2; return
    fi

    WEB_PORT=$nuevo_puerto
    echo -e "${WARN}Cambiando Apache al puerto $WEB_PORT...${NC}"

    if [ "$ENTORNO" = "termux" ]; then
        sed -i "s/^Listen .*/Listen $WEB_PORT/" "$PREFIX/etc/apache2/httpd.conf"
        pkill -9 httpd 2>/dev/null || true; httpd
    else
        if [ "$FAMILIA" = "debian" ]; then
            sudo sed -i "s/^Listen .*/Listen $WEB_PORT/" /etc/apache2/ports.conf
            sudo systemctl restart apache2
        elif [ "$FAMILIA" = "fedora" ] || [ "$FAMILIA" = "arch" ]; then
            sudo sed -i "s/^Listen .*/Listen $WEB_PORT/" /etc/httpd/conf/httpd.conf
            sudo systemctl restart httpd
        fi
    fi
    echo -e "${SUCCESS}Puerto cambiado a $WEB_PORT exitosamente.${NC}"
    sleep 2
}

# ============================================================
# ACCIONES
# ============================================================
start_services() {
    if ! check_installed; then
        echo -e "${DANGER}No esta instalado. Iniciando instalacion...${NC}"; sleep 1
        instalar_lamp; return
    fi
    echo -e "${WARN}Iniciando servicios...${NC}"
    if [ "$ENTORNO" = "termux" ]; then
        httpd 2>/dev/null || apachectl start 2>/dev/null || true
        mysqld_safe --datadir="$PREFIX/var/lib/mysql" --socket="$PREFIX/var/run/mysqld.sock" > /dev/null 2>&1 &
    else
        local DB_SVC=$(get_db_service)
        case "$FAMILIA" in
            debian) sudo systemctl start apache2 $DB_SVC ;;
            fedora|arch) sudo systemctl start httpd $DB_SVC ;;
        esac
    fi
    sleep 1
}

stop_services() {
    echo -e "${DANGER}Deteniendo servicios...${NC}"
    if [ "$ENTORNO" = "termux" ]; then
        pkill -9 httpd 2>/dev/null || true; pkill -9 mysqld 2>/dev/null || true
    else
        local DB_SVC=$(get_db_service)
        case "$FAMILIA" in
            debian) sudo systemctl stop apache2 $DB_SVC ;;
            fedora|arch) sudo systemctl stop httpd $DB_SVC ;;
        esac
    fi
    sleep 1
}

restart_services() {
    stop_services; start_services
    echo -e "${SUCCESS}Servicios reiniciados.${NC}"; sleep 1
}

abrir_phpmyadmin() {
    local url="http://localhost:$WEB_PORT/phpmyadmin"
    echo -e "${ACCENT}Abriendo $url ...${NC}"
    if command -v xdg-open &>/dev/null; then xdg-open "$url" >/dev/null 2>&1
    elif command -v termux-open-url &>/dev/null; then termux-open-url "$url"
    else echo -e "${WARN}Abre manualmente: $url${NC}"; fi
    sleep 1
}

# ============================================================
# PANEL PRINCIPAL
# ============================================================
panel_control() {
    while true; do
        clear
        echo -e "${ACCENT}+--------------------------------------------------------+${NC}"
        echo -e "${ACCENT}|${NC}  ${FG}XAMPP CONTROL PANEL${NC} ${MUTED}(Terminal Edition)${NC}               ${ACCENT}|${NC}"
        echo -e "${ACCENT}+--------------------------------------------------------+${NC}"
        
        echo -e " Sistema: ${FG}$DISTRO${NC} | Arquitectura: ${FG}$ARCH${NC}"
        
        if [ "$DB_MODE" = "ROOT_SIN_PASS" ]; then
            echo -e " Seguridad BD: ${WARN}[ ROOT SIN CONTRASENA ]${NC} (Entrar directo)"
        else
            echo -e " Seguridad BD: ${SUCCESS}[ USUARIO: $DB_USER ]${NC} (Requiere pass)"
        fi
        
        echo -e "${MUTED}+--------------------------------------------------------+${NC}"
        get_status
        echo -e "${MUTED}+--------------------------------------------------------+${NC}"
        
        echo -e "  ${SUCCESS}[1]${NC} Iniciar Servicios      ${DANGER}[2]${NC} Detener Servicios"
        echo -e "  ${WARN}[3]${NC} Reiniciar Servicios    ${ACCENT}[4]${NC} Abrir phpMyAdmin"
        echo -e "  ${ACCENT}[5]${NC} Instalar / Reparar LAMP"
        echo -e "  ${WARN}[6]${NC} Config: Cambiar Puerto Apache"
        echo -e "  ${DANGER}[0]${NC} Salir"
        echo -e "${MUTED}+--------------------------------------------------------+${NC}"
        
        echo -ne " ${ACCENT}->${NC} Selecciona una opcion [0-6]: "
        read opt
        case $opt in
            1) start_services ;;
            2) stop_services ;;
            3) restart_services ;;
            4) abrir_phpmyadmin ;;
            5) instalar_lamp ;;
            6) cambiar_puerto ;;
            0) clear; echo -e "${SUCCESS}Saliendo del panel...${NC}"; exit 0 ;;
            *) echo -e "${DANGER}Opcion invalida.${NC}"; sleep 1 ;;
        esac
    done
}

detect_entorno
panel_control