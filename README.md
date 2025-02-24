# Ambiente WordPress no WSL

Este repositório contém scripts para facilitar a criação e gerenciamento de ambientes WordPress no Windows utilizando o WSL (Windows Subsystem for Linux).

## Visão Geral

O WSL permite executar um ambiente Linux completo dentro do Windows, ideal para desenvolvimento web. Este projeto inclui:

- Script para instalação automatizada do WordPress
- Script para remoção segura de instalações
- Configurações para desenvolvimento de plugins e temas

## Pré-requisitos

- Windows 10/11 com WSL 2 instalado
- Ubuntu (ou outra distribuição Linux) no WSL
- LAMP stack configurado (Apache, MySQL, PHP)

## Instalação do Ambiente Base

Para configurar o ambiente base no WSL:

```bash
# Atualizar pacotes
sudo apt update && sudo apt upgrade -y

# Instalar Apache, MySQL, PHP e extensões necessárias
sudo apt install apache2 mysql-server php php-mysql php-curl php-gd php-xml php-mbstring php-zip unzip

# Iniciar serviços
sudo service apache2 start
sudo service mysql start

# Configurar MySQL
sudo mysql_secure_installation
```

## Scripts Disponíveis

### 1. Instalador WordPress

O script `install_wordpress.sh` cria automaticamente:
- Diretório para o site
- Banco de dados MySQL
- Usuário do banco com permissões
- Arquivo wp-config.php configurado
- Permissões corretas para desenvolvimento

#### Recursos
- Validação de entradas
- Formatação automática de nomes
- Teste de conexão com banco de dados
- Permissões específicas para desenvolvimento de plugins/temas

### 2. Removedor WordPress

O script `remove_wordpress.sh` limpa completamente uma instalação:
- Remove diretório do site
- Apaga banco de dados
- Remove configurações do Apache (se existirem)
- Incluí múltiplas validações de segurança

## Como Usar

### Instalação de um Novo Site

1. Salve o script como `install_wordpress.sh`
2. Dê permissão de execução:
   ```bash
   sudo chmod +x install_wordpress.sh
   ```
3. Execute:
   ```bash
   sudo ./install_wordpress.sh
   ```
4. Siga as instruções na tela
5. Complete a instalação pelo navegador acessando `http://localhost/seu-site`

### Remoção de um Site

1. Salve o script como `remove_wordpress.sh`
2. Dê permissão de execução:
   ```bash
   sudo chmod +x remove_wordpress.sh
   ```
3. Execute:
   ```bash
   sudo ./remove_wordpress.sh
   ```
4. Siga as instruções e confirme a remoção digitando o nome do site

## Desenvolvimento

Após a instalação, você pode:

1. Acessar os arquivos do WordPress via WSL:
   ```bash
   cd /var/www/html/seu-site
   ```

2. Ou via Windows Explorer:
   ```
   \\wsl$\Ubuntu\var\www\html\seu-site
   ```

3. Instalar dependências Node.js em plugins/temas:
   ```bash
   cd /var/www/html/seu-site/wp-content/plugins/seu-plugin
   npm install
   ```

## Dicas

- Para ver todos os bancos de dados:
  ```bash
  mysql -u root -p
  SHOW DATABASES;
  ```

- Para reiniciar serviços:
  ```bash
  sudo service apache2 restart
  sudo service mysql restart
  ```

- Para configurar Node.js no WSL:
  ```bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  nvm install --lts
  ```

## Resolução de Problemas

- **Erro de conexão com banco de dados**: Verifique wp-config.php e credenciais MySQL
- **Problema com permissões**: Execute `sudo chown -R seu-usuario:seu-usuario /caminho/para/pasta`
- **npm install falha**: Verifique permissões da pasta com `ls -la`