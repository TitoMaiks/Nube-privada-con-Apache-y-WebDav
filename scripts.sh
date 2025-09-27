#!/bin/bash

# WebDAV multiusuario con carpetas privadas, sin HTTPS

# Optimizado para evitar error Forbidden
 
# ============================

# Variables editables

# ============================

DOMAIN="IP de Apache"      # dominio o IP de tu servidor

DAV_ROOT="/var/www/webdav"

PASS_FILE="/etc/apache2/webdav.passwd"
 
# Lista de usuarios a crear (usuario:contraseña)

USUARIOS=(

    "Usuario1:Contraseña"

    "Usuario2:Contraseña"

)
 
# ============================

# Instalación paquetes necesarios

# ============================

echo "[INFO] Instalando Apache2 y utilidades..."

apt update

apt install -y apache2 apache2-utils ufw
 
# Activar módulos Apache necesarios

a2enmod dav dav_fs dav_lock auth_basic
 
# ============================

# Crear directorio raíz WebDAV

# ============================

echo "[INFO] Creando carpeta raíz $DAV_ROOT ..."

mkdir -p $DAV_ROOT

chown -R www-data:www-data $DAV_ROOT

chmod -R 750 $DAV_ROOT
 
# ============================

# Crear usuarios y carpetas privadas

# ============================

echo "[INFO] Configurando usuarios y carpetas privadas..."

for u in "${USUARIOS[@]}"; do

    IFS=":" read USER PASS <<< "$u"
 
    # Crear carpeta privada

    USER_DIR="$DAV_ROOT/$USER"

    mkdir -p "$USER_DIR"

    chown -R www-data:www-data "$USER_DIR"

    chmod -R 750 "$USER_DIR"
 
    # Crear usuario en htpasswd

    if [ -f "$PASS_FILE" ]; then

        htpasswd -b $PASS_FILE $USER $PASS

    else

        htpasswd -cb $PASS_FILE $USER $PASS

    fi

done
 
chmod 640 $PASS_FILE

chown root:www-data $PASS_FILE
 
# ============================

# Configurar Apache VirtualHost

# ============================

echo "[INFO] Creando VirtualHost Apache..."

cat > /etc/apache2/sites-available/webdav.conf <<EOF
<VirtualHost *:80>

    ServerName $DOMAIN

EOF
 
for u in "${USUARIOS[@]}"; do

    IFS=":" read USER PASS <<< "$u"

    USER_DIR="$DAV_ROOT/$USER"

    cat >> /etc/apache2/sites-available/webdav.conf <<EOD

    Alias /webdav/$USER $USER_DIR
<Directory $USER_DIR>

        DAV On

        AuthType Basic

        AuthName "WebDAV $USER"

        AuthUserFile $PASS_FILE

        Require user $USER

        Options Indexes FollowSymLinks

        AllowOverride None
</Directory>
 
EOD

done
 
cat >> /etc/apache2/sites-available/webdav.conf <<EOF

    ErrorLog \${APACHE_LOG_DIR}/webdav_error.log

    CustomLog \${APACHE_LOG_DIR}/webdav_access.log combined
</VirtualHost>

EOF
 
# ============================

# Activar sitio y reiniciar Apache

# ============================

a2ensite webdav.conf

systemctl restart apache2
 
# ============================

# Configurar UFW

# ============================

echo "[INFO] Configurando firewall UFW..."

ufw allow OpenSSH

ufw allow 'Apache'

ufw --force enable
 
# ============================

# Montar WebDAV localmente (para un usuario)

# ============================

echo "[INFO] Instalando davfs2 y montando carpeta para el usuario Mikel..."

apt install -y davfs2
 
mkdir -p /home/kali/Documents/webdav
mkdir -p /home/kali/Documents/webdav2

# Guardar credenciales en el archivo secrets

mkdir -p /home/kali/.davfs2

echo "http://$DOMAIN/webdav/$USER $USER Contraseña" >> /home/kali/.davfs2/secrets
echo "http://$DOMAIN/webdav/$USER $USER Contraseña" >> /home/kali/.davfs2/secrets
chmod 600 /home/kali/.davfs2/secrets
 
# Montar sin sudo (si kali está en grupo davfs2)

usermod -aG davfs2 kali

mount -t davfs http://$DOMAIN/webdav/Usuario1 /home/kali/Documents/webdav
mount -t davfs http://$DOMAIN/webdav/Usuario1 /home/kali/Documents/webdav2
chown kali:kali /home/kali/Documents/webdav
chown root:root /home/kali/Documents/webdav

systemctl start apache2
systemctl enable apache2 
# ============================

# Resultado final

# ============================

echo "==========================================="

echo "[OK] Servidor WebDAV multiusuario instalado y accesible."
for u in "${USUARIOS[@]}"; do

    IFS=":" read USER PASS <<< "$u"

    echo "Acceso $USER: http://$DOMAIN/webdav/$USER (usuario: $USER, contraseña: $PASS)"

done

echo "==========================================="
