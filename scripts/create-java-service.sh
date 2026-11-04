#!/usr/bin/env bash

set -euo pipefail

# ---------------------------------------------------------
# Usage
# ---------------------------------------------------------

if [ "$#" -lt 2 ]; then
  echo "Usage:"
  echo "  $0 <service-name> <port> [image-repository]"
  echo
  echo "Example:"
  echo "  $0 observability-demo-service 8084"
  exit 1
fi

SERVICE_NAME="$1"
PORT="$2"
IMAGE_REPOSITORY="${3:-tejupagudala/${SERVICE_NAME}}"

# ---------------------------------------------------------
# Validate input
# ---------------------------------------------------------

if [[ ! "$SERVICE_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "ERROR: service name must use lowercase letters, numbers and hyphens."
  echo "Example: payments-service"
  exit 1
fi

if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: port must be a number."
  exit 1
fi

MODULE_NAME="spring-petclinic-${SERVICE_NAME}"

APP_DIR="app/${MODULE_NAME}"
K8S_DIR="kubernetes/${SERVICE_NAME}"

TEMPLATE_DIR="templates/spring-boot-service"

JAVA_PACKAGE_DIR="${APP_DIR}/src/main/java/org/springframework/samples/petclinic/service"

# Convert:
# observability-demo-service
# into:
# ObservabilityDemoService

CLASS_NAME=$(echo "$SERVICE_NAME" \
  | awk -F'-' '{
      for (i=1; i<=NF; i++) {
        printf "%s%s", toupper(substr($i,1,1)), substr($i,2)
      }
    }')

# ---------------------------------------------------------
# Prevent accidental overwrite
# ---------------------------------------------------------

if [ -d "$APP_DIR" ]; then
  echo "ERROR: $APP_DIR already exists."
  exit 1
fi

if [ -d "$K8S_DIR" ]; then
  echo "ERROR: $K8S_DIR already exists."
  exit 1
fi

# ---------------------------------------------------------
# Create application structure
# ---------------------------------------------------------

echo "Creating Java service: $SERVICE_NAME"

mkdir -p "$JAVA_PACKAGE_DIR"
mkdir -p "${APP_DIR}/src/main/resources"
mkdir -p "$K8S_DIR"

# ---------------------------------------------------------
# Generate pom.xml
# ---------------------------------------------------------

sed \
  -e "s/__SERVICE_NAME__/${SERVICE_NAME}/g" \
  "${TEMPLATE_DIR}/pom.xml.template" \
  > "${APP_DIR}/pom.xml"

# ---------------------------------------------------------
# Generate application.yml
# ---------------------------------------------------------

sed \
  -e "s/__SERVICE_NAME__/${SERVICE_NAME}/g" \
  -e "s/__PORT__/${PORT}/g" \
  "${TEMPLATE_DIR}/src/main/resources/application.yml.template" \
  > "${APP_DIR}/src/main/resources/application.yml"

# ---------------------------------------------------------
# Generate Java application
# ---------------------------------------------------------

sed \
  -e "s/__SERVICE_NAME__/${SERVICE_NAME}/g" \
  -e "s/__CLASS_NAME__/${CLASS_NAME}/g" \
  "${TEMPLATE_DIR}/src/main/java/org/springframework/samples/petclinic/service/ServiceApplication.java.template" \
  > "${JAVA_PACKAGE_DIR}/${CLASS_NAME}Application.java"

# ---------------------------------------------------------
# Generate Dockerfile
# ---------------------------------------------------------

sed \
  -e "s/__SERVICE_NAME__/${SERVICE_NAME}/g" \
  -e "s/__PORT__/${PORT}/g" \
  "${TEMPLATE_DIR}/Dockerfile.template" \
  > "${APP_DIR}/Dockerfile"

# ---------------------------------------------------------
# Add Maven module to parent pom.xml
# ---------------------------------------------------------

python3 - "$MODULE_NAME" <<'PY'
import sys
from pathlib import Path

module = sys.argv[1]

pom = Path("app/pom.xml")
text = pom.read_text()

entry = f"        <module>{module}</module>"

if entry in text:
    print(f"Maven module already exists: {module}")
    sys.exit(0)

if "</modules>" not in text:
    print("ERROR: Could not find </modules> in app/pom.xml")
    sys.exit(1)

text = text.replace(
    "</modules>",
    f"{entry}\n    </modules>",
    1
)

pom.write_text(text)

print(f"Added Maven module: {module}")
PY

# ---------------------------------------------------------
# Generate Helm values
# ---------------------------------------------------------

cat > "${K8S_DIR}/values.yaml" <<VALUES
serviceName: ${SERVICE_NAME}
namespace: petclinic

image:
  repository: ${IMAGE_REPOSITORY}
  tag: latest
  pullPolicy: IfNotPresent

replicaCount: 1

service:
  port: ${PORT}

observability:
  environment: portfolio
  serviceNamespace: petclinic

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

nodeSelector:
  role: backend

tolerations:
  - key: workload
    operator: Equal
    value: backend
    effect: NoSchedule

prometheus:
  enabled: true
  namespace: monitoring
  path: /actuator/prometheus
  interval: 30s
  releaseLabel: kube-prometheus-stack
VALUES

# ---------------------------------------------------------
# Finished
# ---------------------------------------------------------

echo
echo "Service created successfully."
echo
echo "Application:"
echo "  ${APP_DIR}"
echo
echo "Helm values:"
echo "  ${K8S_DIR}/values.yaml"
echo
echo "Service name:"
echo "  ${SERVICE_NAME}"
echo
echo "Port:"
echo "  ${PORT}"
echo
echo "Docker image:"
echo "  ${IMAGE_REPOSITORY}"
