param (
    [string]$id,
    [string]$datainicio,
    [string]$datafim,
    [string]$idpedidootica,
    [string]$notafiscal,
    [string]$cupom,
    [string]$campanha,
    [nullable[int]]$tipopedido,
    [nullable[int]]$status,
    [nullable[int]]$origempedido,
    [nullable[int]]$idpar,
    [string]$laboratorio,
    [string]$otica,
    [switch]$ajuda,
    [switch]$duckdb
)

# Defina a URL base aqui
$baseUrl = "http://localhost:5001"

if ($ajuda) {
    Write-Host "Uso do script buscar-pedidos.ps1"
    Write-Host ""
    Write-Host "Parâmetros possíveis:"
    Write-Host "  -id                : string (filtro pelo id do pedido)"
    Write-Host "  -datainicio        : string (formato AAAA-MM-DD)"
    Write-Host "  -datafim           : string (formato AAAA-MM-DD)"
    Write-Host "  -idpedidootica     : string"
    Write-Host "  -notafiscal        : string"
    Write-Host "  -cupom             : string"
    Write-Host "  -campanha          : string"
    Write-Host "  -tipopedido        : int (0 = Rx, 1 = atacado)"
    Write-Host "  -statuspedido      : int (0 = cancelado, 1 = aberto, 2 = baixado, 3 = faturado)"
    Write-Host "  -origempedido      : int (103 = shop1, 104 = shop2, outro/nenhum = shop3)"
    Write-Host "  -idpar             : int"
    Write-Host "  -ajuda             : exibe esta ajuda"
    exit
}

if (-not $laboratorio -or -not $otica) {
    Write-Host "Erro: Os parâmetros -laboratorio e -otica são obrigatórios."
    exit
}

if ($idpedidootica) {
    $idpedidootica = $idpedidootica.ToUpper()
}

Write-Host "Se comunicando com: $baseUrl"

# REALIZANDO LOGIN
$loginurl = "$baseUrl/api/connect/token"
$loginbody = @{
    grant_type = "password"
    username   = "p"
    password   = "p"
}

try {
    Write-Host "Realizando login..."
    $loginresponse = invoke-restmethod -uri $loginurl -method post -body $loginbody -contenttype "application/x-www-form-urlencoded"
    $access_token = $loginresponse.access_token
    write-host "Login realizado com sucesso"
}
catch {
    write-host "erro ao realizar login: $($_.exception.message)"
    exit 1
}

$headers = @{
    "authorization" = "bearer $access_token"
    "laboratorio"   = $laboratorio
    "otica"         = $otica
}

$queryParams = @{}
if ($id)               { $queryParams["id"] = $id }
if ($datainicio)       { $queryParams["dataInicio"] = $datainicio }
if ($datafim)          { $queryParams["dataFim"] = $datafim }
if ($idpedidootica)    { $queryParams["idPedidoOtica"] = $idpedidootica }
if ($notafiscal)       { $queryParams["notaFiscal"] = $notafiscal }
if ($cupom)            { $queryParams["cupom"] = $cupom }
if ($campanha)         { $queryParams["campanha"] = $campanha }
if ($tipopedido -ne $null)   { $queryParams["tipoPedido"] = $tipopedido }
if ($status -ne $null)       { $queryParams["status"] = $status }
if ($origempedido -ne $null) { $queryParams["origemPedido"] = $origempedido }
if ($idpar -ne $null)        { $queryParams["idPar"] = $idpar }

$querystring = ""
if ($queryparams.count -gt 0) {
    $paramlist = $queryparams.getenumerator() | foreach-object { "$($_.key)=$($_.value)" }
    $querystring = "?" + ($paramlist -join "&")
}

$url = "$baseUrl/api/pedidos$querystring"

# CONSULTANDO PEDIDO
try {
    write-host "Buscando pedidos..."

    $response = invoke-restmethod -uri $url -method get -headers $headers

    if (-not $response) {
        write-host "Nenhum resultado encontrado."
    }
    else {
        $outputDir = Join-Path -Path (Get-Location) -ChildPath "resultado-pedidos"

        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir | Out-Null
        }

        $outputfile = Join-Path -Path $outputDir -ChildPath "resultado-pedidos.json"
        $outputCsv  = Join-Path -Path $outputDir -ChildPath "resultado-pedidos.csv"
        $duckdbFile = Join-Path -Path $outputDir -ChildPath "resultado.duckdb"

        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputfile -Encoding UTF8
        Write-Host "Pedidos encontrados salvos em: $outputfile"

        $response | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Pedidos também exportados para CSV: $outputCsv"

        $duckdbCli = Join-Path -Path $PSScriptRoot -ChildPath "duckdb.exe"
        if (-not (Test-Path $duckdbCli)) {
            Write-Host "Erro: DuckDB CLI não encontrado em $duckdbCli"
            exit 1
        }

        Write-Host "Importando CSV para o DuckDB..."

$duckdbCommand = @"
CREATE TABLE IF NOT EXISTS pedidos AS SELECT * FROM read_csv_auto('$outputCsv');
INSERT INTO pedidos SELECT * FROM read_csv_auto('$outputCsv');
"@

        & $duckdbCli $duckdbFile -c $duckdbCommand

        Write-Host "Dados importados com sucesso para: $duckdbFile"
    }
}
catch {
    write-host "erro ao buscar pedidos: $($_.exception.message)"

    if ($_.exception.response -ne $null) {
        $stream = $_.exception.response.getresponsestream()
        $reader = new-object system.io.streamreader($stream)
        $body = $reader.readtoend()
        
        if (-not [string]::isnullorwhitespace($body)) {
            write-host "resposta do servidor:`n$body"
        }
        else {
            write-host "ocorreu um erro interno."
        }
    }
}