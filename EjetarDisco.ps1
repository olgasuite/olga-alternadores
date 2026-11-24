# EjetarDisco.ps1 - icone na bandeja (ao lado do relogio) para ejetar HDs externos
# Clique (esquerdo ou direito): menu com os discos externos conectados; clicar num disco ejeta.
# Usa a mesma API do "Remover hardware com seguranca" (CM_Request_Device_Eject).
# Se o Windows recusar, mostra qual programa esta usando o disco (evento 225 do Kernel-PnP)
# e oferece fechar esse programa e tentar de novo.
# Arquivo em ASCII puro (o PowerShell 5.1 le .ps1 sem BOM como ANSI).
# Com -Letra X (menu de contexto do disco no Explorador): ejeta direto o disco dessa letra e sai.

param([string]$Letra)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public class DiscoExt {
    public int Numero; public string Letras = ""; public string Rotulo = ""; public string Modelo = "";
    public long Tamanho; public string Bus = "";
}
public class ResultadoEj { public bool Ok; public int Cr; public int Veto; public string VetoNome = ""; }

public static class Ejetor {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern SafeFileHandle CreateFile(string n, uint a, uint s, IntPtr sa, uint c, uint f, IntPtr t);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(SafeFileHandle h, uint code, IntPtr inb, int inl, IntPtr outb, int outl, out int ret, IntPtr ov);

    [StructLayout(LayoutKind.Sequential)] struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid g; public int flags; public IntPtr res; }
    [StructLayout(LayoutKind.Sequential)] struct SP_DEVINFO_DATA { public int cbSize; public Guid g; public int DevInst; public IntPtr res; }
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr e, IntPtr hwnd, int flags);
    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr di, ref Guid g, int idx, ref SP_DEVICE_INTERFACE_DATA d);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_DEVICE_INTERFACE_DATA d, IntPtr det, int size, out int req, ref SP_DEVINFO_DATA di);
    [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
    [DllImport("cfgmgr32.dll")] static extern int CM_Get_Parent(out int parent, int dev, int flags);
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    static extern int CM_Request_Device_EjectW(int dev, out int vetoType, StringBuilder veto, int len, int flags);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);

    const uint IOCTL_STORAGE_GET_DEVICE_NUMBER = 0x2D1080;
    const uint IOCTL_STORAGE_QUERY_PROPERTY = 0x2D1400;
    static Guid DISK = new Guid("53f56307-b6bf-11d0-94f2-00a0c91efb8b");

    static SafeFileHandle Abrir(string caminho) { return CreateFile(caminho, 0, 3, IntPtr.Zero, 3, 0, IntPtr.Zero); }

    static int NumeroDe(SafeFileHandle h) {
        IntPtr b = Marshal.AllocHGlobal(12);
        try {
            int r;
            if (!DeviceIoControl(h, IOCTL_STORAGE_GET_DEVICE_NUMBER, IntPtr.Zero, 0, b, 12, out r, IntPtr.Zero)) return -1;
            if (Marshal.ReadInt32(b, 0) != 7) return -1;   // FILE_DEVICE_DISK
            return Marshal.ReadInt32(b, 4);
        } finally { Marshal.FreeHGlobal(b); }
    }

    // devolve BusType (7 USB, 4 1394, 12 SD, 13 MMC...), RemovableMedia e o modelo
    static int Barramento(SafeFileHandle h, out bool removivel, out string modelo) {
        removivel = false; modelo = "";
        IntPtr q = Marshal.AllocHGlobal(12), o = Marshal.AllocHGlobal(1024);
        try {
            for (int i = 0; i < 12; i++) Marshal.WriteByte(q, i, 0);   // StorageDeviceProperty, PropertyStandardQuery
            int r;
            if (!DeviceIoControl(h, IOCTL_STORAGE_QUERY_PROPERTY, q, 12, o, 1024, out r, IntPtr.Zero)) return -1;
            removivel = Marshal.ReadByte(o, 10) != 0;
            string ven = Txt(o, Marshal.ReadInt32(o, 12)), pro = Txt(o, Marshal.ReadInt32(o, 16));
            modelo = (ven + " " + pro).Trim();
            return Marshal.ReadInt32(o, 28);
        } finally { Marshal.FreeHGlobal(q); Marshal.FreeHGlobal(o); }
    }
    static string Txt(IntPtr b, int off) { return off > 0 && off < 1024 ? (Marshal.PtrToStringAnsi(new IntPtr(b.ToInt64() + off)) ?? "").Trim() : ""; }

    static string NomeBus(int b) {
        switch (b) { case 7: return "USB"; case 4: return "FireWire"; case 12: return "SD"; case 13: return "MMC"; default: return "bus " + b; }
    }

    public static List<DiscoExt> Listar() {
        var por = new SortedDictionary<int, DiscoExt>();
        foreach (var d in DriveInfo.GetDrives()) {
            if (d.DriveType != DriveType.Removable && d.DriveType != DriveType.Fixed) continue;
            string L = d.Name.Substring(0, 1);
            using (var h = Abrir(@"\\.\" + L + ":")) {
                if (h.IsInvalid) continue;
                int n = NumeroDe(h); if (n < 0) continue;
                bool rem; string mod;
                int bus = Barramento(h, out rem, out mod);
                if (!(bus == 7 || bus == 4 || bus == 12 || bus == 13 || rem)) continue;
                DiscoExt x;
                if (!por.TryGetValue(n, out x)) { x = new DiscoExt(); x.Numero = n; x.Modelo = mod; x.Bus = NomeBus(bus); por[n] = x; }
                string rot = "";
                try { if (d.IsReady) { rot = d.VolumeLabel; x.Tamanho += d.TotalSize; } } catch { }
                x.Letras += (x.Letras.Length > 0 ? "," : "") + L;
                x.Rotulo += (x.Rotulo.Length > 0 ? " / " : "") + L + ": " + (rot.Length > 0 ? rot : "(sem nome)");
            }
        }
        return new List<DiscoExt>(por.Values);
    }

    static int DevInstDoDisco(int numero) {
        IntPtr set = SetupDiGetClassDevs(ref DISK, IntPtr.Zero, IntPtr.Zero, 0x12);   // PRESENT | DEVICEINTERFACE
        if (set == new IntPtr(-1)) return 0;
        try {
            for (int i = 0; ; i++) {
                var ifd = new SP_DEVICE_INTERFACE_DATA(); ifd.cbSize = Marshal.SizeOf(ifd);
                if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref DISK, i, ref ifd)) break;
                var di = new SP_DEVINFO_DATA(); di.cbSize = Marshal.SizeOf(di);
                int req;
                SetupDiGetDeviceInterfaceDetail(set, ref ifd, IntPtr.Zero, 0, out req, ref di);
                IntPtr det = Marshal.AllocHGlobal(req);
                try {
                    Marshal.WriteInt32(det, IntPtr.Size == 8 ? 8 : 6);
                    if (!SetupDiGetDeviceInterfaceDetail(set, ref ifd, det, req, out req, ref di)) continue;
                    string caminho = Marshal.PtrToStringUni(new IntPtr(det.ToInt64() + 4));
                    using (var h = Abrir(caminho)) {
                        if (!h.IsInvalid && NumeroDe(h) == numero) return di.DevInst;
                    }
                } finally { Marshal.FreeHGlobal(det); }
            }
        } finally { SetupDiDestroyDeviceInfoList(set); }
        return 0;
    }

    public static ResultadoEj Ejetar(int numero) {
        var res = new ResultadoEj();
        int dev = DevInstDoDisco(numero);
        if (dev == 0) { res.Cr = -1; res.VetoNome = "disco nao encontrado"; return res; }
        int pai; if (CM_Get_Parent(out pai, dev, 0) != 0) pai = dev;
        foreach (int alvo in new int[] { pai, pai, dev }) {   // 2 tentativas no aparelho USB, 1 no disco
            var sb = new StringBuilder(520); int veto;
            int cr = CM_Request_Device_EjectW(alvo, out veto, sb, sb.Capacity, 0);
            res.Cr = cr; res.Veto = veto; res.VetoNome = sb.ToString();
            if (cr == 0 && veto == 0) { res.Ok = true; return res; }
            System.Threading.Thread.Sleep(700);
        }
        return res;
    }
}
'@

# uma instancia so (o modo -Letra, do menu de contexto, roda solto e sai no fim)
if (-not $Letra) {
    $mutex = New-Object System.Threading.Mutex($false, 'Local\OLGA_EjetarDisco')
    if (-not $mutex.WaitOne(0)) { exit }
}

$VETOS = @{ 1 = 'dispositivo antigo'; 2 = 'remocao pendente'; 3 = 'um programa'; 4 = 'um servico do Windows';
            5 = 'arquivo aberto'; 6 = 'outro dispositivo'; 7 = 'um driver'; 9 = 'energia'; 10 = 'disco do sistema (nao removivel)';
            12 = 'falta de permissao'; 13 = 'ja foi removido' }

function Format-GB([long]$b) {
    if ($b -ge 1TB) { return ('{0:N1} TB' -f ($b / 1TB)) }
    return ('{0:N0} GB' -f ($b / 1GB))
}

function New-Icone {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $azul = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 120, 215))
    $branco = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $g.FillEllipse($azul, 0, 0, 31, 31)
    # simbolo de ejetar: triangulo + barra
    $tri = [System.Drawing.Point[]]@((New-Object System.Drawing.Point 16, 6), (New-Object System.Drawing.Point 26, 18), (New-Object System.Drawing.Point 6, 18))
    $g.FillPolygon($branco, $tri)
    $g.FillRectangle($branco, 6, 21, 20, 4)
    $g.Dispose()
    $h = $bmp.GetHicon(); $bmp.Dispose()
    return $h
}

# fecha janelas do Explorador abertas nessas letras (elas seguram o disco)
function Close-JanelasExplorer([string[]]$letras) {
    try {
        $sh = New-Object -ComObject Shell.Application
        foreach ($w in @($sh.Windows())) {
            try { $p = $w.Document.Folder.Self.Path } catch { continue }
            if ($p -match '^([A-Za-z]):' -and $letras -contains $Matches[1].ToUpper()) { $w.Quit() }
        }
    } catch { }
}

# quem segurou o disco: o Windows registra o evento 225 (Kernel-PnP) com o programa e o PID
function Get-Bloqueadores([datetime]$desde) {
    Start-Sleep -Milliseconds 600
    $lista = @()
    try {
        $ev = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-PnP'; Id = 225; StartTime = $desde.AddSeconds(-2) } -MaxEvents 10 -ErrorAction Stop
        foreach ($e in $ev) {
            $nome = $null; $procId = $null
            foreach ($v in $e.Properties.Value) {
                if ($v -is [string] -and $v -match '\\([^\\]+\.exe)$') { $nome = $Matches[1] }
                elseif ($null -ne $v -and "$v" -match '^\d+$' -and -not $procId) { $procId = [int]"$v" }
            }
            if ($nome -and -not ($lista | Where-Object { $_.Pid -eq $procId })) { $lista += [pscustomobject]@{ Nome = $nome; Pid = $procId } }
        }
    } catch { }
    return $lista
}

function Invoke-Ejetar($disco, [int]$tentativa = 1) {
    $letras = $disco.Letras.Split(',')
    $tray.Text = 'Ejetando ' + $disco.Rotulo
    if ($tray.Text.Length -gt 63) { $tray.Text = $tray.Text.Substring(0, 63) }
    Close-JanelasExplorer $letras
    $t0 = Get-Date
    [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
    $r = [Ejetor]::Ejetar($disco.Numero)
    $tray.Text = 'Ejetar disco externo'
    if ($r.Ok) {
        $tray.ShowBalloonTip(4000, 'Pode desconectar', "$($disco.Rotulo)`n$($disco.Modelo)", 'Info')
        $script:ejetou = $true
        return
    }
    $motivo = $VETOS[$r.Veto]; if (-not $motivo) { $motivo = "codigo $($r.Cr)/$($r.Veto)" }
    $quem = @(Get-Bloqueadores $t0)
    $titulo = 'Ejetar disco'
    if ($quem.Count -eq 0) {
        $msg = "O Windows nao liberou $($disco.Rotulo).`nMotivo: $motivo.`n`nFeche arquivos e programas que estejam usando o disco.`n`nTentar de novo?"
        if ([System.Windows.Forms.MessageBox]::Show($msg, $titulo, 'YesNo', 'Warning') -eq 'Yes') { Invoke-Ejetar $disco ($tentativa + 1) }
        return
    }
    $nomes = ($quem | ForEach-Object { "  - $($_.Nome)" + $(if ($_.Pid) { " (PID $($_.Pid))" } else { '' }) }) -join "`n"
    $fechaveis = @($quem | Where-Object { $_.Pid -gt 4 -and $_.Nome -notmatch '^(explorer|svchost|System|MsMpEng|SearchIndexer|SearchProtocolHost|csrss|lsass|services|wininit)\.exe$' })
    if ($fechaveis.Count -eq 0) {
        $msg = "$($disco.Rotulo) esta em uso por:`n$nomes`n`nSao processos do Windows (Explorador, indexacao ou antivirus); costuma liberar em alguns segundos.`n`nTentar de novo?"
        if ([System.Windows.Forms.MessageBox]::Show($msg, $titulo, 'YesNo', 'Warning') -eq 'Yes') { Start-Sleep 2; Invoke-Ejetar $disco ($tentativa + 1) }
        return
    }
    $msg = "$($disco.Rotulo) esta em uso por:`n$nomes`n`nFechar esse(s) programa(s) e tentar de novo?`n(Se houver trabalho nao salvo nele, salve antes e responda Nao.)"
    if ([System.Windows.Forms.MessageBox]::Show($msg, $titulo, 'YesNo', 'Warning') -ne 'Yes') { return }
    foreach ($q in $fechaveis) {
        $p = Get-Process -Id $q.Pid -ErrorAction SilentlyContinue; if (-not $p) { continue }
        [void]$p.CloseMainWindow()
        if (-not $p.WaitForExit(5000)) {
            $m2 = "$($q.Nome) nao fechou sozinho. Forcar o fechamento?`n(Perde o que nao foi salvo nele.)"
            if ([System.Windows.Forms.MessageBox]::Show($m2, $titulo, 'YesNo', 'Warning') -eq 'Yes') { Stop-Process -Id $q.Pid -Force -ErrorAction SilentlyContinue; Start-Sleep 1 }
            else { return }
        }
    }
    Invoke-Ejetar $disco ($tentativa + 1)
}

$h = New-Icone
$script:hIcone = $h
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.Icon]::FromHandle($h)
$tray.Text = 'Ejetar disco externo'

# modo menu de contexto: ejeta o disco da letra pedida e sai
if ($Letra) {
    $L = $Letra.Trim().Substring(0, 1).ToUpper()
    $disco = $null
    try { $disco = @([Ejetor]::Listar()) | Where-Object { $_.Letras.Split(',') -contains $L } | Select-Object -First 1 } catch { }
    if (-not $disco) {
        [void][System.Windows.Forms.MessageBox]::Show("$($L): nao e um disco externo (USB/FireWire/SD) que possa ser ejetado.", 'Ejetar disco', 'OK', 'Information')
    } else {
        $script:ejetou = $false
        $tray.Visible = $true
        Invoke-Ejetar $disco
        if ($script:ejetou) {
            # deixa o aviso "Pode desconectar" aparecer antes de sair
            $fim = New-Object System.Windows.Forms.Timer
            $fim.Interval = 4500
            $fim.add_Tick({ $fim.Stop(); [System.Windows.Forms.Application]::Exit() })
            $fim.Start()
            [System.Windows.Forms.Application]::Run()
        }
    }
    $tray.Dispose()
    [void][Ejetor]::DestroyIcon($script:hIcone)
    exit
}

$menu =New-Object System.Windows.Forms.ContextMenuStrip
# a lista e remontada toda vez que o menu abre
$menu.add_Opening({
    $menu.Items.Clear()
    $discos = @()
    try { $discos = @([Ejetor]::Listar()) } catch { }
    if ($discos.Count -eq 0) {
        $mi = $menu.Items.Add('Nenhum disco externo conectado'); $mi.Enabled = $false
    } else {
        $tit = $menu.Items.Add('Ejetar:'); $tit.Enabled = $false
        foreach ($d in $discos) {
            $txt = "$($d.Rotulo)   -   $(Format-GB $d.Tamanho)"
            if ($d.Modelo) { $txt += "   ($($d.Modelo))" }
            $mi = $menu.Items.Add($txt)
            $mi.Tag = $d
            $mi.Font = New-Object System.Drawing.Font($mi.Font, [System.Drawing.FontStyle]::Bold)
            $mi.add_Click({ param($o, $e) Invoke-Ejetar $o.Tag })
        }
    }
    [void]$menu.Items.Add('-')
    $miWin = $menu.Items.Add('Remover hardware com seguranca (Windows)...')
    $miWin.add_Click({ Start-Process rundll32.exe 'shell32.dll,Control_RunDLL hotplug.dll' })
    $miSair = $menu.Items.Add('Sair')
    $miSair.add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
    $_.Cancel = $false
})
[void]$menu.Items.Add('...')   # sem item nenhum o menu nao abre
$tray.ContextMenuStrip = $menu
# clique esquerdo tambem abre o menu
$mostrar = [System.Windows.Forms.NotifyIcon].GetMethod('ShowContextMenu', [System.Reflection.BindingFlags]'Instance,NonPublic')
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $mostrar.Invoke($tray, $null) }
})

$tray.Visible = $true
[System.Windows.Forms.Application]::Run()

$tray.Dispose()
if ($script:hIcone -ne [IntPtr]::Zero) { [void][Ejetor]::DestroyIcon($script:hIcone) }
$mutex.ReleaseMutex()
