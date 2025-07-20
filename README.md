
# Ecommerce-Automation

Scripts PowerShell para automação de processos de pedidos e faturas em e-commerce, incluindo integração com DuckDB para exportação e análise de dados. Ferramentas para consulta, envio e manipulação de pedidos e faturas, facilitando operações administrativas e integração com sistemas externos.

## Funcionalidades

- Consulta e exportação de pedidos e faturas
- Envio de pedidos via API
- Exportação dos resultados para JSON e CSV
- Importação dos dados para DuckDB para análise
- Scripts parametrizáveis e fáceis de usar

## Requisitos

- Windows PowerShell 5.1 ou superior
- DuckDB CLI (`duckdb.exe`) na pasta do projeto
- Permissões para executar scripts PowerShell

## Instalação

1. Clone o repositório:
   ```
   git clone https://github.com/AdrielSantoss/Ecommerce-Automation.git
   ```
2. Baixe o executável do DuckDB em https://duckdb.org/ e coloque o arquivo `duckdb.exe` na pasta do projeto.
3. Ajuste os parâmetros dos scripts conforme sua necessidade.

## Exemplos de Uso

### Buscar pedidos

```powershell
./buscar-pedidos.ps1 -laboratorio "CNPJ_LAB" -otica "CNPJ_OTICA" -datainicio "2025-01-01" -datafim "2025-01-31"
```

### Buscar faturas

```powershell
./buscar-faturas.ps1 -laboratorio "CNPJ_LAB" -otica "CNPJ_OTICA" -status "pendente"
```

### Enviar pedido

```powershell
./enviar-pedido.ps1 -laboratorio "CNPJ_LAB" -otica "CNPJ_OTICA"
```

Os resultados serão salvos nas pastas `resultado-pedidos` e `resultado-faturas`.

## Exemplos de saída

- `resultado-pedidos/resultado-pedidos.json`
- `resultado-pedidos/resultado-pedidos.csv`
- `./resultado.duckdb`
