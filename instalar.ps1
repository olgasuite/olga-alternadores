# instalar.ps1 - instala os alternadores de tela e de saida de audio neste PC
# Copia para C:\Scripts, cria atalhos na Inicializacao e ja abre os dois icones na bandeja.
# Uso: clicar com o direito > Executar com o PowerShell (ou: powershell -ExecutionPolicy Bypass -File instalar.ps1)

$origem = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = 'C:\Scripts'
New-Item -ItemType Directory -Force $dest | Out-Null

$startup = [Environment]::GetFolderPath('Startup')
$sh = New-Object -ComObject WScript.Shell

foreach ($nome in 'AlternarTela', 'AlternarAudio', 'EjetarDisco') {
    Copy-Item (Join-Path $origem "$nome.ps1") $dest -Force
    Copy-Item (Join-Path $origem "$nome.vbs") $dest -Force
    $lnk = $sh.CreateShortcut((Join-Path $startup "$nome.lnk"))
    $lnk.TargetPath = Join-Path $dest "$nome.vbs"
    $lnk.WorkingDirectory = $dest
    $lnk.Save()
    Start-Process wscript.exe -ArgumentList "`"$(Join-Path $dest "$nome.vbs")`""
    Write-Host "OK: $nome instalado e aberto"
}
Write-Host "Pronto. Se algum icone nao aparecer, ver a setinha ^ da bandeja (icones ocultos)."
