param(
    [string]$pedido,
    [string]$laboratorio,
    [string]$otica,
    [switch]$ajuda
)

# Defina a URL base aqui
$baseUrl = "http://localhost:5001"

if ($ajuda) {
    Write-Host "Uso do script enviar-pedido.ps1"
    Write-Host ""
    Write-Host "Parâmetros:"
    Write-Host "  -pedido        : Caminho para o arquivo JSON do pedido (se não informado, será usado 'pedido.json' no diretório do script)"
    Write-Host "  -laboratorio   : CNPJ do laboratório (obrigatório)"
    Write-Host "  -otica         : CNPJ da ótica (obrigatório)"
    Write-Host "  -ajuda         : Exibe esta ajuda"
    exit
}

if (-not $laboratorio -or -not $otica) {
    Write-Host "Erro: Os Parâmetros -laboratorio e -otica são obrigatórios."
    exit
}

if (-not $pedido) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $defaultPedidoPath = Join-Path $scriptDir "pedido.json"

    if (Test-Path $defaultPedidoPath) {
        $pedido = $defaultPedidoPath
        Write-Host "Parâmetro -pedido não informado. Usando arquivo padrão: $pedido"
    } else {
        Write-Host "Erro: O parâmetro -pedido não foi informado e o arquivo 'pedido.json' não foi encontrado no diretório do script."
        exit
    }
}

Write-Host "Se comunicando com: $baseUrl"

# REALIZANDO LOGIN
Write-Host "Realizando login..."

$url = "$baseUrl/api/connect/token"

$body = @{
    grant_type = "password"
    username   = "p"
    password   = "p"
}

$headers = @{
    "Content-Type" = "application/x-www-form-urlencoded"
}

try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
    $access_token = $response.access_token
    Write-Host "Login realizado com sucesso"
} catch {
    Write-Host "Falha ao realizar login: $($_.Exception.Message)"
    exit
}

# GRAVANDO PEDIDO
if (-Not (Test-Path $pedido)) {
    Write-Host "Arquivo de pedido não encontrado: $pedido"
    exit
}

try {
    $pedidoJson = Get-Content -Path $pedido -Raw | ConvertFrom-Json
} catch {
    Write-Host "Erro ao ler ou interpretar o JSON do pedido: $($_.Exception.Message)"
    exit
}

$pedidoUrl = "$baseUrl/api/pedidos"

$pedidoHeaders = @{
    "Authorization" = "Bearer $access_token"
    "Content-Type"  = "application/json"
    "laboratorio"   = $laboratorio
    "otica"         = $otica
}

Write-Host "Gravando pedido..."

try {
    $pedidoResponse = Invoke-RestMethod -Uri $pedidoUrl -Method Post -Headers $pedidoHeaders -Body ($pedidoJson | ConvertTo-Json -Depth 10)
    Write-Host "Pedido gravado com sucesso"
} catch {
    Write-Host "Erro ao gravar pedido: $($_.Exception.Message)"

    if ($_.Exception.Response -ne $null) {
        try {
            $responseStream = $_.Exception.Response.GetResponseStream()
            $reader = [System.IO.StreamReader]::new($responseStream)
            $responseBody = $reader.ReadToEnd()

            if (![string]::IsNullOrWhiteSpace($responseBody)) {
                Write-Host "Resposta do servidor:`n$responseBody"
            } else {
                Write-Host "Ocorreu um erro interno"
            }
        } catch {
            Write-Host "Falha ao ler resposta do servidor."
        }
    } else {
        Write-Host "Ocorreu um erro interno"
    }
}