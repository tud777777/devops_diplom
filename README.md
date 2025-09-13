# Дипломный практикум в Yandex.Cloud
  * [Цели:](#цели)
  * [Этапы выполнения:](#этапы-выполнения)
     * [Создание облачной инфраструктуры](#создание-облачной-инфраструктуры)
     * [Создание Kubernetes кластера](#создание-kubernetes-кластера)
     * [Создание тестового приложения](#создание-тестового-приложения)
     * [Подготовка cистемы мониторинга и деплой приложения](#подготовка-cистемы-мониторинга-и-деплой-приложения)
     * [Установка и настройка CI/CD](#установка-и-настройка-cicd)
  * [Что необходимо для сдачи задания?](#что-необходимо-для-сдачи-задания)
  * [Как правильно задавать вопросы дипломному руководителю?](#как-правильно-задавать-вопросы-дипломному-руководителю)

---
## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

---
## Этапы выполнения:


### Создание облачной инфраструктуры

1. Создаю два каталога для двух terraform-конфигураций
```
mkdir ~/diplom/terraform-main ~/diplom/terraform-prereq-bucket
```
2. Создаю сервисный аккаунт для каталога diplom-netology в Яндекс Облаке и авторизованный ключ для него через веб-интерфейс

![1-img-1](img/1-img-1.png)

3. Содержимое ключа помещаю в файл ~/diplom/terraform-prereq-bucket/authorized_keys/diplom-netology-admin_authorized_key.json
4. Добавляю .gitignore в каталог ~/diplom/terraform-prereq-bucket/authorized_keys/ с содержимым
```
*key*
```
5. Выполняю terraform init в каталоге ~/diplom/terraform-prereq-bucket
6. Добавляю стандартный для terraform-проекта .gitignore в каталоги ~/diplom/terraform-prereq-bucket/ и ~/diplom/terraform-main
7. Создаю provider.tf
```
terraform {
    required_providers {
        yandex = {
            source = "yandex-cloud/yandex"
        }
    }
}

provider "yandex" {
    zone = var.default_zone
    service_account_key_file = var.authorized_key_file
    cloud_id = var.cloud_id
    folder_id = var.folder_id
}
```
8. Добавляю variables.tf
```
variable "cloud_id" {
    type = string
    description = "Yandex.Cloud Identifier"
}
variable "folder_id" {
    type = string
    description = "Folder Identifier"
}
variable "default_zone" {
    type = string
    description = "Default Zone"
}
variable "authorized_key_file" {
    type = string
    description = "Path to Storage.editor Service Account's authorized_key file"
}
variable "storage_class" {
    type = string
    description = "Bucket's storage class (STANDARD/COLD/ICE)"
}
```
9. terraform.tfvars выглядит следующим образом
```
cloud_id = "b1gmrdbulmjk5vov6tbl"
folder_id = "b1gracaa21gumqmcihci"
default_zone = "ru-central1-a"
authorized_key_file = "./authorized_keys/diplom-netology-admin_authorized_key.json"
storage_class = "STANDARD"
```
10. main.tf, в котором, собственно создаю бакет и сервисный аккаунт для него
```
resource "yandex_storage_bucket" "terraform_state" {
  bucket     = "terraform-state-${var.folder_id}"
  default_storage_class = var.storage_class
  force_destroy = true
  acl = "private"
  access_key = yandex_iam_service_account_static_access_key.sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_key.secret_key
}

resource "yandex_iam_service_account" "sa" {
  name = "sa"
  folder_id = var.folder_id
}

resource "yandex_iam_service_account_static_access_key" "sa_key" {
  service_account_id = yandex_iam_service_account.sa.id
}

resource "yandex_resourcemanager_folder_iam_binding" "storage_editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  members   = ["serviceAccount:${yandex_iam_service_account.sa.id}"]
}

output "bucket_name" {
  value = yandex_storage_bucket.terraform_state.bucket
}

output "access_key" {
  value = yandex_iam_service_account_static_access_key.sa_key.access_key
}

output "secret_key" {
  value = yandex_iam_service_account_static_access_key.sa_key.secret_key
  sensitive = true
}
```
11. Выполняю terraform apply
![1-img-2](img/1-img-2.png)

12. Выполняю команду terraform output secret_key, чтобы получить содержимое закрытого ключа от сервисного аккаунта с ролью storage.editor
13. Добавляю полученные ключи в переменные окружения $ACCESS_KEY и $SECRET_KEY
```
export ACCESS_KEY=YCAJEX2BtfEqiC4w....
export SECRET_KEY=YCMbjPJDul3Pyrpj....
```
14. Перехожу к каталогу terraform-main. Описываю backend вместе с провайдером в файле provider.tf
```
terraform {
    required_providers {
        yandex = {
            source = "yandex-cloud/yandex"
        }
    }
    backend "s3" {
        endpoints = {
            s3 = "https://storage.yandexcloud.net"
        }
        bucket = "terraform-state-b1gracaa21gumqmcihci"
        region = "ru-central1"
        key = "terraform.tfstate"
        skip_region_validation = true
        skip_credentials_validation = true
        skip_requesting_account_id = true
        skip_s3_checksum = true
    }
}

provider "yandex" {
    zone = var.default_zone
    service_account_key_file = var.authorized_key_file
    cloud_id = var.cloud_id
    folder_id = var.folder_id
}
```
15. Выполняю команду terraform init -backend-config="access_key=$ACCESS_KEY" -backend-config="secret_key=$SECRET_KEY"
![1-img-3](img/1-img-3.png)

16. Создаю каталог ~/diplom/terraform-main/authorized_keys и помещаю в него авторизованный ключ сервисного аккаунта, публичный ssh-ключ и .gitignore-файл
```
mkdir ~/diplom/terraform-main/authorized_keys
cp -R ~/diplom/terraform-prereq-bucket/authorized_keys/* ~/diplom/terraform-main/authorized_keys/
cp ~/.ssh/id_ed25519.pub ~/diplom/terraform-main/authorized_keys/
```
17. Описываю переменные для создаваемых инстансов в файле vm-variables.tf
```
variable "platform_id" {
    type = string
    description = "standard-v1/standard-v2/standard-v3"
}
variable "vm-cores" {
    type = number
    description = "Core count"
}
variable "vm-ram" {
    type = number
    description = "RAM Volume"
}
variable "vm-core_fraction" {
    type = number
    description = "core fraction (in percent)"
}
variable "vm-preemptible" {
    type = bool
    description = "Preemptible (true/false)"
}
variable "vm-disk-image_id" {
    type = string
    description = "image id"
}
variable "vm-disk-size" {
    type = number
    description = "Disks volume"
}
variable "vm-disk-type" {
    type = string
}
```
18. Описываю переменные для доступа к Яндекс Облаку в файле variables.tf
```
variable "cloud_id" {
    type = string
    description = "Yandex.Cloud Identifier"
}
variable "folder_id" {
    type = string
    description = "Folder Identifier"
}
variable "default_zone" {
    type = string
    description = "Default Zone"
}
variable "authorized_key_file" {
    type = string
    description = "Path to Storage.editor Service Account's authorized_key file"
}
```
19. terraform.tfvars выглядит так:
```
cloud_id = "b1gmrdbulmjk5vov6tbl"
folder_id = "b1gracaa21gumqmcihci"
default_zone = "ru-central1-a"
authorized_key_file = "./authorized_keys/diplom-netology-admin_authorized_key.json"
platform_id = "standard-v3"
vm-cores = 2
vm-ram = 4
vm-core_fraction = 100
vm-preemptible = true
vm-disk-image_id = "fd81evq9jnnqoa0pc7vf"
vm-disk-size = 20
vm-disk-type = "network-hdd"
```
20. Добавляю файл kubernetes-instances.tf с описанием инстансов и подсетей, которые хочу создать
```
locals {
  subnets = {
    "subnet-ru-central1-a" = { zone = "ru-central1-a", cidr = "192.168.100.0/24" },
    "subnet-ru-central1-b" = { zone = "ru-central1-b", cidr = "192.168.110.0/24" },
    "subnet-ru-central1-d" = { zone = "ru-central1-d", cidr = "192.168.120.0/24" }
  }
  vms = {
    "vm-ru-central1-a" = { zone = "ru-central1-a", subnet_name = "subnet-ru-central1-a" },
    "vm-ru-central1-b" = { zone = "ru-central1-b", subnet_name = "subnet-ru-central1-b" },
    "vm-ru-central1-d" = { zone = "ru-central1-d", subnet_name = "subnet-ru-central1-d" }
  }
}

resource "yandex_vpc_network" "kuber-network" {
    name = "kuber-network"
}

resource "yandex_vpc_subnet" "subnet" {
  for_each       = local.subnets
  name           = each.key
  zone           = each.value.zone
  network_id     = yandex_vpc_network.kuber-network.id
  v4_cidr_blocks = [each.value.cidr]
}

resource "yandex_compute_instance" "kuber-vm" {
  for_each    = local.vms
  name        = each.key
  platform_id = var.platform_id
  zone        = each.value.zone
  allow_stopping_for_update = true
  resources {
    cores  = var.vm-cores
    memory = var.vm-ram
    core_fraction = var.vm-core_fraction
  }
  scheduling_policy {
    preemptible = var.vm-preemptible
  }
  boot_disk {
    initialize_params {
      image_id = var.vm-disk-image_id
      type = var.vm-disk-type
      size = var.vm-disk-size
    }
  }
  network_interface {
    index = 0
    subnet_id = yandex_vpc_subnet.subnet[each.value.subnet_name].id
    nat       = true
  }
  metadata = {
    ssh-keys = "ubuntu:${file("./authorized_keys/id_ed25519.pub")}"
  }
}

resource "yandex_lb_target_group" "ingress_target_group" {
  name = "ingress-target-group"
  dynamic "target" {
    for_each = yandex_compute_instance.kuber-vm
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "ingress_lb" {
  name = "ingress-load-balancer"
  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.ingress_target_group.id
    healthcheck {
      name = "tcp"
      tcp_options {
        port = 80
      }
    }
  }
}

output "Kubernetes-instances-private-IPs" {
  value = { for k, v in yandex_compute_instance.kuber-vm : k => v.network_interface.0.ip_address }
  description = "Private IP addresses of the created instances"
}
output "Kubernetes-instances-public-IPs" {
  value = { for k, v in yandex_compute_instance.kuber-vm : k => v.network_interface.0.nat_ip_address }
  description = "Public IP addresses of the created instances"
}
output "load_balancer_external_ip" {
  value       = yandex_lb_network_load_balancer.ingress_lb.listener[*].external_address_spec[*].address
  description = "External IP address of the Network Load Balancer"
}
```
21. Выполняю terraform apply в каталоге ~/diplom/terraform-main
![1-img-4](img/1-img-4.png)

22. Выполняю terraform destroy, чтобы убедиться, что всё ок
![1-img-5](img/1-img-5.png)

---
### Создание Kubernetes кластера

1. Для работы с kubespray понадобится: 
- склонировать репозиторий https://github.com/kubernetes-sigs/kubespray на свою ВМ
- установить ansible и pip3

```
sudo apt install ansible pyhon3-pip -y
cd ~/diplom && git clone https://github.com/kubernetes-sigs/kubespray
cd kubespray && pip install -r requirements.txt
```
![2-img-1](img/2-img-1.png)

2. Копирую пример конфига кластера в отдельную директорию
```
cp -rfp inventory/sample inventory/netology-cluster
```
3. В каталог terraform-main добавляю файл ansible_inventory.tf в котором описана автоматическая генерация inventory-файла для kubespray
```
locals {

  vm_roles = {
    "vm-ru-central1-a" = "master"
    "vm-ru-central1-b" = "worker1"
    "vm-ru-central1-d" = "worker2"
  }

  hosts = {
    for vm_name, instance in yandex_compute_instance.kuber-vm : local.vm_roles[vm_name] => {
      ansible_host = instance.network_interface.0.nat_ip_address
      access_ip    = instance.network_interface.0.nat_ip_address
      ip           = instance.network_interface.0.ip_address
      ansible_user = "ubuntu"
    }
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tmpl", {
    hosts = local.hosts
  })
  filename = "${path.module}/../kubespray/inventory/netology-cluster/inventory.yml"
}
```
4. В файле ~/diplom/kubespray/inventory/netology-cluster/group_vars/k8s_cluster/k8s-cluster.yml ищу параметр kubeconfig_localhost и выставляю его в true для того, чтобы на локальной машине появился конфиг подключения к кластеру. Также снимаю комментарий с этой строки

5. В файле ~/diplom/kubespray/inventory/netology-cluster/group_vars/k8s_cluster/addons.yml выставляю параметры:

```
ingress_nginx_enabled: true
ingress_nginx_service_type: NodePort
```
Это понадобится для маршрутизации http-запросов между двумя приложениями - grafana и nginx-test-app

6. Запускаю terraform apply снова, для того, чтобы сгенерировать inventory-файл
```
cd ~/diplom/terraform-main && terraform apply
```
```
all:
  hosts:
    master:
      ansible_host: 158.160.57.73
      access_ip: 158.160.57.73
      ip: 192.168.100.14
      ansible_user: ubuntu
    worker1:
      ansible_host: 84.201.164.7
      access_ip: 84.201.164.7
      ip: 192.168.110.33
      ansible_user: ubuntu
    worker2:
      ansible_host: 158.160.187.46
      access_ip: 158.160.187.46
      ip: 192.168.120.17
      ansible_user: ubuntu
  children:
    kube_control_plane:
      hosts:
        master:
    kube_node:
      hosts:
        master:
        worker1:
        worker2:
    etcd:
      hosts:
        master:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
```

7. Запускаю ansible-playbook
```
cd ../kubespray/ && ansible-playbook -i inventory/netology-cluster/inventory.yml cluster.yml -b
```
8. Устанавливаю kubectl на локальную ВМ
```
sudo snap install kubectl --classic
```
9. Копирую содержимое файла ~/diplom/kubespray/inventory/netology-cluster/artifacts/admin.conf в файл ~/.kube/config
```
mkdir ~/.kube && cp ~/diplom/kubespray/inventory/netology-cluster/artifacts/admin.conf ~/.kube/config
```
10. Проверяю подключение к кластеру
```
kubectl get pods --all-namespaces
```
![2-img-2](img/2-img-2.png)


---
### Создание тестового приложения

1. Создал репозиторий на github - https://github.com/thrsnknwldgthtsntpwr/nginx-test-app.git
2. Dockerfile:
```
FROM nginx:alpine
COPY ./index.html /usr/share/nginx/html
EXPOSE 80
```
3. Собрал и запушил в dockerhub
```
cd ~/nginx-test-app
docker login registry.gitlab.com
docker build -t registry.gitlab.com/devops-netology-group/devops_diplom/app:1.0.0 -f ../nginx-test-app/app.dockerfile .
docker push registry.gitlab.com/devops-netology-group/devops_diplom/app:1.0.0
```
4. https://hub.docker.com/repository/docker/thrsnknwldgthtsntpwr/nginx-test-app

5. В настройках репозитория добавил DOCKER_USERNAME и DOCKER_PASSWORD для доступа из github к dockerhub
6. Добавил workflow в github (.github/workflows/docker-publish.yml)
```
name: Docker Build and Push

on:
  push:
    branches:
      - main

jobs:
  build_and_push:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Login to Docker Hub
      uses: docker/login-action@v3
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        file: ./Dockerfile
        push: true
        tags: thrsnknwldgthtsntpwr/nginx-test-app:latest
```
7. Запушил измененную версию страницы - в dockerhub появился latest образ
![3-img-1](img/3-img-1.png)

---
### Подготовка cистемы мониторинга и деплой приложения

Для деплоя prometheus мной был выбран вариант через helm chart

1. Создаю namespace netology в котором будут находиться nginx-test-app и monitoring
```
kubectl create namespace netology
```
2. Устанавливаю helm
```
sudo snap install helm --classic
```
3. Добавляю репозиторий prometheus в helm
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```
4. Устанавливаю prometheus через helm командой:
```
helm install monitoring prometheus-community/kube-prometheus-stack --namespace netology
```
![4-img-1](img/4-img-1.png)

5. Применяю конфиг для ingress
```
kubectl apply -f ~/diplom/ingress-nginx/ingress.yaml
```
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: netology-ingress
  namespace: netology
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80      
      - path: /nginx-test-app
        pathType: Prefix
        backend:
          service:
            name: nginx-test-app-service
            port:
              number: 80
```
![4-img-2](img/4-img-2.png)

6. Разворачиваю deployment и service тестового приложения
```
kubectl apply -f ~/diplom/nginx-test-app/nginx-test-app-deployment.yaml
kubectl apply -f ~/diplom/nginx-test-app/nginx-test-app-service.yaml
```
7. Проверяю доступность grafana и nginx-test-app по адресу балансировщика

![4-img-3](img/4-img-3.png)

8. Получаю пароль от УЗ admin в grafana
```
kubectl --namespace netology get secrets monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```
9. Захожу на веб-интерфейс grafana для добавления дашбордов с метриками kubernetes. Я выбрал этот дашборд - https://grafana.com/grafana/dashboards/18283-kubernetes-dashboard/

Добавляю через Dashboards -> New -> Import 

![4-img-4](img/4-img-4.png)

### Деплой инфраструктуры в terraform pipeline

1. Если на первом этапе вы не воспользовались [Terraform Cloud](https://app.terraform.io/), то задеплойте и настройте в кластере [atlantis](https://www.runatlantis.io/) для отслеживания изменений инфраструктуры. Альтернативный вариант 3 задания: вместо Terraform Cloud или atlantis настройте на автоматический запуск и применение конфигурации terraform из вашего git-репозитория в выбранной вами CI-CD системе при любом комите в main ветку. Предоставьте скриншоты работы пайплайна из CI/CD системы.

Ожидаемый результат:
1. Git репозиторий с конфигурационными файлами для настройки Kubernetes.
2. Http доступ на 80 порту к web интерфейсу grafana.
3. Дашборды в grafana отображающие состояние Kubernetes кластера.
4. Http доступ на 80 порту к тестовому приложению.
5. Atlantis или terraform cloud или ci/cd-terraform
---
### Установка и настройка CI/CD

1. Добавляю файл ci-cd.yaml в репозиторий с тестовым приложением в каталог .github/workflows
```
name: CI/CD Pipeline

on:
  push:
    branches:
      - main
    tags:
      - 'v*'

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Log in to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and Push Docker Image
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.DOCKER_USERNAME }}/nginx-test-app:latest
            ${{ secrets.DOCKER_USERNAME }}/nginx-test-app:${{ github.ref_name }}

  deploy-to-kubernetes:
    runs-on: ubuntu-latest
    needs: build-and-push
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'latest'

      - name: Configure Kubernetes Context
        run: |
          echo "${{ secrets.KUBE_CONFIG_DATA }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig

      - name: Deploy to Kubernetes
        run: |
          export KUBECONFIG=kubeconfig
          kubectl --kubeconfig=kubeconfig apply -f k8s/deployment.yaml -n netology
          kubectl --kubeconfig=kubeconfig apply -f k8s/service.yaml -n netology
          kubectl --kubeconfig=kubeconfig rollout status deployment/nginx-test-app -n netology
```

2. Кодирую конфиг подлкючения к кластеру в base64
```
cat ~/.kube/config | base64
```
3. Добавляю в настройки репозитория на github secrets

KUBE_CONFIG_DATA. Содержимое secret - вывод предыдущей команды

![5-img-1](img/5-img-1.png)

4. Проверяю сборку контейнера
```
cd ~/nginx-test-app
git add .
git commit -m '2.0.1'
git push
git tag v.2.0.1
git push origin tag v.2.0.1
```

5. Вижу, что в dockerhub появились контейнеры с тэгом v.2.0.1 и latest

![5-img-2](img/5-img-2.png)

6. Сама страница 

![5-img-3](img/5-img-3.png)

6. Меняю текст страницы index.html на
```
<head>
    <title>nginx-test-app-index-page-v.3.0.0</title>
</head>
<body>
    <h1>Roman Nikiforov, FOPS-25, v 3.0.0</h1>
</body>
```

7. Выполняю

```
git add .
git commit -m '3.0.0'
git push
git tag v.3.0.0
git push origin v.3.0.0
```

8. Дожидаюсь завершения CI/CD pipeline в github

![5-img-4](img/5-img-4.png)

9. Обновляю страницу

![5-img-5](img/5-img-5.png)

10. Проверяю dockerhub

![5-img-6](img/5-img-6.png)
