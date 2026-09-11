Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
#  Kenzie's Tweaks - Modern PowerShell GUI
#  Requires: Run as Administrator for power plan changes
# ============================================================

# ---------- Admin Check ----------
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ---------- Enable Visual Styles ----------
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ---------- Modern Color Palette ----------
$script:Colors = @{
    Background   = [System.Drawing.Color]::FromArgb(15, 18, 24)
    Surface      = [System.Drawing.Color]::FromArgb(24, 30, 40)
    SurfaceAlt   = [System.Drawing.Color]::FromArgb(32, 40, 54)
    Accent       = [System.Drawing.Color]::FromArgb(0, 150, 255)
    AccentGlow   = [System.Drawing.Color]::FromArgb(0, 200, 255)
    AccentHover  = [System.Drawing.Color]::FromArgb(40, 170, 255)
    Text         = [System.Drawing.Color]::FromArgb(235, 240, 248)
    TextDim      = [System.Drawing.Color]::FromArgb(150, 170, 195)
    Success      = [System.Drawing.Color]::FromArgb(0, 220, 140)
    Warning      = [System.Drawing.Color]::FromArgb(255, 190, 60)
    Danger       = [System.Drawing.Color]::FromArgb(255, 90, 100)
    Border       = [System.Drawing.Color]::FromArgb(50, 65, 90)
}

# ============================================================
#  POWER PLAN PRESETS
# ============================================================
$script:PowerPlans = @(
    @{
        Name = "Kenzie's Custom Plan"
        Guid = "b7701089-9d55-49a7-90ec-f6be3a3566a9"
        Desc = "PS1 Custom Ultra Performance"
        Icon = "⚡"
    },
    @{
        Name = "Ultimate Performance"
        Guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        Desc = "Maximum performance (hidden by default)"
        Icon = "🔥"
    },
    @{
        Name = "High Performance"
        Guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        Desc = "Standard high performance plan"
        Icon = "🚀"
    },
    @{
        Name = "Balanced"
        Guid = "381b4222-f694-41f0-9685-ff5bb260df2e"
        Desc = "Balanced performance & power"
        Icon = "⚖️"
    },
    @{
        Name = "Power Saver"
        Guid = "a1841308-3541-4fab-bc81-f71556f20b4a"
        Desc = "Reduce power consumption"
        Icon = "🔋"
    }
)

# ============================================================
#  HELPER: Rounded Rectangle Path
# ============================================================
function New-RoundedPath {
    param(
        [int]$x, [int]$y, [int]$w, [int]$h, [int]$r
    )
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $r, $r, 180, 90)
    $path.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
    $path.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90)
    $path.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
    $path.CloseFigure()
    return $path
}

# ============================================================
#  CUSTOM MODERN BUTTON CLASS
# ============================================================
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class ModernButton : Button
{
    public Color NormalColor { get; set; } = Color.FromArgb(32, 40, 54);
    public Color HoverColor { get; set; } = Color.FromArgb(45, 60, 85);
    public Color AccentColor { get; set; } = Color.FromArgb(0, 150, 255);
    public Color TextColor { get; set; } = Color.FromArgb(235, 240, 248);
    public int CornerRadius { get; set; } = 14;
    public bool IsActive { get; set; } = false;

    private bool _hover = false;
    private float _glow = 0f;
    private Timer _timer;

    public ModernButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        ForeColor = TextColor;
        Font = new Font("Segoe UI Semibold", 10f, FontStyle.Bold);
        Cursor = Cursors.Hand;
        _timer = new Timer { Interval = 30 };
        _timer.Tick += (s, e) => {
            float target = _hover ? 1f : 0f;
            _glow += (target - _glow) * 0.25f;
            if (Math.Abs(_glow - target) < 0.01f) _glow = target;
            Invalidate();
        };
        _timer.Start();
    }

    protected override void OnMouseEnter(EventArgs e) { _hover = true; base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { _hover = false; base.OnMouseLeave(e); }

    protected override void OnPaint(PaintEventArgs pevent)
    {
        var g = pevent.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        var rect = new Rectangle(0, 0, Width - 1, Height - 1);
        using (var path = GetRoundedPath(rect, CornerRadius))
        {
            Color fill;
            if (IsActive)
                fill = BlendColors(AccentColor, NormalColor, 0.45f);
            else
                fill = BlendColors(NormalColor, HoverColor, _glow);

            using (var brush = new SolidBrush(fill))
                g.FillPath(brush, path);

            // Glow border
            Color borderCol = IsActive
                ? AccentColor
                : BlendColors(Color.FromArgb(50, 65, 90), AccentColor, _glow * 0.7f);
            using (var pen = new Pen(borderCol, IsActive ? 2f : 1.2f))
                g.DrawPath(pen, path);
        }

        // Text
        TextRenderer.DrawText(g, Text, Font, rect, TextColor,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
    }

    private GraphicsPath GetRoundedPath(Rectangle r, int radius)
    {
        var path = new GraphicsPath();
        int d = radius * 2;
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    private Color BlendColors(Color a, Color b, float t)
    {
        t = Math.Max(0, Math.Min(1, t));
        return Color.FromArgb(
            (int)(a.A + (b.A - a.A) * t),
            (int)(a.R + (b.R - a.R) * t),
            (int)(a.G + (b.G - a.G) * t),
            (int)(a.B + (b.B - a.B) * t));
    }
}
"@

# ============================================================
#  MAIN FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Kenzie's Tweaks"
$form.Size = New-Object System.Drawing.Size(820, 640)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Colors.Background
$form.ForeColor = $Colors.Text
$form.FormBorderStyle = "None"
$form.MaximizeBox = $false
$form.DoubleBuffered = $true

# Custom title bar (drag + close)
$script:dragging = $false
$script:dragOffset = New-Object System.Drawing.Point(0, 0)

$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Size = New-Object System.Drawing.Size($form.Width, 46)
$titleBar.Location = New-Object System.Drawing.Point(0, 0)
$titleBar.BackColor = $Colors.Background
$form.Controls.Add($titleBar)

$titleBar.Add_MouseDown({
    param($s, $e)
    $script:dragging = $true
    $script:dragOffset = $e.Location
})
$titleBar.Add_MouseMove({
    param($s, $e)
    if ($script:dragging) {
        $form.Location = New-Object System.Drawing.Point(
            ($form.Location.X + $e.X - $script:dragOffset.X),
            ($form.Location.Y + $e.Y - $script:dragOffset.Y))
    }
})
$titleBar.Add_MouseUp({ $script:dragging = $false })

# Close button (X)
$btnClose = New-Object System.Windows.Forms.Label
$btnClose.Text = "✕"
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$btnClose.ForeColor = $Colors.TextDim
$btnClose.BackColor = $Colors.Background
$btnClose.Size = New-Object System.Drawing.Size(46, 46)
$btnClose.Location = New-Object System.Drawing.Point(($form.Width - 46), 0)
$btnClose.TextAlign = "MiddleCenter"
$btnClose.Cursor = "Hand"
$btnClose.Add_MouseEnter({ $btnClose.ForeColor = $Colors.Danger; $btnClose.BackColor = $Colors.Surface })
$btnClose.Add_MouseLeave({ $btnClose.ForeColor = $Colors.TextDim; $btnClose.BackColor = $Colors.Background })
$btnClose.Add_Click({ $form.Close() })
$titleBar.Controls.Add($btnClose)

# Minimize button
$btnMin = New-Object System.Windows.Forms.Label
$btnMin.Text = "—"
$btnMin.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$btnMin.ForeColor = $Colors.TextDim
$btnMin.BackColor = $Colors.Background
$btnMin.Size = New-Object System.Drawing.Size(46, 46)
$btnMin.Location = New-Object System.Drawing.Point(($form.Width - 92), 0)
$btnMin.TextAlign = "MiddleCenter"
$btnMin.Cursor = "Hand"
$btnMin.Add_MouseEnter({ $btnMin.ForeColor = $Colors.AccentGlow; $btnMin.BackColor = $Colors.Surface })
$btnMin.Add_MouseLeave({ $btnMin.ForeColor = $Colors.TextDim; $btnMin.BackColor = $Colors.Background })
$btnMin.Add_Click({ $form.WindowState = "Minimized" })
$titleBar.Controls.Add($btnMin)

# ============================================================
#  LOADING PANEL (animated splash)
# ============================================================
$loadingPanel = New-Object System.Windows.Forms.Panel
$loadingPanel.Size = New-Object System.Drawing.Size($form.Width, $form.Height)
$loadingPanel.Location = New-Object System.Drawing.Point(0, 0)
$loadingPanel.BackColor = $Colors.Background
$form.Controls.Add($loadingPanel)
$loadingPanel.BringToFront()

$loadingLogo = New-Object System.Windows.Forms.Label
$loadingLogo.Text = "⚡ Kenzie's Tweaks"
$loadingLogo.Font = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
$loadingLogo.ForeColor = $Colors.AccentGlow
$loadingLogo.AutoSize = $true
$loadingLogo.Location = New-Object System.Drawing.Point(240, 240)
$loadingPanel.Controls.Add($loadingLogo)

$loadingStatus = New-Object System.Windows.Forms.Label
$loadingStatus.Text = "Initializing..."
$loadingStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$loadingStatus.ForeColor = $Colors.TextDim
$loadingStatus.AutoSize = $true
$loadingStatus.Location = New-Object System.Drawing.Point(330, 320)
$loadingPanel.Controls.Add($loadingStatus)

# Progress bar (custom drawn)
$progressBar = New-Object System.Windows.Forms.Panel
$progressBar.Size = New-Object System.Drawing.Size(400, 6)
$progressBar.Location = New-Object System.Drawing.Point(200, 370)
$progressBar.BackColor = $Colors.Surface
$loadingPanel.Controls.Add($progressBar)

$progressFill = New-Object System.Windows.Forms.Panel
$progressFill.Size = New-Object System.Drawing.Size(0, 6)
$progressFill.Location = New-Object System.Drawing.Point(0, 0)
$progressFill.BackColor = $Colors.Accent
$progressBar.Controls.Add($progressFill)

# Animated loading sequence
$script:loadingSteps = @(
    "Initializing Kenzie's Tweaks...",
    "Checking administrator privileges...",
    "Loading power plan configurations...",
    "Applying modern UI theme...",
    "Ready."
)
$script:currentStep = 0
$script:progressValue = 0

$loadingTimer = New-Object System.Windows.Forms.Timer
$loadingTimer.Interval = 30
$loadingTimer.Add_Tick({
    $script:progressValue += 2.5
    if ($script:progressValue -gt 100) { $script:progressValue = 100 }

    $progressFill.Width = [int](400 * ($script:progressValue / 100))

    $stepIndex = [Math]::Min([int]($script:progressValue / 20), $script:loadingSteps.Count - 1)
    $loadingStatus.Text = $script:loadingSteps[$stepIndex]

    if ($script:progressValue -ge 100) {
        $loadingTimer.Stop()
        Start-Sleep -Milliseconds 300
        $loadingPanel.Visible = $false
        $loadingPanel.SendToBack()
        Show-MainUI
    }
})
$loadingTimer.Start()

# ============================================================
#  MAIN UI CONTENT PANEL
# ============================================================
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Size = New-Object System.Drawing.Size($form.Width, ($form.Height - 46))
$mainPanel.Location = New-Object System.Drawing.Point(0, 46)
$mainPanel.BackColor = $Colors.Background
$mainPanel.Visible = $false
$form.Controls.Add($mainPanel)

function Show-MainUI {
    $mainPanel.Visible = $true
    $mainPanel.BringToFront()
    $titleBar.BringToFront()
    $btnClose.BringToFront()
    $btnMin.BringToFront()
}

# ---------- HEADER ----------
$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Text = "Kenzie's Tweaks"
$headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$headerLabel.ForeColor = $Colors.Text
$headerLabel.AutoSize = $true
$headerLabel.Location = New-Object System.Drawing.Point(30, 15)
$mainPanel.Controls.Add($headerLabel)

$subHeader = New-Object System.Windows.Forms.Label
$subHeader.Text = "Power Plan Manager · Performance Tweaks"
$subHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$subHeader.ForeColor = $Colors.TextDim
$subHeader.AutoSize = $true
$subHeader.Location = New-Object System.Drawing.Point(33, 58)
$mainPanel.Controls.Add($subHeader)

# Admin badge
$adminBadge = New-Object System.Windows.Forms.Label
if ($isAdmin) {
    $adminBadge.Text = "  ● ADMIN  "
    $adminBadge.ForeColor = $Colors.Success
} else {
    $adminBadge.Text = "  ● NO ADMIN  "
    $adminBadge.ForeColor = $Colors.Warning
}
$adminBadge.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5, [System.Drawing.FontStyle]::Bold)
$adminBadge.BackColor = $Colors.Surface
$adminBadge.AutoSize = $true
$adminBadge.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
$adminBadge.Location = New-Object System.Drawing.Point(650, 25)
$mainPanel.Controls.Add($adminBadge)

# ---------- SEPARATOR ----------
$sep = New-Object System.Windows.Forms.Panel
$sep.Size = New-Object System.Drawing.Size(760, 1)
$sep.Location = New-Object System.Drawing.Point(30, 95)
$sep.BackColor = $Colors.Border
$mainPanel.Controls.Add($sep)

# ---------- CURRENT PLAN DISPLAY ----------
$currentPlanCard = New-Object System.Windows.Forms.Panel
$currentPlanCard.Size = New-Object System.Drawing.Size(760, 85)
$currentPlanCard.Location = New-Object System.Drawing.Point(30, 115)
$currentPlanCard.BackColor = $Colors.Surface
$mainPanel.Controls.Add($currentPlanCard)

$currentPlanIcon = New-Object System.Windows.Forms.Label
$currentPlanIcon.Text = "⚡"
$currentPlanIcon.Font = New-Object System.Drawing.Font("Segoe UI", 30)
$currentPlanIcon.ForeColor = $Colors.AccentGlow
$currentPlanIcon.AutoSize = $true
$currentPlanIcon.Location = New-Object System.Drawing.Point(20, 15)
$currentPlanCard.Controls.Add($currentPlanIcon)

$currentPlanLabel = New-Object System.Windows.Forms.Label
$currentPlanLabel.Text = "ACTIVE POWER PLAN"
$currentPlanLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$currentPlanLabel.ForeColor = $Colors.TextDim
$currentPlanLabel.AutoSize = $true
$currentPlanLabel.Location = New-Object System.Drawing.Point(85, 15)
$currentPlanCard.Controls.Add($currentPlanLabel)

$currentPlanName = New-Object System.Windows.Forms.Label
$currentPlanName.Text = "Detecting..."
$currentPlanName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
$currentPlanName.ForeColor = $Colors.Text
$currentPlanName.AutoSize = $true
$currentPlanName.Location = New-Object System.Drawing.Point(85, 35)
$currentPlanCard.Controls.Add($currentPlanName)

$currentPlanGuid = New-Object System.Windows.Forms.Label
$currentPlanGuid.Text = ""
$currentPlanGuid.Font = New-Object System.Drawing.Font("Consolas", 8)
$currentPlanGuid.ForeColor = $Colors.TextDim
$currentPlanGuid.AutoSize = $true
$currentPlanGuid.Location = New-Object System.Drawing.Point(85, 62)
$currentPlanCard.Controls.Add($currentPlanGuid)

# ---------- SECTION LABEL ----------
$plansLabel = New-Object System.Windows.Forms.Label
$plansLabel.Text = "AVAILABLE POWER PLANS"
$plansLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
$plansLabel.ForeColor = $Colors.TextDim
$plansLabel.AutoSize = $true
$plansLabel.Location = New-Object System.Drawing.Point(33, 220)
$mainPanel.Controls.Add($plansLabel)

# ---------- POWER PLAN BUTTONS ----------
$script:planButtons = @{}
$yPos = 250

foreach ($plan in $PowerPlans) {
    $btn = New-Object ModernButton
    $btn.Text = "$($plan.Icon)  $($plan.Name)"
    $btn.Size = New-Object System.Drawing.Size(240, 62)
    $btn.Location = New-Object System.Drawing.Point(30, $yPos)
    $btn.NormalColor = $Colors.Surface
    $btn.HoverColor = $Colors.SurfaceAlt
    $btn.AccentColor = $Colors.Accent
    $btn.TextColor = $Colors.Text
    $btn.Tag = $plan.Guid

    $btn.Add_Click({
        param($s, $e)
        $guid = $s.Tag
        Apply-PowerPlan -Guid $guid -Button $s
    })

    $mainPanel.Controls.Add($btn)
    $script:planButtons[$plan.Guid] = $btn

    $yPos += 72
}

# ---------- STATUS / TOAST MESSAGE ----------
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = $Colors.Success
$statusLabel.AutoSize = $false
$statusLabel.Size = New-Object System.Drawing.Size(760, 30)
$statusLabel.Location = New-Object System.Drawing.Point(30, 555)
$statusLabel.TextAlign = "MiddleCenter"
$mainPanel.Controls.Add($statusLabel)

# ============================================================
#  POWER PLAN FUNCTIONS
# ============================================================
function Get-ActivePowerPlanGuid {
    try {
        $output = powercfg /getactivescheme 2>$null
        if ($output -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
            return $matches[1].ToLower()
        }
    } catch { }
    return $null
}

function Update-CurrentPlanDisplay {
    $activeGuid = Get-ActivePowerPlanGuid
    if ($activeGuid) {
        $activePlan = $PowerPlans | Where-Object { $_.Guid -eq $activeGuid } | Select-Object -First 1
        if ($activePlan) {
            $currentPlanName.Text = $activePlan.Name
            $currentPlanGuid.Text = "GUID: $($activePlan.Guid)"
            $currentPlanIcon.Text = $activePlan.Icon
        } else {
            $currentPlanName.Text = "Custom Plan"
            $currentPlanGuid.Text = "GUID: $activeGuid"
            $currentPlanIcon.Text = "🔧"
        }

        # Highlight active button
        foreach ($key in $script:planButtons.Keys) {
            $script:planButtons[$key].IsActive = ($key -eq $activeGuid)
            $script:planButtons[$key].Invalidate()
        }
    }
}

function Show-Status {
    param([string]$Message, [string]$Type = "Success")

    $color = switch ($Type) {
        "Success" { $Colors.Success }
        "Error"   { $Colors.Danger }
        "Warning" { $Colors.Warning }
        default   { $Colors.Text }
    }

    $statusLabel.ForeColor = $color
    $statusLabel.Text = $Message

    # Auto-clear after 4 seconds
    $clearTimer = New-Object System.Windows.Forms.Timer
    $clearTimer.Interval = 4000
    $clearTimer.Add_Tick({
        $statusLabel.Text = ""
        $clearTimer.Stop()
        $clearTimer.Dispose()
    })
    $clearTimer.Start()
}

function Apply-PowerPlan {
    param([string]$Guid, [object]$Button)

    if (-not $isAdmin) {
        Show-Status "⚠ Administrator privileges required to change power plan" "Error"
        return
    }

    # Show loading state on button
    $originalText = $Button.Text
    $Button.Text = "⏳  Applying..."
    $Button.Enabled = $false
    [System.Windows.Forms.Application]::DoEvents()

    try {
        # First, ensure plan exists (duplicate from Ultimate if needed)
        $check = powercfg /list 2>$null | Select-String $Guid
        if (-not $check) {
            # Try to duplicate Ultimate Performance as base if available
            $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            $dupResult = powercfg -duplicatescheme $ultimateGuid $Guid 2>&1
            if ($LASTEXITCODE -ne 0) {
                # If that fails, just try to duplicate balanced
                $balGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
                powercfg -duplicatescheme $balGuid $Guid 2>&1 | Out-Null
            }
            Start-Sleep -Milliseconds 200
        }

        # Apply the plan
        $result = powercfg /setactive $Guid 2>&1

        if ($LASTEXITCODE -eq 0) {
            Show-Status "✓ Power plan applied successfully" "Success"
            Start-Sleep -Milliseconds 150
            Update-CurrentPlanDisplay
        } else {
            Show-Status "✗ Failed to apply power plan: $result" "Error"
        }
    } catch {
        Show-Status "✗ Error: $($_.Exception.Message)" "Error"
    } finally {
        $Button.Text = $originalText
        $Button.Enabled = $true
        $Button.Invalidate()
    }
}

# ============================================================
#  FORM EVENTS
# ============================================================
$form.Add_Shown({
    # Wait for loading to complete, then init
    while ($loadingPanel.Visible) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 50
    }
    Update-CurrentPlanDisplay
    $form.Activate()
})

$form.Add_FormClosing({
    # Cleanup
    if ($loadingTimer) { $loadingTimer.Stop(); $loadingTimer.Dispose() }
})

# ============================================================
#  RUN
# ============================================================
[void]$form.ShowDialog()
