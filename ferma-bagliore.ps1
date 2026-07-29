# DISINSTALLAZIONE COMPLETA / FULL UNINSTALL
# --------------------------------------------
# IT: Ferma il motore "scheda accesa" e (se aperto) il pannello di
# regolazione, e toglie l'avvio automatico creato al primo avvio. Dopo
# averlo eseguito, Chrome torna esattamente come prima: non serve nessun
# altro passaggio, l'effetto era solo una finestra sopra lo schermo, non
# ha mai toccato Chrome stesso. Per riattivarlo, fai doppio clic su
# "AVVIA regolazione Chrome.cmd" -- ripartira' e si reinstallera' da solo.
#
# EN: Stops the "active tab glow" engine and (if open) the tuning panel,
# and removes the automatic startup that was created on first run. After
# running this, Chrome goes back to exactly how it was before: nothing
# else needed, the effect was only a window drawn on top of the screen,
# it never touched Chrome itself. To turn it back on, double-click
# "AVVIA regolazione Chrome.cmd" -- it will start again and reinstall
# itself automatically.

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'motore-contrasto\.ps1|regola-bagliore\.ps1' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$percorsoLauncher = Join-Path ([Environment]::GetFolderPath('Startup')) "AvviaMotoreContrastoChrome.vbs"
if (Test-Path $percorsoLauncher) {
    Remove-Item $percorsoLauncher -Force -ErrorAction SilentlyContinue
}

Write-Host "[IT] Fermato e disinstallato: non partira' piu' da solo al prossimo accesso."
Write-Host "[EN] Stopped and uninstalled: it will no longer start automatically at next login."
