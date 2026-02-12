# Дипломный проект DevOps: Инфраструктура (Sprint 1)

Этот репозиторий содержит код Infrastructure as Code (IaC) для развертывания Kubernetes кластера и сервисного сервера в облаке AWS.

## Структура проекта

* **terraform/** — конфигурация инфраструктуры (AWS EC2, VPC, Security Groups).
* **ansible/** — конфигурация настройки серверов (Docker, K8s Cluster, GitLab Runner).

## Требования

Для развертывания на локальной машине должны быть установлены:
* [Terraform](https://www.terraform.io/) (v1.5+)
* [Ansible](https://www.ansible.com/) (v2.10+)
* [AWS CLI](https://aws.amazon.com/cli/) (настроенный профиль или переменные окружения)

## Подготовка окружения

### 1. SSH Ключи
Сгенерируйте SSH-ключ для доступа к серверам (если его нет):
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/diploma_key
```

### 2. Доступ к AWS
Экспортируйте ваши ключи доступа (никогда не сохраняйте их в коде!):

```bash
export AWS_ACCESS_KEY_ID="ваш_ключ"
export AWS_SECRET_ACCESS_KEY="ваш_секрет"
export AWS_DEFAULT_REGION="us-east-1"
```

## Развертывание (Deployment)

### Шаг 1: Поднятие инфраструктуры (Terraform)
Перейдите в папку terraform и инициализируйте проект:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```
Terraform автоматически создаст файл инвентаря для Ansible по пути ../ansible/inventory/hosts.ini.

Шаг 2: Настройка серверов (Ansible)
Перейдите в папку ansible и запустите плейбук:

```bash
cd ../ansible
ansible-playbook playbooks/site.yml
```

Что делает этот плейбук:
1. Устанавливает Docker и Containerd на все хосты.
2. Инициализирует Kubernetes Control Plane на мастере.
3. Настраивает сеть (Flannel CNI).
4. Автоматически подключает Worker-ноду к кластеру.
5. Устанавливает GitLab Runner на сервер srv.

## Проверка работоспособности
Подключитесь к мастер-ноде:

```bash
ssh -i ~/.ssh/diploma_key ubuntu@<MASTER_IP>
```

Проверьте статус узлов:

```bash
kubectl get nodes
```
Ожидаемый результат: статус Ready для всех узлов.