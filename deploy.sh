#!/bin/bash

# Colores para mensajes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==== Despliegue de Oracle23ai-Free con Base de Datos Vectorial ====${NC}"
echo ""

# Verificar si Terraform está instalado
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform no está instalado.${NC}"
    echo -e "Por favor, instala Terraform primero: https://developer.hashicorp.com/terraform/install"
    exit 1
fi

# Verificar que estamos en el directorio correcto
if [ ! -f "provider.tf" ] || [ ! -f "variables.tf" ]; then
    echo -e "${RED}Error: No estás en el directorio del proyecto Terraform.${NC}"
    echo -e "Por favor, ejecuta este script desde el directorio raíz del proyecto."
    exit 1
fi

# Verificar que el archivo terraform.tfvars existe
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: No se encuentra el archivo terraform.tfvars${NC}"
    echo -e "Creando archivo a partir del ejemplo..."
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${YELLOW}Por favor, edita el archivo terraform.tfvars con tus credenciales antes de continuar.${NC}"
    exit 1
fi

echo -e "${YELLOW}Inicializando Terraform...${NC}"
terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}Error al inicializar Terraform. Abortando.${NC}"
    exit 1
fi

echo -e "${YELLOW}Validando la configuración...${NC}"
terraform validate

if [ $? -ne 0 ]; then
    echo -e "${RED}Error en la validación de la configuración. Abortando.${NC}"
    exit 1
fi

echo -e "${YELLOW}Generando plan de Terraform...${NC}"
terraform plan

if [ $? -ne 0 ]; then
    echo -e "${RED}Error al generar el plan. Revisa los errores mostrados arriba.${NC}"
    exit 1
fi

echo -e "${YELLOW}¿Quieres aplicar el plan y crear la infraestructura? (y/n)${NC}"
read -p "" APPLY

if [[ $APPLY == "y" || $APPLY == "Y" ]]; then
    echo -e "${YELLOW}Aplicando plan de Terraform...${NC}"
    terraform apply -auto-approve
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}¡Despliegue completado con éxito!${NC}"
        
        # Obtener la IP pública
        IP=$(terraform output -raw instance_public_ip 2>/dev/null)
        
        if [ -n "$IP" ]; then
            echo -e "${GREEN}IP pública de la instancia: ${YELLOW}$IP${NC}"
            echo -e "${GREEN}Puedes conectarte mediante SSH:${NC}"
            echo -e "ssh opc@$IP"
            echo ""
            echo -e "${YELLOW}Acceso a los servicios:${NC}"
            echo -e "- Oracle DB Enterprise Manager: ${YELLOW}https://$IP:5500/em${NC}"
            echo -e "  Usuario: system"
            echo -e "  Contraseña: Oracle123456"
            echo -e "- Oracle23ai API: ${YELLOW}https://$IP/${NC}"
            echo -e ""
            echo -e "${YELLOW}Pasos post-despliegue:${NC}"
            echo -e "1. Conéctate por SSH:"
            echo -e "   ssh opc@$IP"
            echo -e "2. Actualiza la clave de API de OpenAI:"
            echo -e "   sudo vi /opt/rag/.env"
            echo -e "3. Configura la base de datos vectorial:"
            echo -e "   sudo /opt/rag/setup-vectordb.sh"
            echo -e "4. Reinicia el servicio:"
            echo -e "   sudo systemctl restart oracle23ai"
        else
            echo -e "${YELLOW}No se pudo obtener la IP pública automáticamente.${NC}"
            echo -e "Ejecuta 'terraform output' para ver la información de salida."
        fi
    else
        echo -e "${RED}Error al aplicar el plan. Revisa los errores mostrados arriba.${NC}"
    fi
else
    echo -e "${YELLOW}Despliegue cancelado.${NC}"
fi