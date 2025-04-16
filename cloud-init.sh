#!/bin/bash
# Script de configuración para Oracle 23ai Free en VM.Standard.A1.Flex (ARM) 

# Configuración inicial con recursos maximizados (4 OCPUs, 24GB RAM)
echo "Iniciando configuración de Oracle 23ai Free en OCI ARM VM (Standard.A1.Flex, 4 OCPU, 24GB)..."

# Update system (Oracle Linux 9.5 ARM)
echo "Actualizando sistema Oracle Linux 9.5 ARM..."
dnf update -y
dnf install -y epel-release
# Repos para Oracle Linux 9 ARM
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf config-manager --add-repo=https://yum.oracle.com/repo/OracleLinux/OL9/aarch64/appstream/

# Install required packages (completo para VM con recursos)
echo "Instalando paquetes necesarios..."
dnf install -y podman podman-docker nginx certbot python3-certbot-nginx fail2ban dnf-automatic \
    firewalld auditd rclone logrotate unzip jq gpg htop iotop

# Configure automatic updates for security patches
cat > /etc/dnf/automatic.conf << EOF
[commands]
upgrade_type = security
random_sleep = 360
download_updates = yes
apply_updates = yes
reboot = never
emit_via = stdio
EOF

systemctl enable --now dnf-automatic.timer

# Configure firewall
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=1521/tcp
firewall-cmd --permanent --add-port=5500/tcp
firewall-cmd --reload

# Configure Fail2Ban for SSH
cat > /etc/fail2ban/jail.d/sshd.conf << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/secure
maxretry = 3
bantime = 600
findtime = 600
EOF

systemctl enable --now fail2ban

# Setup audit system
systemctl enable --now auditd
auditctl -w /etc/ssh/sshd_config -p wa -k ssh_config
auditctl -w /etc/passwd -p wa -k user_modification
auditctl -w /etc/shadow -p wa -k user_modification
auditctl -w /opt/rag -p wa -k rag_dir

# Configure Nginx as reverse proxy
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

cat > /etc/nginx/conf.d/oracle23ai.conf << EOF
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}
EOF

# Setup environment for Oracle23ai container
mkdir -p /opt/rag
chmod 700 /opt/rag

# Create .env file with pre-defined secure credentials
cat > /opt/rag/.env << EOF
# Credenciales para Oracle23ai-Free-Semantic-Search
# IMPORTANTE: Mantén este archivo con permisos 600

# OpenAI API Key para embeddings y LLM
OPENAI_API_KEY=sk-example-openaikey123456789

# Oracle Connection String
ORA_CONN_STR=system/Oracle123456@//dbhost:1521/FREEPDB1

# JWT Secret para autenticación
JWT_SECRET_KEY=8f4YzR5QbTw3XpGeV7Jm9KcN2HsA6P1dLxD0iFvS8qUoZ5CaB4E

# Usuario y contraseña de la aplicación
APP_ADMIN_USER=oracle23ai_admin
APP_ADMIN_PASSWORD=vD7p!Rt8@Lk2#9sZ*mQ4xG6yH

# Parámetros de configuración
MAX_TOKEN_LIMIT=8192
EMBEDDING_MODEL=text-embedding-3-small
COMPLETION_MODEL=gpt-3.5-turbo
VECTOR_DIMENSION=1536

# Configuración de backups
BACKUP_PASSPHRASE=Bkp@Or@cl3Ai#2023!
BACKUP_RETENTION_DAYS=30
EOF

chmod 600 /opt/rag/.env

# Setup script to pull and run Oracle 23ai container with Oracle DB optimizado para VM ARM A1.Flex
cat > /opt/rag/run-oracle23ai.sh << EOF
#!/bin/bash
# Configuración optimizada para instancia VM.Standard.A1.Flex con 4 OCPUs y 24GB de RAM

# Pull Oracle Database 23ai Free container image
echo "Descargando imagen de Oracle Database 23ai Free..."
podman pull container-registry.oracle.com/database/free:latest

# Create volume for persistent DB storage
echo "Creando volumen persistente para datos de Oracle..."
podman volume create oracle-db-data

# Run the Oracle 23ai Free database container with optimized settings for A1.Flex
echo "Ejecutando Oracle DB con configuración optimizada para VM.Standard.A1.Flex en México..."
podman run -d \\
    --name oracle23ai-db \\
    --restart always \\
    -p 1521:1521 \\
    -p 5500:5500 \\
    -e ORACLE_PWD=Oracle123456 \\
    -e ORACLE_CHARACTERSET=AL32UTF8 \\
    -e ENABLE_SEMANTIC_SEARCH=true \\
    -e INIT_SGA_SIZE=8192 \\
    -e INIT_PGA_SIZE=2048 \\
    -e CPU_COUNT=4 \\
    -e MEMORY_TARGET=16384M \\
    -e ORACLE_EDITION=FREE \\
    -v oracle-db-data:/opt/oracle/oradata \\
    container-registry.oracle.com/database/free:latest

# Pull and run Oracle23ai RAG application container
echo "Descargando imagen de Oracle23ai RAG application..."
podman pull miguelmurga/oracle23ai-free
echo "Ejecutando Oracle23ai RAG application..."
podman run -d \\
    --name oracle23ai \\
    --restart always \\
    -p 8080:8080 \\
    --env-file /opt/rag/.env \\
    -v /opt/rag/data:/app/data \\
    --link oracle23ai-db:dbhost \\
    miguelmurga/oracle23ai-free
EOF

chmod 700 /opt/rag/run-oracle23ai.sh

# Configure rclone for OCI Object Storage backups
mkdir -p /home/opc/.config/rclone
cat > /home/opc/.config/rclone/rclone.conf << EOF
[oci]
type = s3
provider = Other
env_auth = false
access_key_id = ocid1.credential.placeholder
secret_access_key = placeholder-secret-key
endpoint = https://objectstorage.us-chicago-1.oraclecloud.com
acl = private
EOF

chown -R opc:opc /home/opc/.config

# Setup backup script for .env file
cat > /opt/rag/backup-env.sh << EOF
#!/bin/bash
export BACKUP_PASSPHRASE="Bkp@Or@cl3Ai#2023!"
TODAY=\$(date +%Y%m%d)
gpg --batch --yes --passphrase "\$BACKUP_PASSPHRASE" -c /opt/rag/.env
rclone copy /opt/rag/.env.gpg oci:oracle23ai-backups/env-backup-\$TODAY.gpg
rm /opt/rag/.env.gpg

# Mantener solo los backups de los últimos 30 días
rclone delete --min-age 30d oci:oracle23ai-backups/
EOF

chmod 700 /opt/rag/backup-env.sh

# Setup cron job for daily backups
echo "0 2 * * * /opt/rag/backup-env.sh > /opt/rag/backup.log 2>&1" | crontab -

# Systemd service for Oracle23ai
cat > /etc/systemd/system/oracle23ai.service << EOF
[Unit]
Description=Oracle23ai Free Semantic Search with Database
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/rag
ExecStart=/opt/rag/run-oracle23ai.sh
ExecStop=podman stop oracle23ai oracle23ai-db
ExecStopPost=podman rm oracle23ai oracle23ai-db

[Install]
WantedBy=multi-user.target
EOF

# Start services
systemctl daemon-reload
systemctl enable --now nginx
systemctl enable oracle23ai

# Harden SSH configuration
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Create script to setup Oracle 23ai vector tables optimizado para A1.Flex
cat > /opt/rag/setup-vectordb.sh << EOF
#!/bin/bash
# Wait for Oracle DB to be ready
echo "Waiting for Oracle DB to be ready..."
for i in {1..30}; do
  if podman exec -it oracle23ai-db sqlplus system/Oracle123456@//localhost:1521/FREEPDB1 <<< "SELECT 1 FROM DUAL;" &> /dev/null; then
    echo "Oracle DB is ready."
    break
  fi
  echo "Waiting for Oracle DB... \$i/30"
  sleep 10
done

# Create vector tables for semantic search with advanced configuration
echo "Setting up vector tables for semantic search with high performance configuration..."
podman exec -it oracle23ai-db sqlplus system/Oracle123456@//localhost:1521/FREEPDB1 << SQLEOF
-- Configuración optimizada para VM.Standard.A1.Flex (4 OCPUs, 24GB RAM)
ALTER SYSTEM SET db_cache_size=1G SCOPE=SPFILE;
ALTER SYSTEM SET shared_pool_size=1G SCOPE=SPFILE;
ALTER SYSTEM SET pga_aggregate_target=4G SCOPE=SPFILE;
ALTER SYSTEM SET job_queue_processes=4 SCOPE=SPFILE;
ALTER SYSTEM SET parallel_max_servers=8 SCOPE=SPFILE;

-- Create user for vector store with extended privileges
CREATE USER vectordb IDENTIFIED BY "Vector123456";
GRANT CONNECT, RESOURCE, CREATE SESSION, CREATE TABLE, CREATE VIEW, 
      CREATE PROCEDURE, CREATE SEQUENCE, CREATE TRIGGER, CREATE TYPE,
      CREATE MATERIALIZED VIEW TO vectordb;
ALTER USER vectordb QUOTA UNLIMITED ON USERS;

-- Connect as vectordb user
CONNECT vectordb/Vector123456@localhost:1521/FREEPDB1

-- Create vector tables with optimized storage
CREATE TABLE embedding_collections (
  collection_id VARCHAR2(100) PRIMARY KEY,
  description VARCHAR2(2000),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  metadata CLOB
) TABLESPACE USERS
  STORAGE (INITIAL 10M NEXT 10M);

-- Optimized vector table for high performance
CREATE TABLE embedding_vectors (
  vector_id VARCHAR2(100) PRIMARY KEY,
  collection_id VARCHAR2(100) REFERENCES embedding_collections(collection_id),
  document_text CLOB,
  metadata CLOB,
  embedding_vector VECTOR(1536),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  source_url VARCHAR2(2000),
  chunk_id NUMBER,
  embedding_model VARCHAR2(100)
) TABLESPACE USERS
  STORAGE (INITIAL 100M NEXT 100M)
  LOB(document_text) STORE AS SECUREFILE (CACHE);

-- Create high-performance vector index  
CREATE INDEX vs_embedding_idx ON embedding_vectors(embedding_vector) 
INDEXTYPE IS VECTOR_INDEXTYPE 
PARAMETERS ('M=32, efConstruction=128, distance=cosine');

-- Create optimized indexes for queries
CREATE INDEX idx_embedding_collection ON embedding_vectors(collection_id);
CREATE INDEX idx_embedding_time ON embedding_vectors(created_at);

-- Create advanced vector search procedure
CREATE OR REPLACE PROCEDURE vector_search(
  p_collection_id IN VARCHAR2,
  p_query_vector IN VECTOR,
  p_limit IN NUMBER DEFAULT 10,
  p_threshold IN NUMBER DEFAULT 0.75
) AS
BEGIN
  OPEN :results FOR
    SELECT 
      v.vector_id,
      v.document_text,
      v.metadata,
      v.source_url,
      v.chunk_id,
      VECTOR_DISTANCE(v.embedding_vector, p_query_vector) as similarity_score
    FROM 
      embedding_vectors v
    WHERE 
      v.collection_id = p_collection_id
      AND VECTOR_DISTANCE(v.embedding_vector, p_query_vector) <= p_threshold
    ORDER BY 
      VECTOR_DISTANCE(v.embedding_vector, p_query_vector)
    FETCH FIRST p_limit ROWS ONLY;
END;
/

-- Create procedure for hybrid search (vector + keyword)
CREATE OR REPLACE PROCEDURE hybrid_search(
  p_collection_id IN VARCHAR2,
  p_query_vector IN VECTOR,
  p_keywords IN VARCHAR2,
  p_limit IN NUMBER DEFAULT 10
) AS
BEGIN
  OPEN :results FOR
    WITH vector_results AS (
      SELECT 
        vector_id,
        VECTOR_DISTANCE(embedding_vector, p_query_vector) as v_score
      FROM 
        embedding_vectors
      WHERE 
        collection_id = p_collection_id
      ORDER BY 
        v_score
      FETCH FIRST 100 ROWS ONLY
    ),
    keyword_results AS (
      SELECT 
        vector_id,
        1 as k_score
      FROM 
        embedding_vectors
      WHERE 
        collection_id = p_collection_id
        AND CONTAINS(document_text, p_keywords) > 0
    )
    SELECT 
      v.vector_id,
      e.document_text,
      e.metadata,
      e.source_url,
      (v.v_score * 0.7) + (NVL(k.k_score, 0) * 0.3) as combined_score
    FROM 
      vector_results v
      LEFT JOIN keyword_results k ON v.vector_id = k.vector_id
      JOIN embedding_vectors e ON v.vector_id = e.vector_id
    ORDER BY 
      combined_score
    FETCH FIRST p_limit ROWS ONLY;
END;
/

EXIT;
SQLEOF

# Update connection string in .env file
sed -i "s|ORA_CONN_STR=.*|ORA_CONN_STR=vectordb/Vector123456@//dbhost:1521/FREEPDB1|" /opt/rag/.env

echo "Oracle 23ai vector database setup complete with high-performance configuration!"
EOF

chmod 700 /opt/rag/setup-vectordb.sh

# Create a post-deployment info file
cat > /home/opc/SETUP_INFO.txt << EOF
Oracle23ai Free Semantic Search with Vector Database has been deployed!

Important paths:
- Environment file: /opt/rag/.env (update with actual secrets)
- Container startup script: /opt/rag/run-oracle23ai.sh
- Vector DB setup script: /opt/rag/setup-vectordb.sh
- Nginx configuration: /etc/nginx/conf.d/oracle23ai.conf

To start the service manually:
  sudo systemctl start oracle23ai

To set up vector database tables:
  sudo /opt/rag/setup-vectordb.sh

To view service logs:
  sudo journalctl -u oracle23ai
  sudo podman logs oracle23ai
  sudo podman logs oracle23ai-db

Oracle DB credentials:
  System user: system/Oracle123456
  Vector DB user: vectordb/Vector123456
  Enterprise Manager: https://[server-ip]:5500/em
    Username: system
    Password: Oracle123456

Please remember to:
1. Update the /opt/rag/.env file with actual OpenAI API key
2. Run the setup-vectordb.sh script after deployment
3. Configure rclone for backups with: rclone config
4. Set up BACKUP_PASSPHRASE environment variable for encrypted backups
EOF

# Change ownership to opc user
chown -R opc:opc /home/opc/SETUP_INFO.txt