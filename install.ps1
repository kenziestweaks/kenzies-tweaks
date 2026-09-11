#Requires -Version 5.1
<#
    Kenzie's Tweaks - Modern PowerShell GUI
    Fully compatible with Windows PowerShell 5.1 and PowerShell 7+
#>

# ============================================================
#  AUTO-ELEVATE
# ============================================================
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://raw.githubusercontent.com/kenziestweaks/kenzies-tweaks/main/install.ps1?v=$([DateTime]::Now.Ticks)' | iex`""
        $psi.Verb = "runas"
        [void][System.Diagnostics.Process]::Start($psi)
        exit
    } catch { }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ============================================================
#  COLORS
# ============================================================
$script:C = @{
    Bg        = [System.Drawing.Color]::FromArgb(10, 12, 18)
    BgAlt     = [System.Drawing.Color]::FromArgb(15, 18, 26)
    Surface   = [System.Drawing.Color]::FromArgb(22, 28, 40)
    SurfaceHi = [System.Drawing.Color]::FromArgb(32, 40, 56)
    Border    = [System.Drawing.Color]::FromArgb(45, 58, 80)
    Accent    = [System.Drawing.Color]::FromArgb(0, 160, 255)
    Glow      = [System.Drawing.Color]::FromArgb(0, 200, 255)
    Text      = [System.Drawing.Color]::FromArgb(240, 245, 252)
    TextDim   = [System.Drawing.Color]::FromArgb(140, 160, 185)
    Success   = [System.Drawing.Color]::FromArgb(60, 220, 150)
    Warning   = [System.Drawing.Color]::FromArgb(255, 190, 70)
    Danger    = [System.Drawing.Color]::FromArgb(255, 90, 110)
}

# ============================================================
#  POWER PLANS
# ============================================================
$script:PowerPlans = @(
    @{ Name = "Kenzie's Custom";      Guid = "b7701089-9d55-49a7-90ec-f6be3a3566a9"; Icon = "[K]" }
    @{ Name = "Ultimate Performance"; Guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"; Icon = "[U]" }
    @{ Name = "High Performance";     Guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; Icon = "[H]" }
    @{ Name = "Balanced";             Guid = "381b4222-f694-41f0-9685-ff5bb260df2e"; Icon = "[B]" }
    @{ Name = "Power Saver";          Guid = "a1841308-3541-4fab-bc81-f71556f20b4a"; Icon = "[P]" }
)

# ============================================================
#  COMPILED C# CONTROLS (PS 5.1 safe)
# ============================================================
if (-not ("KenzieUI.ModernButton" -as [type])) {
    $cs = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace KenzieUI
{
    public class GlowPanel : Panel
    {
        private int _radius;
        private Color _borderColor;
        private Color _fillColor;
        private float _glowAmt;
        private Timer _timer;

        public int Radius {
            get { return _radius; }
            set { _radius = value; Invalidate(); }
        }
        public Color BorderColor {
            get { return _borderColor; }
            set { _borderColor = value; Invalidate(); }
        }
        public Color FillColor {
            get { return _fillColor; }
            set { _fillColor = value; Invalidate(); }
        }

        public GlowPanel()
        {
            _radius = 18;
            _borderColor = Color.FromArgb(45, 58, 80);
            _fillColor = Color.FromArgb(22, 28, 40);
            _glowAmt = 0f;

            SetStyle(ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer |
                     ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;

            _timer = new Timer();
            _timer.Interval = 30;
            _timer.Tick += new EventHandler(OnGlowTick);
            _timer.Start();
        }

        private void OnGlowTick(object sender, EventArgs e)
        {
            float target = ClientRectangle.Contains(PointToClient(Cursor.Position)) ? 1f : 0f;
            _glowAmt += (target - _glowAmt) * 0.15f;
            if (Math.Abs(_glowAmt - target) < 0.01f) _glowAmt = target;
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);

            GraphicsPath path = MakeRounded(r, _radius);
            try
            {
                using (SolidBrush b = new SolidBrush(_fillColor))
                    g.FillPath(b, path);

                Color bc = Blend(_borderColor, Color.FromArgb(0, 180, 255), _glowAmt);
                float th = 1f + _glowAmt;
                using (Pen p = new Pen(bc, th))
                    g.DrawPath(p, path);
            }
            finally { path.Dispose(); }
        }

        public static GraphicsPath MakeRounded(Rectangle r, int radius)
        {
            GraphicsPath path = new GraphicsPath();
            int d = radius * 2;
            if (d > r.Width) d = r.Width;
            if (d > r.Height) d = r.Height;
            path.AddArc(r.X, r.Y, d, d, 180, 90);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        public static Color Blend(Color a, Color b, float t)
        {
            if (t < 0) t = 0;
            if (t > 1) t = 1;
            return Color.FromArgb(
                (int)(a.A + (b.A - a.A) * t),
                (int)(a.R + (b.R - a.R) * t),
                (int)(a.G + (b.G - a.G) * t),
                (int)(a.B + (b.B - a.B) * t));
        }
    }

    public class ModernButton : Button
    {
        private Color _normalColor;
        private Color _hoverColor;
        private Color _accentColor;
        private Color _textColor;
        private int _cornerRadius;
        private bool _isActive;
        private bool _hover;
        private float _glow;
        private Timer _timer;

        public Color NormalColor {
            get { return _normalColor; }
            set { _normalColor = value; Invalidate(); }
        }
        public Color HoverColor {
            get { return _hoverColor; }
            set { _hoverColor = value; Invalidate(); }
        }
        public Color AccentColor {
            get { return _accentColor; }
            set { _accentColor = value; Invalidate(); }
        }
        public Color TextColor {
            get { return _textColor; }
            set { _textColor = value; Invalidate(); }
        }
        public int CornerRadius {
            get { return _cornerRadius; }
            set { _cornerRadius = value; Invalidate(); }
        }
        public bool IsActive {
            get { return _isActive; }
            set { _isActive = value; Invalidate(); }
        }

        public ModernButton()
        {
            _normalColor = Color.FromArgb(26, 32, 46);
            _hoverColor = Color.FromArgb(40, 52, 74);
            _accentColor = Color.FromArgb(0, 160, 255);
            _textColor = Color.FromArgb(240, 245, 252);
            _cornerRadius = 14;
            _isActive = false;
            _hover = false;
            _glow = 0f;

            SetStyle(ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer |
                     ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            ForeColor = _textColor;
            Font = new Font("Segoe UI Semibold", 10f, FontStyle.Bold);
            Cursor = Cursors.Hand;

            _timer = new Timer();
            _timer.Interval = 25;
            _timer.Tick += new EventHandler(OnTick);
            _timer.Start();
        }

        private void OnTick(object sender, EventArgs e)
        {
            float target = _hover ? 1f : 0f;
            _glow += (target - _glow) * 0.22f;
            if (Math.Abs(_glow - target) < 0.01f) _glow = target;
            Invalidate();
        }

        protected override void OnMouseEnter(EventArgs e) { _hover = true; base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = false; base.OnMouseLeave(e); }

        protected override void OnPaint(PaintEventArgs pevent)
        {
            Graphics g = pevent.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle rect = new Rectangle(0, 0, Width - 1, Height - 1);

            GraphicsPath path = GlowPanel.MakeRounded(rect, _cornerRadius);
            try
            {
                Color fill;
                if (_isActive)
                    fill = GlowPanel.Blend(_accentColor, _normalColor, 0.40f);
                else
                    fill = GlowPanel.Blend(_normalColor, _hoverColor, _glow);

                using (SolidBrush brush = new SolidBrush(fill))
                    g.FillPath(brush, path);

                Color borderCol = _isActive
                    ? _accentColor
                    : GlowPanel.Blend(Color.FromArgb(45, 58, 80), _accentColor, _glow * 0.8f);
                using (Pen pen = new Pen(borderCol, _isActive ? 2f : 1.2f))
                    g.DrawPath(pen, path);

                if (_isActive)
                {
                    Color glowCol = Color.FromArgb(60, _accentColor);
                    using (Pen glowPen = new Pen(glowCol, 6f))
                        g.DrawPath(glowPen, path);
                }
            }
            finally { path.Dispose(); }

            TextRenderer.DrawText(g, Text, Font, rect, _textColor,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }
}
"@
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $cs -Language CSharp
}

# ============================================================
#  HELPERS
# ============================================================
function Set-DoubleBuffer {
    param([System.Windows.Forms.Control]$Control)
    try {
        $prop = [System.Windows.Forms.Control].GetProperty(
            "DoubleBuffered",
            [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
        if ($prop) { $prop.SetValue($Control, $true, $null) }
    } catch { }
}

function Get-ActivePlanGuid {
    try {
        $out = powercfg /getactivescheme 2>$null
        if ($out -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
            return $matches[1].ToLower()
        }
    } catch { }
    return $null
}

# ============================================================
#  MAIN FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Kenzie's Tweaks"
$form.Size = New-Object System.Drawing.Size(960, 640)
$form.StartPosition = "CenterScreen"
$form.BackColor = $C.Bg
$form.ForeColor = $C.Text
$form.FormBorderStyle = "None"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
Set-DoubleBuffer $form

$form.Add_Resize({
    $r = 20
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc(0, 0, $r * 2, $r * 2, 180, 90)
    $p.AddArc($form.Width - $r * 2, 0, $r * 2, $r * 2, 270, 90)
    $p.AddArc($form.Width - $r * 2, $form.Height - $r * 2, $r * 2, $r * 2, 0, 90)
    $p.AddArc(0, $form.Height - $r * 2, $r * 2, $r * 2, 90, 90)
    $p.CloseAllFigures()
    $form.Region = New-Object System.Drawing.Region($p)
})

# ============================================================
#  TITLE BAR
# ============================================================
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Size = New-Object System.Drawing.Size($form.Width, 46)
$titleBar.Location = New-Object System.Drawing.Point(0, 0)
$titleBar.BackColor = $C.BgAlt
$form.Controls.Add($titleBar)

$script:dragging = $false
$script:dragOffset = New-Object System.Drawing.Point(0, 0)

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

$lblLogo = New-Object System.Windows.Forms.Label
$lblLogo.Text = "KT"
$lblLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$lblLogo.ForeColor = $C.Glow
$lblLogo.AutoSize = $false
$lblLogo.Size = New-Object System.Drawing.Size(34, 34)
$lblLogo.Location = New-Object System.Drawing.Point(14, 6)
$lblLogo.TextAlign = "MiddleCenter"
$lblLogo.BackColor = $C.Surface
$titleBar.Controls.Add($lblLogo)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Kenzie's Tweaks"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $C.Text
$lblTitle.AutoSize = $true
$lblTitle.BackColor = [System.Drawing.Color]::Transparent
$lblTitle.Location = New-Object System.Drawing.Point(58, 13)
$titleBar.Controls.Add($lblTitle)

function New-TitleBtn {
    param([string]$Glyph, [int]$X, [System.Drawing.Color]$Hover)
    $b = New-Object System.Windows.Forms.Label
    $b.Text = $Glyph
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $b.ForeColor = $C.TextDim
    $b.BackColor = [System.Drawing.Color]::Transparent
    $b.Size = New-Object System.Drawing.Size(46, 46)
    $b.Location = New-Object System.Drawing.Point($X, 0)
    $b.TextAlign = "MiddleCenter"
    $b.Cursor = "Hand"
    $b.Add_MouseEnter({ $b.ForeColor = $Hover; $b.BackColor = $C.Surface })
    $b.Add_MouseLeave({ $b.ForeColor = $C.TextDim; $b.BackColor = [System.Drawing.Color]::Transparent })
    return $b
}

$btnMin = New-TitleBtn "-" ($form.Width - 92) $C.Glow
$btnMin.Add_Click({ $form.WindowState = "Minimized" })
$titleBar.Controls.Add($btnMin)

$btnClose = New-TitleBtn "x" ($form.Width - 46) $C.Danger
$btnClose.Add_Click({ $form.Close() })
$titleBar.Controls.Add($btnClose)

# ============================================================
#  LOADING OVERLAY
# ============================================================
$loading = New-Object System.Windows.Forms.Panel
$loading.Size = New-Object System.Drawing.Size($form.Width, $form.Height)
$loading.Location = New-Object System.Drawing.Point(0, 0)
$loading.BackColor = $C.Bg
$form.Controls.Add($loading)
$loading.BringToFront()

$lLogo = New-Object System.Windows.Forms.Label
$lLogo.Text = "KT"
$lLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 36, [System.Drawing.FontStyle]::Bold)
$lLogo.ForeColor = $C.Glow
$lLogo.AutoSize = $false
$lLogo.Size = New-Object System.Drawing.Size(120, 120)
$lLogo.Location = New-Object System.Drawing.Point(420, 190)
$lLogo.TextAlign = "MiddleCenter"
$lLogo.BackColor = $C.Surface
$loading.Controls.Add($lLogo)

$lTitle = New-Object System.Windows.Forms.Label
$lTitle.Text = "Kenzie's Tweaks"
$lTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$lTitle.ForeColor = $C.Text
$lTitle.AutoSize = $true
$lTitle.BackColor = [System.Drawing.Color]::Transparent
$lTitle.Location = New-Object System.Drawing.Point(340, 330)
$loading.Controls.Add($lTitle)

$lStatus = New-Object System.Windows.Forms.Label
$lStatus.Text = "Initializing..."
$lStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lStatus.ForeColor = $C.TextDim
$lStatus.AutoSize = $true
$lStatus.BackColor = [System.Drawing.Color]::Transparent
$lStatus.Location = New-Object System.Drawing.Point(410, 385)
$loading.Controls.Add($lStatus)

$progBg = New-Object System.Windows.Forms.Panel
$progBg.Size = New-Object System.Drawing.Size(340, 4)
$progBg.Location = New-Object System.Drawing.Point(310, 425)
$progBg.BackColor = $C.Surface
$loading.Controls.Add($progBg)

$progFill = New-Object System.Windows.Forms.Panel
$progFill.Size = New-Object System.Drawing.Size(0, 4)
$progFill.Location = New-Object System.Drawing.Point(0, 0)
$progFill.BackColor = $C.Accent
$progBg.Controls.Add($progFill)

$script:loadSteps = @(
    "Initializing Kenzie's Tweaks...",
    "Checking administrator privileges...",
    "Loading power plan configurations...",
    "Building interface...",
    "Ready."
)
$script:loadPct = 0

$loadTimer = New-Object System.Windows.Forms.Timer
$loadTimer.Interval = 25
$loadTimer.Add_Tick({
    $script:loadPct += 2
    if ($script:loadPct -gt 100) { $script:loadPct = 100 }
    $progFill.Width = [int](340 * ($script:loadPct / 100))
    $idx = [Math]::Min([int]($script:loadPct / 20), $script:loadSteps.Count - 1)
    $lStatus.Text = $script:loadSteps[$idx]
    if ($script:loadPct -ge 100) {
        $loadTimer.Stop()
        Start-Sleep -Milliseconds 250
        $loading.Visible = $false
        $loading.SendToBack()
        Update-ActivePlanDisplay
    }
})
$loadTimer.Start()

# ============================================================
#  SIDEBAR + CONTENT
# ============================================================
$main = New-Object System.Windows.Forms.Panel
$main.Size = New-Object System.Drawing.Size($form.Width, ($form.Height - 46))
$main.Location = New-Object System.Drawing.Point(0, 46)
$main.BackColor = $C.Bg
$form.Controls.Add($main)

$sidebar = New-Object KenzieUI.GlowPanel
$sidebar.Size = New-Object System.Drawing.Size(210, ($main.Height - 24))
$sidebar.Location = New-Object System.Drawing.Point(12, 12)
$sidebar.FillColor = $C.BgAlt
$sidebar.BorderColor = $C.Border
$sidebar.Radius = 16
$main.Controls.Add($sidebar)

$sideLogo = New-Object System.Windows.Forms.Label
$sideLogo.Text = "KT"
$sideLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$sideLogo.ForeColor = $C.Glow
$sideLogo.AutoSize = $false
$sideLogo.Size = New-Object System.Drawing.Size(60, 60)
$sideLogo.Location = New-Object System.Drawing.Point(20, 20)
$sideLogo.TextAlign = "MiddleCenter"
$sideLogo.BackColor = $C.Surface
$sidebar.Controls.Add($sideLogo)

$sideName = New-Object System.Windows.Forms.Label
$sideName.Text = "Kenzie's`nTweaks"
$sideName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13, [System.Drawing.FontStyle]::Bold)
$sideName.ForeColor = $C.Text
$sideName.AutoSize = $true
$sideName.BackColor = [System.Drawing.Color]::Transparent
$sideName.Location = New-Object System.Drawing.Point(90, 28)
$sidebar.Controls.Add($sideName)

$adminCard = New-Object KenzieUI.GlowPanel
$adminCard.Size = New-Object System.Drawing.Size(170, 32)
$adminCard.Location = New-Object System.Drawing.Point(20, 95)
$adminCard.Radius = 10
$adminCard.FillColor = if ($isAdmin) { [System.Drawing.Color]::FromArgb(16, 44, 32) } else { [System.Drawing.Color]::FromArgb(44, 34, 12) }
$adminCard.BorderColor = if ($isAdmin) { $C.Success } else { $C.Warning }
$sidebar.Controls.Add($adminCard)

$adminTxt = New-Object System.Windows.Forms.Label
$adminTxt.Text = if ($isAdmin) { "ADMINISTRATOR" } else { "LIMITED MODE" }
$adminTxt.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$adminTxt.ForeColor = if ($isAdmin) { $C.Success } else { $C.Warning }
$adminTxt.AutoSize = $true
$adminTxt.BackColor = [System.Drawing.Color]::Transparent
$adminTxt.Location = New-Object System.Drawing.Point(18, 8)
$adminCard.Controls.Add($adminTxt)

# Nav buttons
$script:navButtons = @{}
$navItems = @(
    @{ Key = "power";  Label = "  Power Plans" }
    @{ Key = "system"; Label = "  System Info" }
    @{ Key = "tweaks"; Label = "  Tweaks" }
    @{ Key = "about";  Label = "  About" }
)

$navY = 145
foreach ($nav in $navItems) {
    $nb = New-Object KenzieUI.ModernButton
    $nb.Text = $nav.Label
    $nb.Size = New-Object System.Drawing.Size(170, 44)
    $nb.Location = New-Object System.Drawing.Point(20, $navY)
    $nb.NormalColor = $C.BgAlt
    $nb.HoverColor = $C.SurfaceHi
    $nb.AccentColor = $C.Accent
    $nb.TextColor = $C.Text
    $nb.CornerRadius = 12
    $nb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $nb.Tag = $nav.Key
    $sidebar.Controls.Add($nb)
    $script:navButtons[$nav.Key] = $nb
    $navY += 52
}

# Content panel
$content = New-Object System.Windows.Forms.Panel
$content.Size = New-Object System.Drawing.Size(($main.Width - 246), ($main.Height - 24))
$content.Location = New-Object System.Drawing.Point(234, 12)
$content.BackColor = $C.Bg
$main.Controls.Add($content)

# ============================================================
#  PAGE: POWER
# ============================================================
$pagePower = New-Object System.Windows.Forms.Panel
$pagePower.Size = $content.Size
$pagePower.Location = New-Object System.Drawing.Point(0, 0)
$pagePower.BackColor = $C.Bg
$content.Controls.Add($pagePower)

$pTitle = New-Object System.Windows.Forms.Label
$pTitle.Text = "Power Plans"
$pTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$pTitle.ForeColor = $C.Text
$pTitle.AutoSize = $true
$pTitle.BackColor = [System.Drawing.Color]::Transparent
$pTitle.Location = New-Object System.Drawing.Point(4, 4)
$pagePower.Controls.Add($pTitle)

$pSub = New-Object System.Windows.Forms.Label
$pSub.Text = "Switch between performance profiles instantly"
$pSub.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$pSub.ForeColor = $C.TextDim
$pSub.AutoSize = $true
$pSub.BackColor = [System.Drawing.Color]::Transparent
$pSub.Location = New-Object System.Drawing.Point(6, 44)
$pagePower.Controls.Add($pSub)

$activeCard = New-Object KenzieUI.GlowPanel
$activeCard.Size = New-Object System.Drawing.Size(($content.Width - 20), 110)
$activeCard.Location = New-Object System.Drawing.Point(4, 80)
$activeCard.Radius = 18
$activeCard.FillColor = $C.Surface
$activeCard.BorderColor = $C.Accent
$pagePower.Controls.Add($activeCard)

$activeIcon = New-Object System.Windows.Forms.Label
$activeIcon.Text = "[K]"
$activeIcon.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 24, [System.Drawing.FontStyle]::Bold)
$activeIcon.ForeColor = $C.Glow
$activeIcon.AutoSize = $false
$activeIcon.Size = New-Object System.Drawing.Size(80, 80)
$activeIcon.Location = New-Object System.Drawing.Point(20, 15)
$activeIcon.TextAlign = "MiddleCenter"
$activeIcon.BackColor = [System.Drawing.Color]::Transparent
$activeCard.Controls.Add($activeIcon)

$activeLabelTop = New-Object System.Windows.Forms.Label
$activeLabelTop.Text = "ACTIVE POWER PLAN"
$activeLabelTop.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$activeLabelTop.ForeColor = $C.TextDim
$activeLabelTop.AutoSize = $true
$activeLabelTop.BackColor = [System.Drawing.Color]::Transparent
$activeLabelTop.Location = New-Object System.Drawing.Point(115, 22)
$activeCard.Controls.Add($activeLabelTop)

$activeName = New-Object System.Windows.Forms.Label
$activeName.Text = "Detecting..."
$activeName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16, [System.Drawing.FontStyle]::Bold)
$activeName.ForeColor = $C.Text
$activeName.AutoSize = $true
$activeName.BackColor = [System.Drawing.Color]::Transparent
$activeName.Location = New-Object System.Drawing.Point(115, 44)
$activeCard.Controls.Add($activeName)

$activeGuid = New-Object System.Windows.Forms.Label
$activeGuid.Text = ""
$activeGuid.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$activeGuid.ForeColor = $C.TextDim
$activeGuid.AutoSize = $true
$activeGuid.BackColor = [System.Drawing.Color]::Transparent
$activeGuid.Location = New-Object System.Drawing.Point(117, 78)
$activeCard.Controls.Add($activeGuid)

$script:planButtons = @{}
$planY = 210
$planX = 4
$col = 0
foreach ($plan in $PowerPlans) {
    $pb = New-Object KenzieUI.ModernButton
    $pb.Text = "$($plan.Icon)  $($plan.Name)"
    $pb.Size = New-Object System.Drawing.Size(220, 68)
    $pb.Location = New-Object System.Drawing.Point($planX, $planY)
    $pb.NormalColor = $C.Surface
    $pb.HoverColor = $C.SurfaceHi
    $pb.AccentColor = $C.Accent
    $pb.TextColor = $C.Text
    $pb.CornerRadius = 14
    $pb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $pb.Tag = $plan.Guid

    $pb.Add_Click({
        param($s, $e)
        Apply-PowerPlan -Guid $s.Tag -Button $s
    })

    $pagePower.Controls.Add($pb)
    $script:planButtons[$plan.Guid] = $pb

    $col++
    if ($col -ge 3) { $col = 0; $planX = 4; $planY += 80 }
    else { $planX += 230 }
}

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = $C.Success
$statusLabel.AutoSize = $false
$statusLabel.Size = New-Object System.Drawing.Size(($content.Width - 20), 30)
$statusLabel.Location = New-Object System.Drawing.Point(4, ($pagePower.Height - 46))
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.BackColor = [System.Drawing.Color]::Transparent
$pagePower.Controls.Add($statusLabel)

# ============================================================
#  PAGE: SYSTEM
# ============================================================
$pageSystem = New-Object System.Windows.Forms.Panel
$pageSystem.Size = $content.Size
$pageSystem.Location = New-Object System.Drawing.Point(0, 0)
$pageSystem.BackColor = $C.Bg
$pageSystem.Visible = $false
$content.Controls.Add($pageSystem)

$sTitle = New-Object System.Windows.Forms.Label
$sTitle.Text = "System Information"
$sTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$sTitle.ForeColor = $C.Text
$sTitle.AutoSize = $true
$sTitle.BackColor = [System.Drawing.Color]::Transparent
$sTitle.Location = New-Object System.Drawing.Point(4, 4)
$pageSystem.Controls.Add($sTitle)

$sysData = @()
try {
    $cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name
    $ramBytes = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory
    $gpu = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1).Name
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $sysData = @(
        @{ Label = "CPU";  Value = if ($cpu) { $cpu.Trim() } else { "Unknown" } }
        @{ Label = "RAM";  Value = if ($ramBytes) { "{0:N1} GB" -f ($ramBytes / 1GB) } else { "Unknown" } }
        @{ Label = "GPU";  Value = if ($gpu) { $gpu } else { "Unknown" } }
        @{ Label = "OS";   Value = if ($os) { "$($os.Caption) ($($os.Version))" } else { "Unknown" } }
        @{ Label = "User"; Value = $env:USERNAME }
    )
} catch { }

$sy = 80
foreach ($f in $sysData) {
    $card = New-Object KenzieUI.GlowPanel
    $card.Size = New-Object System.Drawing.Size(($content.Width - 20), 58)
    $card.Location = New-Object System.Drawing.Point(4, $sy)
    $card.Radius = 12
    $card.FillColor = $C.Surface
    $card.BorderColor = $C.Border
    $pageSystem.Controls.Add($card)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $f.Label.ToUpper()
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = $C.TextDim
    $lbl.AutoSize = $true
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Location = New-Object System.Drawing.Point(20, 10)
    $card.Controls.Add($lbl)

    $val = New-Object System.Windows.Forms.Label
    $val.Text = $f.Value
    $val.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $val.ForeColor = $C.Text
    $val.AutoSize = $true
    $val.BackColor = [System.Drawing.Color]::Transparent
    $val.Location = New-Object System.Drawing.Point(20, 28)
    $card.Controls.Add($val)

    $sy += 66
}

# ============================================================
#  PAGE: TWEAKS
# ============================================================
$pageTweaks = New-Object System.Windows.Forms.Panel
$pageTweaks.Size = $content.Size
$pageTweaks.Location = New-Object System.Drawing.Point(0, 0)
$pageTweaks.BackColor = $C.Bg
$pageTweaks.Visible = $false
$content.Controls.Add($pageTweaks)

$tTitle = New-Object System.Windows.Forms.Label
$tTitle.Text = "Tweaks"
$tTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$tTitle.ForeColor = $C.Text
$tTitle.AutoSize = $true
$tTitle.BackColor = [System.Drawing.Color]::Transparent
$tTitle.Location = New-Object System.Drawing.Point(4, 4)
$pageTweaks.Controls.Add($tTitle)

$tweaks = @(
    @{ Name = "Unlock Ultimate Performance"; Cmd = { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null } }
    @{ Name = "Disable Hibernation";         Cmd = { powercfg -h off } }
    @{ Name = "Disable Telemetry";           Cmd = { Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue } }
    @{ Name = "Enable Game Mode";            Cmd = { if (-not (Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item -Path 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }; Set-ItemProperty -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1 -ErrorAction SilentlyContinue } }
    @{ Name = "Disable Xbox Game Bar";       Cmd = { if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR')) { New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null }; Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0 -ErrorAction SilentlyContinue } }
    @{ Name = "Enable HPET";                 Cmd = { bcdedit /set useplatformclock true 2>&1 | Out-Null } }
)

$ty = 80
foreach ($t in $tweaks) {
    $row = New-Object KenzieUI.GlowPanel
    $row.Size = New-Object System.Drawing.Size(($content.Width - 20), 54)
    $row.Location = New-Object System.Drawing.Point(4, $ty)
    $row.Radius = 12
    $row.FillColor = $C.Surface
    $row.BorderColor = $C.Border
    $pageTweaks.Controls.Add($row)

    $n = New-Object System.Windows.Forms.Label
    $n.Text = $t.Name
    $n.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $n.ForeColor = $C.Text
    $n.AutoSize = $true
    $n.BackColor = [System.Drawing.Color]::Transparent
    $n.Location = New-Object System.Drawing.Point(20, 16)
    $row.Controls.Add($n)

    $btn = New-Object KenzieUI.ModernButton
    $btn.Text = "Run"
    $btn.Size = New-Object System.Drawing.Size(90, 34)
    $btn.Location = New-Object System.Drawing.Point(($row.Width - 108), 10)
    $btn.NormalColor = $C.BgAlt
    $btn.HoverColor = $C.SurfaceHi
    $btn.AccentColor = $C.Accent
    $btn.CornerRadius = 10
    $btn.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)

    $cmd = $t.Cmd
    $btn.Add_Click({
        param($s, $e)
        try {
            & $cmd
            Show-Status "Applied successfully" "Success"
        } catch {
            Show-Status "Error: $($_.Exception.Message)" "Error"
        }
    })
    $row.Controls.Add($btn)

    $ty += 62
}

# ============================================================
#  PAGE: ABOUT
# ============================================================
$pageAbout = New-Object System.Windows.Forms.Panel
$pageAbout.Size = $content.Size
$pageAbout.Location = New-Object System.Drawing.Point(0, 0)
$pageAbout.BackColor = $C.Bg
$pageAbout.Visible = $false
$content.Controls.Add($pageAbout)

$aboutCard = New-Object KenzieUI.GlowPanel
$aboutCard.Size = New-Object System.Drawing.Size(($content.Width - 40), 400)
$aboutCard.Location = New-Object System.Drawing.Point(20, 40)
$aboutCard.Radius = 20
$aboutCard.FillColor = $C.Surface
$aboutCard.BorderColor = $C.Border
$pageAbout.Controls.Add($aboutCard)

$aboutIcon = New-Object System.Windows.Forms.Label
$aboutIcon.Text = "KT"
$aboutIcon.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 40, [System.Drawing.FontStyle]::Bold)
$aboutIcon.ForeColor = $C.Glow
$aboutIcon.AutoSize = $false
$aboutIcon.Size = New-Object System.Drawing.Size(120, 120)
$aboutIcon.Location = New-Object System.Drawing.Point(30, 30)
$aboutIcon.TextAlign = "MiddleCenter"
$aboutIcon.BackColor = $C.BgAlt
$aboutCard.Controls.Add($aboutIcon)

$aboutTitle = New-Object System.Windows.Forms.Label
$aboutTitle.Text = "Kenzie's Tweaks"
$aboutTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 24, [System.Drawing.FontStyle]::Bold)
$aboutTitle.ForeColor = $C.Text
$aboutTitle.AutoSize = $true
$aboutTitle.BackColor = [System.Drawing.Color]::Transparent
$aboutTitle.Location = New-Object System.Drawing.Point(180, 40)
$aboutCard.Controls.Add($aboutTitle)

$aboutVer = New-Object System.Windows.Forms.Label
$aboutVer.Text = "Version 1.0  -  Modern UI"
$aboutVer.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$aboutVer.ForeColor = $C.TextDim
$aboutVer.AutoSize = $true
$aboutVer.BackColor = [System.Drawing.Color]::Transparent
$aboutVer.Location = New-Object System.Drawing.Point(182, 90)
$aboutCard.Controls.Add($aboutVer)

$aboutDesc = New-Object System.Windows.Forms.Label
$aboutDesc.Text = "A sleek PowerShell dashboard for`npower plan management and system tweaks.`nBuilt with WinForms + custom C# controls.`n`nCustom plan GUID:`nb7701089-9d55-49a7-90ec-f6be3a3566a9"
$aboutDesc.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$aboutDesc.ForeColor = $C.Text
$aboutDesc.AutoSize = $true
$aboutDesc.BackColor = [System.Drawing.Color]::Transparent
$aboutDesc.Location = New-Object System.Drawing.Point(182, 130)
$aboutCard.Controls.Add($aboutDesc)

# ============================================================
#  NAVIGATION
# ============================================================
$script:pages = @{
    power  = $pagePower
    system = $pageSystem
    tweaks = $pageTweaks
    about  = $pageAbout
}

function Switch-Page {
    param([string]$Key)
    foreach ($k in $script:pages.Keys) {
        $script:pages[$k].Visible = ($k -eq $Key)
        $script:navButtons[$k].IsActive = ($k -eq $Key)
    }
    $script:pages[$Key].BringToFront()
}

foreach ($k in $script:navButtons.Keys) {
    $key = $k
    $script:navButtons[$k].Add_Click({
        Switch-Page -Key $key
    })
}

# ============================================================
#  FUNCTIONS
# ============================================================
function Update-ActivePlanDisplay {
    $activeGuid = Get-ActivePlanGuid
    if ($activeGuid) {
        $plan = $PowerPlans | Where-Object { $_.Guid -eq $activeGuid } | Select-Object -First 1
        if ($plan) {
            $activeName.Text = "$($plan.Icon)  $($plan.Name)"
            $activeGuid.Text = "GUID: $($plan.Guid)"
            $activeIcon.Text = $plan.Icon
        } else {
            $activeName.Text = "Custom Plan"
            $activeGuid.Text = "GUID: $activeGuid"
            $activeIcon.Text = "[?]"
        }
        foreach ($key in $script:planButtons.Keys) {
            $script:planButtons[$key].IsActive = ($key -eq $activeGuid)
        }
    }
}

function Show-Status {
    param([string]$Message, [string]$Type = "Success")
    $color = switch ($Type) {
        "Success" { $C.Success }
        "Error"   { $C.Danger }
        "Warning" { $C.Warning }
        default   { $C.Text }
    }
    $statusLabel.ForeColor = $color
    $statusLabel.Text = $Message

    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 4000
    $t.Add_Tick({
        $statusLabel.Text = ""
        $t.Stop()
        $t.Dispose()
    })
    $t.Start()
}

function Apply-PowerPlan {
    param([string]$Guid, [object]$Button)

    if (-not $isAdmin) {
        Show-Status "Administrator privileges required" "Error"
        return
    }

    $orig = $Button.Text
    $Button.Text = "Applying..."
    $Button.Enabled = $false
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $check = powercfg /list 2>$null | Select-String $Guid
        if (-not $check) {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $Guid 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e $Guid 2>&1 | Out-Null
            }
            Start-Sleep -Milliseconds 250
        }

        powercfg /setactive $Guid 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Show-Status "Power plan applied" "Success"
            Start-Sleep -Milliseconds 120
            Update-ActivePlanDisplay
        } else {
            Show-Status "Failed to apply power plan" "Error"
        }
    } catch {
        Show-Status "Error: $($_.Exception.Message)" "Error"
    } finally {
        $Button.Text = $orig
        $Button.Enabled = $true
        $Button.Invalidate()
    }
}

# ============================================================
#  FORM EVENTS
# ============================================================
$form.Add_Shown({
    Switch-Page -Key "power"
    $form.Activate()
})

$form.Add_FormClosing({
    if ($loadTimer) { $loadTimer.Stop(); $loadTimer.Dispose() }
})

# ============================================================
#  RUN
# ============================================================
[void]$form.ShowDialog()
