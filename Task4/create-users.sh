#!/bin/bash

set -euo pipefail

MINIKUBE_DIR="${HOME}/.minikube"
CA_CERT="${MINIKUBE_DIR}/ca.crt"
CA_KEY="${MINIKUBE_DIR}/ca.key"

if [ ! -f "$CA_CERT" ] || [ ! -f "$CA_KEY" ]; then
    echo "Сертификаты minikube не найдены!"
    echo "Убедитесь, что minikube установлен и запущен"
    exit 1
fi

CERTS_DIR="./kube-users"
mkdir -p "${CERTS_DIR}"

create_user() {
    local username=$1
    local groups=$2
    local namespace=$3

    echo "Создаём пользователя: $username"
    echo "Группы: ${groups:-<none>}"
    echo "Неймспейс: ${namespace:-<default>}"

    openssl genrsa -out "${CERTS_DIR}/${username}.key" 2048 >/dev/null 2>&1

    if [ -n "$groups" ]; then
        openssl req -new -key "${CERTS_DIR}/${username}.key" \
            -out "${CERTS_DIR}/${username}.csr" \
            -subj "/CN=${username}/O=${groups//,//O=}" >/dev/null 2>&1
    else
        openssl req -new -key "${CERTS_DIR}/${username}.key" \
            -out "${CERTS_DIR}/${username}.csr" \
            -subj "/CN=${username}" >/dev/null 2>&1
    fi

    openssl x509 -req -in "${CERTS_DIR}/${username}.csr" \
        -CA "$CA_CERT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -out "${CERTS_DIR}/${username}.crt" \
        -days 365 >/dev/null 2>&1

    kubectl config set-credentials "${username}" \
        --client-certificate="${CERTS_DIR}/${username}.crt" \
        --client-key="${CERTS_DIR}/${username}.key" \
        --embed-certs=true >/dev/null

        if [ -n "$namespace" ]; then
        kubectl config set-context "${username}-context" \
            --cluster=minikube \
            --user="${username}" \
            --namespace="${namespace}" >/dev/null
    else
        kubectl config set-context "${username}-context" \
            --cluster=minikube \
            --user="${username}" >/dev/null
    fi

    echo "  [✓] Пользователь ${username} создан с контекстом ${username}-context"
    echo
}

echo "Создаём пользователей minikube"
echo "----------------------------------"

create_user "chewbacca" "qa-team" ""
create_user "luke_dev" "developers" "development"
create_user "obi_wan" "senior-developers" "production"
create_user "tarkin" "senior-devops-engineers" "development"
create_user "vader" "senior-devops-engineers" "production"
create_user "palpatine" "cluster-administrators" ""

echo "  [✓] Пользователи успешно созданы!"
echo "Файлы сертификатов помещены в каталог ${CERTS_DIR}/"