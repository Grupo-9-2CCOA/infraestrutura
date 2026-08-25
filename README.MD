# Infraestrutura AWS - Terraform

Este repositório contém a infraestrutura como código (IaC) do projeto de extensão acadêmico **Doces com Amor**, utilizando **Terraform** para provisionar e gerenciar os recursos na AWS.

## Objetivo

Provisionar uma infraestrutura organizada em camadas, separando os recursos públicos e privados da aplicação.

A infraestrutura contempla a hospedagem do Frontend, Backend, banco de dados MySQL, armazenamento de dados para análise e recursos de observabilidade.

## Arquitetura

```text
                              Internet
                                 |
                                 v
                    Application Load Balancer
                                 |
                    +------------+------------+
                    |                         |
                    v                         v
               Frontend A                Frontend B
            Public Subnet A           Public Subnet B
                    |                         |
                    v                         v
               Backend A                 Backend B
           Private Subnet A          Private Subnet B
                    |                         |
                    +------------+------------+
                                 |
                                 v
                            EC2 MySQL
                         Private Subnet DB
                                 |
                                 v
                         VPC Endpoint S3
                                 |
                    +------------+------------+
                    |            |            |
                    v            v            v
                  Bronze       Silver        Gold
                    S3           S3           S3
```

O **Application Load Balancer** recebe as requisições provenientes da internet e distribui o tráfego entre as duas instâncias de Frontend.

Cada Frontend se comunica com seu respectivo Backend:

```text
Frontend A -> Backend A
Frontend B -> Backend B
```

As instâncias de Backend estão em subnets privadas e não possuem exposição direta à internet.

Os dois Backends acessam o banco de dados **MySQL**, executado em uma instância EC2 localizada em uma subnet privada dedicada ao banco de dados.

## Componentes

A infraestrutura é composta por:

- 1 VPC;
- 2 subnets públicas;
- 2 subnets privadas para Backend;
- 1 subnet privada para o banco de dados;
- 2 instâncias EC2 para Frontend;
- 2 instâncias EC2 para Backend;
- 1 instância EC2 para MySQL;
- 1 Application Load Balancer;
- Internet Gateway;
- NAT Gateway;
- Route Tables;
- Security Groups;
- VPC Endpoint para Amazon S3;
- 3 buckets Amazon S3;
- Amazon CloudWatch;
- Amazon SNS.

## Armazenamento e Análise de Dados

O projeto utiliza três buckets Amazon S3 para organizar os dados destinados à análise.

### Bronze

Armazena os dados brutos, preservando as informações próximas ao formato original.

### Silver

Armazena os dados após processos de limpeza, tratamento e padronização.

### Gold

Armazena os dados preparados para consumo analítico, como dashboards, indicadores e relatórios.

## Segurança

A comunicação entre as camadas da aplicação é controlada através de Security Groups.

O fluxo permitido segue a arquitetura:

```text
Internet
   |
   v
ALB
   |
   v
Frontend
   |
   v
Backend
   |
   v
MySQL
```

O MySQL aceita conexões na porta `3306` somente das instâncias de Backend.

As instâncias de Backend e MySQL não possuem exposição direta à internet.

Credenciais e informações sensíveis não devem ser armazenadas no repositório, incluindo:

- AWS Access Key;
- AWS Secret Access Key;
- AWS Session Token;
- Senha do MySQL;
- Arquivos `.pem`;
- Arquivos `.tfstate`;
- Arquivos `.env`.

## Observabilidade

A infraestrutura utiliza **Amazon CloudWatch** para monitoramento dos recursos provisionados.

O CloudWatch é responsável pela coleta e visualização de métricas da infraestrutura, além da criação de alarmes.

O **Amazon SNS** é utilizado para envio de notificações quando os alarmes configurados são acionados.

## Pré-requisitos

Para executar o projeto é necessário possuir:

- Terraform;
- AWS CLI;
- Conta AWS;
- Credenciais AWS configuradas.

Verifique as instalações:

```bash
terraform version
aws --version
```

## Execução

Inicialize o Terraform:

```bash
terraform init
```

Valide as configurações:

```bash
terraform validate
```

Visualize os recursos que serão criados:

```bash
terraform plan
```

Provisione a infraestrutura:

```bash
terraform apply
```

Para remover os recursos provisionados:

```bash
terraform destroy
```

## Projeto

**Projeto:** Doces com Amor  
**Tipo:** Projeto de Extensão Acadêmico  
**Cloud Provider:** AWS  
**Infrastructure as Code:** Terraform  
**Banco de Dados:** MySQL  

Este repositório tem como objetivo manter a infraestrutura AWS do projeto versionada, documentada e reproduzível através do Terraform.