terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. СЕТЬ (VPC)
# Создаем изолированную сеть
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "diploma-vpc"
  }
}

# Интернет-шлюз, чтобы серверы могли качать пакеты
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Публичная подсеть
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true         # Раздавать публичные IP автоматически
  availability_zone       = "us-east-1a" # Фиксированная зона
}

# Маршрутизация
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 2. БЕЗОПАСНОСТЬ (Security Group)
resource "aws_security_group" "k8s_sg" {
  name        = "k8s_security_group"
  description = "Allow SSH, K8s ports and internal traffic"
  vpc_id      = aws_vpc.main.id

  # Входящий SSH (порт 22) - открыт для всего мира (для простоты)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Входящий трафик для Kubernetes API (6443)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort Services (диапазон портов для приложений в K8s)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Разрешаем любой трафик ВНУТРИ сети между серверами
  # (мастер должен общаться с воркерами без ограничений)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  
  # Исходящий трафик - разрешено всё (чтобы качать обновления)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. КЛЮЧИ
# Загружаем публичный ключ в AWS
resource "aws_key_pair" "deployer" {
  key_name   = "diploma-key"
  public_key = file("~/.ssh/diploma_key.pub") # Не забываем указать верный путь к файлу :)
}

# 4. СЕРВЕРЫ (EC2 Instances)
# Ищем свежий образ Ubuntu 22.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Сервер Master
resource "aws_instance" "k8s_master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium" # Это база для Kubernetes
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tags = {
    Name = "k8s-master"
    Role = "master"
  }
}

# Сервер Worker (App)
resource "aws_instance" "k8s_worker" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium" 
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tags = {
    Name = "k8s-worker"
    Role = "worker"
  }
}

# Сервер SRV (Инструменты)
resource "aws_instance" "srv" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tags = {
    Name = "srv"
    Role = "srv"
  }
}

# 5. ВЫВОД (Outputs)
# Чтобы после запуска мы сразу увидели IP адреса
output "master_ip" {
  value = aws_instance.k8s_master.public_ip
}
output "worker_ip" {
  value = aws_instance.k8s_worker.public_ip
}
output "srv_ip" {
  value = aws_instance.srv.public_ip
}

# Генерируем файл инвентаря для Ansible
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tftpl", {
    master_ip    = aws_instance.k8s_master.public_ip
    worker_ip    = aws_instance.k8s_worker.public_ip
    srv_ip       = aws_instance.srv.public_ip
    ssh_key_path = "~/.ssh/diploma_key"
  })
  
  # Сохраняем файл в папку ansible/inventory
  filename = "../ansible/inventory/hosts.ini"
}