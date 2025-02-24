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
echo -e "${RED}"
echo "╔══════════════════════════════════════════╗"
echo "║       Removedor de Sites WordPress       ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    print_error "Por favor, execute o script como root (sudo ./remove_wordpress.sh)"
    exit 1
fi

# Função para formatar nome do banco de dados
format_db_name() {
    echo "wp_$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[- ]/_/g')"
}

# Muda para um diretório seguro antes de executar as operações
cd /tmp

# Solicita o nome do site
while true; do
    read -p "$(echo -e "${BLUE}Digite o nome do site que deseja remover:${NC} ")" site_name
    
    # Verifica se o input está vazio
    if [ -z "$site_name" ]; then
        print_error "O nome do site não pode estar vazio!"
        continue
    fi
    
    # Verifica se o nome é apenas uma barra (/) ou outro caminho perigoso
    if [[ "$site_name" == "/" || "$site_name" == "/var" || "$site_name" == "/var/www" || "$site_name" == "/var/www/html" ]]; then
        print_error "Nome de site inválido ou perigoso!"
        continue
    fi
    
    # Converte para minúsculas
    site_name=$(echo "$site_name" | tr '[:upper:]' '[:lower:]')
    db_name=$(format_db_name "$site_name")
    
    # Verifica se o diretório existe
    if [ ! -d "/var/www/html/$site_name" ]; then
        print_error "O diretório /var/www/html/$site_name não existe!"
        continue
    fi
    
    # Se chegou aqui, o nome é válido
    break
done

# Confirmação de segurança
print_warning "ATENÇÃO! Isso irá remover:"
echo -e "${RED}  - Diretório: /var/www/html/$site_name${NC}"
echo -e "${RED}  - Banco de dados: $db_name${NC}"
print_warning "Esta ação não pode ser desfeita!"
echo

while true; do
    read -p "$(echo -e "${YELLOW}Digite o nome do site novamente para confirmar a remoção:${NC} ")" confirmation
    
    # Verifica se o input está vazio
    if [ -z "$confirmation" ]; then
        print_error "A confirmação não pode estar vazia!"
        continue
    fi
    
    if [ "$site_name" != "$confirmation" ]; then
        print_error "Os nomes não coincidem. Operação cancelada por segurança."
        exit 1
    fi
    
    # Se chegou aqui, a confirmação é válida
    break
done

# Verifica uma última vez se o caminho é seguro
if [[ "$site_name" == "/" || "$site_name" == "/var" || "$site_name" == "/var/www" || "$site_name" == "/var/www/html" || -z "$site_name" ]]; then
    print_error "ERRO CRÍTICO: Caminho não seguro detectado. Operação abortada."
    exit 1
fi

# Remove o diretório do site
print_message "Removendo diretório do site..."
rm -rf "/var/www/html/$site_name"

# Remove o banco de dados e revoga privilégios
print_message "Removendo banco de dados..."
mysql -u root -p <<MYSQL_SCRIPT
DROP DATABASE IF EXISTS $db_name;
DROP DATABASE IF EXISTS ${site_name};
DROP DATABASE IF EXISTS ${site_name//-/_};
DROP DATABASE IF EXISTS wp_${site_name};
DROP DATABASE IF EXISTS wp_${site_name//-/_};
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Verifica se existem arquivos de configuração do Apache
if [ -f "/etc/apache2/sites-available/$site_name.conf" ]; then
    echo "Removendo configuração do Apache..."
    a2dissite "$site_name.conf"
    rm "/etc/apache2/sites-available/$site_name.conf"
    service apache2 reload
fi

echo -e "
${GREEN}Remoção concluída com sucesso!${NC}

${BLUE}Itens removidos:${NC}
➜ Diretório: /var/www/html/$site_name
➜ Banco de dados: Tentativa de remoção de:
  - $db_name
  - ${site_name}
  - ${site_name//-/_}
  - wp_${site_name}
  - wp_${site_name//-/_}
➜ Configurações do Apache limpas (se existiam)

${GREEN}O site foi completamente removido do sistema.${NC}"