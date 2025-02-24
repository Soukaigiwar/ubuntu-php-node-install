#!/bin/bash

# Cores para o terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_message() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}Erro:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Atenção:${NC} $1"
}

print_info() {
    echo -e "${BLUE}Info:${NC} $1"
}

# Banner inicial
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║     Instalador Automático WordPress      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then 
    print_error "Por favor, execute o script como root (sudo ./install_wordpress.sh)"
    exit 1
fi

# Função para validar o nome do site (sem espaços ou caracteres especiais)
validate_site_name() {
    if [[ ! $1 =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Nome do site inválido. Use apenas letras, números, hífen e underscore."
        return 1
    fi
    if [[ -z "$1" ]]; then
        print_error "O nome não pode estar vazio."
        return 1
    fi
    return 0
}

# Solicita informações do usuário
print_info "Vamos configurar seu novo site WordPress"

# Loop para obter nome do site válido
while true; do
    read -p "$(echo -e "${BLUE}Digite o nome do site (ex: meusite):${NC} ")" site_name_input
    
    # Verifica se o input está vazio
    if [ -z "$site_name_input" ]; then
        print_error "O nome do site não pode estar vazio!"
        continue
    fi
    
    site_name=$(echo "$site_name_input" | tr '[:upper:]' '[:lower:]')
    if validate_site_name "$site_name"; then
        print_message "O nome do site será: $site_name"
        break
    fi
done

# Função para formatar nome do banco de dados
format_db_name() {
    # Substitui hífens e espaços por underscore e adiciona prefixo wp_
    echo "wp_$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[- ]/_/g')"
}

# Loop para obter nome do banco de dados válido
while true; do
    read -p "$(echo -e "${BLUE}Digite o nome do banco de dados (ou pressione Enter para usar o nome do site):${NC} ")" db_name_input
    if [ -z "$db_name_input" ]; then
        db_name_input=$site_name
    fi
    
    db_name=$(format_db_name "$db_name_input")
    if [[ ! -z "$db_name" ]]; then
        print_message "O nome do banco de dados será: $db_name"
        break
    else
        print_error "Nome de banco de dados inválido!"
    fi
done

# Loop para obter usuário do banco de dados válido
while true; do
    read -p "$(echo -e "${BLUE}Digite o usuário do banco de dados (ou pressione Enter para usar o nome do site):${NC} ")" db_user_input
    if [ -z "$db_user_input" ]; then
        db_user_input=$site_name
    fi
    
    # Remove caracteres problemáticos e limita tamanho para MySQL
    db_user=$(echo "$db_user_input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9_]/_/g' | cut -c 1-16)
    if [[ ! -z "$db_user" ]]; then
        print_message "O usuário do banco de dados será: $db_user"
        break
    else
        print_error "Nome de usuário inválido!"
    fi
done

# Obter senha segura para o banco de dados
while true; do
    read -s -p "$(echo -e "${BLUE}Digite a senha do banco de dados:${NC} ")" db_password
    echo
    
    # Verificar se a senha está vazia
    if [ -z "$db_password" ]; then
        print_error "A senha não pode estar vazia!"
        continue
    fi
    
    # Verificar comprimento mínimo da senha
    if [ ${#db_password} -lt 8 ]; then
        print_warning "A senha deve ter pelo menos 8 caracteres."
        continue
    fi
    
    read -s -p "$(echo -e "${BLUE}Confirme a senha do banco de dados:${NC} ")" db_password_confirm
    echo
    
    if [ "$db_password" != "$db_password_confirm" ]; then
        print_error "As senhas não coincidem!"
        continue
    fi
    
    print_message "Senha definida com sucesso!"
    break
done

# Criar diretório do site
print_message "Criando diretório para o site..."
mkdir -p /var/www/html/$site_name
cd /var/www/html/$site_name

# Download e extração do WordPress
print_message "Baixando WordPress..."
wget -q --show-progress https://wordpress.org/latest.zip
print_message "Extraindo arquivos..."
unzip -q latest.zip
mv wordpress/* .
rm -rf wordpress latest.zip

# Configurar permissões
print_message "Configurando permissões..."
chown -R www-data:www-data /var/www/html/$site_name
chmod -R 755 /var/www/html/$site_name

# Configurar permissões especiais para plugins e themes
print_info "Configurando permissões para desenvolvimento..."
current_user=$(logname)
sudo chown -R $current_user:$current_user /var/www/html/$site_name/wp-content/plugins
sudo chown -R $current_user:$current_user /var/www/html/$site_name/wp-content/themes
print_message "Permissões configuradas para o usuário $current_user"

# Verificar se o MySQL está rodando
if ! service mysql status > /dev/null; then
    print_warning "O MySQL não está em execução. Tentando iniciar..."
    service mysql start
    
    # Verifica novamente
    if ! service mysql status > /dev/null; then
        print_error "Não foi possível iniciar o MySQL. Verifique a instalação."
        exit 1
    fi
fi

# Criar banco de dados e usuário
print_message "Configurando banco de dados..."
# Primeiro, tentar sem senha para ver se o root não tem senha configurada
if mysql -u root -e ";" 2>/dev/null; then
    mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    mysql_status=$?
else
    # Tentar com autenticação de senha
    print_info "Precisamos da senha do usuário root do MySQL para criar o banco de dados."
    mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    mysql_status=$?
fi

if [ $mysql_status -ne 0 ]; then
    print_error "Erro ao configurar o banco de dados."
    exit 1
fi

# Criar wp-config.php
print_message "Configurando wp-config.php..."
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$db_name/" wp-config.php
sed -i "s/username_here/$db_user/" wp-config.php
sed -i "s/password_here/$db_password/" wp-config.php

# Gerar chaves de segurança
print_message "Gerando chaves de segurança..."
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
if [ -z "$SALT" ]; then
    # Se falhar ao obter as chaves online, crie algumas aleatórias
    print_warning "Não foi possível obter chaves online. Gerando chaves localmente..."
    SALT="define('AUTH_KEY',        '$(openssl rand -base64 48)');\n"
    SALT+="define('SECURE_AUTH_KEY', '$(openssl rand -base64 48)');\n"
    SALT+="define('LOGGED_IN_KEY',   '$(openssl rand -base64 48)');\n"
    SALT+="define('NONCE_KEY',       '$(openssl rand -base64 48)');\n"
    SALT+="define('AUTH_SALT',       '$(openssl rand -base64 48)');\n"
    SALT+="define('SECURE_AUTH_SALT','$(openssl rand -base64 48)');\n"
    SALT+="define('LOGGED_IN_SALT',  '$(openssl rand -base64 48)');\n"
    SALT+="define('NONCE_SALT',      '$(openssl rand -base64 48)');\n"
fi
SALT="${SALT//\"/\\\"}"
sed -i "/#@-/,/#@+/c\\$SALT" wp-config.php

# Teste a conexão com o banco de dados
print_message "Testando conexão com o banco de dados..."
if php -r "
\$conn = new mysqli('localhost', '$db_user', '$db_password', '$db_name');
if (\$conn->connect_error) {
    echo 'ERRO: ' . \$conn->connect_error;
    exit(1);
}
echo 'Conexão bem-sucedida!';
\$conn->close();
"
then
    print_message "Conexão com o banco de dados testada com sucesso!"
else
    print_error "Falha na conexão com o banco de dados. Verifique as credenciais."
    print_info "Você pode tentar corrigir manualmente editando o arquivo wp-config.php"
fi

echo -e "
${GREEN}Instalação concluída com sucesso!${NC}

${BLUE}Informações do seu site:${NC}
➜ Site: http://localhost/$site_name
➜ Banco de dados: $db_name
➜ Usuário BD: $db_user
➜ Senha BD: $db_password

${YELLOW}Arquivos do site:${NC}
➜ No Windows Explorer: \\\\wsl$\\Ubuntu\\var\\www\\html\\$site_name

${GREEN}Tudo pronto! Acesse http://localhost/$site_name para configurar o WordPress.${NC}"