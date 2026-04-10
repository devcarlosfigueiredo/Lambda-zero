# ⚡ Serverless AWS API

> API REST serverless com custo operacional próximo de zero — 100% provisionada via Terraform e com deploy automatizado por GitHub Actions.

```
Client → API Gateway (HTTP API v2) → Lambda → DynamoDB
                                            ↑
                                     CloudWatch Logs + Alarms
```

## Stack

| Componente | Tecnologia |
|---|---|
| Runtime | Python 3.12 |
| Compute | AWS Lambda |
| API | AWS API Gateway HTTP API v2 |
| Base de dados | AWS DynamoDB (PAY_PER_REQUEST) |
| Observabilidade | AWS CloudWatch (Logs + Alarms + Dashboard) |
| IaC | Terraform ≥ 1.7 |
| CI/CD | GitHub Actions + OIDC (sem access keys) |
| Testes | pytest + moto (mock AWS sem custo real) |

---

## Endpoints

| Método | Path | Lambda | Descrição |
|---|---|---|---|
| `POST` | `/items` | `create_item` | Criar item |
| `GET` | `/items` | `list_items` | Listar todos (suporta `?category=`) |
| `GET` | `/items/{id}` | `get_item` | Obter por ID |
| `DELETE` | `/items/{id}` | `delete_item` | Eliminar por ID |

### Exemplo de payload (POST /items)

```json
{
  "name": "Monitor 4K",
  "category": "electronics",
  "description": "Monitor Dell 27\" 4K USB-C"
}
```

---

## Estrutura do Projecto

```
serverless-aws-api/
├── src/
│   ├── handlers/
│   │   ├── create_item.py      # POST /items
│   │   ├── get_item.py         # GET /items/{id}
│   │   ├── list_items.py       # GET /items
│   │   └── delete_item.py      # DELETE /items/{id}
│   └── utils/
│       ├── dynamodb.py         # Cliente DynamoDB reutilizável
│       ├── response.py         # Helpers de resposta HTTP
│       └── validators.py       # Validação de input
├── tests/
│   ├── conftest.py             # Fixtures partilhadas (mock DynamoDB)
│   ├── test_create_item.py
│   └── test_get_item.py        # Testa get, list e delete
├── terraform/
│   ├── provider.tf             # Provider AWS + backend S3
│   ├── variables.tf            # Variáveis configuráveis
│   ├── dynamodb.tf             # Tabela + GSI
│   ├── lambda.tf               # 4 funções Lambda
│   ├── api_gateway.tf          # HTTP API + rotas + integrações
│   ├── iam.tf                  # Roles com least privilege + OIDC
│   ├── main.tf                 # CloudWatch Alarms + Dashboard
│   └── outputs.tf              # Endpoint URL e ARNs
├── .github/workflows/
│   ├── ci.yml                  # Lint + testes em cada push
│   └── deploy.yml              # Deploy automático no merge para main
├── Makefile                    # Comandos de desenvolvimento
├── requirements.txt
└── requirements-dev.txt
```

---

## Setup inicial (uma vez por conta AWS)

### 1. Pré-requisitos

```bash
# Ferramentas necessárias
aws --version       # AWS CLI v2
terraform --version # ≥ 1.7
python3.12 --version
make --version
```

### 2. Configurar OIDC no GitHub Actions

```bash
# Criar o OIDC provider na tua conta AWS (só uma vez)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 3. Editar `terraform/iam.tf`

Substituir `YOUR_ORG/YOUR_REPO` pelo teu repositório GitHub:

```hcl
"token.actions.githubusercontent.com:sub" = "repo:meu-org/meu-repo:*"
```

### 4. Bootstrap do estado remoto Terraform

```bash
export STATE_BUCKET="meu-projeto-terraform-state-$(aws sts get-caller-identity --query Account --output text)"
export LAMBDA_S3_BUCKET="meu-projeto-lambda-packages"

# Criar bucket S3 + tabela DynamoDB para lock
make bootstrap STATE_BUCKET=$STATE_BUCKET

# Criar bucket para artefactos Lambda
aws s3 mb s3://$LAMBDA_S3_BUCKET --region eu-west-1
```

### 5. Actualizar backend no provider.tf

```hcl
backend "s3" {
  bucket = "meu-projeto-terraform-state-123456789"  # ← o teu bucket
  ...
}
```

### 6. Configurar GitHub Secrets

No repositório: **Settings → Secrets and variables → Actions**

| Secret | Valor |
|---|---|
| `AWS_ROLE_ARN` | ARN do role `github-actions` (output do terraform) |
| `LAMBDA_S3_BUCKET` | Nome do bucket de artefactos Lambda |
| `STATE_BUCKET` | Nome do bucket de estado Terraform |

---

## Desenvolvimento local

```bash
# Instalar dependências de desenvolvimento
make install-dev

# Correr testes (com mock AWS — sem custo real)
make test

# Correr linter
make lint

# Formatar código
make format
```

---

## Deploy

### Via GitHub Actions (recomendado)

O deploy corre automaticamente em cada push para `main`.

Para deploy manual com ambiente específico:
1. GitHub → Actions → "Deploy" → "Run workflow"
2. Escolher environment: `dev` | `staging` | `prod`

### Via Makefile (local)

```bash
export STATE_BUCKET="meu-terraform-state-bucket"
export LAMBDA_S3_BUCKET="meu-lambda-bucket"
export ENVIRONMENT=dev

# Preview das mudanças
make plan

# Deploy completo (test → build → upload → apply)
make deploy

# Destruir todos os recursos
make destroy
```

---

## Destruir infraestrutura

```bash
# Via Makefile (pede confirmação)
make destroy ENVIRONMENT=dev

# Via GitHub Actions: Run workflow → marcar "destroy: true"
```

---

## Boas práticas implementadas

| Prática | Implementação |
|---|---|
| Zero credenciais no código | OIDC com GitHub Actions |
| Least privilege | Role IAM separada por Lambda com acções mínimas |
| IaC completo | Zero recursos criados manualmente |
| Testes sem cloud real | moto mock — gratuito e rápido |
| Estado Terraform seguro | S3 encriptado + DynamoDB lock |
| DynamoDB encriptado | SSE activado por defeito |
| Protecção em produção | `deletion_protection_enabled = true` em prod |
| Observabilidade | CloudWatch Logs + Alarms + Dashboard |
| Rastreio distribuído | X-Ray activado em todas as Lambdas |

---

## Custo estimado (Free Tier)

| Serviço | Free Tier | Custo em demo |
|---|---|---|
| Lambda | 1M requests/mês + 400K GB-s | **$0** |
| API Gateway HTTP API | 1M requests/mês | **$0** |
| DynamoDB | 25GB storage + 25 RCU/WCU | **$0** |
| CloudWatch Logs | 5GB ingestão/mês | **$0** |
| **Total** | | **~$0/mês** |

---

## Licença

MIT
