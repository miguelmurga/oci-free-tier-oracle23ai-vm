# Oracle 23ai Free Semantic Search Infrastructure

Este proyecto proporciona la infraestructura Terraform para desplegar Oracle Database 23ai Free con búsqueda vectorial en Oracle Cloud Infrastructure (OCI) utilizando recursos del nivel gratuito.

## Arquitectura

La arquitectura implementa un sistema RAG (Retrieval-Augmented Generation) con los siguientes componentes:

```
TD
%% 1. VM OCI Free Tier (Podman + Oracle 23ai)
subgraph subGraph1["💻 VM (OCI Always‑Free) + Podman + Hardening"]
direction TB
Q1["Consulta RAG"] --> EM1["Embeddings"]
EM1 --> ORCL["🗂️ Oracle 23ai‑Free‑Semantic‑Search Container<br/>(HTTPS + Logs + Vectores)"]
ORCL --> CONT["Contexto Relevante"]
end
```

### Componentes principales:

1. **VM en OCI Always Free Tier**:
   - Oracle Linux 9.5 ARM (Compatible con Always Free)
   - 4 OCPUs / 24 GB RAM / 200 GB almacenamiento
   - VM.Standard.A1.Flex (ARM)

2. **Contenedores Podman**:
   - Oracle Database 23ai Free con Vector Search
   - Oracle23ai-Free API (Servicio RAG)

3. **Seguridad**:
   - Firewall y configuraciones de seguridad
   - Acceso HTTPS con Nginx como reverse proxy
   - Backups y hardening del sistema

## Prerrequisitos

1. Cuenta en Oracle Cloud Infrastructure (OCI)
2. Terraform instalado localmente
3. Pares de claves OCI configurados
4. Clave SSH generada para acceso a la instancia

## Configuración

1. Clona este repositorio:
   ```bash
   git clone https://github.com/miguelmurga/oci-free-tier-oracle23ai-vm.git
   cd oci-free-tier-oracle23ai-vm
   ```

2. Crea el archivo `terraform.tfvars` a partir del ejemplo:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edita `terraform.tfvars` con tus credenciales OCI:
   ```
   # OCI Authentication
   region           = "mx-queretaro-1"  # Tu región OCI
   tenancy_ocid     = "ocid1.tenancy.oc1..xxxxxxxx"
   user_ocid        = "ocid1.user.oc1..xxxxxxxx"
   fingerprint      = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
   private_key_path = "ruta/a/tu/clave-api-oci.pem"
   compartment_ocid = "ocid1.compartment.oc1..xxxxxxxx"

   # SSH Public Key
   ssh_public_key   = "ssh-rsa AAAAB3Nz...tu-clave-ssh-publica"
   ```

## Despliegue

1. Inicializa Terraform:
   ```bash
   terraform init
   ```

2. Verifica el plan de Terraform:
   ```bash
   terraform plan
   ```

3. Aplica la configuración:
   ```bash
   terraform apply
   ```

## Post-Instalación

Una vez desplegada la instancia:

1. Conéctate a la instancia mediante SSH:
   ```bash
   ssh opc@<IP-PÚBLICA-DE-INSTANCIA>
   ```

2. Revisa el archivo de información de configuración:
   ```bash
   cat SETUP_INFO.txt
   ```

3. Configura la base de datos vectorial:
   ```bash
   sudo /opt/rag/setup-vectordb.sh
   ```

4. Actualiza la API key de OpenAI:
   ```bash
   sudo vi /opt/rag/.env
   ```

5. Reinicia el servicio:
   ```bash
   sudo systemctl restart oracle23ai
   ```

## Acceso a los Servicios

- **Oracle23ai API**: `https://<IP-pública>/`
- **Oracle Enterprise Manager**: `https://<IP-pública>:5500/em`
  - Usuario: system
  - Contraseña: Oracle123456 (cambiar en producción)

## Seguridad

- La instancia está configurada con firewall que permite solo:
  - SSH (22): Acceso administrativo seguro
  - HTTPS (443): Acceso a la API RAG
  - Oracle DB (1521): Acceso a la base de datos (configurable para restringir)
  - Oracle Enterprise Manager (5500): Administración de la base de datos
- Fail2Ban para protección contra ataques de fuerza bruta
- Actualizaciones automáticas de seguridad
- Acceso SSH restringido a claves (no contraseñas)
- Conexiones HTTPS con TLS 1.2+

## Características de Oracle 23ai

- **Búsqueda Vectorial**: Índices optimizados para búsqueda semántica
- **Tipos de Vector**: Soporte nativo para vectores de embeddings
- **Procedimientos Optimizados**: Búsqueda por similitud y búsqueda híbrida
- **Escalabilidad**: Configurado para aprovechar al máximo los recursos gratuitos

## Limitaciones

- La disponibilidad de VM.Standard.A1.Flex puede ser limitada en algunas regiones
- El tier gratuito de OCI tiene restricciones en recursos y tiempo de uso
- Puede ser necesario ajustar parámetros de Oracle Database según la carga de trabajo

## Licencia

Este proyecto está licenciado bajo la Licencia MIT.

## Contribuciones

Las contribuciones son bienvenidas. Por favor, envía tus pull requests o issues.