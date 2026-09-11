#Requires -Version 5.1
<#
    Kenzie's Tweaks v2 - Ultra Modern Dashboard
    PS 5.1 + PS 7 compatible
#>

# ============================================================
#  AUTO-ELEVATE
# ============================================================
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
$script:isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $script:isAdmin) {
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
    Bg        = [System.Drawing.Color]::FromArgb(8, 10, 16)
    BgAlt     = [System.Drawing.Color]::FromArgb(14, 17, 26)
    Surface   = [System.Drawing.Color]::FromArgb(20, 26, 38)
    SurfaceHi = [System.Drawing.Color]::FromArgb(30, 38, 54)
    Border    = [System.Drawing.Color]::FromArgb(42, 54, 74)
    Accent    = [System.Drawing.Color]::FromArgb(60, 140, 255)
    Accent2   = [System.Drawing.Color]::FromArgb(140, 80, 255)
    Glow      = [System.Drawing.Color]::FromArgb(90, 200, 255)
    Cyan      = [System.Drawing.Color]::FromArgb(80, 240, 255)
    Pink      = [System.Drawing.Color]::FromArgb(255, 120, 200)
    Text      = [System.Drawing.Color]::FromArgb(240, 246, 255)
    TextMid   = [System.Drawing.Color]::FromArgb(180, 198, 220)
    TextDim   = [System.Drawing.Color]::FromArgb(130, 150, 178)
    Success   = [System.Drawing.Color]::FromArgb(50, 220, 150)
    Warning   = [System.Drawing.Color]::FromArgb(255, 190, 70)
    Danger    = [System.Drawing.Color]::FromArgb(255, 90, 110)
}

# ============================================================
#  POWER PLANS
# ============================================================
$script:PowerPlans = @(
    @{ Name = "Kenzie's Custom";      Guid = "b7701089-9d55-49a7-90ec-f6be3a3566a9"; Tag = "K" }
    @{ Name = "Ultimate Performance"; Guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"; Tag = "U" }
    @{ Name = "High Performance";     Guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; Tag = "H" }
    @{ Name = "Balanced";             Guid = "381b4222-f694-41f0-9685-ff5bb260df2e"; Tag = "B" }
    @{ Name = "Power Saver";          Guid = "a1841308-3541-4fab-bc81-f71556f20b4a"; Tag = "P" }
)

# ============================================================
#  C# CONTROLS
# ============================================================
if (-not ("KTUI" -as [type])) {
    $cs = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public static class KTUI
{
    public static GraphicsPath Round(Rectangle r, int radius)
    {
        GraphicsPath p = new GraphicsPath();
        int d = radius * 2;
        if (d > r.Width) d = r.Width;
        if (d > r.Height) d = r.Height;
        if (d < 1) d = 1;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    public static Color Blend(Color a, Color b, float t)
    {
        if (t < 0) t = 0; if (t > 1) t = 1;
        return Color.FromArgb(
            (int)(a.A + (b.A - a.A) * t),
            (int)(a.R + (b.R - a.R) * t),
            (int)(a.G + (b.G - a.G) * t),
            (int)(a.B + (b.B - a.B) * t));
    }
}

public class KCard : Panel
{
    private int _radius = 16;
    private Color _fill = Color.FromArgb(20, 26, 38);
    private Color _border = Color.FromArgb(42, 54, 74);
    private bool _hoverGlow = true;
    private float _glowAmt = 0f;
    private Timer _t;

    public int Radius { get { return _radius; } set { _radius = value; Invalidate(); } }
    public Color FillColor { get { return _fill; } set { _fill = value; Invalidate(); } }
    public Color BorderColor { get { return _border; } set { _border = value; Invalidate(); } }
    public bool HoverGlow { get { return _hoverGlow; } set { _hoverGlow = value; } }

    public KCard()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        _t = new Timer();
        _t.Interval = 30;
        _t.Tick += new EventHandler(Tick);
        _t.Start();
    }

    private void Tick(object s, EventArgs e)
    {
        float target = (_hoverGlow && ClientRectangle.Contains(PointToClient(Cursor.Position))) ? 1f : 0f;
        _glowAmt += (target - _glowAmt) * 0.18f;
        if (Math.Abs(_glowAmt - target) < 0.01f) _glowAmt = target;
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
        GraphicsPath path = KTUI.Round(r, _radius);
        try
        {
            using (SolidBrush b = new SolidBrush(_fill))
                g.FillPath(b, path);
            Color bc = KTUI.Blend(_border, Color.FromArgb(90, 200, 255), _glowAmt);
            using (Pen p = new Pen(bc, 1f + _glowAmt * 1.2f))
                g.DrawPath(p, path);
            if (_glowAmt > 0.05f)
            {
                using (Pen gp = new Pen(Color.FromArgb((int)(_glowAmt * 60), 90, 200, 255), 6f))
                    g.DrawPath(gp, path);
            }
        }
        finally { path.Dispose(); }
    }
}

public class KButton : Button
{
    private Color _normal = Color.FromArgb(24, 30, 44);
    private Color _hover = Color.FromArgb(38, 50, 72);
    private Color _accent = Color.FromArgb(60, 140, 255);
    private Color _textColor = Color.FromArgb(240, 246, 255);
    private int _radius = 14;
    private bool _active;
    private bool _hovering;
    private float _glow;
    private Timer _t;

    public Color NormalColor { get { return _normal; } set { _normal = value; Invalidate(); } }
    public Color HoverColor { get { return _hover; } set { _hover = value; Invalidate(); } }
    public Color AccentColor { get { return _accent; } set { _accent = value; Invalidate(); } }
    public Color TextColor { get { return _textColor; } set { _textColor = value; Invalidate(); } }
    public int Radius { get { return _radius; } set { _radius = value; Invalidate(); } }
    public bool IsActive { get { return _active; } set { _active = value; Invalidate(); } }

    public KButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        Font = new Font("Segoe UI Semibold", 10f, FontStyle.Bold);
        Cursor = Cursors.Hand;
        _t = new Timer();
        _t.Interval = 25;
        _t.Tick += new EventHandler(Tick);
        _t.Start();
    }

    private void Tick(object s, EventArgs e)
    {
        float tgt = _hovering ? 1f : 0f;
        _glow += (tgt - _glow) * 0.22f;
        if (Math.Abs(_glow - tgt) < 0.01f) _glow = tgt;
        Invalidate();
    }

    protected override void OnMouseEnter(EventArgs e) { _hovering = true; base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { _hovering = false; base.OnMouseLeave(e); }

    protected override void OnPaint(PaintEventArgs pevent)
    {
        Graphics g = pevent.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
        GraphicsPath path = KTUI.Round(r, _radius);
        try
        {
            if (_active)
            {
                using (LinearGradientBrush lg = new LinearGradientBrush(r,
                    Color.FromArgb(60, 140, 255), Color.FromArgb(140, 80, 255),
                    LinearGradientMode.Horizontal))
                    g.FillPath(lg, path);
            }
            else
            {
                Color fill = KTUI.Blend(_normal, _hover, _glow);
                using (SolidBrush b = new SolidBrush(fill))
                    g.FillPath(b, path);
            }
            Color bc = _active
                ? Color.FromArgb(180, 220, 255)
                : KTUI.Blend(Color.FromArgb(42, 54, 74), _accent, _glow * 0.9f);
            using (Pen p = new Pen(bc, _active ? 1.6f : 1.2f))
                g.DrawPath(p, path);
            if (_active || _glow > 0.3f)
            {
                int a = _active ? 90 : (int)(_glow * 60);
                using (Pen gp = new Pen(Color.FromArgb(a, 90, 200, 255), 6f))
                    g.DrawPath(gp, path);
            }
        }
        finally { path.Dispose(); }
        TextRenderer.DrawText(g, Text, Font, r, _active ? Color.White : _textColor,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
    }
}

public class KBar : Control
{
    private float _value = 0f;
    private float _anim = 0f;
    private Color _c1 = Color.FromArgb(60, 140, 255);
    private Color _c2 = Color.FromArgb(80, 240, 255);
    private Timer _t;

    public float Value { get { return _value; } set { _value = value; } }
    public Color ColorFrom { get { return _c1; } set { _c1 = value; Invalidate(); } }
    public Color ColorTo { get { return _c2; } set { _c2 = value; Invalidate(); } }

    public KBar()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        _t = new Timer();
        _t.Interval = 16;
        _t.Tick += new EventHandler(Tick);
        _t.Start();
    }

    private void Tick(object s, EventArgs e)
    {
        float tgt = Math.Min(_value, 100f) / 100f;
        _anim += (tgt - _anim) * 0.15f;
        if (Math.Abs(_anim - tgt) < 0.001f) _anim = tgt;
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        int r = Height / 2;
        Rectangle full = new Rectangle(0, 0, Width - 1, Height - 1);
        GraphicsPath fullPath = KTUI.Round(full, r);
        using (SolidBrush bg = new SolidBrush(Color.FromArgb(30, 38, 54)))
            g.FillPath(bg, fullPath);
        fullPath.Dispose();
        int fillW = (int)(Width * _anim);
        if (fillW > 4)
        {
            Rectangle fr = new Rectangle(0, 0, fillW, Height - 1);
            GraphicsPath fp = KTUI.Round(fr, r);
            using (LinearGradientBrush lb = new LinearGradientBrush(
                new Rectangle(0, 0, Math.Max(fillW, 2), Height),
                _c1, _c2, LinearGradientMode.Horizontal))
                g.FillPath(lb, fp);
            fp.Dispose();
        }
    }
}

public class KSpark : Control
{
    private System.Collections.Generic.List<float> _pts =
        new System.Collections.Generic.List<float>();
    private int _maxPts = 60;
    private Color _line = Color.FromArgb(80, 240, 255);
    private Color _fill = Color.FromArgb(30, 200, 255);

    public Color LineColor { get { return _line; } set { _line = value; Invalidate(); } }
    public Color FillColor { get { return _fill; } set { _fill = value; Invalidate(); } }
    public int MaxPoints { get { return _maxPts; } set { _maxPts = value; } }

    public KSpark()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
    }

    public void Push(float v) { _pts.Add(v); while (_pts.Count > _maxPts) _pts.RemoveAt(0); Invalidate(); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        if (_pts.Count < 2) return;
        float step = (float)Width / (_maxPts - 1);
        PointF[] pts = new PointF[_pts.Count];
        int off = _maxPts - _pts.Count;
        for (int i = 0; i < _pts.Count; i++)
        {
            float x = (off + i) * step;
            float y = Height - (_pts[i] / 100f) * Height;
            if (y < 0) y = 0; if (y > Height) y = Height;
            pts[i] = new PointF(x, y);
        }
        PointF[] fillPts = new PointF[pts.Length + 2];
        Array.Copy(pts, fillPts, pts.Length);
        fillPts[pts.Length] = new PointF(pts[pts.Length - 1].X, Height);
        fillPts[pts.Length + 1] = new PointF(pts[0].X, Height);
        using (SolidBrush fb = new SolidBrush(Color.FromArgb(40, _fill)))
            g.FillPolygon(fb, fillPts);
        using (Pen p = new Pen(_line, 1.8f))
            g.DrawLines(p, pts);
    }
}
"@
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $cs -Language CSharp
}

# ============================================================
#  HELPERS
# ============================================================
function Enable-DoubleBuffer {
    param([System.Windows.Forms.Control]$c)
    try {
        $p = [System.Windows.Forms.Control].GetProperty("DoubleBuffered",
            [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
        if ($p) { $p.SetValue($c, $true, $null) }
    } catch { }
}

function Get-ActivePlanGuid {
    try {
        $o = powercfg /getactivescheme 2>$null
        if ($o -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
            return $matches[1].ToLower()
        }
    } catch { }
    return $null
}

function New-Label {
    param($parent, $text, $x, $y, $size = 10, $color = $null, $bold = $false, $width = 0, $height = 0)
    if (-not $color) { $color = $C.Text }
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $l.Font = New-Object System.Drawing.Font("Segoe UI", $size, $style)
    $l.ForeColor = $color
    $l.BackColor = [System.Drawing.Color]::Transparent
    if ($width -gt 0) {
        $l.AutoSize = $false
        $l.Size = New-Object System.Drawing.Size($width, $height)
    } else {
        $l.AutoSize = $true
    }
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $parent.Controls.Add($l)
    return $l
}

# ============================================================
#  FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Kenzie's Tweaks"
$form.Size = New-Object System.Drawing.Size(1100, 720)
$form.StartPosition = "CenterScreen"
$form.BackColor = $C.Bg
$form.ForeColor = $C.Text
$form.FormBorderStyle = "None"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
Enable-DoubleBuffer $form

$form.Add_Resize({
    $r = 22
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
$titleBar.Size = New-Object System.Drawing.Size($form.Width, 52)
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

$brandLogo = New-Object System.Windows.Forms.Label
$brandLogo.Text = "KT"
$brandLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
$brandLogo.ForeColor = [System.Drawing.Color]::White
$brandLogo.AutoSize = $false
$brandLogo.Size = New-Object System.Drawing.Size(38, 38)
$brandLogo.Location = New-Object System.Drawing.Point(14, 7)
$brandLogo.TextAlign = "MiddleCenter"
$brandLogo.BackColor = $C.Accent
$titleBar.Controls.Add($brandLogo)

$brandTitle = New-Object System.Windows.Forms.Label
$brandTitle.Text = "Kenzie's Tweaks"
$brandTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
$brandTitle.ForeColor = $C.Text
$brandTitle.AutoSize = $true
$brandTitle.BackColor = [System.Drawing.Color]::Transparent
$brandTitle.Location = New-Object System.Drawing.Point(60, 9)
$titleBar.Controls.Add($brandTitle)

$brandSub = New-Object System.Windows.Forms.Label
$brandSub.Text = "Ultra Performance Dashboard"
$brandSub.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$brandSub.ForeColor = $C.TextDim
$brandSub.AutoSize = $true
$brandSub.BackColor = [System.Drawing.Color]::Transparent
$brandSub.Location = New-Object System.Drawing.Point(62, 30)
$titleBar.Controls.Add($brandSub)

function New-Tb {
    param([string]$Glyph, [int]$X, [System.Drawing.Color]$Hover)
    $b = New-Object System.Windows.Forms.Label
    $b.Text = $Glyph
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $b.ForeColor = $C.TextDim
    $b.BackColor = [System.Drawing.Color]::Transparent
    $b.Size = New-Object System.Drawing.Size(46, 52)
    $b.Location = New-Object System.Drawing.Point($X, 0)
    $b.TextAlign = "MiddleCenter"
    $b.Cursor = "Hand"
    $script:hoverColor = $Hover
    $b.Add_MouseEnter({
        param($s, $e)
        $s.ForeColor = $script:hoverColor
        $s.BackColor = $C.Surface
    })
    $b.Add_MouseLeave({
        param($s, $e)
        $s.ForeColor = $C.TextDim
        $s.BackColor = [System.Drawing.Color]::Transparent
    })
    return $b
}

$btnMin = New-Tb "_" ($form.Width - 92) $C.Glow
$btnMin.Add_Click({ $form.WindowState = "Minimized" })
$titleBar.Controls.Add($btnMin)

$btnClose = New-Tb "X" ($form.Width - 46) $C.Danger
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
$lLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 44, [System.Drawing.FontStyle]::Bold)
$lLogo.ForeColor = [System.Drawing.Color]::White
$lLogo.AutoSize = $false
$lLogo.Size = New-Object System.Drawing.Size(140, 140)
$lLogo.Location = New-Object System.Drawing.Point(480, 200)
$lLogo.TextAlign = "MiddleCenter"
$lLogo.BackColor = $C.Accent
$loading.Controls.Add($lLogo)

$lTitle = New-Object System.Windows.Forms.Label
$lTitle.Text = "Kenzie's Tweaks"
$lTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 26, [System.Drawing.FontStyle]::Bold)
$lTitle.ForeColor = $C.Text
$lTitle.AutoSize = $true
$lTitle.BackColor = [System.Drawing.Color]::Transparent
$lTitle.Location = New-Object System.Drawing.Point(390, 370)
$loading.Controls.Add($lTitle)

$lSub = New-Object System.Windows.Forms.Label
$lSub.Text = "Ultra Performance Dashboard"
$lSub.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lSub.ForeColor = $C.TextDim
$lSub.AutoSize = $true
$lSub.BackColor = [System.Drawing.Color]::Transparent
$lSub.Location = New-Object System.Drawing.Point(462, 415)
$loading.Controls.Add($lSub)

$lStatus = New-Object System.Windows.Forms.Label
$lStatus.Text = "Initializing..."
$lStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lStatus.ForeColor = $C.TextMid
$lStatus.AutoSize = $true
$lStatus.BackColor = [System.Drawing.Color]::Transparent
$lStatus.Location = New-Object System.Drawing.Point(490, 465)
$loading.Controls.Add($lStatus)

$lBarBg = New-Object System.Windows.Forms.Panel
$lBarBg.Size = New-Object System.Drawing.Size(380, 4)
$lBarBg.Location = New-Object System.Drawing.Point(360, 495)
$lBarBg.BackColor = $C.Surface
$loading.Controls.Add($lBarBg)

$lBarFill = New-Object System.Windows.Forms.Panel
$lBarFill.Size = New-Object System.Drawing.Size(0, 4)
$lBarFill.Location = New-Object System.Drawing.Point(0, 0)
$lBarFill.BackColor = $C.Accent
$lBarBg.Controls.Add($lBarFill)

$script:loadSteps = @(
    "Initializing engine...",
    "Checking privileges...",
    "Enumerating hardware...",
    "Loading power profiles...",
    "Rendering interface...",
    "Ready."
)
$script:loadPct = 0

$loadTimer = New-Object System.Windows.Forms.Timer
$loadTimer.Interval = 22
$loadTimer.Add_Tick({
    $script:loadPct += 2
    if ($script:loadPct -gt 100) { $script:loadPct = 100 }
    $lBarFill.Width = [int](380 * ($script:loadPct / 100))
    $idx = [Math]::Min([int]($script:loadPct / 17), $script:loadSteps.Count - 1)
    $lStatus.Text = $script:loadSteps[$idx]
    if ($script:loadPct -ge 100) {
        $loadTimer.Stop()
        Start-Sleep -Milliseconds 200
        $loading.Visible = $false
        $loading.SendToBack()
        Update-ActivePlanDisplay
    }
})
$loadTimer.Start()

# ============================================================
#  LAYOUT
# ============================================================
$main = New-Object System.Windows.Forms.Panel
$main.Size = New-Object System.Drawing.Size($form.Width, ($form.Height - 52))
$main.Location = New-Object System.Drawing.Point(0, 52)
$main.BackColor = $C.Bg
$form.Controls.Add($main)

# Sidebar
$sidebar = New-Object KCard
$sidebar.Size = New-Object System.Drawing.Size(230, ($main.Height - 24))
$sidebar.Location = New-Object System.Drawing.Point(12, 12)
$sidebar.FillColor = $C.BgAlt
$sidebar.BorderColor = $C.Border
$sidebar.Radius = 18
$sidebar.HoverGlow = $false
$main.Controls.Add($sidebar)

$sideBadge = New-Object System.Windows.Forms.Label
$sideBadge.Text = "KT"
$sideBadge.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 20, [System.Drawing.FontStyle]::Bold)
$sideBadge.ForeColor = [System.Drawing.Color]::White
$sideBadge.AutoSize = $false
$sideBadge.Size = New-Object System.Drawing.Size(58, 58)
$sideBadge.Location = New-Object System.Drawing.Point(22, 22)
$sideBadge.TextAlign = "MiddleCenter"
$sideBadge.BackColor = $C.Accent
$sidebar.Controls.Add($sideBadge)

$sideName = New-Object System.Windows.Forms.Label
$sideName.Text = "Kenzie's`nTweaks"
$sideName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13, [System.Drawing.FontStyle]::Bold)
$sideName.ForeColor = $C.Text
$sideName.AutoSize = $true
$sideName.BackColor = [System.Drawing.Color]::Transparent
$sideName.Location = New-Object System.Drawing.Point(92, 30)
$sidebar.Controls.Add($sideName)

$adminCard = New-Object KCard
$adminCard.Size = New-Object System.Drawing.Size(190, 36)
$adminCard.Location = New-Object System.Drawing.Point(20, 105)
$adminCard.Radius = 10
$adminCard.HoverGlow = $false
$adminCard.FillColor = if ($isAdmin) { [System.Drawing.Color]::FromArgb(16, 44, 32) } else { [System.Drawing.Color]::FromArgb(44, 34, 12) }
$adminCard.BorderColor = if ($isAdmin) { $C.Success } else { $C.Warning }
$sidebar.Controls.Add($adminCard)

$adminTxt = New-Object System.Windows.Forms.Label
$adminTxt.Text = if ($isAdmin) { "ADMINISTRATOR" } else { "LIMITED MODE" }
$adminTxt.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$adminTxt.ForeColor = if ($isAdmin) { $C.Success } else { $C.Warning }
$adminTxt.AutoSize = $true
$adminTxt.BackColor = [System.Drawing.Color]::Transparent
$adminTxt.Location = New-Object System.Drawing.Point(18, 9)
$adminCard.Controls.Add($adminTxt)

$navLabel = New-Object System.Windows.Forms.Label
$navLabel.Text = "NAVIGATION"
$navLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 7.5, [System.Drawing.FontStyle]::Bold)
$navLabel.ForeColor = $C.TextDim
$navLabel.AutoSize = $true
$navLabel.BackColor = [System.Drawing.Color]::Transparent
$navLabel.Location = New-Object System.Drawing.Point(24, 165)
$sidebar.Controls.Add($navLabel)

$script:navButtons = @{}
$navItems = @(
    @{ Key = "dashboard"; Label = "Dashboard" }
    @{ Key = "power";     Label = "Power Plans" }
    @{ Key = "system";    Label = "System Info" }
    @{ Key = "processes"; Label = "Processes" }
    @{ Key = "tweaks";    Label = "Tweaks" }
    @{ Key = "about";     Label = "About" }
)

$navY = 190
foreach ($nav in $navItems) {
    $nb = New-Object KButton
    $nb.Text = $nav.Label
    $nb.Size = New-Object System.Drawing.Size(190, 42)
    $nb.Location = New-Object System.Drawing.Point(20, $navY)
    $nb.NormalColor = $C.BgAlt
    $nb.HoverColor = $C.SurfaceHi
    $nb.AccentColor = $C.Accent
    $nb.TextColor = $C.TextMid
    $nb.Radius = 12
    $nb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $nb.Tag = $nav.Key
    $sidebar.Controls.Add($nb)
    $script:navButtons[$nav.Key] = $nb
    $navY += 48
}

# Content
$content = New-Object System.Windows.Forms.Panel
$content.Size = New-Object System.Drawing.Size(($main.Width - 266), ($main.Height - 24))
$content.Location = New-Object System.Drawing.Point(254, 12)
$content.BackColor = $C.Bg
$main.Controls.Add($content)

# ============================================================
#  PAGE: DASHBOARD
# ============================================================
$pageDash = New-Object System.Windows.Forms.Panel
$pageDash.Size = $content.Size
$pageDash.Location = New-Object System.Drawing.Point(0, 0)
$pageDash.BackColor = $C.Bg
$content.Controls.Add($pageDash)

New-Label $pageDash "Dashboard" 4 4 22 $C.Text $true | Out-Null
New-Label $pageDash "Live system performance overview" 6 44 9.5 $C.TextDim | Out-Null

# CPU Card
$cpuCard = New-Object KCard
$cpuCard.Size = New-Object System.Drawing.Size((($content.Width - 30) / 2), 150)
$cpuCard.Location = New-Object System.Drawing.Point(4, 80)
$cpuCard.FillColor = $C.Surface
$cpuCard.BorderColor = $C.Border
$pageDash.Controls.Add($cpuCard)

New-Label $cpuCard "CPU" 20 16 10 $C.TextDim $true | Out-Null
$cpuPct = New-Label $cpuCard "0%" 20 36 28 $C.Text $true | Out-Null
$cpuBar = New-Object KBar
$cpuBar.Size = New-Object System.Drawing.Size(($cpuCard.Width - 40), 8)
$cpuBar.Location = New-Object System.Drawing.Point(20, 92)
$cpuBar.ColorFrom = $C.Accent
$cpuBar.ColorTo = $C.Cyan
$cpuCard.Controls.Add($cpuBar)
$cpuSpark = New-Object KSpark
$cpuSpark.Size = New-Object System.Drawing.Size(($cpuCard.Width - 40), 30)
$cpuSpark.Location = New-Object System.Drawing.Point(20, 110)
$cpuSpark.LineColor = $C.Cyan
$cpuSpark.FillColor = $C.Accent
$cpuCard.Controls.Add($cpuSpark)

# RAM Card
$ramCard = New-Object KCard
$ramCard.Size = New-Object System.Drawing.Size((($content.Width - 30) / 2), 150)
$ramCard.Location = New-Object System.Drawing.Point(4 + (($content.Width - 30) / 2) + 10, 80)
$ramCard.FillColor = $C.Surface
$ramCard.BorderColor = $C.Border
$pageDash.Controls.Add($ramCard)

New-Label $ramCard "MEMORY" 20 16 10 $C.TextDim $true | Out-Null
$ramPct = New-Label $ramCard "0%" 20 36 28 $C.Text $true | Out-Null
$ramBar = New-Object KBar
$ramBar.Size = New-Object System.Drawing.Size(($ramCard.Width - 40), 8)
$ramBar.Location = New-Object System.Drawing.Point(20, 92)
$ramBar.ColorFrom = $C.Accent2
$ramBar.ColorTo = $C.Pink
$ramCard.Controls.Add($ramBar)
$ramSpark = New-Object KSpark
$ramSpark.Size = New-Object System.Drawing.Size(($ramCard.Width - 40), 30)
$ramSpark.Location = New-Object System.Drawing.Point(20, 110)
$ramSpark.LineColor = $C.Pink
$ramSpark.FillColor = $C.Accent2
$ramCard.Controls.Add($ramSpark)

# Top processes card
$procCard = New-Object KCard
$procCard.Size = New-Object System.Drawing.Size(($content.Width - 8), 240)
$procCard.Location = New-Object System.Drawing.Point(4, 240)
$procCard.FillColor = $C.Surface
$procCard.BorderColor = $C.Border
$procCard.HoverGlow = $false
$pageDash.Controls.Add($procCard)

New-Label $procCard "TOP PROCESSES BY CPU" 20 16 10 $C.TextDim $true | Out-Null

$procList = New-Object System.Windows.Forms.Label
$procList.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$procList.ForeColor = $C.TextMid
$procList.BackColor = [System.Drawing.Color]::Transparent
$procList.AutoSize = $false
$procList.Size = New-Object System.Drawing.Size(($procCard.Width - 40), 200)
$procList.Location = New-Object System.Drawing.Point(20, 42)
$procCard.Controls.Add($procList)

# ============================================================
#  PAGE: POWER
# ============================================================
$pagePower = New-Object System.Windows.Forms.Panel
$pagePower.Size = $content.Size
$pagePower.Location = New-Object System.Drawing.Point(0, 0)
$pagePower.BackColor = $C.Bg
$pagePower.Visible = $false
$content.Controls.Add($pagePower)

New-Label $pagePower "Power Plans" 4 4 22 $C.Text $true | Out-Null
New-Label $pagePower "Switch between performance profiles instantly" 6 44 9.5 $C.TextDim | Out-Null

$activeCard = New-Object KCard
$activeCard.Size = New-Object System.Drawing.Size(($content.Width - 20), 110)
$activeCard.Location = New-Object System.Drawing.Point(4, 80)
$activeCard.Radius = 18
$activeCard.FillColor = $C.Surface
$activeCard.BorderColor = $C.Accent
$activeCard.HoverGlow = $false
$pagePower.Controls.Add($activeCard)

New-Label $activeCard "ACTIVE POWER PLAN" 115 22 8 $C.TextDim $true | Out-Null

$activeNameLbl = New-Object System.Windows.Forms.Label
$activeNameLbl.Text = "Detecting..."
$activeNameLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16, [System.Drawing.FontStyle]::Bold)
$activeNameLbl.ForeColor = $C.Text
$activeNameLbl.AutoSize = $true
$activeNameLbl.BackColor = [System.Drawing.Color]::Transparent
$activeNameLbl.Location = New-Object System.Drawing.Point(115, 44)
$activeCard.Controls.Add($activeNameLbl)

$activeGuidLbl = New-Object System.Windows.Forms.Label
$activeGuidLbl.Text = ""
$activeGuidLbl.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$activeGuidLbl.ForeColor = $C.TextDim
$activeGuidLbl.AutoSize = $true
$activeGuidLbl.BackColor = [System.Drawing.Color]::Transparent
$activeGuidLbl.Location = New-Object System.Drawing.Point(117, 78)
$activeCard.Controls.Add($activeGuidLbl)

$script:planButtons = @{}
$planY = 210
$planX = 4
$col = 0
foreach ($plan in $PowerPlans) {
    $pb = New-Object KButton
    $pb.Text = "[$($plan.Tag)]  $($plan.Name)"
    $pb.Size = New-Object System.Drawing.Size(220, 68)
    $pb.Location = New-Object System.Drawing.Point($planX, $planY)
    $pb.NormalColor = $C.Surface
    $pb.HoverColor = $C.SurfaceHi
    $pb.AccentColor = $C.Accent
    $pb.TextColor = $C.Text
    $pb.Radius = 14
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

New-Label $pageSystem "System Information" 4 4 22 $C.Text $true | Out-Null
New-Label $pageSystem "Hardware and OS details" 6 44 9.5 $C.TextDim | Out-Null

$sysData = @()
try {
    $cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name
    $ramBytes = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory
    $gpu = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1).Name
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $mobo = (Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue).Product
    $sysData = @(
        @{ L = "CPU";         V = if ($cpu) { $cpu.Trim() } else { "Unknown" } }
        @{ L = "RAM";         V = if ($ramBytes) { "{0:N1} GB" -f ($ramBytes / 1GB) } else { "Unknown" } }
        @{ L = "GPU";         V = if ($gpu) { $gpu } else { "Unknown" } }
        @{ L = "Motherboard"; V = if ($mobo) { $mobo } else { "Unknown" } }
        @{ L = "OS";          V = if ($os) { "$($os.Caption) ($($os.Version))" } else { "Unknown" } }
        @{ L = "User";        V = $env:USERNAME }
    )
} catch { }

$sy = 80
foreach ($f in $sysData) {
    $card = New-Object KCard
    $card.Size = New-Object System.Drawing.Size(($content.Width - 20), 58)
    $card.Location = New-Object System.Drawing.Point(4, $sy)
    $card.Radius = 12
    $card.FillColor = $C.Surface
    $card.BorderColor = $C.Border
    $pageSystem.Controls.Add($card)

    New-Label $card $f.L.ToUpper() 20 10 8 $C.TextDim $true | Out-Null
    New-Label $card $f.V 20 28 10 $C.Text | Out-Null

    $sy += 66
}

# ============================================================
#  PAGE: PROCESSES
# ============================================================
$pageProc = New-Object System.Windows.Forms.Panel
$pageProc.Size = $content.Size
$pageProc.Location = New-Object System.Drawing.Point(0, 0)
$pageProc.BackColor = $C.Bg
$pageProc.Visible = $false
$content.Controls.Add($pageProc)

New-Label $pageProc "Processes" 4 4 22 $C.Text $true | Out-Null
New-Label $pageProc "Top consumers - auto-refreshing" 6 44 9.5 $C.TextDim | Out-Null

$procBigCard = New-Object KCard
$procBigCard.Size = New-Object System.Drawing.Size(($content.Width - 8), ($content.Height - 90))
$procBigCard.Location = New-Object System.Drawing.Point(4, 76)
$procBigCard.FillColor = $C.Surface
$procBigCard.BorderColor = $C.Border
$procBigCard.HoverGlow = $false
$pageProc.Controls.Add($procBigCard)

$procGrid = New-Object System.Windows.Forms.Label
$procGrid.Font = New-Object System.Drawing.Font("Consolas", 10)
$procGrid.ForeColor = $C.TextMid
$procGrid.BackColor = [System.Drawing.Color]::Transparent
$procGrid.AutoSize = $false
$procGrid.Size = New-Object System.Drawing.Size(($procBigCard.Width - 40), ($procBigCard.Height - 40))
$procGrid.Location = New-Object System.Drawing.Point(20, 20)
$procBigCard.Controls.Add($procGrid)

# ============================================================
#  PAGE: TWEAKS
# ============================================================
$pageTweaks = New-Object System.Windows.Forms.Panel
$pageTweaks.Size = $content.Size
$pageTweaks.Location = New-Object System.Drawing.Point(0, 0)
$pageTweaks.BackColor = $C.Bg
$pageTweaks.Visible = $false
$content.Controls.Add($pageTweaks)

New-Label $pageTweaks "Tweaks" 4 4 22 $C.Text $true | Out-Null
New-Label $pageTweaks "One-click system optimizations" 6 44 9.5 $C.TextDim | Out-Null

$tweaks = @(
    @{ N = "Unlock Ultimate Performance"; C = { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null } }
    @{ N = "Disable Hibernation";         C = { powercfg -h off } }
    @{ N = "Disable Telemetry";           C = { Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue } }
    @{ N = "Enable Game Mode";            C = { if (-not (Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }; Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 -ErrorAction SilentlyContinue } }
    @{ N = "Disable Xbox Game Bar";       C = { if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR')) { New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null }; Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 -ErrorAction SilentlyContinue } }
)

$ty = 80
foreach ($t in $tweaks) {
    $row = New-Object KCard
    $row.Size = New-Object System.Drawing.Size(($content.Width - 20), 58)
    $row.Location = New-Object System.Drawing.Point(4, $ty)
    $row.Radius = 12
    $row.FillColor = $C.Surface
    $row.BorderColor = $C.Border
    $pageTweaks.Controls.Add($row)

    New-Label $row $t.N 20 18 10.5 $C.Text $true | Out-Null

    $btn = New-Object KButton
    $btn.Text = "Run"
    $btn.Size = New-Object System.Drawing.Size(90, 34)
    $btn.Location = New-Object System.Drawing.Point(($row.Width - 108), 12)
    $btn.NormalColor = $C.BgAlt
    $btn.HoverColor = $C.SurfaceHi
    $btn.AccentColor = $C.Accent
    $btn.Radius = 10
    $btn.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
    $cmd = $t.C
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
    $ty += 66
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

New-Label $pageAbout "About" 4 4 22 $C.Text $true | Out-Null

$aboutCard = New-Object KCard
$aboutCard.Size = New-Object System.Drawing.Size(($content.Width - 40), 380)
$aboutCard.Location = New-Object System.Drawing.Point(4, 60)
$aboutCard.Radius = 20
$aboutCard.FillColor = $C.Surface
$aboutCard.BorderColor = $C.Border
$aboutCard.HoverGlow = $false
$pageAbout.Controls.Add($aboutCard)

$aboutLogo = New-Object System.Windows.Forms.Label
$aboutLogo.Text = "KT"
$aboutLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 36, [System.Drawing.FontStyle]::Bold)
$aboutLogo.ForeColor = [System.Drawing.Color]::White
$aboutLogo.AutoSize = $false
$aboutLogo.Size = New-Object System.Drawing.Size(110, 110)
$aboutLogo.Location = New-Object System.Drawing.Point(30, 30)
$aboutLogo.TextAlign = "MiddleCenter"
$aboutLogo.BackColor = $C.Accent
$aboutCard.Controls.Add($aboutLogo)

New-Label $aboutCard "Kenzie's Tweaks" 170 40 24 $C.Text $true | Out-Null
New-Label $aboutCard "Version 2.0 - Ultra Modern UI" 172 85 10 $C.TextDim | Out-Null
New-Label $aboutCard "A sleek PowerShell dashboard for`npower plan management and system monitoring.`nBuilt with WinForms + custom C# controls.`n`nCustom plan GUID:`nb7701089-9d55-49a7-90ec-f6be3a3566a9" 172 115 10.5 $C.TextMid | Out-Null
New-Label $aboutCard "github.com/kenziestweaks" 172 320 9 $C.TextDim | Out-Null

# ============================================================
#  NAVIGATION
# ============================================================
$script:pages = @{
    dashboard = $pageDash
    power     = $pagePower
    system    = $pageSystem
    processes = $pageProc
    tweaks    = $pageTweaks
    about     = $pageAbout
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
    $ag = Get-ActivePlanGuid
    if ($ag) {
        $plan = $PowerPlans | Where-Object { $_.Guid -eq $ag } | Select-Object -First 1
        if ($plan) {
            $activeNameLbl.Text = "[$($plan.Tag)]  $($plan.Name)"
            $activeGuidLbl.Text = "GUID: $($plan.Guid)"
        } else {
            $activeNameLbl.Text = "Custom Plan"
            $activeGuidLbl.Text = "GUID: $ag"
        }
        foreach ($key in $script:planButtons.Keys) {
            $script:planButtons[$key].IsActive = ($key -eq $ag)
        }
    }
}

function Show-Status {
    param([string]$Message, [string]$Type = "Success")
    $col = switch ($Type) {
        "Success" { $C.Success }
        "Error"   { $C.Danger }
        "Warning" { $C.Warning }
        default   { $C.Text }
    }
    $statusLabel.ForeColor = $col
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
    if (-not $script:isAdmin) {
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
            Start-Sleep -Milliseconds 100
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
#  LIVE MONITOR TIMER
# ============================================================
$monTimer = New-Object System.Windows.Forms.Timer
$monTimer.Interval = 1000
$monTimer.Add_Tick({
    try {
        $cpuVal = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average).Average
        if (-not $cpuVal) { $cpuVal = 0 }
        $cpuPct.Text = "$([int]$cpuVal)%"
        $cpuBar.Value = $cpuVal
        $cpuSpark.Push([float]$cpuVal)

        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $used = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
            $ramVal = [math]::Round(($used / $os.TotalVisibleMemorySize) * 100, 1)
            $ramPct.Text = "$([int]$ramVal)%"
            $ramBar.Value = $ramVal
            $ramSpark.Push([float]$ramVal)
        }
    } catch { }

    # Top processes for both dashboard card and processes page
    try {
        $procs = Get-Process -ErrorAction SilentlyContinue |
            Sort-Object -Property CPU -Descending |
            Select-Object -First 10
        $sb = New-Object System.Text.StringBuilder
        $i = 1
        foreach ($p in $procs) {
            $cpuMs = if ($p.CPU) { [int]$p.CPU } else { 0 }
            $memMB = [int]($p.WorkingSet64 / 1MB)
            [void]$sb.AppendLine(("{0,2}.  {1,-25}  CPU:{2,6} ms   RAM:{3,5} MB" -f $i, $p.ProcessName, $cpuMs, $memMB))
            $i++
        }
        $procList.Text = $sb.ToString()
        $procGrid.Text = $sb.ToString()
    } catch { }
})
$monTimer.Start()

# ============================================================
#  FORM EVENTS
# ============================================================
$form.Add_Shown({
    Switch-Page -Key "dashboard"
    $form.Activate()
})

$form.Add_FormClosing({
    try { $loadTimer.Stop(); $loadTimer.Dispose() } catch { }
    try { $monTimer.Stop(); $monTimer.Dispose() } catch { }
})

[void]$form.ShowDialog()