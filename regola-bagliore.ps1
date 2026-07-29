# PANNELLO DI REGOLAZIONE per il motore "scheda accesa" di Chrome.
# All'apertura ferma il motore silenzioso e ne fa girare una copia locale
# per farti vedere le modifiche dal vivo. Chiudendo il pannello (con la X
# o con "Salva e riavvia"): salva le tue scelte e fa ripartire da solo il
# motore silenzioso con i nuovi valori -- non serve nessun altro passaggio.

Add-Type -AssemblyName System.Windows.Forms, System.Drawing, UIAutomationClient, UIAutomationTypes, WindowsBase

Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing, UIAutomationClient, UIAutomationTypes, WindowsBase @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Automation;
using System.Windows.Forms;

public struct POINTA { public int X, Y; public POINTA(int x, int y) { X = x; Y = y; } }
public struct SIZEA { public int cx, cy; public SIZEA(int x, int y) { cx = x; cy = y; } }
[StructLayout(LayoutKind.Sequential)]
public struct BLENDFUNCTION {
    public byte BlendOp, BlendFlags, SourceConstantAlpha, AlphaFormat;
}

public class Win32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    public const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    public const uint PW_RENDERFULLCONTENT = 0x00000002;
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
    [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr hObject);
    [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr hdc);
    [DllImport("user32.dll")]
    public static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref POINTA pptDst, ref SIZEA psize,
        IntPtr hdcSrc, ref POINTA pprSrc, int crKey, ref BLENDFUNCTION pblend, uint dwFlags);

    public const byte AC_SRC_OVER = 0;
    public const byte AC_SRC_ALPHA = 1;
    public const uint ULW_ALPHA = 2;

    public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc p, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINTA punto);

    public static bool ChromeEDavveroVisibileIn(POINTA punto, string processoAtteso) {
        IntPtr finestraSopra = WindowFromPoint(punto);
        if (finestraSopra == IntPtr.Zero) return false;
        return NomeProcessoProprietario(finestraSopra) == processoAtteso;
    }

    public static bool ChromeEDavveroVisibileInTutto(int x, int y, int larghezza, int altezza, string processoAtteso) {
        int destra = x + larghezza - 1;
        int basso = y + altezza - 1;
        POINTA[] punti = new POINTA[] {
            new POINTA(x + 1, y + 1),
            new POINTA(destra - 1, y + 1),
            new POINTA(x + 1, basso - 1),
            new POINTA(destra - 1, basso - 1),
            new POINTA(x + larghezza / 2, y + altezza / 2)
        };
        foreach (var p in punti) {
            if (!ChromeEDavveroVisibileIn(p, processoAtteso)) return false;
        }
        return true;
    }

    public static IntPtr TrovaChromeVisibile(string classeAttesa, string processoAtteso) {
        IntPtr trovata = IntPtr.Zero;
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            var sb = new StringBuilder(256);
            GetClassName(h, sb, 256);
            if (sb.ToString() != classeAttesa) return true;
            if (NomeProcessoProprietario(h) != processoAtteso) return true;
            trovata = h;
            return false;
        }, IntPtr.Zero);
        return trovata;
    }

    public static void MostraConAlfaVero(IntPtr hwndFinestra, Bitmap immagine, Point posizione) {
        IntPtr schermoDc = GetDC(IntPtr.Zero);
        IntPtr memDc = CreateCompatibleDC(schermoDc);
        IntPtr hBitmap = IntPtr.Zero;
        IntPtr vecchioOggetto = IntPtr.Zero;
        try {
            hBitmap = immagine.GetHbitmap(Color.FromArgb(0, 0, 0, 0));
            vecchioOggetto = SelectObject(memDc, hBitmap);

            var dimensione = new SIZEA(immagine.Width, immagine.Height);
            var puntoOrigine = new POINTA(0, 0);
            var puntoDestinazione = new POINTA(posizione.X, posizione.Y);
            var sfumatura = new BLENDFUNCTION();
            sfumatura.BlendOp = AC_SRC_OVER;
            sfumatura.BlendFlags = 0;
            sfumatura.SourceConstantAlpha = 255;
            sfumatura.AlphaFormat = AC_SRC_ALPHA;

            UpdateLayeredWindow(hwndFinestra, schermoDc, ref puntoDestinazione, ref dimensione,
                memDc, ref puntoOrigine, 0, ref sfumatura, ULW_ALPHA);
        } finally {
            ReleaseDC(IntPtr.Zero, schermoDc);
            if (vecchioOggetto != IntPtr.Zero) SelectObject(memDc, vecchioOggetto);
            if (hBitmap != IntPtr.Zero) DeleteObject(hBitmap);
            DeleteDC(memDc);
        }
    }

    public static string NomeProcessoProprietario(IntPtr hWnd) {
        uint pid;
        GetWindowThreadProcessId(hWnd, out pid);
        try {
            using (var p = Process.GetProcessById((int)pid)) {
                return p.ProcessName;
            }
        } catch {
            return "";
        }
    }
}

public static class Contrasto {
    public static Bitmap CatturaFinestra(IntPtr hwnd, Rectangle areaSchermo) {
        Win32.RECT finestra;
        Win32.GetWindowRect(hwnd, out finestra);
        int larghezzaFinestra = finestra.Right - finestra.Left;
        int altezzaFinestra = finestra.Bottom - finestra.Top;
        if (larghezzaFinestra <= 0 || altezzaFinestra <= 0) {
            return new Bitmap(Math.Max(1, areaSchermo.Width), Math.Max(1, areaSchermo.Height), PixelFormat.Format32bppArgb);
        }

        using (var completa = new Bitmap(larghezzaFinestra, altezzaFinestra, PixelFormat.Format32bppArgb)) {
            using (var g = Graphics.FromImage(completa)) {
                IntPtr hdc = g.GetHdc();
                try {
                    Win32.PrintWindow(hwnd, hdc, Win32.PW_RENDERFULLCONTENT);
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }

            int relX = areaSchermo.X - finestra.Left;
            int relY = areaSchermo.Y - finestra.Top;
            var ritaglio = new Rectangle(
                Math.Max(0, relX), Math.Max(0, relY),
                Math.Max(1, Math.Min(areaSchermo.Width, larghezzaFinestra - relX)),
                Math.Max(1, Math.Min(areaSchermo.Height, altezzaFinestra - relY)));

            return completa.Clone(ritaglio, completa.PixelFormat);
        }
    }

    public static void SchiarisciArea(Graphics destinazione, Bitmap originale, Rectangle areaSorgente, Rectangle areaDestinazione, int puntoBianco) {
        float scala = 255f / Math.Max(1, puntoBianco);
        var matrice = new ColorMatrix();
        matrice.Matrix00 = scala;
        matrice.Matrix11 = scala;
        matrice.Matrix22 = scala;
        matrice.Matrix33 = 1f;
        matrice.Matrix44 = 1f;
        using (var attributi = new ImageAttributes()) {
            attributi.SetColorMatrix(matrice);
            destinazione.DrawImage(originale, areaDestinazione,
                areaSorgente.X, areaSorgente.Y, areaSorgente.Width, areaSorgente.Height, GraphicsUnit.Pixel, attributi);
        }
    }

    public static void SchiarisciSoloChiari(Graphics destinazione, Bitmap originale, Rectangle areaSorgente, Rectangle areaDestinazione, int puntoBianco, int sogliaSfondo) {
        using (var ritaglio = originale.Clone(areaSorgente, originale.PixelFormat)) {
            var dati = ritaglio.LockBits(new Rectangle(0, 0, ritaglio.Width, ritaglio.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            try {
                int byteCount = Math.Abs(dati.Stride) * ritaglio.Height;
                byte[] pixel = new byte[byteCount];
                Marshal.Copy(dati.Scan0, pixel, 0, byteCount);

                float scala = 255f / Math.Max(1, puntoBianco);
                float denom = Math.Max(1, puntoBianco - sogliaSfondo);

                for (int i = 0; i + 3 < byteCount; i += 4) {
                    byte b = pixel[i]; byte gr = pixel[i + 1]; byte r = pixel[i + 2];
                    int lum = Math.Max(r, Math.Max(gr, b));
                    float t = (lum - sogliaSfondo) / denom;
                    if (t < 0f) t = 0f; else if (t > 1f) t = 1f;
                    if (t > 0f) {
                        pixel[i]     = (byte)Math.Min(255f, b + (Math.Min(255f, b * scala) - b) * t);
                        pixel[i + 1] = (byte)Math.Min(255f, gr + (Math.Min(255f, gr * scala) - gr) * t);
                        pixel[i + 2] = (byte)Math.Min(255f, r + (Math.Min(255f, r * scala) - r) * t);
                    }
                }
                Marshal.Copy(pixel, 0, dati.Scan0, byteCount);
            } finally {
                ritaglio.UnlockBits(dati);
            }
            destinazione.DrawImage(ritaglio, areaDestinazione);
        }
    }
}

public static class ElementiChrome {
    private static AutomationElement TrovaPrimoDiTipo(IntPtr hwnd, ControlType tipo) {
        try {
            var finestra = AutomationElement.FromHandle(hwnd);
            if (finestra == null) return null;
            var cond = new PropertyCondition(AutomationElement.ControlTypeProperty, tipo);
            return finestra.FindFirst(TreeScope.Descendants, cond);
        } catch { return null; }
    }

    private static Rectangle? RettangoloDi(AutomationElement el) {
        if (el == null) return null;
        var r = el.Current.BoundingRectangle;
        if (r.Width <= 0 || r.Height <= 0) return null;
        return Rectangle.Round(new RectangleF((float)r.X, (float)r.Y, (float)r.Width, (float)r.Height));
    }

    public static Rectangle? SchedaAttiva(IntPtr hwnd) {
        try {
            var finestra = AutomationElement.FromHandle(hwnd);
            if (finestra == null) return null;
            var condTab = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);
            var schede = finestra.FindAll(TreeScope.Descendants, condTab);
            foreach (AutomationElement scheda in schede) {
                object patternObj;
                if (scheda.TryGetCurrentPattern(SelectionItemPattern.Pattern, out patternObj)) {
                    var pattern = (SelectionItemPattern)patternObj;
                    if (pattern.Current.IsSelected) {
                        return RettangoloDi(scheda);
                    }
                }
            }
        } catch { }
        return null;
    }

    public static Rectangle? ZonaSchede(IntPtr hwnd) {
        return RettangoloDi(TrovaPrimoDiTipo(hwnd, ControlType.Tab));
    }

    public static Rectangle? ZonaStrumenti(IntPtr hwnd) {
        return RettangoloDi(TrovaPrimoDiTipo(hwnd, ControlType.ToolBar));
    }
}

public class FinestraBagliore : Form {
    public int RaggioAngoli = 10;
    public int ProfonditaBagliore = 7;
    public Color ColoreBagliore = Color.FromArgb(255, 80, 200, 255);

    public FinestraBagliore() {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        TopMost = true;
        Bounds = new Rectangle(-5000, -5000, 10, 10);
    }

    protected override CreateParams CreateParams {
        get {
            const int WS_EX_TRANSPARENT = 0x20;
            const int WS_EX_NOACTIVATE = 0x08000000;
            const int WS_EX_TOOLWINDOW = 0x00000080;
            const int WS_EX_LAYERED = 0x00080000;
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_TRANSPARENT | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_LAYERED;
            return cp;
        }
    }

    protected override bool ShowWithoutActivation { get { return true; } }

    private static GraphicsPath PercorsoArrotondato(Rectangle r, int raggio) {
        int d = raggio * 2;
        var percorso = new GraphicsPath();
        percorso.AddArc(r.X, r.Y, d, d, 180, 90);
        percorso.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        percorso.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        percorso.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        percorso.CloseFigure();
        return percorso;
    }

    public float PercentualeStaccoOrizzontale = 0.34f;
    public float PercentualeStaccoVerticale = 0.06f;

    public int PuntoBiancoSchede = 190;
    public int PuntoBiancoToolbar = 190;
    public int SogliaSfondoSchede = 90;
    public int SogliaSfondoToolbar = 90;
    public float SpessoreLinea = 0.1f;

    public void MostraBagliore(IntPtr hwndChrome, Rectangle schedaAttiva, Rectangle? zonaSchede, Rectangle? zonaStrumenti) {
        Rectangle unione = schedaAttiva;
        if (zonaSchede.HasValue) unione = Rectangle.Union(unione, zonaSchede.Value);
        if (zonaStrumenti.HasValue) unione = Rectangle.Union(unione, zonaStrumenti.Value);

        if (!Visible) Show();

        using (var catturata = Contrasto.CatturaFinestra(hwndChrome, unione))
        using (var immagine = new Bitmap(Math.Max(1, unione.Width), Math.Max(1, unione.Height), PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(immagine)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;

            if (zonaSchede.HasValue) {
                var rel = new Rectangle(zonaSchede.Value.X - unione.X, zonaSchede.Value.Y - unione.Y,
                    zonaSchede.Value.Width, zonaSchede.Value.Height);
                Contrasto.SchiarisciSoloChiari(g, catturata, rel, rel, PuntoBiancoSchede, SogliaSfondoSchede);
            }
            if (zonaStrumenti.HasValue) {
                var rel = new Rectangle(zonaStrumenti.Value.X - unione.X, zonaStrumenti.Value.Y - unione.Y,
                    zonaStrumenti.Value.Width, zonaStrumenti.Value.Height);
                Contrasto.SchiarisciSoloChiari(g, catturata, rel, rel, PuntoBiancoToolbar, SogliaSfondoToolbar);
            }

            int staccoX = (int)(schedaAttiva.Width * PercentualeStaccoOrizzontale / 2f);
            int staccoY = (int)(schedaAttiva.Height * PercentualeStaccoVerticale / 2f);
            var anelloBagliore = new Rectangle(
                schedaAttiva.X - unione.X + staccoX, schedaAttiva.Y - unione.Y + staccoY,
                Math.Max(1, schedaAttiva.Width - staccoX * 2), Math.Max(1, schedaAttiva.Height - staccoY * 2));

            for (int i = 0; i < ProfonditaBagliore; i++) {
                float t = (float)i / ProfonditaBagliore;
                int alfa = (int)(255 * (1f - t));
                if (alfa <= 0) continue;

                var rettangolo = new Rectangle(anelloBagliore.X + i, anelloBagliore.Y + i,
                    Math.Max(1, anelloBagliore.Width - i * 2), Math.Max(1, anelloBagliore.Height - i * 2));
                int raggio = Math.Max(1, RaggioAngoli - i);

                using (var percorso = PercorsoArrotondato(rettangolo, raggio))
                using (var penna = new Pen(Color.FromArgb(alfa, ColoreBagliore), SpessoreLinea)) {
                    g.DrawPath(penna, percorso);
                }
            }

            Win32.MostraConAlfaVero(this.Handle, immagine, new Point(unione.X, unione.Y));
        }
    }

    public void NascondiSeVisibile() {
        if (Visible) Hide();
    }
}
"@

[Win32]::SetProcessDPIAware() | Out-Null

# ================== RICETTA: Google Chrome ==================
$classeFinestra = "Chrome_WidgetWin_1"
$nomeProcesso = "chrome"
# ==============================================================

$cartellaMia = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$percorsoImpostazioni = Join-Path $cartellaMia "impostazioni-bagliore.json"
$percorsoMotore = Join-Path $cartellaMia "motore-contrasto.ps1"

# Ferma il motore silenzioso, se sta girando, cosi' non "litiga" con
# l'anteprima dal vivo di questo pannello.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'motore-contrasto\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 300

$bagliore = New-Object FinestraBagliore
if (Test-Path $percorsoImpostazioni) {
    try {
        $imp = Get-Content $percorsoImpostazioni -Raw | ConvertFrom-Json
        $bagliore.ColoreBagliore = [System.Drawing.Color]::FromArgb(255, [int]$imp.ColoreR, [int]$imp.ColoreG, [int]$imp.ColoreB)
        $bagliore.ProfonditaBagliore = [int]$imp.ProfonditaBagliore
        $bagliore.SpessoreLinea = [float]$imp.SpessoreLinea
        $bagliore.PercentualeStaccoOrizzontale = [float]$imp.PercentualeStaccoOrizzontale
        $bagliore.PercentualeStaccoVerticale = [float]$imp.PercentualeStaccoVerticale
        $bagliore.RaggioAngoli = [int]$imp.RaggioAngoli
        $bagliore.PuntoBiancoSchede = [int]$imp.PuntoBiancoSchede
        $bagliore.PuntoBiancoToolbar = [int]$imp.PuntoBiancoToolbar
    } catch { }
}

[IntPtr]$script:hwndChromeUltima = [Win32]::TrovaChromeVisibile($classeFinestra, $nomeProcesso)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    try {
        $hwndAttiva = [Win32]::GetForegroundWindow()
        $nomeClasse = New-Object System.Text.StringBuilder 256
        [Win32]::GetClassName($hwndAttiva, $nomeClasse, 256) | Out-Null

        $eDavveroChrome = ($nomeClasse.ToString() -eq $classeFinestra) -and
                          ([Win32]::NomeProcessoProprietario($hwndAttiva) -eq $nomeProcesso)

        if ($eDavveroChrome) {
            $script:hwndChromeUltima = $hwndAttiva
        }

        $hwndDaUsare = $script:hwndChromeUltima

        if ($hwndDaUsare -ne [IntPtr]::Zero -and [Win32]::IsWindow($hwndDaUsare) -and -not [Win32]::IsIconic($hwndDaUsare)) {
            $scheda = [ElementiChrome]::SchedaAttiva($hwndDaUsare)
            if ($scheda -and [Win32]::ChromeEDavveroVisibileInTutto([int]$scheda.X, [int]$scheda.Y, [int]$scheda.Width, [int]$scheda.Height, $nomeProcesso)) {
                $zonaSchede = [ElementiChrome]::ZonaSchede($hwndDaUsare)
                if ($zonaSchede -and -not [Win32]::ChromeEDavveroVisibileInTutto([int]$zonaSchede.X, [int]$zonaSchede.Y, [int]$zonaSchede.Width, [int]$zonaSchede.Height, $nomeProcesso)) {
                    $zonaSchede = $null
                }
                $zonaStrumenti = [ElementiChrome]::ZonaStrumenti($hwndDaUsare)
                if ($zonaStrumenti -and -not [Win32]::ChromeEDavveroVisibileInTutto([int]$zonaStrumenti.X, [int]$zonaStrumenti.Y, [int]$zonaStrumenti.Width, [int]$zonaStrumenti.Height, $nomeProcesso)) {
                    $zonaStrumenti = $null
                }
                $bagliore.MostraBagliore($hwndDaUsare, $scheda, $zonaSchede, $zonaStrumenti)
            } else {
                $bagliore.NascondiSeVisibile()
            }
        } else {
            $bagliore.NascondiSeVisibile()
        }
    } catch {
        $bagliore.NascondiSeVisibile()
    }
})
$timer.Start()

# ================== PANNELLO DI REGOLAZIONE ==================
$pannello = New-Object System.Windows.Forms.Form
$pannello.Text = "Regolazione bagliore"
$pannello.Size = New-Object System.Drawing.Size(400, 700)
$pannello.MinimumSize = New-Object System.Drawing.Size(360, 400)
$pannello.FormBorderStyle = 'Sizable'
$pannello.MaximizeBox = $true
$pannello.StartPosition = 'CenterScreen'
$pannello.TopMost = $true

$coloreSfondo = [System.Drawing.Color]::FromArgb(32, 32, 32)
$coloreTesto = [System.Drawing.Color]::FromArgb(230, 230, 230)
$pannello.BackColor = $coloreSfondo
$pannello.ForeColor = $coloreTesto

$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.ColumnCount = 3
$layout.RowCount = 12
$layout.BackColor = $coloreSfondo
$layout.Padding = New-Object System.Windows.Forms.Padding(10)
[void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 40)))
[void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 45)))
[void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 15)))
$pannello.Controls.Add($layout)

$script:rigaCorrente = 0
$script:manopole = @{}

function Aggiungi-Manopola {
    param($chiave, $etichetta, $minimo, $massimo, $valoreIniziale, $azione)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $etichetta
    $lbl.AutoSize = $true
    $lbl.Anchor = 'Left'
    $lbl.ForeColor = $coloreTesto
    $lbl.BackColor = $coloreSfondo

    $slider = New-Object System.Windows.Forms.TrackBar
    $slider.Minimum = $minimo
    $slider.Maximum = $massimo
    $slider.Value = [Math]::Max($minimo, [Math]::Min($massimo, $valoreIniziale))
    $slider.Dock = 'Fill'
    $slider.TickStyle = 'None'
    $slider.BackColor = $coloreSfondo

    $valLbl = New-Object System.Windows.Forms.Label
    $valLbl.Text = "$($slider.Value)"
    $valLbl.AutoSize = $true
    $valLbl.Anchor = 'Left'
    $valLbl.ForeColor = $coloreTesto
    $valLbl.BackColor = $coloreSfondo

    $slider.Add_Scroll({
        $valLbl.Text = "$($slider.Value)"
        & $azione $slider.Value
    }.GetNewClosure())

    $riga = $script:rigaCorrente
    $layout.Controls.Add($lbl, 0, $riga)
    $layout.Controls.Add($slider, 1, $riga)
    $layout.Controls.Add($valLbl, 2, $riga)
    $script:rigaCorrente++

    $script:manopole[$chiave] = @{ Slider = $slider; Etichetta = $valLbl }
}

Aggiungi-Manopola "R" "Colore - Rosso" 0 255 $bagliore.ColoreBagliore.R {
    param($v)
    $c = $bagliore.ColoreBagliore
    $bagliore.ColoreBagliore = [System.Drawing.Color]::FromArgb(255, $v, $c.G, $c.B)
}
Aggiungi-Manopola "G" "Colore - Verde" 0 255 $bagliore.ColoreBagliore.G {
    param($v)
    $c = $bagliore.ColoreBagliore
    $bagliore.ColoreBagliore = [System.Drawing.Color]::FromArgb(255, $c.R, $v, $c.B)
}
Aggiungi-Manopola "B" "Colore - Blu" 0 255 $bagliore.ColoreBagliore.B {
    param($v)
    $c = $bagliore.ColoreBagliore
    $bagliore.ColoreBagliore = [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $v)
}
Aggiungi-Manopola "Profondita" "Profondita' bagliore (px)" 1 30 $bagliore.ProfonditaBagliore {
    param($v) $bagliore.ProfonditaBagliore = $v
}
Aggiungi-Manopola "Spessore" "Spessore tratto (x10)" 1 50 ([int]($bagliore.SpessoreLinea * 10)) {
    param($v) $bagliore.SpessoreLinea = $v / 10.0
}
Aggiungi-Manopola "StaccoOriz" "Distacco orizzontale (%)" 0 60 ([int]($bagliore.PercentualeStaccoOrizzontale * 100)) {
    param($v) $bagliore.PercentualeStaccoOrizzontale = $v / 100.0
}
Aggiungi-Manopola "StaccoVert" "Distacco verticale (%)" 0 80 ([int]($bagliore.PercentualeStaccoVerticale * 100)) {
    param($v) $bagliore.PercentualeStaccoVerticale = $v / 100.0
}
Aggiungi-Manopola "Angoli" "Angoli arrotondati (px)" 0 20 $bagliore.RaggioAngoli {
    param($v) $bagliore.RaggioAngoli = $v
}

# Manopola generale: sposta INSIEME le due manopole di zona (schede e
# barra strumenti), che restano comunque regolabili una per una dopo.
Aggiungi-Manopola "VivaciaTutte" "Vivacita' scritte - TUTTE" 110 255 $bagliore.PuntoBiancoSchede {
    param($v)
    $bagliore.PuntoBiancoSchede = $v
    $bagliore.PuntoBiancoToolbar = $v
    $script:manopole["VivaciaSchede"].Slider.Value = $v
    $script:manopole["VivaciaSchede"].Etichetta.Text = "$v"
    $script:manopole["VivaciaToolbar"].Slider.Value = $v
    $script:manopole["VivaciaToolbar"].Etichetta.Text = "$v"
}
Aggiungi-Manopola "VivaciaSchede" "Vivacita' - striscia schede" 110 255 $bagliore.PuntoBiancoSchede {
    param($v) $bagliore.PuntoBiancoSchede = $v
}
Aggiungi-Manopola "VivaciaToolbar" "Vivacita' - barra strumenti" 110 255 $bagliore.PuntoBiancoToolbar {
    param($v) $bagliore.PuntoBiancoToolbar = $v
}

function Salva-ERiavvia {
    $daSalvare = [PSCustomObject]@{
        ColoreR = $bagliore.ColoreBagliore.R
        ColoreG = $bagliore.ColoreBagliore.G
        ColoreB = $bagliore.ColoreBagliore.B
        ProfonditaBagliore = $bagliore.ProfonditaBagliore
        SpessoreLinea = $bagliore.SpessoreLinea
        PercentualeStaccoOrizzontale = $bagliore.PercentualeStaccoOrizzontale
        PercentualeStaccoVerticale = $bagliore.PercentualeStaccoVerticale
        RaggioAngoli = $bagliore.RaggioAngoli
        PuntoBiancoSchede = $bagliore.PuntoBiancoSchede
        PuntoBiancoToolbar = $bagliore.PuntoBiancoToolbar
    }
    $daSalvare | ConvertTo-Json | Set-Content -Path $percorsoImpostazioni -Encoding UTF8

    $timer.Stop()
    $bagliore.NascondiSeVisibile()

    Start-Process powershell -ArgumentList '-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',"`"$percorsoMotore`""
}

$bottoneSalva = New-Object System.Windows.Forms.Button
$bottoneSalva.Text = "Salva e riavvia versione automatica"
$bottoneSalva.Dock = 'Fill'
$bottoneSalva.BackColor = [System.Drawing.Color]::FromArgb(50, 90, 60)
$bottoneSalva.ForeColor = $coloreTesto
$bottoneSalva.FlatStyle = 'Flat'
$bottoneSalva.Add_Click({
    Salva-ERiavvia
    $pannello.Tag = "salvato"
    $pannello.Close()
})
$layout.Controls.Add($bottoneSalva, 0, $script:rigaCorrente)
$layout.SetColumnSpan($bottoneSalva, 3)
$script:rigaCorrente++

$pannello.Add_FormClosing({
    # Se non hai gia' cliccato "Salva e riavvia" (che chiude da solo il
    # pannello), chiudere la finestra col tasto X fa la stessa cosa:
    # salva le scelte fatte finora e fa ripartire il motore silenzioso.
    if ($pannello.Tag -ne "salvato") {
        Salva-ERiavvia
    }
})

$pannello.Add_Shown({
    $scuro = 1
    [Win32]::DwmSetWindowAttribute($pannello.Handle, [Win32]::DWMWA_USE_IMMERSIVE_DARK_MODE, [ref]$scuro, 4) | Out-Null
})

[System.Windows.Forms.Application]::Run($pannello)
