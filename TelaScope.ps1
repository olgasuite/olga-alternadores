# TelaScope.ps1 - icone na bandeja (ao lado do relogio) para a 2a tela (projetor scope)
# Clique esquerdo: alterna a tela secundaria entre SCOPE (1920x804) e PADRAO (1920x1080).
# Clique direito: menu. Mantem a 2a tela encostada onde estava (em cima da principal)
# e leva junto a janela de imagem do DCP-o-matic Player, que passa a usar o novo formato.
#
# Tambem corrige o DCP-o-matic Player (2.18) em modo duas telas: ele cria a janela de
# imagem com 1920x1080 mesmo numa tela 1920x804, e o flat vaza para a tela principal.
# A cada 2 s a janela de imagem e ajustada ao tamanho real do monitor.
#
# REQUISITO: a resolucao personalizada 1920x804 precisa existir no painel da placa de
# video (NVIDIA: Painel de Controle > Alterar resolucao > Personalizar; AMD: Adrenalin >
# Resolucoes personalizadas; Intel: Graphics Command Center). Sem ela o Windows recusa
# a troca e o icone avisa. O script em si funciona com qualquer placa.

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class TScope {
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
    public struct RECT { public int L, T, R, B; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettings(string d, int m, ref DEVMODE dm);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int ChangeDisplaySettingsEx(string d, ref DEVMODE dm, IntPtr h, uint f, IntPtr p);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);

    public static void DpiAware() { SetProcessDPIAware(); }

    // leitura AO VIVO dos monitores (Screen.AllScreens do .NET fica em cache)
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct MONITORINFOEX { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string szDevice; }
    delegate bool MonProc(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonProc p, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool GetMonitorInfo(IntPtr h, ref MONITORINFOEX mi);
    public class Tela { public string Dev; public bool Principal; public int X, Y, W, H; }
    public static List<Tela> Telas() {
        List<Tela> res = new List<Tela>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, delegate(IntPtr h, IntPtr dc, ref RECT rr, IntPtr l) {
            MONITORINFOEX mi = new MONITORINFOEX(); mi.cbSize = Marshal.SizeOf(mi);
            if (GetMonitorInfo(h, ref mi)) {
                Tela t = new Tela(); t.Dev = mi.szDevice; t.Principal = (mi.dwFlags & 1) != 0;
                t.X = mi.rcMonitor.L; t.Y = mi.rcMonitor.T; t.W = mi.rcMonitor.R - mi.rcMonitor.L; t.H = mi.rcMonitor.B - mi.rcMonitor.T;
                res.Add(t);
            }
            return true;
        }, IntPtr.Zero);
        return res;
    }
    public static Tela Secundaria() { foreach (Tela t in Telas()) if (!t.Principal) return t; return null; }
    public static Tela Principal() { foreach (Tela t in Telas()) if (t.Principal) return t; return null; }

    public static DEVMODE Atual(string dev) {
        DEVMODE dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(dm);
        EnumDisplaySettings(dev, -1, ref dm); return dm;
    }

    // muda resolucao + posicao; tenta manter a frequencia, se nao der tenta sem ela
    public static int Mudar(string dev, int w, int h, int x, int y) {
        DEVMODE dm = Atual(dev);
        dm.dmPelsWidth = w; dm.dmPelsHeight = h; dm.dmPositionX = x; dm.dmPositionY = y;
        dm.dmFields = 0x80000 | 0x100000 | 0x20 | 0x400000; // largura|altura|posicao|frequencia
        int r = ChangeDisplaySettingsEx(dev, ref dm, IntPtr.Zero, 0x1, IntPtr.Zero); // CDS_UPDATEREGISTRY
        if (r != 0) {
            dm.dmFields = 0x80000 | 0x100000 | 0x20;
            r = ChangeDisplaySettingsEx(dev, ref dm, IntPtr.Zero, 0x1, IntPtr.Zero);
        }
        return r;
    }

    // janelas sem titulo do DCP-o-matic Player cujo canto esta em (x,y) = janela de imagem
    public static List<IntPtr> JanelasImagem(int[] pids, int x, int y) {
        List<IntPtr> res = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            if (!IsWindowVisible(h) || GetWindowTextLength(h) != 0) return true;
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (Array.IndexOf(pids, (int)pid) < 0) return true;
            RECT r; GetWindowRect(h, out r);
            if (r.L == x && r.T == y && r.R - r.L >= 600) res.Add(h);
            return true;
        }, IntPtr.Zero);
        return res;
    }

    public static void Posicionar(IntPtr h, int x, int y, int w, int hh) {
        SetWindowPos(h, IntPtr.Zero, x, y, w, hh, 0x0014); // NOZORDER|NOACTIVATE
    }

    // janela de imagem do Player no canto de um monitor secundario, mas com tamanho
    // diferente do monitor (o Player cria 1920x1080) -> ajusta ao monitor
    public static int AjustarImagem(int[] pids) {
        int n = 0;
        foreach (Tela t in Telas()) {
            if (t.Principal) continue;
            foreach (IntPtr h in JanelasImagem(pids, t.X, t.Y)) {
                RECT r; GetWindowRect(h, out r);
                if (r.R - r.L != t.W || r.B - r.T != t.H) { Posicionar(h, t.X, t.Y, t.W, t.H); n++; }
            }
        }
        return n;
    }
}
'@
[TScope]::DpiAware()

# uma instancia so
$mutex = New-Object System.Threading.Mutex($false, 'Local\OLGA_TelaScope')
if (-not $mutex.WaitOne(0)) { exit }

$LARG = 1920; $ALT_SCOPE = 804; $ALT_PADRAO = 1080

$script:hIcone = [IntPtr]::Zero
$script:estado = 'x'

function Get-Estado {
    $s = [TScope]::Secundaria()
    if (-not $s) { return 'sem' }
    if ($s.H -eq $ALT_SCOPE) { return 'scope' }
    if ($s.H -eq $ALT_PADRAO) { return 'padrao' }
    return 'outro'
}

function New-Icone([string]$est) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 2
    switch ($est) {
        'scope'  { $cor = [System.Drawing.Color]::FromArgb(255, 140, 0);  $r = New-Object System.Drawing.Rectangle 1, 9, 30, 13 }
        'padrao' { $cor = [System.Drawing.Color]::FromArgb(0, 120, 215);  $r = New-Object System.Drawing.Rectangle 3, 5, 26, 21 }
        default  { $cor = [System.Drawing.Color]::FromArgb(120, 120, 120); $r = New-Object System.Drawing.Rectangle 3, 5, 26, 21 }
    }
    $b = New-Object System.Drawing.SolidBrush $cor
    $g.FillRectangle($b, $r); $g.DrawRectangle($pen, $r)
    # "S" ou "P" no meio
    $letra = @{ scope = 'S'; padrao = 'P' }[$est]; if (-not $letra) { $letra = '?' }
    $f = New-Object System.Drawing.Font 'Segoe UI', 11, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString($letra, $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF $r.X, $r.Y, $r.Width, $r.Height), $sf)
    $g.Dispose()
    $h = $bmp.GetHicon(); $bmp.Dispose(); return $h
}

function Update-Icone {
    $est = Get-Estado
    if ($est -eq $script:estado) { return }
    $script:estado = $est
    $h = New-Icone $est
    $tray.Icon = [System.Drawing.Icon]::FromHandle($h)
    if ($script:hIcone -ne [IntPtr]::Zero) { [void][TScope]::DestroyIcon($script:hIcone) }
    $script:hIcone = $h
    switch ($est) {
        'scope'  { $tray.Text = '2a tela: SCOPE 1920x804 (clique: padrao)' }
        'padrao' { $tray.Text = '2a tela: PADRAO 1920x1080 (clique: scope)' }
        'sem'    { $tray.Text = '2a tela: nao encontrada (estendida?)' }
        default  { $tray.Text = '2a tela: outra resolucao (clique: scope)' }
    }
    $miScope.Checked = ($est -eq 'scope')
    $miPadrao.Checked = ($est -eq 'padrao')
}

function Set-Altura([int]$alt) {
    $s = [TScope]::Secundaria()
    if (-not $s) {
        $tray.ShowBalloonTip(3000, 'Tela Scope', 'Nao ha 2a tela estendida. Ligue a TV/projetor e use Estender.', 'Warning')
        return
    }
    $p = [TScope]::Principal()
    # mantem a 2a tela encostada: se esta em cima da principal, a borda de baixo fica no lugar
    $x = $s.X; $y = $s.Y
    if ($p -and ($s.Y + $s.H) -eq $p.Y) { $y = $p.Y - $alt }

    $pids = @(Get-Process dcpomatic2_player -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $janelas = @()
    if ($pids.Count) { $janelas = [TScope]::JanelasImagem([int[]]$pids, $s.X, $s.Y) }

    $r = [TScope]::Mudar($s.Dev, $LARG, $alt, $x, $y)
    if ($r -ne 0) {
        $tray.ShowBalloonTip(4000, 'Tela Scope', "O Windows recusou ${LARG}x${alt} (codigo $r). Crie essa resolucao personalizada no painel da placa de video (NVIDIA/AMD/Intel).", 'Warning')
    } else {
        Start-Sleep -Milliseconds 800
        $n = [TScope]::Secundaria()
        if ($n) { foreach ($j in $janelas) { [TScope]::Posicionar($j, $n.X, $n.Y, $n.W, $n.H) } }
    }
    $script:estado = 'x'
    Update-Icone
}

$tray = New-Object System.Windows.Forms.NotifyIcon
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miScope = $menu.Items.Add('Scope (1920x804)')
$miPadrao = $menu.Items.Add('Padrao (1920x1080)')
[void]$menu.Items.Add('-')
$miCfg = $menu.Items.Add('Configuracoes de video do Windows...')
$miSair = $menu.Items.Add('Sair')
$miScope.add_Click({ Set-Altura $ALT_SCOPE })
$miPadrao.add_Click({ Set-Altura $ALT_PADRAO })
$miCfg.add_Click({ Start-Process 'ms-settings:display' })
$miSair.add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
$tray.ContextMenuStrip = $menu
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        if ((Get-Estado) -eq 'scope') { Set-Altura $ALT_PADRAO } else { Set-Altura $ALT_SCOPE }
    }
})

Update-Icone
$tray.Visible = $true

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_Tick({
    Update-Icone
    try {
        $pids = @(Get-Process dcpomatic2_player -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
        if ($pids.Count) { [void][TScope]::AjustarImagem([int[]]$pids) }
    } catch { }
})
$timer.Start()

[System.Windows.Forms.Application]::Run()

$timer.Stop()
$tray.Dispose()
if ($script:hIcone -ne [IntPtr]::Zero) { [void][TScope]::DestroyIcon($script:hIcone) }
$mutex.ReleaseMutex()
