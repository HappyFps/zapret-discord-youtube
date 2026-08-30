Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$serviceName = 'zapret'
$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Zapret Tray.lnk'
$launcherPath = Join-Path $PSScriptRoot 'Start-ZapretTray.vbs'

function Get-ServiceState {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($null -eq $service) { return 'NotInstalled' }
    return $service.Status.ToString()
}

function Test-Autostart {
    return Test-Path -LiteralPath $startupShortcut
}

function Set-Autostart([bool] $enabled) {
    if ($enabled) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupShortcut)
        $shortcut.TargetPath = "$env:WINDIR\System32\wscript.exe"
        $shortcut.Arguments = '"' + $launcherPath + '"'
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.Description = 'Zapret Tray'
        $shortcut.Save()
    } elseif (Test-Path -LiteralPath $startupShortcut) {
        Remove-Item -LiteralPath $startupShortcut -Force
    }
}

function Invoke-ElevatedServiceAction([ValidateSet('Start', 'Stop')] $action) {
    $verb = if ($action -eq 'Start') { 'Start-Service' } else { 'Stop-Service' }
    $command = "$verb -Name '$serviceName'"
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-Command', $command) -Verb RunAs -Wait
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not $($action.ToLower()) the zapret service. Approve the administrator prompt and retry.", 'Zapret Tray', 'OK', 'Warning') | Out-Null
    }
    Update-Ui
}

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$statusItem = $menu.Items.Add('Checking status...')
$statusItem.Enabled = $false
$menu.Items.Add('-') | Out-Null
$toggleItem = $menu.Items.Add('Toggle')
$startItem = $menu.Items.Add('Start zapret')
$stopItem = $menu.Items.Add('Stop zapret')
$autostartItem = New-Object System.Windows.Forms.ToolStripMenuItem('Start with Windows')
$autostartItem.CheckOnClick = $true
$menu.Items.Add($autostartItem) | Out-Null
$menu.Items.Add('-') | Out-Null
$exitItem = $menu.Items.Add('Exit')

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.ContextMenuStrip = $menu
$tray.Icon = [System.Drawing.SystemIcons]::Shield
$tray.Visible = $true

function Update-Ui {
    $state = Get-ServiceState
    $running = $state -eq 'Running'
    $label = switch ($state) {
        'Running' { 'zapret is running' }
        'Stopped' { 'zapret is stopped' }
        'NotInstalled' { 'zapret service is not installed' }
        default { "zapret: $state" }
    }
    $tray.Text = "Zapret Tray - $label"
    $statusItem.Text = "Status: $label"
    $toggleItem.Enabled = $state -in @('Running', 'Stopped')
    $startItem.Enabled = $state -eq 'Stopped'
    $stopItem.Enabled = $state -eq 'Running'
    $autostartItem.Checked = Test-Autostart
}

$toggleItem.add_Click({ if ((Get-ServiceState) -eq 'Running') { Invoke-ElevatedServiceAction Stop } else { Invoke-ElevatedServiceAction Start } })
$startItem.add_Click({ Invoke-ElevatedServiceAction Start })
$stopItem.add_Click({ Invoke-ElevatedServiceAction Stop })
$autostartItem.add_Click({ Set-Autostart $autostartItem.Checked })
$tray.add_MouseClick({ param($sender, $event) if ($event.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $menu.Show([System.Windows.Forms.Cursor]::Position) } })
$exitItem.add_Click({ $tray.Visible = $false; $tray.Dispose(); [System.Windows.Forms.Application]::Exit() })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.add_Tick({ Update-Ui })

Update-Ui
$timer.Start()
[System.Windows.Forms.Application]::Run()

