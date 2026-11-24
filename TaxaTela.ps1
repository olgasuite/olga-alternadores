# TaxaTela.ps1 - icone na bandeja (ao lado do relogio) para trocar a taxa de atualizacao (Hz)
# O icone mostra a taxa atual. Clique esquerdo: escolhe a proxima taxa disponivel (na resolucao
# atual); o numero aparece num aviso grande e a troca so acontece ATRASO ms depois do ultimo
# clique - assim da para passar por varias opcoes sem a tela piscar a cada uma.
# Clique direito: menu com as taxas (troca na hora) e, com mais de uma tela, qual tela o clique muda.
# Arquivo em ASCII puro (o PowerShell 5.1 le .ps1 sem BOM como ANSI).

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class Taxa {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceKey;
    }
    public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct MONITORINFOEX { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string szDevice; }
    delegate bool MonProc(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr l);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettings(string d, int m, ref DEVMODE dm);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int ChangeDisplaySettingsEx(string d, ref DEVMODE dm, IntPtr h, uint f, IntPtr p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool EnumDisplayDevices(string d, int i, ref DISPLAY_DEVICE dd, int f);
    [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonProc p, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool GetMonitorInfo(IntPtr h, ref MONITORINFOEX mi);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    public static void DpiAware() { SetProcessDPIAware(); }

    public class Tela { public string Dev; public string Nome; public bool Principal; public int W, H, Hz; }

    // leitura AO VIVO das telas ligadas (Screen.AllScreens fica em cache)
    public static List<Tela> Telas() {
        List<Tela> res = new List<Tela>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, delegate(IntPtr h, IntPtr dc, ref RECT rr, IntPtr l) {
            MONITORINFOEX mi = new MONITORINFOEX(); mi.cbSize = Marshal.SizeOf(mi);
            if (GetMonitorInfo(h, ref mi)) {
                Tela t = new Tela(); t.Dev = mi.szDevice; t.Principal = (mi.dwFlags & 1) != 0;
                DEVMODE dm = Atual(t.Dev); t.W = dm.dmPelsWidth; t.H = dm.dmPelsHeight; t.Hz = dm.dmDisplayFrequency;
                DISPLAY_DEVICE dd = new DISPLAY_DEVICE(); dd.cb = Marshal.SizeOf(dd);
                t.Nome = EnumDisplayDevices(t.Dev, 0, ref dd, 0) ? dd.DeviceString : "";
                res.Add(t);
            }
            return true;
        }, IntPtr.Zero);
        res.Sort(delegate(Tela a, Tela b) { return string.CompareOrdinal(a.Dev, b.Dev); });
        return res;
    }

    public static DEVMODE Atual(string dev) {
        DEVMODE dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
        EnumDisplaySettings(dev, -1, ref dm); return dm;
    }

    // taxas que a tela aceita na resolucao e cor atuais (sem entrelacado)
    public static List<int> Taxas(string dev) {
        DEVMODE cur = Atual(dev);
        List<int> res = new List<int>();
        DEVMODE dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
        for (int i = 0; EnumDisplaySettings(dev, i, ref dm); i++) {
            if (dm.dmPelsWidth != cur.dmPelsWidth || dm.dmPelsHeight != cur.dmPelsHeight) continue;
            if (dm.dmBitsPerPel != cur.dmBitsPerPel || (dm.dmDisplayFlags & 2) != 0) continue;
            if (dm.dmDisplayFrequency > 1 && !res.Contains(dm.dmDisplayFrequency)) res.Add(dm.dmDisplayFrequency);
        }
        if (cur.dmDisplayFrequency > 1 && !res.Contains(cur.dmDisplayFrequency)) res.Add(cur.dmDisplayFrequency);
        res.Sort();
        return res;
    }

    // so a frequencia: resolucao e posicao ficam como estao (nao desfaz o scope do TelaScope)
    // teste = true -> CDS_TEST: o Windows so diz se aceitaria, sem mexer na tela
    public static int Mudar(string dev, int hz, bool teste) {
        DEVMODE dm = Atual(dev);
        dm.dmDisplayFrequency = hz;
        dm.dmFields = 0x400000; // DM_DISPLAYFREQUENCY
        return ChangeDisplaySettingsEx(dev, ref dm, IntPtr.Zero, teste ? 0x2u : 0x1u, IntPtr.Zero); // CDS_TEST / CDS_UPDATEREGISTRY
    }
}

// aviso grande que aparece sem roubar o foco de quem estiver na frente
public class AvisoTaxa : Form {
    public Label Numero = new Label(), Linha = new Label();
    public AvisoTaxa() {
        FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true;
        StartPosition = FormStartPosition.Manual; Width = 230; Height = 110;
        BackColor = System.Drawing.Color.FromArgb(32, 32, 32);
        Numero.Dock = DockStyle.Fill; Numero.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
        Numero.Font = new System.Drawing.Font("Segoe UI", 34, System.Drawing.FontStyle.Bold);
        Linha.Dock = DockStyle.Bottom; Linha.Height = 26; Linha.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
        Linha.Font = new System.Drawing.Font("Segoe UI", 9); Linha.ForeColor = System.Drawing.Color.Gainsboro;
        Controls.Add(Numero); Controls.Add(Linha);
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get { CreateParams p = base.CreateParams; p.ExStyle |= 0x08000000 | 0x80 | 0x8; return p; } // NOACTIVATE|TOOLWINDOW|TOPMOST
    }
}
'@
[Taxa]::DpiAware()

# uma instancia so
$mutex = New-Object System.Threading.Mutex($false, 'Local\OLGA_TaxaTela')
if (-not $mutex.WaitOne(0)) { exit }

$ATRASO = 2500   # ms sem clique ate aplicar
$REG = 'HKCU:\Software\OLGA\TaxaTela'

$script:hIcone = [IntPtr]::Zero
$script:iconeDe = ''
$script:pendente = 0

$AZUL = [System.Drawing.Color]::FromArgb(0, 120, 215)
$LARANJA = [System.Drawing.Color]::FromArgb(255, 140, 0)

# tela que o clique muda: a escolhida no menu (se ainda estiver ligada) ou a principal
function Get-Alvo {
    $telas = @([Taxa]::Telas())
    $esc = $null
    try { $esc = (Get-ItemProperty $REG -Name Tela -ErrorAction Stop).Tela } catch { }
    foreach ($t in $telas) { if ($t.Dev -eq $esc) { return $t } }
    foreach ($t in $telas) { if ($t.Principal) { return $t } }
    return $telas | Select-Object -First 1
}

function Get-NomeTela($t) {
    $n = $t.Dev -replace '^\\\\\.\\DISPLAY', 'Tela '
    if ($t.Principal) { $n += ' (principal)' }
    return "$n - $($t.W)x$($t.H)"
}

function Set-Icone([int]$hz, [bool]$pend) {
    $chave = "$hz|$pend"
    if ($chave -eq $script:iconeDe) { return }
    $script:iconeDe = $chave
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $cor = $(if ($pend) { $LARANJA } else { $AZUL })
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $cor), 0, 2, 32, 28)
    $txt = $(if ($hz -gt 0) { "$hz" } else { '?' })
    $tam = $(if ($txt.Length -ge 3) { 13 } else { 19 })
    $f = New-Object System.Drawing.Font 'Arial', $tam, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString($txt, $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 2, 32, 29), $sf)
    $g.Dispose()
    $h = $bmp.GetHicon(); $bmp.Dispose()
    $tray.Icon = [System.Drawing.Icon]::FromHandle($h)
    if ($script:hIcone -ne [IntPtr]::Zero) { [void][Taxa]::DestroyIcon($script:hIcone) }
    $script:hIcone = $h
}

function Update-Estado {
    if ($script:pendente) { return }
    $t = Get-Alvo
    if (-not $t) { Set-Icone 0 $false; $tray.Text = 'Taxa da tela: nenhuma tela'; return }
    Set-Icone $t.Hz $false
    $txt = "Taxa: $($t.Hz) Hz - " + (Get-NomeTela $t)
    if ($txt.Length -gt 63) { $txt = $txt.Substring(0, 63) }
    $tray.Text = $txt
}

function Show-Aviso([string]$numero, [string]$linha, $cor) {
    $aviso.Numero.Text = $numero
    $aviso.Numero.ForeColor = $cor
    $aviso.Linha.Text = $linha
    # acima da bandeja, perto do mouse, dentro da area de trabalho da tela do mouse
    $pos = [System.Windows.Forms.Cursor]::Position
    $wa = [System.Windows.Forms.Screen]::FromPoint($pos).WorkingArea
    $x = [Math]::Min([Math]::Max($pos.X - $aviso.Width / 2, $wa.Left + 8), $wa.Right - $aviso.Width - 8)
    $y = $wa.Bottom - $aviso.Height - 12
    $aviso.Location = New-Object System.Drawing.Point ([int]$x), ([int]$y)
    if (-not $aviso.Visible) { $aviso.Show() }
    $aviso.Refresh()
}

# clique: avanca para a proxima taxa so na tela (aviso + icone); aplica depois do ATRASO
function Step-Taxa {
    $t = Get-Alvo
    if (-not $t) { return }
    $lista = @([Taxa]::Taxas($t.Dev))
    if ($lista.Count -lt 2) {
        Show-Aviso "$($t.Hz) Hz" 'unica taxa disponivel' $AZUL
        $tFechar.Stop(); $tFechar.Start()
        return
    }
    $base = $(if ($script:pendente) { $script:pendente } else { $t.Hz })
    $i = [Array]::IndexOf($lista, $base)
    $script:pendente = $lista[($i + 1) % $lista.Count]
    $script:pendenteDev = $t.Dev
    $igual = ($script:pendente -eq $t.Hz)
    Set-Icone $script:pendente (-not $igual)
    $linha = $(if ($igual) { 'taxa atual - nada muda' } else { "agora $($t.Hz) Hz - troca ao parar de clicar" })
    Show-Aviso "$($script:pendente) Hz" $linha $(if ($igual) { $AZUL } else { $LARANJA })
    $tFechar.Stop()
    $tAplicar.Stop(); $tAplicar.Start()
}

function Set-Taxa([string]$dev, [int]$hz) {
    $script:pendente = 0
    $dm = [Taxa]::Atual($dev)
    $atual = $dm.dmDisplayFrequency
    # a resolucao pode ter mudado enquanto a troca esperava (TelaScope scope <-> padrao):
    # so aplica se a taxa ainda existe no formato atual e o Windows aceita no teste
    $validas = @([Taxa]::Taxas($dev))
    if ($hz -ne $atual -and ($validas -notcontains $hz -or [Taxa]::Mudar($dev, $hz, $true) -ne 0)) {
        Show-Aviso "$atual Hz" "$hz Hz nao existe em $($dm.dmPelsWidth)x$($dm.dmPelsHeight) - nada mudou" ([System.Drawing.Color]::Tomato)
    } elseif ($hz -ne $atual) {
        $r = [Taxa]::Mudar($dev, $hz, $false)
        if ($r -ne 0) {
            Show-Aviso "$atual Hz" "o Windows recusou $hz Hz (codigo $r)" ([System.Drawing.Color]::Tomato)
        } else {
            Show-Aviso "$hz Hz" 'aplicado' $AZUL
        }
    } else {
        Show-Aviso "$hz Hz" 'taxa atual - nada mudou' $AZUL
    }
    $tFechar.Stop(); $tFechar.Start()
    $script:iconeDe = ''
    Update-Estado
}

$aviso = New-Object AvisoTaxa
$tray = New-Object System.Windows.Forms.NotifyIcon

$tAplicar = New-Object System.Windows.Forms.Timer
$tAplicar.Interval = $ATRASO
$tAplicar.add_Tick({ $tAplicar.Stop(); if ($script:pendente) { Set-Taxa $script:pendenteDev $script:pendente } })
$tFechar = New-Object System.Windows.Forms.Timer
$tFechar.Interval = 1800
$tFechar.add_Tick({ $tFechar.Stop(); $aviso.Hide() })

$menu = New-Object System.Windows.Forms.ContextMenuStrip
# remontado toda vez que abre (tela ligada/desligada, resolucao mudada)
$menu.add_Opening({
    $menu.Items.Clear()
    $alvo = Get-Alvo
    if ($alvo) {
        $tit = $menu.Items.Add('Taxa de ' + (Get-NomeTela $alvo) + ':'); $tit.Enabled = $false
        foreach ($hz in [Taxa]::Taxas($alvo.Dev)) {
            $mi = $menu.Items.Add("   $hz Hz")
            $mi.Checked = ($hz -eq $alvo.Hz)
            $mi.Tag = @($alvo.Dev, $hz)
            $mi.add_Click({ param($o, $e) $tAplicar.Stop(); Set-Taxa $o.Tag[0] $o.Tag[1] })
        }
        $telas = @([Taxa]::Telas())
        if ($telas.Count -gt 1) {
            [void]$menu.Items.Add('-')
            $t2 = $menu.Items.Add('O clique muda a taxa de:'); $t2.Enabled = $false
            foreach ($t in $telas) {
                $mi = $menu.Items.Add('   ' + (Get-NomeTela $t) + " ($($t.Hz) Hz)")
                $mi.Checked = ($t.Dev -eq $alvo.Dev)
                $mi.Tag = $t.Dev
                $mi.add_Click({ param($o, $e)
                    New-Item $REG -Force | Out-Null
                    Set-ItemProperty $REG -Name Tela -Value $o.Tag
                    $script:pendente = 0; $tAplicar.Stop(); $script:iconeDe = ''; Update-Estado })
            }
        }
    } else {
        $mi = $menu.Items.Add('Nenhuma tela encontrada'); $mi.Enabled = $false
    }
    [void]$menu.Items.Add('-')
    $miCfg = $menu.Items.Add('Configuracoes de video do Windows...')
    $miCfg.add_Click({ Start-Process 'ms-settings:display' })
    $miSair = $menu.Items.Add('Sair')
    $miSair.add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
    $_.Cancel = $false
})
[void]$menu.Items.Add('...')   # sem item nenhum o menu nao abre
$tray.ContextMenuStrip = $menu
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Step-Taxa }
})

Update-Estado
$tray.Visible = $true

# acompanha mudancas feitas por fora (configuracoes do Windows, painel da placa)
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_Tick({ try { Update-Estado } catch { } })
$timer.Start()

[System.Windows.Forms.Application]::Run()

$timer.Stop()
$tray.Dispose()
if ($script:hIcone -ne [IntPtr]::Zero) { [void][Taxa]::DestroyIcon($script:hIcone) }
$mutex.ReleaseMutex()
