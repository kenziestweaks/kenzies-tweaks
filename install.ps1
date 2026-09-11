#Requires -Version 5.1
<#
.SYNOPSIS
    Kenzie's Tweaks — Modern PowerShell GUI
.DESCRIPTION
    A sleek, animated, dark-themed tweaking tool with power plan management.
    Compatible with Windows PowerShell 5.1 and PowerShell 7+.
.NOTES
    Run as Administrator for full functionality.
#>

# ============================================================
#  ELEVATE IF NOT ADMIN
# ============================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://raw.githubusercontent.com/kenziestweaks/kenzies-tweaks/main/install.ps1?v=$([DateTime]::Now.Ticks)' | iex`""
        $psi.Verb = "runas"
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    } catch {
        # User declined UAC — continue without admin
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Management 2>$null

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ============================================================
#  GLOBAL STATE
# ============================================================
$script:Colors = @{
    Bg          = [System.Drawing.Color]::FromArgb(10, 12, 18)
    BgAlt       = [System.Drawing.Color]::FromArgb(15, 18, 26)
    Surface     = [System.Drawing.Color]::FromArgb(22, 28, 40)
    SurfaceHi   = [System.Drawing.Color]::FromArgb(32, 40, 56)
    Border      = [System.Drawing.Color]::FromArgb(45, 58, 80)
    Accent      = [System.Drawing.Color]::FromArgb(0, 160, 255)
    Accent2     = [System.Drawing.Color]::FromArgb(120, 80, 255)
    Glow        = [System.Drawing.Color]::FromArgb(0, 200, 255)
    Text        = [System.Drawing.Color]::FromArgb(240, 245, 252)
    TextDim     = [System.Drawing.Color]::FromArgb(140, 160, 185)
    Success     = [System.Drawing.Color]::FromArgb(60, 220, 150)
    Warning     = [System.Drawing.Color]::FromArgb(255, 190, 70)
    Danger      = [System.Drawing.Color]::FromArgb(255, 90, 110)
}

$script:PowerPlans = @(
    @{ Name = "Kenzie's Custom"; Guid = "b7701089-9d55-49a7-90ec-f6be3a3566a9"; Icon = "⚡"; Desc = "Custom ultra performance" }
    @{ Name = "Ultimate Performance"; Guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"; Icon = "🔥"; Desc = "Maximum performance" }
    @{ Name = "High Performance"; Guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; Icon = "🚀"; Desc = "Standard performance" }
    @{ Name = "Balanced"; Guid = "381b4222-f694-41f0-9685-ff5bb260df2e"; Icon = "⚖"; Desc = "Balanced mode" }
    @{ Name = "Power Saver"; Guid = "a1841308-3541-4fab-bc81-f71556f20b4a"; Icon = "🔋"; Desc = "Reduce power" }
)

# ============================================================
#  CUSTOM C# CONTROLS  (C# 5 safe — PS 5.1 compatible)
# ============================================================
if (-not ("KenzieUI" -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace KenzieUI
{
    // ---------- GLOW CARD PANEL ----------
    public class GlowPanel : Panel
    {
        private int _radius = 18;
        private Color _borderColor = Color.FromArgb(45, 58, 80);
        private Color _fillColor = Color.FromArgb(22, 28, 40);
        private bool _glow = false;
        private float _glowAmt = 0f;
        private Timer _timer;

        public int Radius { get { return _radius; } set { _radius = value; Invalidate(); } }
        public Color BorderColor { get { return _borderColor; } set { _borderColor = value; Invalidate(); } }
        public Color FillColor { get { return _fillColor; } set { _fillColor = value; Invalidate(); } }
        public bool EnableGlow { get { return _glow; } set { _glow = value; } }

        public GlowPanel()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer |
                     ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            _timer = new Timer();
            _timer.Interval = 30;
            _timer.Tick += delegate(object s, EventArgs e) {
                float target = _glow ? 1f : 0f;
                _glowAmt += (target - _glowAmt) * 0.15f;
                if (Math.Abs(_glowAmt - target) < 0.01f) _glowAmt = target;
                Invalidate();
            };
            _timer.Start();
        }

        protected override void OnMouseEnter(EventArgs e) { _glow = true; base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _glow = false; base.OnMouseLeave(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);

            GraphicsPath path = Rounded(r, _radius);
            try
            {
                using (SolidBrush b = new SolidBrush(_fillColor))
                    g.FillPath(b, path);

                Color bc = _borderColor;
                float thickness = 1f;
                if (_glowAmt > 0.01f)
                {
                    bc = Blend(_borderColor, Color.FromArgb(0, 180, 255), _glowAmt);
                    thickness = 1f + _glowAmt;
                }
                using (Pen p = new Pen(bc, thickness))
                    g.DrawPath(p, path);
            }
            finally { path.Dispose(); }
        }

        private GraphicsPath Rounded(Rectangle r, int radius)
        {
            GraphicsPath path = new GraphicsPath();
            int d = radius * 2;
            path.AddArc(r.X, r.Y, d, d, 180, 90);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        public static Color Blend(Color a, Color b, float t)
        {
            t = Math.Max(0, Math.Min(1, t));
            return Color.FromArgb(
                (int)(a.A + (b.A - a.A) * t),
                (int)(a.R + (b.R - a.R) * t),
                (int)(a.G + (b.G - a.G) * t),
                (int)(a.B + (b.B - a.B) * t));
        }
    }

    // ---------- MODERN BUTTON ----------
    public class ModernButton : Button
    {
        private Color _normalColor = Color.FromArgb(26, 32, 46);
        private Color _hoverColor  = Color.FromArgb(40, 52, 74);
        private Color _accentColor = Color.FromArgb(0, 160, 255);
        private Color _textColor   = Color.FromArgb(240, 245, 252);
        private int   _cornerRadius = 14;
        private bool  _isActive    = false;
        private bool  _isDanger    = false;

        public Color NormalColor { get { return _normalColor; } set { _normalColor = value; Invalidate(); } }
        public Color HoverColor  { get { return _hoverColor; }  set { _hoverColor = value;  Invalidate(); } }
        public Color AccentColor { get { return _accentColor; } set { _accentColor = value; Invalidate(); } }
        public Color TextColor   { get { return _textColor; }   set { _textColor = value;   Invalidate(); } }
        public int  CornerRadius { get { return _cornerRadius; } set { _cornerRadius = value; Invalidate(); } }
        public bool IsActive     { get { return _isActive; }    set { _isActive = value;    Invalidate(); } }
        public bool IsDanger     { get { return _isDanger; }    set { _isDanger = value;    Invalidate(); } }

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
            ForeColor = _textColor;
            Font = new Font("Segoe UI Semibold", 10f, FontStyle.Bold);
            Cursor = Cursors.Hand;
            _timer = new Timer();
            _timer.Interval = 25;
            _timer.Tick += delegate(object s, EventArgs e) {
                float target = _hover ? 1f : 0f;
                _glow += (target - _glow) * 0.22f;
                if (Math.Abs(_glow - target) < 0.01f) _glow = target;
                Invalidate();
            };
            _timer.Start();
        }

        protected override void OnMouseEnter(EventArgs e) { _hover = true;  base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hover = false; base.OnMouseLeave(e); }

        protected override void OnPaint(PaintEventArgs pevent)
        {
            Graphics g = pevent.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle rect = new Rectangle(0, 0, Width - 1, Height - 1);

            GraphicsPath path = GetRoundedPath(rect, _cornerRadius);
            try
            {
                Color fill;
                if (_isActive)
                    fill = GlowPanel.Blend(_accentColor, _normalColor, 0.40f);
                else if (_isDanger && _glow > 0.05f)
                    fill = GlowPanel.Blend(_normalColor, Color.FromArgb(180, 40, 60), _glow * 0.6f);
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
                    using (Pen glowPen = new Pen(Color.FromArgb(60, _accentColor), 6f))
                        g.DrawPath(glowPen, path);
                }
            }
            finally { path.Dispose(); }

            TextRenderer.DrawText(g, Text, Font, rect, _textColor,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }

        private GraphicsPath GetRoundedPath(Rectangle r, int radius)
        {
            GraphicsPath path = new GraphicsPath();
            int d = radius * 2;
            path.AddArc(r.X, r.Y, d, d, 180, 90);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    // ---------- ANIMATED TOGGLE ----------
    public class ModernToggle : Control
    {
        private bool _checked = false;
        private float _anim = 0f;
        private Timer _timer;
        public Color OnColor  = Color.FromArgb(0, 180, 120);
        public Color OffColor = Color.FromArgb(60, 70, 88);
        public Color KnobColor = Color.White;

        public bool Checked {
            get { return _checked; }
            set { _checked = value; }
        }

        public event EventHandler CheckedChanged;

        public ModernToggle()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer |
                     ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Size = new Size(52, 28);
            Cursor = Cursors.Hand;
            _timer = new Timer();
            _timer.Interval = 16;
            _timer.Tick += delegate(object s, EventArgs e) {
                float target = _checked ? 1f : 0f;
                _anim += (target - _anim) * 0.25f;
                if (Math.Abs(_anim - target) < 0.01f) _anim = target;
                Invalidate();
            };
            _timer.Start();
        }

        protected override void OnClick(EventArgs e)
        {
            _checked = !_checked;
            if (CheckedChanged != null) CheckedChanged(this, EventArgs.Empty);
            base.OnClick(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            Color bg = GlowPanel.Blend(OffColor, OnColor, _anim);
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            GraphicsPath path = new GraphicsPath();
            int d = Height - 2;
            path.AddArc(r.X, r.Y, d, d, 90, 180);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 180);
            path.CloseFigure();

            using (SolidBrush b = new SolidBrush(bg))
                g.FillPath(b, path);
            path.Dispose();

            int knobSize = Height - 6;
            int knobX = (int)(3 + _anim * (Width - knobSize - 6));
            using (SolidBrush kb = new SolidBrush(KnobColor))
                g.FillEllipse(kb, knobX, 3, knobSize, knobSize);
        }
    }
}
"@
}

# ============================================================
#  HELPER FUNCTIONS
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

function Get-ActivePowerPlanGuid {
    try {
        $out = powercfg /getactivescheme 2>$null
        if ($out -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
            return $matches[1].ToLower()
        }
    } catch { }
    return $null
}

function Get-SystemInfo {
    $info = @{ CPU = "Unknown"; RAM = "Unknown"; GPU = "Unknown"; OS = "Unknown"; User = $env:USERNAME }
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cpu) { $info.CPU = $cpu.Name.Trim() }
        $ram = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory
        if ($ram) { $info.RAM = "{0:N1} GB" -f ($ram / 1GB) }
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($gpu) { $info.GPU = $gpu.Name }
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) { $info.OS = "$($os.Caption) ($($os.Version))" }
    } catch { }
    return $info
}

# ============================================================
#  MAIN FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Kenzie's Tweaks"
$form.Size = New-Object System.Drawing.Size(980, 700)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Colors.Bg
$form.ForeColor = $Colors.Text
$form.FormBorderStyle = "None"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Padding = New-Object System.Windows.Forms.Padding(1)
Set-DoubleBuffer $form

# Rounded form region (Windows 11-ish corners)
$form.Add_Resize({
    $r = 18
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $r * 2, $r * 2, 180, 90)
    $path.AddArc($form.Width - $r * 2, 0, $r * 2, $r * 2, 270, 90)
    $path.AddArc($form.Width - $r * 2, $form.Height - $r * 2, $r * 2, $r * 2, 0, 90)
    $path.AddArc(0, $form.Height - $r * 2, $r * 2, $r * 2, 90, 90)
    $path.CloseAllFigures()
    $form.Region = New-Object System.Drawing.Region($path)
})

# ============================================================
#  CUSTOM TITLE BAR
# ============================================================
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Size = New-Object System.Drawing.Size($form.Width, 48)
$titleBar.Location = New-Object System.Drawing.Point(0, 0)
$titleBar.BackColor = $Colors.BgAlt
$form.Controls.Add($titleBar)

$script:dragging = $false
$script:dragOffset = New-Object System.Drawing.Point(0, 0)

$titleBar.Add_MouseDown({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true
        $script:dragOffset = $e.Location
    }
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

$logoLabel = New-Object System.Windows.Forms.Label
$logoLabel.Text = "⚡"
$logoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16)
$logoLabel.ForeColor = $Colors.Glow
$logoLabel.AutoSize = $true
$logoLabel.Location = New-Object System.Drawing.Point(18, 10)
$logoLabel.BackColor = [System.Drawing.Color]::Transparent
$titleBar.Controls.Add($logoLabel)

$titleText = New-Object System.Windows.Forms.Label
$titleText.Text = "Kenzie's Tweaks"
$titleText.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
$titleText.ForeColor = $Colors.Text
$titleText.AutoSize = $true
$titleText.Location = New-Object System.Drawing.Point(48, 13)
$titleText.BackColor = [System.Drawing.Color]::Transparent
$titleBar.Controls.Add($titleText)

# Window control buttons
function New-TitleButton {
    param([string]$Glyph, [int]$X, [System.Drawing.Color]$HoverColor)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Glyph
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $lbl.ForeColor = $Colors.TextDim
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Size = New-Object System.Drawing.Size(46, 48)
    $lbl.Location = New-Object System.Drawing.Point($X, 0)
    $lbl.TextAlign = "MiddleCenter"
    $lbl.Cursor = "Hand"
    $lbl.Add_MouseEnter({ $lbl.ForeColor = $HoverColor; $lbl.BackColor = $Colors.Surface })
    $lbl.Add_MouseLeave({ $lbl.ForeColor = $Colors.TextDim; $lbl.BackColor = [System.Drawing.Color]::Transparent })
    return $lbl
}

$btnMin = New-TitleButton "—" ($form.Width - 92) $Colors.Glow
$btnMin.Add_Click({ $form.WindowState = "Minimized" })
$titleBar.Controls.Add($btnMin)

$btnClose = New-TitleButton "✕" ($form.Width - 46) $Colors.Danger
$btnClose.Add_Click({ $form.Close() })
$titleBar.Controls.Add($btnClose)

# ============================================================
#  LOADING OVERLAY
# ============================================================
$loadingPanel = New-Object System.Windows.Forms.Panel
$loadingPanel.Size = New-Object System.Drawing.Size($form.Width, $form.Height)
$loadingPanel.Location = New-Object System.Drawing.Point(0, 0)
$loadingPanel.BackColor = $Colors.Bg
$form.Controls.Add($loadingPanel)
$loadingPanel.BringToFront()

$loadingIcon = New-Object System.Windows.Forms.Label
$loadingIcon.Text = "⚡"
$loadingIcon.Font = New-Object System.Drawing.Font("Segoe UI", 60)
$loadingIcon.ForeColor = $Colors.Glow
$loadingIcon.AutoSize = $true
$loadingIcon.BackColor = [System.Drawing.Color]::Transparent
$loadingIcon.Location = New-Object System.Drawing.Point(430, 220)
$loadingPanel.Controls.Add($loadingIcon)

$loadingTitle = New-Object System.Windows.Forms.Label
$loadingTitle.Text = "Kenzie's Tweaks"
$loadingTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 26, [System.Drawing.FontStyle]::Bold)
$loadingTitle.ForeColor = $Colors.Text
$loadingTitle.AutoSize = $true
$loadingTitle.BackColor = [System.Drawing.Color]::Transparent
$loadingTitle.Location = New-Object System.Drawing.Point(330, 340)
$loadingPanel.Controls.Add($loadingTitle)

$loadingStatus = New-Object System.Windows.Forms.Label
$loadingStatus.Text = "Initializing..."
$loadingStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$loadingStatus.ForeColor = $Colors.TextDim
$loadingStatus.AutoSize = $true
$loadingStatus.BackColor = [System.Drawing.Color]::Transparent
$loadingStatus.Location = New-Object System.Drawing.Point(415, 400)
$loadingPanel.Controls.Add($loadingStatus)

$progressBg = New-Object System.Windows.Forms.Panel
$progressBg.Size = New-Object System.Drawing.Size(360, 4)
$progressBg.Location = New-Object System.Drawing.Point(310, 440)
$progressBg.BackColor = $Colors.Surface
$loadingPanel.Controls.Add($progressBg)

$progressFill = New-Object System.Windows.Forms.Panel
$progressFill.Size = New-Object System.Drawing.Size(0, 4)
$progressFill.Location = New-Object System.Drawing.Point(0, 0)
$progressFill.BackColor = $Colors.Accent
$progressBg.Controls.Add($progressFill)

$script:loadingSteps = @(
    "Initializing Kenzie's Tweaks...",
    "Checking administrator privileges...",
    "Loading power plan configurations...",
    "Probing system information...",
    "Applying modern theme...",
    "Ready."
)
$script:progress = 0

$loadingTimer = New-Object System.Windows.Forms.Timer
$loadingTimer.Interval = 25
$loadingTimer.Add_Tick({
    $script:progress += 2
    if ($script:progress -gt 100) { $script:progress = 100 }
    $progressFill.Width = [int](360 * ($script:progress / 100))
    $stepIdx = [Math]::Min([int]($script:progress / 17), $script:loadingSteps.Count - 1)
    $loadingStatus.Text = $script:loadingSteps[$stepIdx]
    if ($script:progress -ge 100) {
        $loadingTimer.Stop()
        Start-Sleep -Milliseconds 250
        $loadingPanel.Visible = $false
        $loadingPanel.SendToBack()
    }
})
$loadingTimer.Start()

# ============================================================
#  MAIN CONTENT
# ============================================================
$main = New-Object System.Windows.Forms.Panel
$main.Size = New-Object System.Drawing.Size($form.Width, ($form.Height - 48))
$main.Location = New-Object System.Drawing.Point(0, 48)
$main.BackColor = $Colors.Bg
$form.Controls.Add($main)

# ---------- SIDEBAR ----------
$sidebar = New-Object KenzieUI.GlowPanel
$sidebar.Size = New-Object System.Drawing.Size(220, ($main.Height - 24))
$sidebar.Location = New-Object System.Drawing.Point(12, 12)
$sidebar.FillColor = $Colors.BgAlt
$sidebar.BorderColor = $Colors.Border
$sidebar.Radius = 16
$main.Controls.Add($sidebar)

$logoBig = New-Object System.Windows.Forms.Label
$logoBig.Text = "⚡"
$logoBig.Font = New-Object System.Drawing.Font("Segoe UI", 32)
$logoBig.ForeColor = $Colors.Glow
$logoBig.AutoSize = $true
$logoBig.BackColor = [System.Drawing.Color]::Transparent
$logoBig.Location = New-Object System.Drawing.Point(20, 20)
$sidebar.Controls.Add($logoBig)

$brandLabel = New-Object System.Windows.Forms.Label
$brandLabel.Text = "Kenzie's`nTweaks"
$brandLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
$brandLabel.ForeColor = $Colors.Text
$brandLabel.AutoSize = $true
$brandLabel.BackColor = [System.Drawing.Color]::Transparent
$brandLabel.Location = New-Object System.Drawing.Point(70, 30)
$sidebar.Controls.Add($brandLabel)

# Admin badge
$adminBadge = New-Object KenzieUI.GlowPanel
$adminBadge.Size = New-Object System.Drawing.Size(180, 34)
$adminBadge.Location = New-Object System.Drawing.Point(20, 100)
$adminBadge.Radius = 10
$adminBadge.FillColor = if ($isAdmin) { [System.Drawing.Color]::FromArgb(18, 46, 34) } else { [System.Drawing.Color]::FromArgb(46, 36, 14) }
$adminBadge.BorderColor = if ($isAdmin) { $Colors.Success } else { $Colors.Warning }
$sidebar.Controls.Add($adminBadge)

$adminText = New-Object System.Windows.Forms.Label
$adminText.Text = if ($isAdmin) { "●  ADMINISTRATOR" } else { "●  LIMITED MODE" }
$adminText.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$adminText.ForeColor = if ($isAdmin) { $Colors.Success } else { $Colors.Warning }
$adminText.AutoSize = $true
$adminText.BackColor = [System.Drawing.Color]::Transparent
$adminText.Location = New-Object System.Drawing.Point(15, 9)
$adminBadge.Controls.Add($adminText)

# Nav buttons
$script:navButtons = @{}
$navItems = @(
    @{ Key = "power";    Label = "  ⚡  Power Plans" }
    @{ Key = "system";   Label = "  💻  System Info" }
    @{ Key = "tweaks";   Label = "  🔧  Tweaks" }
    @{ Key = "about";    Label = "  ℹ  About" }
)

$navY = 160
foreach ($nav in $navItems) {
    $nb = New-Object KenzieUI.ModernButton
    $nb.Text = $nav.Label
    $nb.Size = New-Object System.Drawing.Size(180, 46)
    $nb.Location = New-Object System.Drawing.Point(20, $navY)
    $nb.NormalColor = $Colors.BgAlt
    $nb.HoverColor = $Colors.SurfaceHi
    $nb.AccentColor = $Colors.Accent
    $nb.TextColor = $Colors.Text
    $nb.CornerRadius = 12
    $nb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $nb.Tag = $nav.Key
    $main.Controls.Add($nb) # add to main for correct z-order
    $sidebar.Controls.Add($nb) # then sidebar
    $nb.Parent = $sidebar
    $script:navButtons[$nav.Key] = $nb
    $navY += 54
}

# ---------- CONTENT AREA ----------
$content = New-Object System.Windows.Forms.Panel
$content.Size = New-Object System.Drawing.Size(($main.Width - 256), ($main.Height - 24))
$content.Location = New-Object System.Drawing.Point(244, 12)
$content.BackColor = $Colors.Bg
$main.Controls.Add($content)

# ============================================================
#  PAGE: POWER PLANS
# ============================================================
$pagePower = New-Object System.Windows.Forms.Panel
$pagePower.Size = $content.Size
$pagePower.Location = New-Object System.Drawing.Point(0, 0)
$pagePower.BackColor = $Colors.Bg
$content.Controls.Add($pagePower)

$powerTitle = New-Object System.Windows.Forms.Label
$powerTitle.Text = "Power Plans"
$powerTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$powerTitle.ForeColor = $Colors.Text
$powerTitle.AutoSize = $true
$powerTitle.BackColor = [System.Drawing.Color]::Transparent
$powerTitle.Location = New-Object System.Drawing.Point(4, 4)
$pagePower.Controls.Add($powerTitle)

$powerSub = New-Object System.Windows.Forms.Label
$powerSub.Text = "Switch between performance profiles instantly"
$powerSub.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$powerSub.ForeColor = $Colors.TextDim
$powerSub.AutoSize = $true
$powerSub.BackColor = [System.Drawing.Color]::Transparent
$powerSub.Location = New-Object System.Drawing.Point(6, 44)
$pagePower.Controls.Add($powerSub)

# Active plan card
$activeCard = New-Object KenzieUI.GlowPanel
$activeCard.Size = New-Object System.Drawing.Size(($content.Width - 20), 110)
$activeCard.Location = New-Object System.Drawing.Point(4, 80)
$activeCard.Radius = 18
$activeCard.FillColor = $Colors.Surface
$activeCard.BorderColor = $Colors.Accent
$pagePower.Controls.Add($activeCard)

$activeIcon = New-Object System.Windows.Forms.Label
$activeIcon.Text = "⚡"
$activeIcon.Font = New-Object System.Drawing.Font("Segoe UI", 42)
$activeIcon.ForeColor = $Colors.Glow
$activeIcon.AutoSize = $true
$activeIcon.BackColor = [System.Drawing.Color]::Transparent
$activeIcon.Location = New-Object System.Drawing.Point(24, 22)
$activeCard.Controls.Add($activeIcon)

$activeLabelTop = New-Object System.Windows.Forms.Label
$activeLabelTop.Text = "ACTIVE POWER PLAN"
$activeLabelTop.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$activeLabelTop.ForeColor = $Colors.TextDim
$activeLabelTop.AutoSize = $true
$activeLabelTop.BackColor = [System.Drawing.Color]::Transparent
$activeLabelTop.Location = New-Object System.Drawing.Point(110, 22)
$activeCard.Controls.Add($activeLabelTop)

$activeName = New-Object System.Windows.Forms.Label
$activeName.Text = "Detecting..."
$activeName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16, [System.Drawing.FontStyle]::Bold)
$activeName.ForeColor = $Colors.Text
$activeName.AutoSize = $true
$activeName.BackColor = [System.Drawing.Color]::Transparent
$activeName.Location = New-Object System.Drawing.Point(110, 44)
$activeCard.Controls.Add($activeName)

$activeGuid = New-Object System.Windows.Forms.Label
$activeGuid.Text = ""
$activeGuid.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$activeGuid.ForeColor = $Colors.TextDim
$activeGuid.AutoSize = $true
$activeGuid.BackColor = [System.Drawing.Color]::Transparent
$activeGuid.Location = New-Object System.Drawing.Point(112, 78)
$activeCard.Controls.Add($activeGuid)

# Plan buttons grid
$script:planButtons = @{}
$planY = 210
$planX = 4
$col = 0
foreach ($plan in $PowerPlans) {
    $pb = New-Object KenzieUI.ModernButton
    $pb.Text = "$($plan.Icon)  $($plan.Name)"
    $pb.Size = New-Object System.Drawing.Size(190, 72)
    $pb.Location = New-Object System.Drawing.Point($planX, $planY)
    $pb.NormalColor = $Colors.Surface
    $pb.HoverColor = $Colors.SurfaceHi
    $pb.AccentColor = $Colors.Accent
    $pb.TextColor = $Colors.Text
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
    if ($col -ge 2) { $col = 0; $planX = 4; $planY += 84 }
    else { $planX += 200 }
}

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = $Colors.Success
$statusLabel.AutoSize = $false
$statusLabel.Size = New-Object System.Drawing.Size(($content.Width - 20), 30)
$statusLabel.Location = New-Object System.Drawing.Point(4, ($pagePower.Height - 46))
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.BackColor = [System.Drawing.Color]::Transparent
$pagePower.Controls.Add($statusLabel)

# ============================================================
#  PAGE: SYSTEM INFO
# ============================================================
$pageSystem = New-Object System.Windows.Forms.Panel
$pageSystem.Size = $content.Size
$pageSystem.Location = New-Object System.Drawing.Point(0, 0)
$pageSystem.BackColor = $Colors.Bg
$pageSystem.Visible = $false
$content.Controls.Add($pageSystem)

$sysTitle = New-Object System.Windows.Forms.Label
$sysTitle.Text = "System Information"
$sysTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$sysTitle.ForeColor = $Colors.Text
$sysTitle.AutoSize = $true
$sysTitle.BackColor = [System.Drawing.Color]::Transparent
$sysTitle.Location = New-Object System.Drawing.Point(4, 4)
$pageSystem.Controls.Add($sysTitle)

$sysSub = New-Object System.Windows.Forms.Label
$sysSub.Text = "Live hardware and OS details"
$sysSub.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$sysSub.ForeColor = $Colors.TextDim
$sysSub.AutoSize = $true
$sysSub.BackColor = [System.Drawing.Color]::Transparent
$sysSub.Location = New-Object System.Drawing.Point(6, 44)
$pageSystem.Controls.Add($sysSub)

$sysInfo = Get-SystemInfo
$sysFields = @(
    @{ Label = "CPU";  Value = $sysInfo.CPU }
    @{ Label = "RAM";  Value = $sysInfo.RAM }
    @{ Label = "GPU";  Value = $sysInfo.GPU }
    @{ Label = "OS";   Value = $sysInfo.OS }
    @{ Label = "User"; Value = $sysInfo.User }
)

$sy = 90
foreach ($f in $sysFields) {
    $card = New-Object KenzieUI.GlowPanel
    $card.Size = New-Object System.Drawing.Size(($content.Width - 20), 60)
    $card.Location = New-Object System.Drawing.Point(4, $sy)
    $card.Radius = 12
    $card.FillColor = $Colors.Surface
    $card.BorderColor = $Colors.Border
    $pageSystem.Controls.Add($card)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $f.Label.ToUpper()
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = $Colors.TextDim
    $lbl.AutoSize = $true
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Location = New-Object System.Drawing.Point(20, 12)
    $card.Controls.Add($lbl)

    $val = New-Object System.Windows.Forms.Label
    $val.Text = $f.Value
    $val.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $val.ForeColor = $Colors.Text
    $val.AutoSize = $true
    $val.BackColor = [System.Drawing.Color]::Transparent
    $val.Location = New-Object System.Drawing.Point(20, 30)
    $card.Controls.Add($val)

    $sy += 68
}

# ============================================================
#  PAGE: TWEAKS
# ============================================================
$pageTweaks = New-Object System.Windows.Forms.Panel
$pageTweaks.Size = $content.Size
$pageTweaks.Location = New-Object System.Drawing.Point(0, 0)
$pageTweaks.BackColor = $Colors.Bg
$pageTweaks.Visible = $false
$content.Controls.Add($pageTweaks)

$twTitle = New-Object System.Windows.Forms.Label
$twTitle.Text = "Tweaks"
$twTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$twTitle.ForeColor = $Colors.Text
$twTitle.AutoSize = $true
$twTitle.BackColor = [System.Drawing.Color]::Transparent
$twTitle.Location = New-Object System.Drawing.Point(4, 4)
$pageTweaks.Controls.Add($twTitle)

$twSub = New-Object System.Windows.Forms.Label
$twSub.Text = "Toggle common system tweaks"
$twSub.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$twSub.ForeColor = $Colors.TextDim
$twSub.AutoSize = $true
$twSub.BackColor = [System.Drawing.Color]::Transparent
$twSub.Location = New-Object System.Drawing.Point(6, 44)
$pageTweaks.Controls.Add($twSub)

$tweaks = @(
    @{ Name = "Ultimate Performance"; Desc = "Unlock Ultimate Performance power plan"; Cmd = { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null } }
    @{ Name = "Disable Hibernation"; Desc = "Frees disk space, disables hibernate"; Cmd = { powercfg -h off } }
    @{ Name = "Disable Telemetry"; Desc = "Stops DiagTrack service"; Cmd = { Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue } }
    @{ Name = "Enable Game Mode"; Desc = "Enables Windows Game Mode"; Cmd = { Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -ErrorAction SilentlyContinue } }
    @{ Name = "Disable Xbox Game Bar"; Desc = "Removes Game Bar overlay"; Cmd = { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -ErrorAction SilentlyContinue } }
    @{ Name = "High Performance Timer"; Desc = "Enables HPET for gaming"; Cmd = { bcdedit /set useplatformclock true 2>$null } }
)

$ty = 90
foreach ($t in $tweaks) {
    $row = New-Object KenzieUI.GlowPanel
    $row.Size = New-Object System.Drawing.Size(($content.Width - 20), 58)
    $row.Location = New-Object System.Drawing.Point(4, $ty)
    $row.Radius = 12
    $row.FillColor = $Colors.Surface
    $row.BorderColor = $Colors.Border
    $pageTweaks.Controls.Add($row)

    $n = New-Object System.Windows.Forms.Label
    $n.Text = $t.Name
    $n.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $n.ForeColor = $Colors.Text
    $n.AutoSize = $true
    $n.BackColor = [System.Drawing.Color]::Transparent
    $n.Location = New-Object System.Drawing.Point(20, 10)
    $row.Controls.Add($n)

    $d = New-Object System.Windows.Forms.Label
    $d.Text = $t.Desc
    $d.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $d.ForeColor = $Colors.TextDim
    $d.AutoSize = $true
    $d.BackColor = [System.Drawing.Color]::Transparent
    $d.Location = New-Object System.Drawing.Point(20, 32)
    $row.Controls.Add($d)

    $btn = New-Object KenzieUI.ModernButton
    $btn.Text = "Run"
    $btn.Size = New-Object System.Drawing.Size(90, 36)
    $btn.Location = New-Object System.Drawing.Point(($row.Width - 110), 11)
    $btn.NormalColor = $Colors.BgAlt
    $btn.HoverColor = $Colors.SurfaceHi
    $btn.AccentColor = $Colors.Accent
    $btn.CornerRadius = 10
    $btn.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
    $cmd = $t.Cmd
    $btn.Add_Click({
        param($s, $e)
        try {
            & $cmd
            Show-Status "✓ $($s.Parent.Controls[0].Text) applied" "Success"
        } catch {
            Show-Status "✗ Error: $($_.Exception.Message)" "Error"
        }
    })
    $row.Controls.Add($btn)

    $ty += 66
}

# ============================================================
#  PAGE: ABOUT
# ============================================================
$pageAbout = New-Object System.Windows.Forms.Panel
$pageAbout.Size = $content.Size
$pageAbout.Location = New-Object System.Drawing.Point(0, 0)
$pageAbout.BackColor = $Colors.Bg
$pageAbout.Visible = $false
$content.Controls.Add($pageAbout)

$aboutCard = New-Object KenzieUI.GlowPanel
$aboutCard.Size = New-Object System.Drawing.Size(($content.Width - 40), 400)
$aboutCard.Location = New-Object System.Drawing.Point(20, 60)
$aboutCard.Radius = 20
$aboutCard.FillColor = $Colors.Surface
$aboutCard.BorderColor = $Colors.Border
$pageAbout.Controls.Add($aboutCard)

$aboutIcon = New-Object System.Windows.Forms.Label
$aboutIcon.Text = "⚡"
$aboutIcon.Font = New-Object System.Drawing.Font("Segoe UI", 60)
$aboutIcon.ForeColor = $Colors.Glow
$aboutIcon.AutoSize = $true
$aboutIcon.BackColor = [System.Drawing.Color]::Transparent
$aboutIcon.Location = New-Object System.Drawing.Point(($aboutCard.Width - 130), 20)
$aboutCard.Controls.Add($aboutIcon)

$aboutTitle = New-Object System.Windows.Forms.Label
$aboutTitle.Text = "Kenzie's Tweaks"
$aboutTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 24, [System.Drawing.FontStyle]::Bold)
$aboutTitle.ForeColor = $Colors.Text
$aboutTitle.AutoSize = $true
$aboutTitle.BackColor = [System.Drawing.Color]::Transparent
$aboutTitle.Location = New-Object System.Drawing.Point(40, 40)
$aboutCard.Controls.Add($aboutTitle)

$aboutVer = New-Object System.Windows.Forms.Label
$aboutVer.Text = "Version 1.0  ·  Modern UI"
$aboutVer.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$aboutVer.ForeColor = $Colors.TextDim
$aboutVer.AutoSize = $true
$aboutVer.BackColor = [System.Drawing.Color]::Transparent
$aboutVer.Location = New-Object System.Drawing.Point(42, 88)
$aboutCard.Controls.Add($aboutVer)

$aboutDesc = New-Object System.Windows.Forms.Label
$aboutDesc.Text = "A sleek PowerShell dashboard for`npower plan management and system tweaks.`nBuilt with WinForms + custom C# controls.`n`nCustom plan GUID:`nb7701089-9d55-49a7-90ec-f6be3a3566a9"
$aboutDesc.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$aboutDesc.ForeColor = $Colors.Text
$aboutDesc.AutoSize = $true
$aboutDesc.BackColor = [System.Drawing.Color]::Transparent
$aboutDesc.Location = New-Object System.Drawing.Point(42, 130)
$aboutCard.Controls.Add($aboutDesc)

$aboutFooter = New-Object System.Windows.Forms.Label
$aboutFooter.Text = "© Kenzie's Tweaks  ·  github.com/kenziestweaks"
$aboutFooter.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$aboutFooter.ForeColor = $Colors.TextDim
$aboutFooter.AutoSize = $true
$aboutFooter.BackColor = [System.Drawing.Color]::Transparent
$aboutFooter.Location = New-Object System.Drawing.Point(42, 340)
$aboutCard.Controls.Add($aboutFooter)

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
#  CORE ACTIONS
# ============================================================
function Update-ActivePlanDisplay {
    $activeGuid = Get-ActivePowerPlanGuid
    if ($activeGuid) {
        $plan = $PowerPlans | Where-Object { $_.Guid -eq $activeGuid } | Select-Object -First 1
        if ($plan) {
            $activeName.Text = "$($plan.Icon)  $($plan.Name)"
            $activeGuid.Text = "GUID: $($plan.Guid)"
            $activeIcon.Text = $plan.Icon
        } else {
            $activeName.Text = "🔧  Custom Plan"
            $activeGuid.Text = "GUID: $activeGuid"
            $activeIcon.Text = "🔧"
        }
        foreach ($key in $script:planButtons.Keys) {
            $script:planButtons[$key].IsActive = ($key -eq $activeGuid)
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
        Show-Status "⚠ Administrator privileges required" "Error"
        return
    }

    $orig = $Button.Text
    $Button.Text = "⏳  Applying..."
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
            Show-Status "✓ Power plan applied" "Success"
            Start-Sleep -Milliseconds 120
            Update-ActivePlanDisplay
        } else {
            Show-Status "✗ Failed to apply power plan" "Error"
        }
    } catch {
        Show-Status "✗ $($_.Exception.Message)" "Error"
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
    while ($loadingPanel.Visible) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 30
    }
    Update-ActivePlanDisplay
    $form.Activate()
})

$form.Add_FormClosing({
    if ($loadingTimer) { $loadingTimer.Stop(); $loadingTimer.Dispose() }
})

# ============================================================
#  RUN
# ============================================================
[void]$form.ShowDialog()
