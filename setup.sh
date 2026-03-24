#!/bin/bash

# Script de configuração do LLM Cluster Proxy
# Autor: Michel Vittoria
# Última atualização: Março 2026

set -e  # Sai no primeiro erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de utilidade
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 não está instalado"
        return 1
    fi
    print_success "$1 está instalado"
    return 0
}

# Verificar se é root
if [ "$EUID" -eq 0 ]; then 
    print_warning "Não execute este script como root/sudo"
    exit 1
fi

print_header "LLM CLUSTER PROXY - CONFIGURAÇÃO AUTOMÁTICA"

# 1. Verificar dependências
print_header "1. VERIFICANDO DEPENDÊNCIAS"

check_command python3
check_command pip3
check_command curl
check_command git

# Verificar versão do Python
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

if [ $PYTHON_MAJOR -lt 3 ] || ([ $PYTHON_MAJOR -eq 3 ] && [ $PYTHON_MINOR -lt 10 ]); then
    print_error "Python 3.10+ é necessário (versão atual: $PYTHON_VERSION)"
    exit 1
fi
print_success "Python $PYTHON_VERSION (OK)"

# 2. Instalar LiteLLM
print_header "2. INSTALANDO LITELLM"

if pip3 show litellm &> /dev/null; then
    print_success "LiteLLM já está instalado"
else
    print_warning "Instalando LiteLLM..."
    pip3 install litellm --user
    if [ $? -eq 0 ]; then
        print_success "LiteLLM instalado com sucesso"
    else
        print_error "Falha ao instalar LiteLLM"
        exit 1
    fi
fi

# 3. Criar arquivos de configuração
print_header "3. CRIANDO ARQUIVOS DE CONFIGURAÇÃO"

CONFIG_DIR="$HOME"
LITELLM_CONFIG="$CONFIG_DIR/litellm-config.yaml"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"

# Criar diretório do OpenCode se não existir
mkdir -p "$HOME/.config/opencode"

# Copiar arquivos de configuração
if [ -f "litellm-config.yaml" ]; then
    cp litellm-config.yaml "$LITELLM_CONFIG"
    print_success "Configuração LiteLLM copiada para $LITELLM_CONFIG"
else
    print_warning "Arquivo litellm-config.yaml não encontrado no repositório"
fi

if [ -f "opencode-config.json" ]; then
    cp opencode-config.json "$OPENCODE_CONFIG"
    print_success "Configuração OpenCode copiada para $OPENCODE_CONFIG"
else
    print_warning "Arquivo opencode-config.json não encontrado no repositório"
fi

# 4. Configurar variáveis de ambiente
print_header "4. CONFIGURAÇÃO DE VARIÁVEIS DE AMBIENTE"

ENV_FILE="$HOME/.llm-cluster-env"

cat > "$ENV_FILE" << 'EOF'
# LLM Cluster Proxy - Variáveis de Ambiente
# Adicione suas chaves API abaixo

# DeepSeek API (https://platform.deepseek.com/)
export DEEPSEEK_API_KEY="sua-chave-aqui"

# Groq API (https://console.groq.com/)
export GROQ_API_KEY="sua-chave-aqui"

# OpenRouter API (https://openrouter.ai/)
export OPENROUTER_API_KEY="sua-chave-aqui"

# Google Gemini API (https://aistudio.google.com/)
export GEMINI_API_KEY="sua-chave-aqui"

# Adicione ao seu .bashrc ou .zshrc:
# source ~/.llm-cluster-env
EOF

print_success "Arquivo de variáveis de ambiente criado: $ENV_FILE"
print_warning "Edite $ENV_FILE e adicione suas chaves API"

# 5. Configurar serviço systemd
print_header "5. CONFIGURAÇÃO DO SERVICIO SYSTEMD"

SERVICE_FILE="/etc/systemd/system/litellm.service"
USERNAME=$(whoami)

if [ -f "systemd/litellm.service" ]; then
    sudo cp systemd/litellm.service "$SERVICE_FILE"
    sudo sed -i "s/USUARIO/$USERNAME/g" "$SERVICE_FILE"
    print_success "Arquivo de serviço systemd copiado"
elif [ -f "litellm.service.example" ]; then
    sudo cp litellm.service.example "$SERVICE_FILE"
    sudo sed -i "s/USUARIO/$USERNAME/g" "$SERVICE_FILE"
    print_success "Arquivo de serviço systemd copiado do exemplo"
else
    # Criar arquivo de serviço manualmente
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=LiteLLM Proxy Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USERNAME
WorkingDirectory=/home/$USERNAME
Environment="PATH=/home/$USERNAME/.local/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/$USERNAME/.local/bin/litellm \\
  --config /home/$USERNAME/litellm-config.yaml \\
  --port 4000 \\
  --drop_params \\
  --debug
Restart=always
RestartSec=5
StandardOutput=append:/home/$USERNAME/litellm.log
StandardError=append:/home/$USERNAME/litellm.log

# Limite de recursos
MemoryLimit=512M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF
    print_success "Arquivo de serviço systemd criado manualmente"
fi

# 6. Testar configuração
print_header "6. TESTANDO CONFIGURAÇÃO"

# Verificar se o arquivo de configuração existe
if [ -f "$LITELLM_CONFIG" ]; then
    print_success "Arquivo de configuração LiteLLM encontrado"
else
    print_error "Arquivo de configuração LiteLLM não encontrado: $LITELLM_CONFIG"
fi

# Verificar se o diretório do OpenCode existe
if [ -d "$HOME/.config/opencode" ]; then
    print_success "Diretório OpenCode configurado"
else
    print_error "Diretório OpenCode não encontrado"
fi

# 7. Instruções finais
print_header "7. INSTRUÇÕES FINAIS"

cat << EOF

${GREEN}✅ CONFIGURAÇÃO COMPLETA!${NC}

Para usar o LLM Cluster Proxy:

${YELLOW}1. Configure suas chaves API:${NC}
   Edite o arquivo: ${BLUE}$ENV_FILE${NC}
   Adicione suas chaves API reais

${YELLOW}2. Carregue as variáveis de ambiente:${NC}
   source $ENV_FILE
   (Adicione esta linha ao seu ~/.bashrc ou ~/.zshrc)

${YELLOW}3. Inicie o serviço systemd:${NC}
   sudo systemctl daemon-reload
   sudo systemctl enable litellm
   sudo systemctl start litellm

${YELLOW}4. Verifique o status:${NC}
   sudo systemctl status litellm
   tail -f ~/litellm.log

${YELLOW}5. Teste o endpoint:${NC}
   curl http://localhost:4000/v1/models

${YELLOW}6. Configure o OpenCode:${NC}
   Certifique-se de que ${BLUE}$OPENCODE_CONFIG${NC} está correto

${YELLOW}Comandos úteis:${NC}
   • Monitorar logs: ${BLUE}tail -f ~/litellm.log${NC}
   • Reiniciar serviço: ${BLUE}sudo systemctl restart litellm${NC}
   • Parar serviço: ${BLUE}sudo systemctl stop litellm${NC}
   • Verificar saúde: ${BLUE}curl http://localhost:4000/v1/health${NC}

${GREEN}Documentação completa em: README.md${NC}

EOF

print_success "Script de configuração concluído!"
print_warning "Não se esqueça de configurar suas chaves API em $ENV_FILE"