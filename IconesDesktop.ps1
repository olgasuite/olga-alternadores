# IconesDesktop.ps1 - icone na bandeja que esconde/mostra os icones da Area de Trabalho
# E a mesma opcao do Windows "Exibir > Mostrar icones da area de trabalho": os arquivos continuam
# na pasta Desktop (nada e ocultado), so a Area de Trabalho para de desenhar os icones.
# Clique esquerdo: alterna. Clique direito: menu.
# Manda ao Explorador o comando do proprio menu (WM_COMMAND 0x7402 na janela SHELLDLL_DefView),
# por isso troca na hora e sem reiniciar o Explorador. Timer acompanha quem trocar pelo menu do Windows.
# Arquivo em ASCII puro.

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class OlgaIconesDesktop {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr handle);

    // janela que hospeda os icones: dentro do Progman ou de um WorkerW (apos papel de parede em apresentacao, Win+Tab etc.)
    public static IntPtr DefView() {
        IntPtr achado = IntPtr.Zero;
        IntPtr p = FindWindow("Progman", null);
        if (p != IntPtr.Zero) achado = FindWindowEx(p, IntPtr.Zero, "SHELLDLL_DefView", null);
        if (achado != IntPtr.Zero) return achado;
        EnumWindows(delegate (IntPtr h, IntPtr l) {
            StringBuilder sb = new StringBuilder(64);
            GetClassName(h, sb, 64);
            if (sb.ToString() == "WorkerW") {
                IntPtr d = FindWindowEx(h, IntPtr.Zero, "SHELLDLL_DefView", null);
                if (d != IntPtr.Zero) { achado = d; return false; }
            }
            return true;
        }, IntPtr.Zero);
        return achado;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder sb, int max);

    // 1 = visiveis, 0 = escondidos, -1 = Area de Trabalho nao encontrada
    public static int Estado() {
        IntPtr d = DefView();
        if (d == IntPtr.Zero) return -1;
        IntPtr lista = FindWindowEx(d, IntPtr.Zero, "SysListView32", null);
        if (lista == IntPtr.Zero) return -1;
        return IsWindowVisible(lista) ? 1 : 0;
    }
    // o mesmo comando do item "Mostrar icones da area de trabalho" do menu do Explorador
    public static bool Alternar() {
        IntPtr d = DefView();
        if (d == IntPtr.Zero) return false;
        SendMessage(d, 0x0111, (IntPtr)0x7402, IntPtr.Zero);
        return true;
    }
}
'@

# uma instancia so
$mutex = New-Object System.Threading.Mutex($false, 'Local\OLGA_IconesDesktop')
if (-not $mutex.WaitOne(0)) { exit }

# desenha o icone: monitor com 4 iconezinhos (visiveis) ou monitor vazio com risco (escondidos)
function New-Icone([bool]$visiveis) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $cor = $(if ($visiveis) { [System.Drawing.Color]::FromArgb(0, 120, 215) } else { [System.Drawing.Color]::FromArgb(130, 130, 130) })
    $pena = New-Object System.Drawing.Pen $cor, 2.5
    $g.DrawRectangle($pena, 2, 3, 28, 20)                     # tela
    $g.DrawLine($pena, 16, 23, 16, 28); $g.DrawLine($pena, 9, 29, 23, 29)   # pe
    if ($visiveis) {
        $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 170, 0))
        foreach ($p in @(@(6, 7), @(13, 7), @(6, 14), @(13, 14))) { $g.FillRectangle($b, $p[0], $p[1], 5, 5) }
        $b.Dispose()
    } else {
        $x = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(210, 40, 40)), 3
        $g.DrawLine($x, 7, 7, 25, 19)
        $x.Dispose()
    }
    $pena.Dispose(); $g.Dispose()
    $h = $bmp.GetHicon(); $bmp.Dispose()
    return $h
}

$script:hIcone = [IntPtr]::Zero
$script:estado = $null

function Update-Icone {
    $e = [OlgaIconesDesktop]::Estado()
    if ($e -eq $script:estado) { return }
    $script:estado = $e
    $h = New-Icone ($e -ne 0)
    $tray.Icon = [System.Drawing.Icon]::FromHandle($h)
    if ($script:hIcone -ne [IntPtr]::Zero) { [void][OlgaIconesDesktop]::DestroyIcon($script:hIcone) }
    $script:hIcone = $h
    $tray.Text = $(if ($e -eq 1) { 'Icones da Area de Trabalho: visiveis (clique para esconder)' }
                   elseif ($e -eq 0) { 'Icones da Area de Trabalho: escondidos (clique para mostrar)' }
                   else { 'Icones da Area de Trabalho (Explorador nao encontrado)' })
}

function Switch-Icones {
    if (-not [OlgaIconesDesktop]::Alternar()) {
        $tray.ShowBalloonTip(3000, 'Icones da Area de Trabalho', 'Nao achei a Area de Trabalho do Explorador.', 'Warning')
        return
    }
    Start-Sleep -Milliseconds 150
    Update-Icone
}

$tray = New-Object System.Windows.Forms.NotifyIcon
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miMostrar = $menu.Items.Add('Mostrar icones da Area de Trabalho')
[void]$menu.Items.Add('-')
$miSair = $menu.Items.Add('Sair')
$miMostrar.add_Click({ Switch-Icones })
$miSair.add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
$menu.add_Opening({ Update-Icone; $miMostrar.Checked = ($script:estado -eq 1) })
$tray.ContextMenuStrip = $menu
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Switch-Icones }
})

Update-Icone
$tray.Visible = $true

# acompanha a troca feita pelo menu do Windows (e o Explorador reiniciando)
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_Tick({ Update-Icone })
$timer.Start()

[System.Windows.Forms.Application]::Run()

$timer.Stop()
$tray.Dispose()
if ($script:hIcone -ne [IntPtr]::Zero) { [void][OlgaIconesDesktop]::DestroyIcon($script:hIcone) }
$mutex.ReleaseMutex()
