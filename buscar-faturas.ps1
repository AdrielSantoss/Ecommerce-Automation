param (
    [string]$status,
    [string]$datainicio,
    [string]$datafim,
    [string]$datavencimentoinicial,
    [string]$datavencimentofinal,
    [nullable[decimal]]$valorinicial,
    [nullable[decimal]]$valorfinal,
    [string]$numeronotafiscal,
    [string]$numeroboleto,
    [string]$laboratorio,
    [string]$otica,
    [switch]$ajuda
)

$baseUrl = "http://localhost:5001"

if ($ajuda) {
    Write-Host "Uso do script buscar-faturas.ps1"
    Write-Host ""
    Write-Host "Parâmetros possíveis:"
    Write-Host "  -status                : string (valores possíveis: 'pendente', 'baixado')"
    Write-Host "  -datainicio            : string (formato AAAA-MM-DD)"
    Write-Host "  -datafim               : string (formato AAAA-MM-DD)"
    Write-Host "  -datavencimentoinicial : string (formato AAAA-MM-DD)"
    Write-Host "  -datavencimentofinal   : string (formato AAAA-MM-DD)"
    Write-Host "  -valorinicial          : decimal"
    Write-Host "  -valorfinal            : decimal"
    Write-Host "  -numeronotafiscal      : string"
    Write-Host "  -numeroboleto          : string"
    Write-Host "  -laboratorio           : string (CNPJ do laboratório)"
    Write-Host "  -otica                 : string (CNPJ da ótica)"
    Write-Host "  -ajuda                 : exibe esta ajuda"
    exit
}

if (-not $laboratorio -or -not $otica) {
    Write-Host "Erro: Os parâmetros -laboratorio e -otica são obrigatórios."
    exit
}

if (-not $laboratorio -or -not $otica) {
    Write-Host "Erro: Os parâmetros -laboratorio e -otica são obrigatórios."
    exit 1
}

Write-Host "Se comunicando com: $baseUrl"

# Login
$loginurl = "$baseUrl/api/connect/token"
$loginbody = @{
    grant_type = "password"
    username   = "p"
    password   = "p"
}

try {
    Write-Host "Realizando login..."
    $loginresponse = Invoke-RestMethod -Uri $loginurl -Method Post -Body $loginbody -ContentType "application/x-www-form-urlencoded"
    $access_token = $loginresponse.access_token
    Write-Host "Login realizado com sucesso"
}
catch {
    Write-Host "Erro ao realizar login: $($_.Exception.Message)"
    exit 1
}

$headers = @{
    "authorization" = "bearer $access_token"
    "laboratorio"   = $laboratorio
    "otica"         = $otica
}

$queryParams = @{}
if ($status)                  { $queryParams["status"] = $status }
if ($datainicio)              { $queryParams["dataInicio"] = $datainicio }
if ($datafim)                 { $queryParams["dataFim"] = $datafim }
if ($datavencimentoinicial)   { $queryParams["dataVencimentoInicial"] = $datavencimentoinicial }
if ($datavencimentofinal)     { $queryParams["dataVencimentoFinal"] = $datavencimentofinal }
if ($valorinicial -ne $null)  { $queryParams["valorInicial"] = $valorinicial }
if ($valorfinal -ne $null)    { $queryParams["valorFinal"] = $valorfinal }
if ($numeronotafiscal)        { $queryParams["numeroNotaFiscal"] = $numeronotafiscal }
if ($numeroboleto)            { $queryParams["numeroBoleto"] = $numeroboleto }

$querystring = ""
if ($queryParams.Count -gt 0) {
    $paramlist = $queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    $querystring = "?" + ($paramlist -join "&")
}

$url = "$baseUrl/api/faturas$querystring"

try {
    Write-Host "Buscando faturas..."
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

    if (-not $response) {
        Write-Host "Nenhum resultado encontrado."
    } else {
        $outputDir = Join-Path -Path (Get-Location) -ChildPath "resultado-faturas"        

        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir | Out-Null
        }

        $outputfile = Join-Path -Path $outputDir -ChildPath "resultado-faturas.json"
        $outputCsv  = Join-Path -Path $outputDir -ChildPath "resultado-faturas.csv"
        $duckdbFile = Join-Path -Path $outputDir -ChildPath "resultado.duckdb"

        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputfile -Encoding UTF8
        Write-Host "Faturas encontradas salvas em: $outputfile"

        $response | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Faturas também exportadas para CSV: $outputCsv"

        $duckdbCli = Join-Path -Path $PSScriptRoot -ChildPath "duckdb.exe"
        if (-not (Test-Path $duckdbCli)) {
            Write-Host "Erro: DuckDB CLI não encontrado em $duckdbCli"
            exit 1
        }

        Write-Host "Importando CSV para o DuckDB..."

        $duckdbCommand = @"
CREATE TABLE IF NOT EXISTS faturas AS SELECT * FROM read_csv_auto('$outputCsv');
INSERT INTO faturas SELECT * FROM read_csv_auto('$outputCsv');
"@

        & $duckdbCli $duckdbFile -c $duckdbCommand

        Write-Host "Dados importados com sucesso para: $duckdbFile"
    }
}
catch {
    Write-Host "Erro ao buscar faturas: $($_.Exception.Message)"

    if ($_.Exception.Response -ne $null) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()

        if (-not [string]::IsNullOrWhiteSpace($body)) {
            Write-Host "Resposta do servidor:`n$body"
        } else {
            Write-Host "Ocorreu um erro interno."
        }
    }
}
