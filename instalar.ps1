# instalar.ps1 - instala os alternadores OLGA (icones na bandeja) neste PC
# Abre uma janela para escolher quais instalar. O que ja esta instalado vem marcado;
# desmarcar um item instalado desinstala (fecha o icone, tira da Inicializacao e apaga de C:\Scripts).
# Uso: clicar com o direito > Executar com o PowerShell (ou: powershell -ExecutionPolicy Bypass -File instalar.ps1)
#
# Sem janela (ex.: instalacao remota):
#   instalar.ps1 -Itens AlternarAudio,TaxaTela     instala/atualiza so esses (os outros ficam como estao)
#   instalar.ps1 -Todos                            instala/atualiza todos
#   instalar.ps1 -Remover TelaScope                desinstala esses
# Nomes: AlternarTela, AlternarAudio, EjetarDisco, EjetarMenu, Lixeira, TelaScope, TaxaTela, MenuClassico, DetalhesPastas, BarraLimpa
#
# BarraLimpa: tira da barra de tarefas Pesquisar e Visao de Tarefas (Win10 e 11), Cortana, Noticias e
# Interesses, Reunir Agora e Pessoas (Win10), Widgets, Chat e Copilot (Win11). Guarda os valores anteriores
# em HKCU\Software\OLGA\BarraLimpa (desmarcar devolve). Widgets/Noticias bloqueados pelo Windows -> politica (UAC).
#
# DetalhesPastas: todas as pastas abrem em Detalhes com as mesmas colunas (Nome, Tipo, Modificacao,
# Criacao, Tamanho, Duracao, Altura, Largura, Taxa de bits video/audio, Taxa de quadros).
# Zera as vistas salvas pasta a pasta (backup .reg em C:\Scripts) e reinicia o Explorador.
# Desmarcar devolve os padroes anteriores (as pastas ja abertas continuam em Detalhes).
#
# Lixeira: icone da Lixeira na bandeja; ao instalar, esconde a Lixeira da Area de Trabalho
# (ao desinstalar, ela volta). Da para mostrar/esconder depois pelo menu do icone.
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
$REGLIXEIRA = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
$CLSIDLIXEIRA = '{645FF040-5081-101B-9F08-00AA002F954E}'
$REGCLASSICO = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$WIN11 = [Environment]::OSVersion.Version.Build -ge 22000
$reiniciarExplorer = $false
$REGSTREAMS = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Streams\Defaults'
$REGDETALHES = 'HKCU:\Software\OLGA\DetalhesPastas'
$BAGS = 'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell'
# Geral, Documentos, Imagens, Musicas, Videos, Downloads
$TIPOSPASTA = @('{5C4F28B5-F869-4E84-8E60-F11DB97C5CC7}', '{7D49D726-3C21-4F05-99AA-FDC2C9474656}',
    '{B3690E58-E961-423B-B687-386EBFD83239}', '{94D6DDCC-4A68-4175-A374-BD584A510B78}',
    '{5FA96407-7E77-483C-AC93-691D05850DE8}', '{885A186E-A440-4ADA-812B-DB871B942259}')
# vista "Geral" do DESKTOP-LG (25/11/2026, ordem e larguras ajustadas pelo usuario): Detalhes, ordem por Nome
$VISTADETALHES = 'HAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPHx8fEUAAAAAAAAAAAAAAAAAAAAeAMAAHQDAAAxU1BTBdXN1ZwuGxCTlwgAKyz5roMAAAAiAAAAAEcAcgBvAHUAcABCAHkASwBlAHkAOgBGAE0AVABJAEQAAAAIAAAATgAAAHsAMAAwADAAMAAwADAAMAAwAC0AMAAwADAAMAAtADAAMAAwADAALQAwADAAMAAwAC0AMAAwADAAMAAwADAAMAAwADAAMAAwADAAfQAAAAAAMwAAACIAAAAARwByAG8AdQBwAEIAeQBEAGkAcgBlAGMAdABpAG8AbgAAABMAAAABAAAAWwAAAAoAAAAAUwBvAHIAdAAAAEIAAAAeAAAAcAByAG8AcAA0ADIAOQA0ADkANgA3ADIAOQA1AAAAAAAcAAAAAQAAAJEERGSLTNERi3AIADaxGgMGAAAAAQAAACUAAAAUAAAAAEcAcgBvAHUAcABWAGkAZQB3AAAACwAAAAAAAAAbAAAACgAAAABNAG8AZABlAAAAEwAAAAQAAAAjAAAAEgAAAABJAGMAbwBuAFMAaQB6AGUAAAATAAAAEAAAAGUBAAAQAAAAAEMAbwBsAEkAbgBmAG8AAABCAAAAHgAAAHAAcgBvAHAANAAyADkANAA5ADYANwAyADkANQAAAAAAIAEAAP3f3/0QAAAAAAAAAAAAAAALAAAAGAAAADDxJbfvRxoQpfECYIye66wKAAAA4gAAADDxJbfvRxoQpfECYIye66wEAAAAXAAAADDxJbfvRxoQpfECYIye66wOAAAAigAAADDxJbfvRxoQpfECYIye66wPAAAAdgAAADDxJbfvRxoQpfECYIye66wMAAAAUAAAAJAERGSLTNERi3AIADaxGgMDAAAAbgAAAJEERGSLTNERi3AIADaxGgMDAAAAUAAAAJEERGSLTNERi3AIADaxGgMEAAAAUAAAAJEERGSLTNERi3AIADaxGgMIAAAAegAAAJEERGSLTNERi3AIADaxGgMGAAAAiwAAAJAERGSLTNERi3AIADaxGgMEAAAAeAAAAC8AAAAeAAAAAEcAcgBvAHUAcABCAHkASwBlAHkAOgBQAEkARAAAABMAAAAAAAAAHwAAAA4AAAAARgBGAGwAYQBnAHMAAAATAAAAAQAgQTEAAAAgAAAAAEwAbwBnAGkAYwBhAGwAVgBpAGUAdwBNAG8AZABlAAAAEwAAAAEAAAAAAAAAAAAAAA=='

# Nome = arquivo .ps1/.vbs (EjetarMenu usa os arquivos do EjetarDisco); Padrao = marcado na 1a instalacao
$CATALOGO = @(
    [pscustomobject]@{ Nome = 'AlternarTela';  Padrao = $true;  Titulo = 'Duplicar / Estender tela';
        Desc = 'Clique alterna a projecao entre Duplicar e Estender.' }
    [pscustomobject]@{ Nome = 'AlternarAudio'; Padrao = $true;  Titulo = 'Saida de audio + mudo';
        Desc = 'Clique passa para a proxima saida de audio; depois da ultima, mudo.' }
    [pscustomobject]@{ Nome = 'EjetarDisco';   Padrao = $true;  Titulo = 'Ejetar disco externo (bandeja)';
        Desc = 'Menu com os HDs externos; mostra qual programa esta segurando o disco.' }
    [pscustomobject]@{ Nome = 'EjetarMenu';    Padrao = $true;  Titulo = 'Ejetar disco no clique direito do HD';
        Desc = 'Item "Ejetar disco (OLGA)" no menu do disco.' }
    [pscustomobject]@{ Nome = 'Lixeira';       Padrao = $true;  Titulo = 'Lixeira na bandeja (sai da Area de Trabalho)';
        Desc = 'Clique abre a Lixeira; menu esvazia. Some da Area de Trabalho (volta se desmarcar).' }
    [pscustomobject]@{ Nome = 'TaxaTela';      Padrao = $true;  Titulo = 'Taxa de atualizacao (Hz)';
        Desc = 'Clique escolhe a taxa; a troca so acontece ao parar de clicar.' }
    [pscustomobject]@{ Nome = 'TelaScope';     Padrao = $false; Titulo = 'Tela Scope 1920x804 / 1920x1080 (2a tela)';
        Desc = 'Precisa da resolucao 1920x804 criada no painel da placa de video.' }
    [pscustomobject]@{ Nome = 'MenuClassico';  Padrao = $false; Titulo = 'Menu classico no clique direito (Windows 11)' + $(if ($WIN11) { '' } else { ' - sem efeito no Win10' });
        Desc = 'Menu completo de sempre, sem "Mostrar mais opcoes". Reinicia o Explorador.' }
    [pscustomobject]@{ Nome = 'BarraLimpa';    Padrao = $true;  Titulo = 'Barra de tarefas sem distracoes';
        Desc = 'Tira Pesquisar, Visao de Tarefas, Widgets/Noticias, Cortana, Chat, Copilot, Reunir Agora.' }
    [pscustomobject]@{ Nome = 'DetalhesPastas'; Padrao = $false; Titulo = 'Todas as pastas em Detalhes com as mesmas colunas';
        Desc = 'Nome, tipo, datas, tamanho, duracao, resolucao, bitrate, fps. Reinicia o Explorador.' }
)

function Test-Instalado([string]$nome) {
    if ($nome -eq 'EjetarMenu') { return (Test-Path $REGMENU) }
    if ($nome -eq 'MenuClassico') { return (Test-Path "$REGCLASSICO\InprocServer32") }
    if ($nome -eq 'DetalhesPastas') { return (Test-Path $REGDETALHES) }
    if ($nome -eq 'BarraLimpa') { return (Test-Path $REGBARRA) }
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

function Set-LixeiraNaAreaDeTrabalho([bool]$mostrar) {
    if (-not (Test-Path $REGLIXEIRA)) { New-Item -Path $REGLIXEIRA -Force | Out-Null }
    New-ItemProperty $REGLIXEIRA -Name $CLSIDLIXEIRA -Value $(if ($mostrar) { 0 } else { 1 }) -PropertyType DWord -Force | Out-Null
    # avisa o Explorador para redesenhar a Area de Trabalho (SHCNE_ASSOCCHANGED)
    if (-not ('OlgaInstNotify' -as [type])) {
        Add-Type -Name OlgaInstNotify -Namespace '' -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int e, uint f, IntPtr a, IntPtr b);'
    }
    [OlgaInstNotify]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}

function Stop-Explorador {
    & taskkill.exe /f /im explorer.exe 2>&1 | Out-Null
    Start-Sleep -Milliseconds 800
}

function Start-Explorador {
    Start-Sleep -Seconds 2
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

function Install-DetalhesPastas {
    if (-not (Test-Path $REGSTREAMS)) { New-Item -Path $REGSTREAMS -Force | Out-Null }
    if (-not (Test-Path $REGDETALHES)) {
        # guarda os padroes que existiam antes, para devolver ao desinstalar
        New-Item -Path "$REGDETALHES\Anterior" -Force | Out-Null
        $atual = Get-ItemProperty $REGSTREAMS
        foreach ($t in $TIPOSPASTA) {
            if ($null -ne $atual.$t) { New-ItemProperty "$REGDETALHES\Anterior" -Name $t -Value ([byte[]]$atual.$t) -PropertyType Binary -Force | Out-Null }
        }
    }
    New-Item -ItemType Directory -Force $dest | Out-Null
    $bak = Join-Path $dest ("backup_vistas_pastas_{0:yyyyMMdd_HHmm}.reg" -f (Get-Date))
    & reg.exe export $BAGS $bak /y 2>&1 | Out-Null
    $vista = [Convert]::FromBase64String($VISTADETALHES)
    Stop-Explorador
    & reg.exe delete "$BAGS\Bags" /f 2>&1 | Out-Null
    & reg.exe delete "$BAGS\BagMRU" /f 2>&1 | Out-Null
    foreach ($t in $TIPOSPASTA) { New-ItemProperty $REGSTREAMS -Name $t -Value $vista -PropertyType Binary -Force | Out-Null }
    # sem deteccao automatica de tipo: toda pasta usa a vista Geral
    $all = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell"
    New-Item -Path $all -Force | Out-Null
    Set-ItemProperty $all -Name 'FolderType' -Value 'NotSpecified'
    Set-ItemProperty $REGDETALHES -Name 'Instalado' -Value (Get-Date -Format 'dd/MM/yyyy HH:mm')
    Start-Explorador
}

function Uninstall-DetalhesPastas {
    Stop-Explorador
    foreach ($t in $TIPOSPASTA) { Remove-ItemProperty $REGSTREAMS -Name $t -ErrorAction SilentlyContinue }
    if (Test-Path "$REGDETALHES\Anterior") {
        $ant = Get-ItemProperty "$REGDETALHES\Anterior"
        foreach ($t in $TIPOSPASTA) {
            if ($null -ne $ant.$t) { New-ItemProperty $REGSTREAMS -Name $t -Value ([byte[]]$ant.$t) -PropertyType Binary -Force | Out-Null }
        }
    }
    Remove-ItemProperty "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" -Name 'FolderType' -ErrorAction SilentlyContinue
    Remove-Item $REGDETALHES -Recurse -Force -ErrorAction SilentlyContinue
    Start-Explorador
}

# ---------- BarraLimpa: tira distracoes da barra de tarefas (Win10 e Win11) ----------
$ADVBARRA = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$BARRA = @(
    # W = 10, 11 ou 0 (os dois)
    [pscustomobject]@{ W = 0;  P = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; N = 'SearchboxTaskbarMode'; V = 0 }   # Pesquisar
    [pscustomobject]@{ W = 0;  P = $ADVBARRA; N = 'ShowTaskViewButton'; V = 0 }                                                  # Visao de Tarefas
    [pscustomobject]@{ W = 10; P = $ADVBARRA; N = 'ShowCortanaButton'; V = 0 }                                                   # Cortana
    [pscustomobject]@{ W = 10; P = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds'; N = 'ShellFeedsTaskbarViewMode'; V = 2 }  # Noticias e Interesses
    [pscustomobject]@{ W = 10; P = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; N = 'HideSCAMeetNow'; V = 1 } # Reunir Agora
    [pscustomobject]@{ W = 10; P = "$ADVBARRA\People"; N = 'PeopleBand'; V = 0 }                                                 # Pessoas
    [pscustomobject]@{ W = 11; P = $ADVBARRA; N = 'TaskbarDa'; V = 0 }                                                           # Widgets
    [pscustomobject]@{ W = 11; P = $ADVBARRA; N = 'TaskbarMn'; V = 0 }                                                           # Chat (Teams)
    [pscustomobject]@{ W = 11; P = $ADVBARRA; N = 'ShowCopilotButton'; V = 0 }                                                   # Copilot
)
$REGBARRA = 'HKCU:\Software\OLGA\BarraLimpa'
# Widgets (Win11) e Noticias (Win10): o Windows recente bloqueia a chave do usuario (UCPD);
# se nao der, usa a politica da maquina (pede permissao de administrador)
$POLWIDGETS = 'HKLM\SOFTWARE\Policies\Microsoft\Dsh|AllowNewsAndInterests'
$POLNOTICIAS = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds|EnableFeeds'

function Invoke-RegAdmin([string]$comandos) {
    # roda reg.exe como administrador (UAC)
    try {
        $p = Start-Process cmd.exe -ArgumentList "/c $comandos" -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
        return ($p.ExitCode -eq 0)
    } catch { return $false }
}

function Install-BarraLimpa {
    $ver = $(if ($WIN11) { 11 } else { 10 })
    $primeira = -not (Test-Path $REGBARRA)
    if ($primeira) { New-Item -Path "$REGBARRA\Anterior" -Force | Out-Null }
    foreach ($b in $BARRA | Where-Object { $_.W -eq 0 -or $_.W -eq $ver }) {
        $chave = "$($b.P)|$($b.N)"
        $atual = (Get-ItemProperty $b.P -Name $b.N -ErrorAction SilentlyContinue).($b.N)
        if ($primeira) {
            New-ItemProperty "$REGBARRA\Anterior" -Name $chave -Value $(if ($null -eq $atual) { 'ausente' } else { "$atual" }) -PropertyType String -Force | Out-Null
        }
        if ($atual -eq $b.V) { continue }
        try {
            if (-not (Test-Path $b.P)) { New-Item -Path $b.P -Force | Out-Null }
            New-ItemProperty $b.P -Name $b.N -Value $b.V -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        } catch {
            $pol = $(if ($b.N -eq 'TaskbarDa') { $POLWIDGETS } elseif ($b.N -eq 'ShellFeedsTaskbarViewMode') { $POLNOTICIAS } else { $null })
            if (-not $pol) { $script:log += "BarraLimpa: nao consegui mudar $($b.N)"; continue }
            $pk, $pn = $pol -split '\|'
            if ($script:interativo -and (Invoke-RegAdmin "reg add `"$pk`" /v $pn /t REG_DWORD /d 0 /f")) {
                Set-ItemProperty $REGBARRA -Name 'Politica' -Value $pol
                $script:log += "BarraLimpa: $($b.N) bloqueado pelo Windows; aplicado pela politica ($pk)."
            } else {
                $script:log += "BarraLimpa: $($b.N) bloqueado pelo Windows; rodar o instalador com janela e aceitar o pedido de administrador."
            }
        }
    }
    Set-ItemProperty $REGBARRA -Name 'Instalado' -Value (Get-Date -Format 'dd/MM/yyyy HH:mm')
    $script:reiniciarBarra = $true
}

function Uninstall-BarraLimpa {
    if (Test-Path "$REGBARRA\Anterior") {
        $ant = Get-ItemProperty "$REGBARRA\Anterior"
        foreach ($pr in $ant.PSObject.Properties | Where-Object { $_.Name -like 'HKCU:*|*' }) {
            $p, $n = $pr.Name -split '\|'
            try {
                if ($pr.Value -eq 'ausente') { Remove-ItemProperty $p -Name $n -ErrorAction Stop }
                else { New-ItemProperty $p -Name $n -Value ([int]$pr.Value) -PropertyType DWord -Force -ErrorAction Stop | Out-Null }
            } catch { }
        }
    }
    $pol = (Get-ItemProperty $REGBARRA -Name 'Politica' -ErrorAction SilentlyContinue).Politica
    if ($pol) {
        $pk, $pn = $pol -split '\|'
        if (-not (Invoke-RegAdmin "reg delete `"$pk`" /v $pn /f")) { $script:log += "BarraLimpa: a politica $pk ficou (precisa de administrador)." }
    }
    Remove-Item $REGBARRA -Recurse -Force -ErrorAction SilentlyContinue
    $script:reiniciarBarra = $true
}

function Install-Item([string]$nome) {
    if ($nome -eq 'BarraLimpa') { Install-BarraLimpa; return }
    if ($nome -eq 'DetalhesPastas') { Install-DetalhesPastas; return }
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
    if ($nome -eq 'Lixeira') { Set-LixeiraNaAreaDeTrabalho $false }
}

function Uninstall-Item([string]$nome) {
    if ($nome -eq 'BarraLimpa') { Uninstall-BarraLimpa; return }
    if ($nome -eq 'DetalhesPastas') { Uninstall-DetalhesPastas; return }
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
    if ($nome -eq 'Lixeira') { Set-LixeiraNaAreaDeTrabalho $true }
    Remove-Item (Join-Path $startup "$nome.lnk") -Force -ErrorAction SilentlyContinue
    # o EjetarDisco continua sendo usado pelo item do clique direito
    if (-not ($nome -eq 'EjetarDisco' -and (Test-Path $REGMENU))) {
        Remove-Item "$dest\$nome.ps1", "$dest\$nome.vbs" -Force -ErrorAction SilentlyContinue
    }
}

# ---------- o que fazer ----------
$nomes = @($CATALOGO | ForEach-Object { $_.Nome })
$instalar = @(); $remover = @($Remover)   # $remover e $Remover sao a mesma variavel (PowerShell ignora maiusculas)
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
$reiniciarBarra = $false
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
if ($reiniciarBarra -and -not ($reiniciarExplorer -and $WIN11)) {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    $log += 'Explorador reiniciado para aplicar a barra de tarefas.'
}
if (-not $log) { $log = @('Nada mudou.') }
if ($instalar -contains 'TelaScope') { $log += ''; $log += 'TelaScope: precisa da resolucao personalizada 1920x804 no painel da placa de video.' }
if ($instalar -contains 'EjetarMenu' -and $WIN11 -and -not (Test-Instalado 'MenuClassico')) { $log += ''; $log += 'Ejetar no clique direito: sem o Menu classico, no Windows 11 fica em "Mostrar mais opcoes".' }
$log += ''; $log += 'Se algum icone nao aparecer, ver a setinha ^ da bandeja (icones ocultos).'
$log | ForEach-Object { Write-Host $_ }
if ($interativo) { [void][System.Windows.Forms.MessageBox]::Show(($log -join "`n"), 'Alternadores OLGA', 'OK', 'Information') }
