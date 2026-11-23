# instalar.ps1 - instala os alternadores (tela, audio, ejetar disco, tela scope) neste PC
# Copia para C:\Scripts, cria atalhos na Inicializacao e ja abre os icones na bandeja.
# Uso: clicar com o direito > Executar com o PowerShell (ou: powershell -ExecutionPolicy Bypass -File instalar.ps1)
#
# TelaScope (2a tela scope 1920x804 <-> padrao 1920x1080 + correcao do DCP-o-matic Player)
# so troca a resolucao se 1920x804 existir como resolucao personalizada no painel da placa
# de video (NVIDIA, AMD ou Intel). Sem ela o icone abre, mas avisa ao tentar trocar.

$origem = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = 'C:\Scripts'
New-Item -ItemType Directory -Force $dest | Out-Null

$startup = [Environment]::GetFolderPath('Startup')
$sh = New-Object -ComObject WScript.Shell

foreach ($nome in 'AlternarTela', 'AlternarAudio', 'EjetarDisco', 'TelaScope') {
    Copy-Item (Join-Path $origem "$nome.ps1") $dest -Force
    Copy-Item (Join-Path $origem "$nome.vbs") $dest -Force
    $lnk = $sh.CreateShortcut((Join-Path $startup "$nome.lnk"))
    $lnk.TargetPath = Join-Path $dest "$nome.vbs"
    $lnk.WorkingDirectory = $dest
    $lnk.Save()
    Start-Process wscript.exe -ArgumentList "`"$(Join-Path $dest "$nome.vbs")`""
    Write-Host "OK: $nome instalado e aberto"
}
Write-Host ""
Write-Host "TelaScope: precisa da resolucao personalizada 1920x804 criada no painel da placa de video"
Write-Host "(NVIDIA / AMD / Intel) para a 2a tela. Sem ela, os outros icones funcionam normalmente."
Write-Host "Pronto. Se algum icone nao aparecer, ver a setinha ^ da bandeja (icones ocultos)."
