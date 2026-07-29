# MOTORE "SCHEDA ACCESA" per Chrome -- versione silenziosa
# ----------------------------------------------------------
# Cosa fa: trova la scheda attualmente attiva e le disegna intorno un
# bagliore colorato, e schiarisce le scritte spente nella striscia delle
# schede e nella barra degli strumenti. Non tocca il contenuto delle
# pagine web, solo la "cornice" di Chrome.
#
# Resta acceso anche se lavori in un'altra finestra (compreso il
# pannello di regolazione): mostra sempre l'ultima scheda Chrome vista,
# finche' quella finestra Chrome esiste ed e' visibile.
#
# Legge le impostazioni da impostazioni-bagliore.json all'avvio (se
# esiste). Per fermarlo: chiudi il processo powershell.exe che lo fa
# girare (o usa ferma-bagliore.ps1).

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
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref POINTA pptDst, ref SIZEA psize,
        IntPtr hdcSrc, ref POINTA pprSrc, int crKey, ref BLENDFUNCTION pblend, uint dwFlags);

    public const byte AC_SRC_OVER = 0;
    public const byte AC_SRC_ALPHA = 1;
    public const uint ULW_ALPHA = 2;

    public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc p, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINTA punto);

    // Vero se nel punto indicato (di solito il centro della scheda attiva)
    // c'e' davvero Chrome in primo piano -- se un'altra finestra e' stata
    // trascinata sopra a coprire quel punto, il bagliore non deve
    // continuare a disegnarsi li' sopra (la finestra del bagliore e'
    // sempre in primo piano su tutto il desktop, quindi da sola non se ne
    // accorgerebbe).
    public static bool ChromeEDavveroVisibileIn(POINTA punto, string processoAtteso) {
        IntPtr finestraSopra = WindowFromPoint(punto);
        if (finestraSopra == IntPtr.Zero) return false;
        return NomeProcessoProprietario(finestraSopra) == processoAtteso;
    }

    // Controlla i 4 angoli + il centro di un intero rettangolo: se anche
    // uno solo di questi punti e' coperto da un'altra finestra, trattiamo
    // TUTTO il rettangolo come coperto. Necessario per le fasce larghe e
    // basse (come la barra degli strumenti), dove il solo centro puo'
    // restare libero anche se una finestra ne copre meta'.
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

    // Cerca una finestra Chrome vera (classe giusta E programma giusto)
    // gia' visibile da qualche parte, cosi' il motore funziona subito
    // all'avvio anche se Chrome non e' la finestra attiva in quel momento.
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

    // Disegna un bitmap con trasparenza vera (sfumature comprese) esattamente
    // sopra la posizione indicata, usando la tecnica delle "finestre a
    // strati" di Windows invece del trucco del colore magico, che non
    // regge le sfumature.
    public static string UltimoEsitoComposizione = "";

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

            bool ok = UpdateLayeredWindow(hwndFinestra, schermoDc, ref puntoDestinazione, ref dimensione,
                memDc, ref puntoOrigine, 0, ref sfumatura, ULW_ALPHA);
            if (!ok) {
                int errore = Marshal.GetLastWin32Error();
                UltimoEsitoComposizione = "FALLITO errore=" + errore + " hwnd=" + hwndFinestra + " dim=" + dimensione.cx + "x" + dimensione.cy + " pos=" + puntoDestinazione.X + "," + puntoDestinazione.Y + " schermoDc=" + schermoDc + " memDc=" + memDc + " hBitmap=" + hBitmap;
            } else {
                UltimoEsitoComposizione = "OK dim=" + dimensione.cx + "x" + dimensione.cy + " pos=" + puntoDestinazione.X + "," + puntoDestinazione.Y;
            }
        } finally {
            ReleaseDC(IntPtr.Zero, schermoDc);
            if (vecchioOggetto != IntPtr.Zero) SelectObject(memDc, vecchioOggetto);
            if (hBitmap != IntPtr.Zero) DeleteObject(hBitmap);
            DeleteDC(memDc);
        }
    }

    // La CLASSE della finestra da sola non basta: tantissimi programmi
    // (compresa l'app di Claude) sono costruiti con la stessa tecnologia
    // di Chrome e condividono la stessa etichetta. Controlliamo anche
    // il nome del PROGRAMMA vero che ha creato quella finestra.
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

// Chiede direttamente a Chrome di "auto-ritrarsi" dentro un nostro bitmap
// (non e' una fotografia dello schermo, quindi non rischia di fotografare
// il nostro stesso bagliore) e poi schiarisce il risultato: i grigi spenti
// diventano piu' bianchi, senza mai scurire nulla.
public static class Contrasto {
    // PrintWindow disegna sempre a partire dall'angolo in alto a sinistra
    // dell'INTERA finestra, non da dove vogliamo noi. Quindi catturiamo
    // tutta la finestra e poi ritagliamo solo il pezzo che ci interessa,
    // calcolando la sua posizione relativa alla finestra.
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

    // Schiarisce una porzione di "originale" (area sorgente, in pixel
    // relativi a "originale") disegnandola in "areaDestinazione" -- serve
    // per pescare un pezzo solo dalla foto grande dell'intera fascia
    // catturata, senza doverla ritagliare a parte.
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

    // Come SchiarisciArea, ma tocca SOLO i pixel gia' chiari (scritte e
    // icone): quelli sotto "sogliaSfondo" restano esattamente come sono,
    // cosi' lo sfondo della scheda non si schiarisce mai. La transizione
    // e' morbida (non un taglio netto) per non creare un bordo brutto
    // intorno alle lettere.
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

// Usa l'Automazione Interfaccia Utente di Windows (la stessa tecnologia
// che usano i lettori di schermo) per trovare la scheda attiva e le due
// fasce "striscia delle schede" e "barra degli strumenti", senza
// modificare nulla dentro Chrome.
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

    // La striscia orizzontale che contiene tutte le schede aperte
    // (non solo quella attiva) -- e' un unico controllo "Tab" in Chrome.
    public static Rectangle? ZonaSchede(IntPtr hwnd) {
        return RettangoloDi(TrovaPrimoDiTipo(hwnd, ControlType.Tab));
    }

    // La barra con i pulsanti indietro/avanti/ricarica e la barra
    // degli indirizzi -- e' un unico controllo "ToolBar" in Chrome.
    public static Rectangle? ZonaStrumenti(IntPtr hwnd) {
        return RettangoloDi(TrovaPrimoDiTipo(hwnd, ControlType.ToolBar));
    }
}

// Finestra senza bordi, sempre in primo piano, trasparente ovunque tranne
// dove disegniamo. Lascia passare i click alla finestra sotto
// (WS_EX_TRANSPARENT) e non ruba mai il focus (WS_EX_NOACTIVATE).
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

    // Distacco dal vero bordo della scheda: a sinistra/destra serve di piu'
    // per non finire sopra l'icona e sulla "x" per chiudere; sopra/sotto
    // invece va tenuto stretto per sfruttare meglio l'altezza della scheda.
    public float PercentualeStaccoOrizzontale = 0.34f;
    public float PercentualeStaccoVerticale = 0.06f;

    public int PuntoBiancoSchede = 190;    // vivacita' delle scritte/icone nella striscia delle schede (sfondo intoccato)
    public int PuntoBiancoToolbar = 190;   // vivacita' delle scritte/icone nella barra degli strumenti (sfondo intoccato)
    public int SogliaSfondoSchede = 90;    // sotto questo grigio, nella striscia schede, non si tocca nulla
    public int SogliaSfondoToolbar = 90;   // sotto questo grigio, nella barra strumenti, non si tocca nulla
    public float SpessoreLinea = 0.1f;

    // schedaAttiva: per il bagliore. zonaSchede/zonaStrumenti: le fasce
    // da schiarire (possono mancare se Chrome non le espone in quel
    // momento -- in quel caso semplicemente non si tocca quella fascia).
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
$nomeProcesso = "chrome"   # deve essere ESATTAMENTE Google Chrome, non un altro programma con la stessa etichetta
# ==============================================================

$cartellaMia = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$percorsoImpostazioni = Join-Path $cartellaMia "impostazioni-bagliore.json"

# Auto-installazione / self-install:
# Al primissimo avvio, se non esiste ancora un collegamento nella cartella
# di avvio automatico di Windows, lo creiamo da soli -- cosi' chiunque
# scarichi questo script (non solo su questo PC) lo fa partire una volta e
# da quel momento riparte da solo ad ogni accensione, senza nessuna
# manovra manuale ne' diritti da amministratore.
#
# On the very first run, if a shortcut doesn't already exist in Windows'
# Startup folder, we create it ourselves -- so anyone who downloads this
# script (on any PC, not just this one) runs it once and from then on it
# starts by itself at every login, with no manual step and no admin
# rights needed. To remove this, run ferma-bagliore.ps1 (stop-glow.ps1).
try {
    $cartellaAvvio = [Environment]::GetFolderPath('Startup')
    $percorsoLauncher = Join-Path $cartellaAvvio "AvviaMotoreContrastoChrome.vbs"
    if (-not (Test-Path $percorsoLauncher)) {
        $percorsoMotore = Join-Path $cartellaMia "motore-contrasto.ps1"
        $contenutoVbs = 'Set objShell = CreateObject("WScript.Shell")' + "`r`n" +
            'objShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""' + $percorsoMotore + '""", 0, False' + "`r`n"
        Set-Content -Path $percorsoLauncher -Value $contenutoVbs -Encoding ASCII -NoNewline
    }
} catch { }

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

# Cerchiamo subito una finestra Chrome visibile, cosi' il bagliore
# funziona dal primo istante anche se non hai ancora cliccato su Chrome.
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

        # Il bagliore resta acceso sull'ultima finestra Chrome vista anche
        # se ora il focus e' su un'altra applicazione (pannello di
        # regolazione compreso): si spegne solo se quella finestra Chrome
        # non esiste piu' o e' minimizzata.
        $hwndDaUsare = $script:hwndChromeUltima

        if ($hwndDaUsare -ne [IntPtr]::Zero -and [Win32]::IsWindow($hwndDaUsare) -and -not [Win32]::IsIconic($hwndDaUsare)) {
            $scheda = [ElementiChrome]::SchedaAttiva($hwndDaUsare)
            if ($scheda -and [Win32]::ChromeEDavveroVisibileInTutto([int]$scheda.X, [int]$scheda.Y, [int]$scheda.Width, [int]$scheda.Height, $nomeProcesso)) {
                # La scheda attiva e' davvero visibile: controlliamo anche
                # le altre due fasce UNA PER UNA (su tutta la loro area, non
                # solo il centro), perche' un'altra finestra potrebbe
                # coprirne solo una parte -- es. solo meta' della barra
                # strumenti, che e' molto piu' larga della scheda.
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
                # La scheda attiva stessa non e' visibile (qualcosa, es.
                # Claude Code, e' stato trascinato sopra): spegni tutto.
                if ($traccia) { "  -> NASCONDO (scheda nulla o coperta)" | Out-File -Append -FilePath "$env:TEMP\debug-bagliore.log" }
                $bagliore.NascondiSeVisibile()
            }
        } else {
            $bagliore.NascondiSeVisibile()
        }
    } catch {
        "$(Get-Date -Format 'HH:mm:ss.fff') $($_.Exception.GetType().FullName): $($_.Exception.Message)`n$($_.Exception.StackTrace)" | Out-File -Append -FilePath "$env:TEMP\debug-bagliore.log"
        $bagliore.NascondiSeVisibile()
    }
})

$timer.Start()

# Nessun pannello qui: gira in silenzio finche' non lo fermi tu (o finche'
# non lo ferma il pannello di regolazione per farti vedere le modifiche
# dal vivo). Application.Run() senza una form tiene viva la coda messaggi
# di cui il timer e la finestra del bagliore hanno bisogno.
[System.Windows.Forms.Application]::Run()
