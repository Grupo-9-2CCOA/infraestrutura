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
- 1 instância EC2 dedicada ao backup diário do MySQL;
- 1 Application Load Balancer;
- Internet Gateway;
- NAT Gateway;
- Route Tables;
- Security Groups;
- VPC Endpoint para Amazon S3;
- Data Lake opcional com 3 buckets Amazon S3;
- Bucket Amazon S3 para backups do MySQL;
- Amazon CloudWatch;
- Amazon SNS.
- 2 repositórios Amazon ECR persistentes, gerenciados separadamente em `bootstrap/`.

## Armazenamento e Análise de Dados

O projeto utiliza três buckets Amazon S3 para organizar os dados destinados à análise.

O módulo permanece implementado para evolução futura, mas vem desabilitado por
padrão porque a política da AWS Academy nega uma consulta de Object Lock exigida
pelo provider Terraform. Em uma conta compatível, habilite-o com:

```hcl
enable_data_lake = true
```

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

## Backup do banco de dados

O módulo `backup/` cria um bucket S3 versionado e um tópico SNS. O módulo
`compute/` provisiona uma instância EC2 dedicada em `compute/user-data/backup.sh`,
que instala o MySQL client e a AWS CLI, grava o script
`compute/scripts/backup_mysql.sh` e registra um Cron Job diário em
`/etc/cron.d/mysql-backup`.

O fluxo executado diariamente é:

```text
mysqldump completo -> arquivo mysql-backup-AAAA-MM-DD.sql -> upload S3
                                                          -> e-mail SNS (sucesso/erro)
```

O backup roda em uma instância dedicada, sem alterar o `user_data` da instância
MySQL. Assim, aplicar esta configuração não recria o banco de dados existente.

Detalhes:

- O nome do arquivo contém a data ISO (`mysql-backup-2026-11-12.sql`).
- O objeto é gravado em `s3://<bucket>/mysql-backups/AAAA-MM-DD/`.
- O dump usa `--single-transaction` e `--no-tablespaces` para não bloquear as
  tabelas InnoDB nem exigir o privilégio global `PROCESS`.
- O log da execução fica em `/var/log/mysql-backup.log` na instância de backup.
- O agendamento padrão é `0 3 * * *`, em **UTC** (meia-noite em Brasília).
  Ajuste com `backup_schedule` se necessário.
- A retenção padrão é de 30 dias (`backup_retention_days`).
- O e-mail do administrador é configurado em `backup_alert_email` e, quando
  omitido, usa `alarm_email`. A assinatura SNS precisa ser confirmada por e-mail.

O e-mail depende de permissões `s3:PutObject` e `sns:Publish` no Instance Profile
das instâncias. Quando `create_ec2_instance_profile = true` (padrão), o Terraform
cria e anexa essa política automaticamente. Quando um perfil existente é usado
(`create_ec2_instance_profile = false`, comum na AWS Academy), o perfil precisa
já possuir essas permissões.

Se a conta negar a criação do bucket S3 (mesma limitação de Object Lock descrita
acima), informe um bucket existente em `backup_bucket_name`; o Terraform passa a
apenas gravar os objetos nele.

Para restaurar um backup:

```bash
aws s3 cp s3://<bucket>/mysql-backups/AAAA-MM-DD/mysql-backup-AAAA-MM-DD.sql .
mysql -h <host> -u <usuario> -p < mysql-backup-AAAA-MM-DD.sql
```

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

### 1. Criar os repositórios de imagens

O diretório `bootstrap/` possui estado separado para que os repositórios ECR não
sejam removidos junto com o ambiente temporário:

```bash
cd bootstrap
terraform init
terraform apply
```

Anote as URLs exibidas nos outputs. Essa etapa é executada apenas na preparação
inicial da conta AWS.

### 2. Publicar as imagens

Os repositórios Backend e Frontend possuem workflows que, após merge na `main`,
executam os testes e publicam uma imagem com a tag imutável do commit.

Configure em cada repositório do GitHub:

- variável `AWS_REGION`;
- secret `AWS_ROLE_ARN`, quando OIDC estiver disponível; ou
- secrets temporários `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e
  `AWS_SESSION_TOKEN`, para AWS Academy.

### 3. Criar o ambiente temporário

Copie `terraform.tfvars.example` para `terraform.tfvars`. Por padrão, o
Terraform consulta o ECR e seleciona automaticamente as imagens publicadas mais
recentemente pelo Backend e Frontend. Depois execute na raiz:

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

As EC2 instalam Docker, autenticam no ECR e iniciam os containers reais. Por
padrão, o Terraform cria um Instance Profile com leitura do ECR. Se a conta
acadêmica bloquear criação de IAM, defina `create_ec2_instance_profile = false`
e informe um `ec2_instance_profile_name` existente com essa permissão. Quando
usar o Google Calendar, o perfil existente também precisa ler o secret indicado.

Para rollback, defina opcionalmente `backend_image_uri` e/ou
`frontend_image_uri` com uma tag ou digest imutável. Sem essas variáveis, cada
nova criação do ambiente utiliza automaticamente as imagens mais recentes.

Para habilitar o Google Calendar, mantenha o JSON da conta de serviço **fora do
repositório** (por exemplo em `~/.secrets/google-calendar-key.json`) e informe o
caminho em `google_calendar_credentials_file`. O Terraform grava o conteúdo no
Secrets Manager durante o `apply`, e a Lambda passa a autenticar sem nenhum passo
manual. Como o valor fica em texto puro no `terraform.tfstate`, proteja esse
arquivo. Alternativamente, crie o secret fora do Terraform e informe apenas o ARN
em `google_calendar_secret_arn`.

> A credencial AWS configurada localmente precisa estar válida antes de `plan`
> ou `apply`. A infraestrutura não é criada pelos workflows das aplicações.

Para remover os recursos provisionados:

```bash
terraform destroy
```

O `destroy` deve ser executado logo após testes e apresentações para interromper
os custos de EC2, ALB e NAT Gateway. Os repositórios ECR permanecem porque usam
o estado Terraform independente do diretório `bootstrap/`.

## Projeto

**Projeto:** Doces com Amor  
**Tipo:** Projeto de Extensão Acadêmico  
**Cloud Provider:** AWS  
**Infrastructure as Code:** Terraform  
**Banco de Dados:** MySQL  

Este repositório tem como objetivo manter a infraestrutura AWS do projeto versionada, documentada e reproduzível através do Terraform.
