# AlternarAudio.ps1 - icone na bandeja (ao lado do relogio) para trocar a saida de audio
# Clique esquerdo: passa para a proxima saida da lista. Clique direito: menu com todas.
# Usa a API interna IPolicyConfig (a mesma do painel de som do Windows).

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct PROPERTYKEY { public Guid fmtid; public int pid; }

[StructLayout(LayoutKind.Sequential)]
public struct PROPVARIANT { public short vt; public short r1, r2, r3; public IntPtr p; public int p2; }

[Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPropertyStore {
    int GetCount(out int c);
    int GetAt(int i, out PROPERTYKEY k);
    int GetValue(ref PROPERTYKEY k, out PROPVARIANT v);
    int SetValue(ref PROPERTYKEY k, ref PROPVARIANT v);
    int Commit();
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o);
    int OpenPropertyStore(int access, out IPropertyStore ps);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    int GetState(out int st);
}

[Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceCollection {
    int GetCount(out int c);
    int Item(int i, out IMMDevice d);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int flow, int mask, out IMMDeviceCollection col);
    int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice d);
    int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice d);
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int RegisterControlChangeNotify(); int UnregisterControlChangeNotify(); int GetChannelCount();
    int SetMasterVolumeLevel(); int SetMasterVolumeLevelScalar(); int GetMasterVolumeLevel();
    int GetMasterVolumeLevelScalar(); int SetChannelVolumeLevel(); int SetChannelVolumeLevelScalar();
    int GetChannelVolumeLevel(); int GetChannelVolumeLevelScalar();
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool mudo, ref Guid ctx);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mudo);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorCo { }

[Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPolicyConfig {
    int GetMixFormat(); int GetDeviceFormat(); int ResetDeviceFormat(); int SetDeviceFormat();
    int GetProcessingPeriod(); int SetProcessingPeriod(); int GetShareMode(); int SetShareMode();
    int GetPropertyValue(); int SetPropertyValue();
    int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
}

[ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
class PolicyConfigCo { }

public class Saida { public string Id; public string Nome; }

public static class AltAudio {
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr handle);
    [DllImport("ole32.dll")] static extern int PropVariantClear(ref PROPVARIANT v);

    static IMMDeviceEnumerator En() { return (IMMDeviceEnumerator)(new MMDeviceEnumeratorCo()); }

    // saidas (render=0) ativas (DEVICE_STATE_ACTIVE=1)
    public static List<Saida> Listar() {
        var lista = new List<Saida>();
        IMMDeviceCollection col;
        Marshal.ThrowExceptionForHR(En().EnumAudioEndpoints(0, 1, out col));
        int n; col.GetCount(out n);
        PROPERTYKEY nome = new PROPERTYKEY();
        nome.fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"); nome.pid = 14;
        for (int i = 0; i < n; i++) {
            IMMDevice d; col.Item(i, out d);
            var s = new Saida(); d.GetId(out s.Id);
            IPropertyStore ps; d.OpenPropertyStore(0, out ps);
            PROPVARIANT v; ps.GetValue(ref nome, out v);
            s.Nome = Marshal.PtrToStringUni(v.p);
            PropVariantClear(ref v);
            lista.Add(s);
        }
        lista.Sort(delegate(Saida a, Saida b) { return string.Compare(a.Nome, b.Nome, StringComparison.CurrentCultureIgnoreCase); });
        return lista;
    }

    public static string Atual() {
        IMMDevice d;
        if (En().GetDefaultAudioEndpoint(0, 0, out d) != 0 || d == null) return null;
        string id; d.GetId(out id); return id;
    }

    // muda para todos os papeis: console, multimidia e comunicacao
    public static int Definir(string id) {
        var pc = (IPolicyConfig)(new PolicyConfigCo());
        int r = 0;
        for (int role = 0; role < 3; role++) { int x = pc.SetDefaultEndpoint(id, role); if (x != 0) r = x; }
        return r;
    }

    // mudo do Windows (o mesmo da tecla de mudo / icone de volume), por saida
    static IAudioEndpointVolume Vol(string id) {
        IMMDevice d;
        if (id == null || En().GetDevice(id, out d) != 0 || d == null) return null;
        Guid iid = typeof(IAudioEndpointVolume).GUID; object o;
        if (d.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) return null;
        return (IAudioEndpointVolume)o;
    }
    public static bool Mudo(string id) {
        var v = Vol(id); if (v == null) return false;
        bool m; v.GetMute(out m); return m;
    }
    public static int DefinirMudo(string id, bool mudo) {
        var v = Vol(id); if (v == null) return -1;
        Guid g = Guid.Empty; return v.SetMute(mudo, ref g);
    }
}
'@

# uma instancia so
$mutex = New-Object System.Threading.Mutex($false, 'Local\OLGA_AlternarAudio')
if (-not $mutex.WaitOne(0)) { exit }

$script:hIcone = [IntPtr]::Zero
$script:hIconeMudo = [IntPtr]::Zero
$script:idAtual = $null
$script:mudoAtual = $null

function New-Icone([bool]$mudo = $false) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $azul = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 120, 215))
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 2
    $onda = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 140, 0)), 3
    # alto-falante
    $pts = [System.Drawing.Point[]]@(
        (New-Object System.Drawing.Point 2, 11), (New-Object System.Drawing.Point 9, 11),
        (New-Object System.Drawing.Point 17, 3), (New-Object System.Drawing.Point 17, 29),
        (New-Object System.Drawing.Point 9, 21), (New-Object System.Drawing.Point 2, 21))
    $g.FillPolygon($azul, $pts); $g.DrawPolygon($pen, $pts)
    if ($mudo) {
        # X vermelho no lugar das ondas
        $x = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(232, 17, 35)), 4
        $g.DrawLine($x, 19, 9, 30, 23); $g.DrawLine($x, 30, 9, 19, 23)
        $x.Dispose()
    } else {
        # ondas
        $g.DrawArc($onda, 14, 9, 10, 14, -55, 110)
        $g.DrawArc($onda, 14, 3, 17, 26, -55, 110)
    }
    $g.Dispose()
    $h = $bmp.GetHicon()
    $bmp.Dispose()
    return $h
}

function Get-Nome($id) {
    foreach ($s in [AltAudio]::Listar()) { if ($s.Id -eq $id) { return $s.Nome } }
    return '(nenhuma)'
}

function Update-Estado {
    try { $id = [AltAudio]::Atual() } catch { $id = $null }
    try { $mudo = [AltAudio]::Mudo($id) } catch { $mudo = $false }
    if ($id -eq $script:idAtual -and $mudo -eq $script:mudoAtual) { return }
    $script:idAtual = $id
    $script:mudoAtual = $mudo
    if ($mudo) { $tray.Icon = $script:icoMudo; $t = 'Audio: MUDO (' + (Get-Nome $id) + ')' }
    else { $tray.Icon = $script:icoSom; $t = 'Audio: ' + (Get-Nome $id) }
    if ($t.Length -gt 63) { $t = $t.Substring(0, 63) }   # limite do tooltip da bandeja
    $tray.Text = $t
}

function Set-Mudo([bool]$mudo) {
    $id = [AltAudio]::Atual()
    $r = [AltAudio]::DefinirMudo($id, $mudo)
    if ($r -ne 0) {
        $tray.ShowBalloonTip(3000, 'Alternar audio', "Nao consegui mudar o mudo (codigo $r).", 'Warning')
    } elseif ($mudo) {
        $tray.ShowBalloonTip(1500, 'Audio', 'MUDO', 'Info')
    } else {
        $tray.ShowBalloonTip(1500, 'Saida de audio', (Get-Nome $id), 'Info')
    }
    $script:idAtual = $null
    Update-Estado
}

function Set-Saida($s) {
    # tirar do mudo a saida que estava muda, para o som nao sumir junto
    $ant = [AltAudio]::Atual()
    if ($ant -and $ant -ne $s.Id -and [AltAudio]::Mudo($ant)) { [void][AltAudio]::DefinirMudo($ant, $false) }
    $r = [AltAudio]::Definir($s.Id)
    if ($r -ne 0) {
        $tray.ShowBalloonTip(3000, 'Alternar audio', "O Windows recusou a mudanca (codigo $r).", 'Warning')
    } else {
        # escolher uma saida = querer ouvir: tira do mudo
        if ([AltAudio]::Mudo($s.Id)) { [void][AltAudio]::DefinirMudo($s.Id, $false) }
        $tray.ShowBalloonTip(1500, 'Saida de audio', $s.Nome, 'Info')
    }
    $script:idAtual = $null
    Update-Estado
}

# ciclo do clique: saida 1 -> saida 2 -> ... -> MUDO -> saida 1
function Set-Proxima {
    $lista = @([AltAudio]::Listar())
    if ($lista.Count -eq 0) {
        $tray.ShowBalloonTip(2000, 'Alternar audio', 'Nenhuma saida de audio disponivel.', 'Info')
        return
    }
    $atual = [AltAudio]::Atual()
    $i = -1
    for ($k = 0; $k -lt $lista.Count; $k++) { if ($lista[$k].Id -eq $atual) { $i = $k } }
    if ([AltAudio]::Mudo($atual)) {
        $prox = $lista[($i + 1) % $lista.Count]
        if ($prox.Id -eq $atual) { Set-Mudo $false } else { Set-Saida $prox }
    } elseif ($i -eq $lista.Count - 1) {
        Set-Mudo $true
    } else {
        Set-Saida $lista[$i + 1]
    }
}

$script:hIcone = New-Icone $false
$script:hIconeMudo = New-Icone $true
$script:icoSom = [System.Drawing.Icon]::FromHandle($script:hIcone)
$script:icoMudo = [System.Drawing.Icon]::FromHandle($script:hIconeMudo)
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $script:icoSom

$menu = New-Object System.Windows.Forms.ContextMenuStrip
# a lista e remontada toda vez que o menu abre (fone/HDMI conectado depois aparece)
$menu.add_Opening({
    $menu.Items.Clear()
    $atual = [AltAudio]::Atual()
    $mudo = [AltAudio]::Mudo($atual)
    foreach ($s in [AltAudio]::Listar()) {
        $mi = $menu.Items.Add($s.Nome)
        $mi.Checked = ($s.Id -eq $atual -and -not $mudo)
        $mi.Tag = $s
        $mi.add_Click({ param($o, $e) Set-Saida $o.Tag })
    }
    $miMudo = $menu.Items.Add('Mudo')
    $miMudo.Checked = $mudo
    $miMudo.add_Click({ Set-Mudo (-not [AltAudio]::Mudo([AltAudio]::Atual())) })
    [void]$menu.Items.Add('-')
    $miCfg = $menu.Items.Add('Configuracoes de som do Windows...')
    $miCfg.add_Click({ Start-Process 'ms-settings:sound' })
    $miSair = $menu.Items.Add('Sair')
    $miSair.add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
    $_.Cancel = $false
})
[void]$menu.Items.Add('...')   # sem item nenhum o menu nao abre
$tray.ContextMenuStrip = $menu
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Set-Proxima }
})

Update-Estado
$tray.Visible = $true

# acompanha mudancas feitas por fora (painel de som, fone conectado etc.)
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_Tick({ Update-Estado })
$timer.Start()

[System.Windows.Forms.Application]::Run()

$timer.Stop()
$tray.Dispose()
if ($script:hIcone -ne [IntPtr]::Zero) { [void][AltAudio]::DestroyIcon($script:hIcone) }
if ($script:hIconeMudo -ne [IntPtr]::Zero) { [void][AltAudio]::DestroyIcon($script:hIconeMudo) }
$mutex.ReleaseMutex()
