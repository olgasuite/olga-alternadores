# instalar.ps1 - instala os alternadores OLGA (icones na bandeja) neste PC
# Abre uma janela para escolher quais instalar. O que ja esta instalado vem marcado;
# desmarcar um item instalado desinstala (fecha o icone, tira da Inicializacao e apaga de C:\Scripts).
# Uso: clicar com o direito > Executar com o PowerShell (ou: powershell -ExecutionPolicy Bypass -File instalar.ps1)
#
# Sem janela (ex.: instalacao remota):
#   instalar.ps1 -Itens AlternarAudio,TaxaTela     instala/atualiza so esses (os outros ficam como estao)
#   instalar.ps1 -Todos                            instala/atualiza todos
#   instalar.ps1 -Remover TelaScope                desinstala esses
# Nomes: AlternarTela, AlternarAudio, EjetarDisco, EjetarMenu, TelaScope, TaxaTela, MenuClassico
#
# MenuClassico (so Windows 11): clique direito do Explorador volta ao menu completo do Windows 10,
# sem o "Mostrar mais opcoes". E so uma chave no registro (HKCU); reinicia o Explorador ao aplicar.
#
# TelaScope (2a tela scope 1920x804 <-> padrao 1920x1080 + correcao do DCP-o-matic Player)
# so troca a resolucao se 1920x804 existir como resolucao personalizada no painel da placa
# de video (NVIDIA, AMD ou Intel). Sem ela o icone abre, mas avisa ao tentar trocar.
# Arquivo em ASCII puro.

param([string[]]$Itens, [switch]$Todos, [string[]]$Remover)

$origem = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = 'C:\Scripts'
$startup = [Environment]::GetFolderPath('Startup')
$REGMENU = 'HKCU:\Software\Classes\Drive\shell\OLGA_EjetarDisco'
$REGCLASSICO = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$WIN11 = [Environment]::OSVersion.Version.Build -ge 22000
$reiniciarExplorer = $false

# Nome = arquivo .ps1/.vbs (EjetarMenu usa os arquivos do EjetarDisco); Padrao = marcado na 1a instalacao
$CATALOGO = @(
    [pscustomobject]@{ Nome = 'AlternarTela';  Padrao = $true;  Titulo = 'Duplicar / Estender tela';
        Desc = 'Clique alterna a projecao entre Duplicar e Estender.' }
    [pscustomobject]@{ Nome = 'AlternarAudio'; Padrao = $true;  Titulo = 'Saida de audio + mudo';
        Desc = 'Clique passa para a proxima saida de audio; depois da ultima, mudo.' }
    [pscustomobject]@{ Nome = 'EjetarDisco';   Padrao = $true;  Titulo = 'Ejetar disco externo (bandeja)';
        Desc = 'Menu com os HDs externos; mostra qual programa esta segurando o disco.' }
    [pscustomobject]@{ Nome = 'EjetarMenu';    Padrao = $true;  Titulo = 'Ejetar disco no clique direito do HD';
        Desc = 'Item "Ejetar disco (OLGA)" no menu do disco (Win11: Mostrar mais opcoes).' }
    [pscustomobject]@{ Nome = 'TaxaTela';      Padrao = $true;  Titulo = 'Taxa de atualizacao (Hz)';
        Desc = 'Clique escolhe a taxa; a troca so acontece ao parar de clicar.' }
    [pscustomobject]@{ Nome = 'TelaScope';     Padrao = $false; Titulo = 'Tela Scope 1920x804 / 1920x1080 (2a tela)';
        Desc = 'Precisa da resolucao 1920x804 criada no painel da placa de video.' }
    [pscustomobject]@{ Nome = 'MenuClassico';  Padrao = $false; Titulo = 'Menu classico no clique direito (Windows 11)' + $(if ($WIN11) { '' } else { ' - sem efeito no Win10' });
        Desc = 'Menu completo de sempre, sem "Mostrar mais opcoes". Reinicia o Explorador.' }
)

function Test-Instalado([string]$nome) {
    if ($nome -eq 'EjetarMenu') { return (Test-Path $REGMENU) }
    if ($nome -eq 'MenuClassico') { return (Test-Path "$REGCLASSICO\InprocServer32") }
    return (Test-Path (Join-Path $startup "$nome.lnk"))
}

function Stop-Icone([string]$nome) {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match "\\$nome\.ps1" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Copy-Arquivos([string]$nome) {
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item (Join-Path $origem "$nome.ps1") $dest -Force
    Copy-Item (Join-Path $origem "$nome.vbs") $dest -Force
}

function Install-Item([string]$nome) {
    if ($nome -eq 'MenuClassico') {
        if (-not (Test-Path "$REGCLASSICO\InprocServer32")) { $script:reiniciarExplorer = $true }
        New-Item -Path "$REGCLASSICO\InprocServer32" -Force | Out-Null
        Set-ItemProperty "$REGCLASSICO\InprocServer32" -Name '(default)' -Value ''
        return
    }
    if ($nome -eq 'EjetarMenu') {
        Copy-Arquivos 'EjetarDisco'
        New-Item -Path "$REGMENU\command" -Force | Out-Null
        Set-ItemProperty $REGMENU -Name 'MUIVerb' -Value 'Ejetar disco (OLGA)'
        New-ItemProperty $REGMENU -Name 'Icon' -Value '%SystemRoot%\System32\hotplug.dll,0' -PropertyType ExpandString -Force | Out-Null
        Set-ItemProperty "$REGMENU\command" -Name '(default)' -Value "wscript.exe `"$(Join-Path $dest 'EjetarDisco.vbs')`" `"%1`""
        return
    }
    Stop-Icone $nome   # a versao aberta segura o mutex: fecha para abrir a nova
    Copy-Arquivos $nome
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut((Join-Path $startup "$nome.lnk"))
    $lnk.TargetPath = Join-Path $dest "$nome.vbs"
    $lnk.WorkingDirectory = $dest
    $lnk.Save()
    Start-Process wscript.exe -ArgumentList "`"$(Join-Path $dest "$nome.vbs")`""
}

function Uninstall-Item([string]$nome) {
    if ($nome -eq 'MenuClassico') {
        Remove-Item $REGCLASSICO -Recurse -Force -ErrorAction SilentlyContinue
        $script:reiniciarExplorer = $true
        return
    }
    if ($nome -eq 'EjetarMenu') {
        Remove-Item $REGMENU -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Instalado 'EjetarDisco')) { Remove-Item "$dest\EjetarDisco.ps1", "$dest\EjetarDisco.vbs" -Force -ErrorAction SilentlyContinue }
        return
    }
    Stop-Icone $nome
    Remove-Item (Join-Path $startup "$nome.lnk") -Force -ErrorAction SilentlyContinue
    # o EjetarDisco continua sendo usado pelo item do clique direito
    if (-not ($nome -eq 'EjetarDisco' -and (Test-Path $REGMENU))) {
        Remove-Item "$dest\$nome.ps1", "$dest\$nome.vbs" -Force -ErrorAction SilentlyContinue
    }
}

# ---------- o que fazer ----------
$nomes = @($CATALOGO | ForEach-Object { $_.Nome })
$instalar = @(); $remover = @()
$interativo = -not ($Itens -or $Todos -or $Remover)

if (-not $interativo) {
    $Itens = @($Itens | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    $Remover = @($Remover | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    foreach ($n in @($Itens) + @($Remover)) { if ($nomes -notcontains $n) { Write-Host "Nome desconhecido: $n (validos: $($nomes -join ', '))"; exit 1 } }
    $instalar = $(if ($Todos) { $nomes } else { $Itens })
    $remover = $Remover
} else {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $primeira = -not ($nomes | Where-Object { Test-Instalado $_ })
    $f = New-Object System.Windows.Forms.Form
    $f.Text = 'Alternadores OLGA - instalar'
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterScreen'; $f.Font = New-Object System.Drawing.Font 'Segoe UI', 9
    $f.ClientSize = New-Object System.Drawing.Size 520, (90 + 52 * $CATALOGO.Count)
    $topo = New-Object System.Windows.Forms.Label
    $topo.Text = "Marque os icones que quer neste PC. Desmarcar um que ja esta instalado desinstala.`nOs marcados sao (re)instalados com a versao desta pasta."
    $topo.SetBounds(14, 10, 495, 36)
    $f.Controls.Add($topo)
    $caixas = @{}
    $y = 52
    foreach ($c in $CATALOGO) {
        $inst = Test-Instalado $c.Nome
        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text = $c.Titulo + $(if ($inst) { '   (instalado)' } else { '' })
        $cb.Font = New-Object System.Drawing.Font 'Segoe UI', 9, ([System.Drawing.FontStyle]::Bold)
        $cb.Checked = $(if ($primeira) { $c.Padrao } else { $inst })
        $cb.SetBounds(16, $y, 490, 22)
        $d = New-Object System.Windows.Forms.Label
        $d.Text = $c.Desc; $d.ForeColor = [System.Drawing.Color]::DimGray
        $d.SetBounds(34, $y + 22, 470, 20)
        $f.Controls.Add($cb); $f.Controls.Add($d)
        $caixas[$c.Nome] = $cb
        $y += 52
    }
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Aplicar'; $ok.SetBounds(316, $y + 6, 90, 28); $ok.DialogResult = 'OK'
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancelar'; $cancel.SetBounds(416, $y + 6, 90, 28); $cancel.DialogResult = 'Cancel'
    $f.Controls.Add($ok); $f.Controls.Add($cancel)
    $f.AcceptButton = $ok; $f.CancelButton = $cancel
    if ($f.ShowDialog() -ne 'OK') { exit }
    foreach ($c in $CATALOGO) {
        if ($caixas[$c.Nome].Checked) { $instalar += $c.Nome }
        elseif (Test-Instalado $c.Nome) { $remover += $c.Nome }
    }
}

# ---------- aplicar ----------
$log = @()
foreach ($n in $remover) {
    try { Uninstall-Item $n; $log += "Removido: $n" } catch { $log += "ERRO ao remover ${n}: $($_.Exception.Message)" }
}
foreach ($n in $instalar) {
    try { Install-Item $n; $log += "Instalado: $n" } catch { $log += "ERRO ao instalar ${n}: $($_.Exception.Message)" }
}
if ($reiniciarExplorer -and $WIN11) {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    $log += 'Explorador reiniciado para aplicar o menu do clique direito.'
}
if (-not $log) { $log = @('Nada mudou.') }
if ($instalar -contains 'TelaScope') { $log += ''; $log += 'TelaScope: precisa da resolucao personalizada 1920x804 no painel da placa de video.' }
if ($instalar -contains 'EjetarMenu') { $log += ''; $log += 'Ejetar no clique direito: no Windows 11 fica em "Mostrar mais opcoes".' }
$log += ''; $log += 'Se algum icone nao aparecer, ver a setinha ^ da bandeja (icones ocultos).'
$log | ForEach-Object { Write-Host $_ }
if ($interativo) { [void][System.Windows.Forms.MessageBox]::Show(($log -join "`n"), 'Alternadores OLGA', 'OK', 'Information') }
