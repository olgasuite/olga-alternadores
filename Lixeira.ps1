# Lixeira.ps1 - icone da Lixeira na bandeja (ao lado do relogio), para tirar a Lixeira da Area de Trabalho
# Clique esquerdo: abre a Lixeira. Clique direito: menu (abrir, esvaziar, mostrar/esconder na Area de Trabalho).
# Icone = o da propria Lixeira do Windows (vazia/cheia); dica mostra quantos itens e o tamanho.
# O instalar.ps1 esconde a Lixeira da Area de Trabalho ao instalar e devolve ao desinstalar.
# Arquivo em ASCII puro.

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class OlgaLixeira {
    [StructLayout(LayoutKind.Sequential)]
    struct SHQUERYRBINFO { public int cbSize; public long i64Size; public long i64NumItems; }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern int SHQueryRecycleBin(string root, ref SHQUERYRBINFO info);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern int SHEmptyRecycleBin(IntPtr hwnd, string root, uint flags);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct SHSTOCKICONINFO { public uint cbSize; public IntPtr hIcon; public int iSysImageIndex; public int iIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szPath; }
    [DllImport("shell32.dll")] static extern int SHGetStockIconInfo(uint siid, uint flags, ref SHSTOCKICONINFO info);
    [DllImport("shell32.dll")] static extern void SHChangeNotify(int eventId, uint flags, IntPtr a, IntPtr b);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr handle);

    // devolve {itens, bytes}; itens = -1 se a consulta falhar
    public static long[] Consultar() {
        SHQUERYRBINFO i = new SHQUERYRBINFO();
        i.cbSize = Marshal.SizeOf(typeof(SHQUERYRBINFO));
        if (SHQueryRecycleBin(null, ref i) != 0) return new long[] { -1, 0 };
        return new long[] { i.i64NumItems, i.i64Size };
    }
    // flags 0 = o Windows pergunta "Tem certeza?" e mostra o progresso
    public static int Esvaziar() { return SHEmptyRecycleBin(IntPtr.Zero, null, 0); }
    // SIID_RECYCLER = 31, SIID_RECYCLERFULL = 32; SHGSI_ICON | SHGSI_SMALLICON
    public static IntPtr Icone(bool cheia) {
        SHSTOCKICONINFO s = new SHSTOCKICONINFO();
        s.cbSize = (uint)Marshal.SizeOf(typeof(SHSTOCKICONINFO));
        if (SHGetStockIconInfo(cheia ? 32u : 31u, 0x101, ref s) != 0) return IntPtr.Zero;
        return s.hIcon;
    }
    // avisa o Explorador para redesenhar a Area de Trabalho
    public static void Atualizar() { SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero); }
}
'@

# uma instancia so
$mutex = New-Object System.Threading.Mutex($false, 'Local\OLGA_Lixeira')
if (-not $mutex.WaitOne(0)) { exit }

$CLSID = '{645FF040-5081-101B-9F08-00AA002F954E}'
$HIDE = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'

function Test-NaAreaDeTrabalho {
    $v = (Get-ItemProperty $HIDE -Name $CLSID -ErrorAction SilentlyContinue).$CLSID
    return ($v -ne 1)
}

function Set-NaAreaDeTrabalho([bool]$mostrar) {
    if (-not (Test-Path $HIDE)) { New-Item -Path $HIDE -Force | Out-Null }
    New-ItemProperty $HIDE -Name $CLSID -Value $(if ($mostrar) { 0 } else { 1 }) -PropertyType DWord -Force | Out-Null
    [OlgaLixeira]::Atualizar()
}

function Format-Tamanho([long]$b) {
    if ($b -ge 1GB) { return ('{0:N1} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N0} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0:N0} KB' -f ($b / 1KB)) }
    return "$b bytes"
}

$script:hIcone = [IntPtr]::Zero
$script:cheia = $null
$script:texto = $null

function Update-Icone {
    $r = [OlgaLixeira]::Consultar()
    $n = $r[0]
    $cheia = $n -gt 0
    if ($cheia -ne $script:cheia) {
        $h = [OlgaLixeira]::Icone($cheia)
        if ($h -ne [IntPtr]::Zero) {
            $tray.Icon = [System.Drawing.Icon]::FromHandle($h)
            if ($script:hIcone -ne [IntPtr]::Zero) { [void][OlgaLixeira]::DestroyIcon($script:hIcone) }
            $script:hIcone = $h
        }
        $script:cheia = $cheia
    }
    if ($n -lt 0) { $t = 'Lixeira (clique para abrir)' }
    elseif ($n -eq 0) { $t = 'Lixeira vazia' }
    elseif ($n -eq 1) { $t = "Lixeira: 1 item ($(Format-Tamanho $r[1]))" }
    else { $t = "Lixeira: $n itens ($(Format-Tamanho $r[1]))" }
    if ($t -ne $script:texto) { $tray.Text = $t; $script:texto = $t }
    $miEsv.Enabled = $n -ne 0
}

function Open-Lixeira { Start-Process explorer.exe 'shell:RecycleBinFolder' }

$tray = New-Object System.Windows.Forms.NotifyIcon
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miAbrir = $menu.Items.Add('Abrir a Lixeira')
$miAbrir.Font = New-Object System.Drawing.Font $miAbrir.Font, ([System.Drawing.FontStyle]::Bold)
$miEsv = $menu.Items.Add('Esvaziar a Lixeira...')
[void]$menu.Items.Add('-')
$miDesk = $menu.Items.Add('Mostrar a Lixeira na Area de Trabalho')
[void]$menu.Items.Add('-')
$miSair = $menu.Items.Add('Sair')
$miAbrir.add_Click({ Open-Lixeira })
$miEsv.add_Click({
    [void][OlgaLixeira]::Esvaziar()   # cancelado pelo usuario tambem cai aqui; o timer acerta o icone
    $script:cheia = $null; Update-Icone
})
$miDesk.add_Click({ Set-NaAreaDeTrabalho (-not (Test-NaAreaDeTrabalho)) })
$miSair.add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
$menu.add_Opening({ $miDesk.Checked = Test-NaAreaDeTrabalho; Update-Icone })
$tray.ContextMenuStrip = $menu
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Open-Lixeira }
})

Update-Icone
$tray.Visible = $true

# acompanha o que vai para a Lixeira
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.add_Tick({ Update-Icone })
$timer.Start()

[System.Windows.Forms.Application]::Run()

$timer.Stop()
$tray.Dispose()
if ($script:hIcone -ne [IntPtr]::Zero) { [void][OlgaLixeira]::DestroyIcon($script:hIcone) }
$mutex.ReleaseMutex()
