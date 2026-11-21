# AlternarTela.ps1 - icone na bandeja (ao lado do relogio) para alternar a 2a tela
# Clique esquerdo: alterna Duplicar <-> Estender. Clique direito: menu.
# Usa SetDisplayConfig direto (o DisplaySwitch.exe mudou de parametros no Win11 24H2).

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class AltTela {
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr handle);
    [DllImport("user32.dll")] public static extern int SetDisplayConfig(uint numPaths, IntPtr paths, uint numModes, IntPtr modes, uint flags);
    const uint SDC_APPLY = 0x80, SDC_TOPOLOGY_CLONE = 0x2, SDC_TOPOLOGY_EXTEND = 0x4;
    public static int Duplicar() { return SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, SDC_APPLY | SDC_TOPOLOGY_CLONE); }
    public static int Estender() { return SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, SDC_APPLY | SDC_TOPOLOGY_EXTEND); }
    // SM_CMONITORS: em modo duplicado o Windows enxerga 1 monitor so
    public static bool Estendida() { return GetSystemMetrics(80) >= 2; }
}
'@

# uma instancia so
$mutex = New-Object System.Threading.Mutex($false, 'Local\OLGA_AlternarTela')
if (-not $mutex.WaitOne(0)) { exit }

$script:hIcone = [IntPtr]::Zero
$script:estado = $null

function New-Icone([bool]$estendida) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 2
    $azul = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 120, 215))
    $laranja = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 140, 0))
    if ($estendida) {
        # duas telas lado a lado
        $r1 = New-Object System.Drawing.Rectangle 1, 7, 14, 13
        $r2 = New-Object System.Drawing.Rectangle 17, 7, 14, 13
    } else {
        # duas telas sobrepostas (mesma imagem)
        $r1 = New-Object System.Drawing.Rectangle 2, 3, 19, 15
        $r2 = New-Object System.Drawing.Rectangle 11, 13, 19, 15
    }
    $g.FillRectangle($azul, $r1); $g.DrawRectangle($pen, $r1)
    $g.FillRectangle($laranja, $r2); $g.DrawRectangle($pen, $r2)
    if ($estendida) { $g.FillRectangle([System.Drawing.Brushes]::White, 12, 25, 8, 3) }
    $g.Dispose()
    $h = $bmp.GetHicon()
    $bmp.Dispose()
    return $h
}

function Update-Icone {
    $est = [AltTela]::Estendida()
    if ($est -eq $script:estado) { return }
    $script:estado = $est
    $h = New-Icone $est
    $tray.Icon = [System.Drawing.Icon]::FromHandle($h)
    if ($script:hIcone -ne [IntPtr]::Zero) { [void][AltTela]::DestroyIcon($script:hIcone) }
    $script:hIcone = $h
    if ($est) { $tray.Text = 'Tela: ESTENDIDA (clique para duplicar)' }
    else { $tray.Text = 'Tela: DUPLICADA (clique para estender)' }
    $miDup.Checked = -not $est
    $miEst.Checked = $est
}

function Set-Modo([bool]$estender) {
    if ($estender) { $r = [AltTela]::Estender() } else { $r = [AltTela]::Duplicar() }
    if ($r -ne 0) {
        $tray.ShowBalloonTip(3000, 'Alternar tela', "O Windows recusou a mudanca (codigo $r). A 2a tela esta ligada?", 'Warning')
    }
    $script:estado = $null
    Update-Icone
}

$tray = New-Object System.Windows.Forms.NotifyIcon
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miDup = $menu.Items.Add('Duplicar')
$miEst = $menu.Items.Add('Estender')
[void]$menu.Items.Add('-')
$miCfg = $menu.Items.Add('Configuracoes de video do Windows...')
$miSair = $menu.Items.Add('Sair')
$miDup.add_Click({ Set-Modo $false })
$miEst.add_Click({ Set-Modo $true })
$miCfg.add_Click({ Start-Process 'ms-settings:display' })
$miSair.add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
$tray.ContextMenuStrip = $menu
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Set-Modo (-not [AltTela]::Estendida()) }
})

Update-Icone
$tray.Visible = $true

# acompanha mudancas feitas por fora (Win+P, cabo desligado etc.)
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_Tick({ Update-Icone })
$timer.Start()

[System.Windows.Forms.Application]::Run()

$timer.Stop()
$tray.Dispose()
if ($script:hIcone -ne [IntPtr]::Zero) { [void][AltTela]::DestroyIcon($script:hIcone) }
$mutex.ReleaseMutex()
