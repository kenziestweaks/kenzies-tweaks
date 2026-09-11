#Requires -Version 5.1
<#
    Kenzie's Tweaks v3 - Sleek Dark Dashboard
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
#  COLOR PALETTE  (sleek dark)
# ============================================================
$script:C = @{
    Bg         = [System.Drawing.Color]::FromArgb(7, 9, 14)
    BgAlt      = [System.Drawing.Color]::FromArgb(12, 15, 22)
    Surface    = [System.Drawing.Color]::FromArgb(18, 22, 32)
    SurfaceAlt = [System.Drawing.Color]::FromArgb(24, 30, 42)
    SurfaceHi  = [System.Drawing.Color]::FromArgb(32, 40, 56)
    Border     = [System.Drawing.Color]::FromArgb(38, 48, 68)
    BorderHi   = [System.Drawing.Color]::FromArgb(58, 72, 98)
    Accent     = [System.Drawing.Color]::FromArgb(74, 158, 255)
    Accent2    = [System.Drawing.Color]::FromArgb(140, 90, 255)
    Glow       = [System.Drawing.Color]::FromArgb(90, 200, 255)
    Cyan       = [System.Drawing.Color]::FromArgb(80, 240, 255)
    Pink       = [System.Drawing.Color]::FromArgb(255, 120, 200)
    Text       = [System.Drawing.Color]::FromArgb(238, 244, 252)
    TextMid    = [System.Drawing.Color]::FromArgb(170, 188, 210)
    TextDim    = [System.Drawing.Color]::FromArgb(120, 138, 165)
    Muted      = [System.Drawing.Color]::FromArgb(80, 95, 115)
    Success    = [System.Drawing.Color]::FromArgb(60, 220, 150)
    Warning    = [System.Drawing.Color]::FromArgb(255, 190, 70)
    Danger     = [System.Drawing.Color]::FromArgb(255, 100, 120)
    Off        = [System.Drawing.Color]::FromArgb(60, 72, 92)
}

$script:PowerPlans = @(
    @{ Name = "Kenzie's Custom";      Guid = "b7701089-9d55-49a7-90ec-f6be3a3566a9"; Tag = "K" }
    @{ Name = "Ultimate Performance"; Guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"; Tag = "U" }
    @{ Name = "High Performance";     Guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; Tag = "H" }
    @{ Name = "Balanced";             Guid = "381b4222-f694-41f0-9685-ff5bb260df2e"; Tag = "B" }
    @{ Name = "Power Saver";          Guid = "a1841308-3541-4fab-bc81-f71556f20b4a"; Tag = "P" }
)

# ============================================================
#  C# CONTROLS  (all PS 5.1 safe)
# ============================================================
if (-not ("K3" -as [type])) {
    $cs = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public static class K3
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

// ------------ Rounded card with subtle glow ------------
public class K3Card : Panel
{
    private int _radius = 14;
    private Color _fill = Color.FromArgb(18, 22, 32);
    private Color _border = Color.FromArgb(38, 48, 68);
    private float _glowAmt = 0f;
    private bool _hoverGlow = true;
    private Timer _t;
    private bool _hovering = false;

    public int Radius { get { return _radius; } set { _radius = value; Invalidate(); } }
    public Color FillColor { get { return _fill; } set { _fill = value; Invalidate(); } }
    public Color BorderColor { get { return _border; } set { _border = value; Invalidate(); } }
    public bool HoverGlow { get { return _hoverGlow; } set { _hoverGlow = value; } }

    public K3Card()
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
        float target = (_hoverGlow && _hovering) ? 1f : 0f;
        _glowAmt += (target - _glowAmt) * 0.16f;
        if (Math.Abs(_glowAmt - target) < 0.01f) _glowAmt = target;
        Invalidate();
    }

    protected override void OnMouseEnter(EventArgs e) { _hovering = true; base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { _hovering = false; base.OnMouseLeave(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
        GraphicsPath path = K3.Round(r, _radius);
        try
        {
            using (SolidBrush b = new SolidBrush(_fill))
                g.FillPath(b, path);

            Color bc = K3.Blend(_border, Color.FromArgb(74, 158, 255), _glowAmt * 0.8f);
            using (Pen p = new Pen(bc, 1f))
                g.DrawPath(p, path);

            if (_glowAmt > 0.05f)
            {
                using (Pen gp = new Pen(Color.FromArgb((int)(_glowAmt * 50), 74, 158, 255), 4f))
                    g.DrawPath(gp, path);
            }
        }
        finally { path.Dispose(); }
    }
}

// ------------ Modern button ------------
public class K3Button : Button
{
    private Color _normal = Color.FromArgb(24, 30, 42);
    private Color _hover = Color.FromArgb(36, 46, 64);
    private Color _accent = Color.FromArgb(74, 158, 255);
    private Color _textColor = Color.FromArgb(238, 244, 252);
    private int _radius = 10;
    private bool _active;
    private bool _hovering;
    private float _glow;
    private bool _danger;
    private Timer _t;

    public Color NormalColor { get { return _normal; } set { _normal = value; Invalidate(); } }
    public Color HoverColor { get { return _hover; } set { _hover = value; Invalidate(); } }
    public Color AccentColor { get { return _accent; } set { _accent = value; Invalidate(); } }
    public Color TextColor { get { return _textColor; } set { _textColor = value; Invalidate(); } }
    public int Radius { get { return _radius; } set { _radius = value; Invalidate(); } }
    public bool IsActive { get { return _active; } set { _active = value; Invalidate(); } }
    public bool IsDanger { get { return _danger; } set { _danger = value; Invalidate(); } }

    public K3Button()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        Font = new Font("Segoe UI Semibold", 9.5f, FontStyle.Bold);
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
        GraphicsPath path = K3.Round(r, _radius);
        try
        {
            if (_active)
            {
                using (LinearGradientBrush lg = new LinearGradientBrush(r,
                    Color.FromArgb(74, 158, 255), Color.FromArgb(140, 90, 255),
                    LinearGradientMode.Horizontal))
                    g.FillPath(lg, path);
            }
            else
            {
                Color baseFill = _normal;
                Color hoverFill = _danger ? Color.FromArgb(160, 40, 60) : _hover;
                Color fill = K3.Blend(baseFill, hoverFill, _glow);
                using (SolidBrush b = new SolidBrush(fill))
                    g.FillPath(b, path);
            }

            Color bc = _active
                ? Color.FromArgb(200, 230, 255)
                : K3.Blend(Color.FromArgb(38, 48, 68), _accent, _glow * 0.9f);
            using (Pen p = new Pen(bc, _active ? 1.6f : 1f))
                g.DrawPath(p, path);

            if (_glow > 0.35f || _active)
            {
                int a = _active ? 70 : (int)(_glow * 45);
                using (Pen gp = new Pen(Color.FromArgb(a, 74, 158, 255), 4f))
                    g.DrawPath(gp, path);
            }
        }
        finally { path.Dispose(); }

        Color tcol = _active ? Color.White : _textColor;
        TextRenderer.DrawText(g, Text, Font, r, tcol,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
    }
}

// ------------ Animated toggle switch ------------
public class K3Toggle : Control
{
    private bool _checked;
    private float _anim;
    private Timer _t;
    private Color _onColor = Color.FromArgb(60, 220, 150);
    private Color _offColor = Color.FromArgb(60, 72, 92);
    private bool _busy;

    public bool Checked { get { return _checked; } set { _checked = value; Invalidate(); } }
    public bool Busy { get { return _busy; } set { _busy = value; Invalidate(); } }
    public Color OnColor { get { return _onColor; } set { _onColor = value; Invalidate(); } }
    public Color OffColor { get { return _offColor; } set { _offColor = value; Invalidate(); } }

    public event EventHandler Toggled;

    public K3Toggle()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Size = new Size(48, 24);
        Cursor = Cursors.Hand;
        _anim = 0f;
        _t = new Timer();
        _t.Interval = 16;
        _t.Tick += new EventHandler(Tick);
        _t.Start();
    }

    private void Tick(object s, EventArgs e)
    {
        float tgt = _checked ? 1f : 0f;
        _anim += (tgt - _anim) * 0.22f;
        if (Math.Abs(_anim - tgt) < 0.005f) _anim = tgt;
        Invalidate();
    }

    protected override void OnClick(EventArgs e)
    {
        if (!_busy)
        {
            _checked = !_checked;
            if (Toggled != null) Toggled(this, EventArgs.Empty);
        }
        base.OnClick(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        Color bg = K3.Blend(_offColor, _onColor, _anim);
        Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
        GraphicsPath path = new GraphicsPath();
        int d = Height - 2;
        path.AddArc(r.X, r.Y, d, d, 90, 180);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 180);
        path.CloseFigure();

        using (SolidBrush b = new SolidBrush(bg))
            g.FillPath(b, path);

        if (_anim > 0.1f)
        {
            using (Pen gp = new Pen(Color.FromArgb((int)(_anim * 90), _onColor), 3f))
                g.DrawPath(gp, path);
        }
        path.Dispose();

        int knobSize = Height - 6;
        int knobX = (int)(3 + _anim * (Width - knobSize - 6));
        using (SolidBrush kb = new SolidBrush(Color.White))
            g.FillEllipse(kb, knobX, 3, knobSize, knobSize);
    }
}

// ------------ Gradient bar ------------
public class K3Bar : Control
{
    private float _value;
    private float _anim;
    private Color _c1 = Color.FromArgb(74, 158, 255);
    private Color _c2 = Color.FromArgb(80, 240, 255);
    private Timer _t;

    public float Value { get { return _value; } set { _value = value; } }
    public Color ColorFrom { get { return _c1; } set { _c1 = value; Invalidate(); } }
    public Color ColorTo { get { return _c2; } set { _c2 = value; Invalidate(); } }

    public K3Bar()
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
        GraphicsPath fp = K3.Round(full, r);
        using (SolidBrush bg = new SolidBrush(Color.FromArgb(28, 36, 50)))
            g.FillPath(bg, fp);
        fp.Dispose();

        int fillW = (int)(Width * _anim);
        if (fillW > 3)
        {
            Rectangle fr = new Rectangle(0, 0, fillW, Height - 1);
            GraphicsPath fillPath = K3.Round(fr, r);
            using (LinearGradientBrush lb = new LinearGradientBrush(
                new Rectangle(0, 0, Math.Max(fillW, 2), Height),
                _c1, _c2, LinearGradientMode.Horizontal))
                g.FillPath(lb, fillPath);
            fillPath.Dispose();
        }
    }
}

// ------------ Sparkline ------------
public class K3Spark : Control
{
    private System.Collections.Generic.List<float> _pts = new System.Collections.Generic.List<float>();
    private int _maxPts = 60;
    private Color _line = Color.FromArgb(80, 240, 255);
    private Color _fill = Color.FromArgb(74, 158, 255);

    public Color LineColor { get { return _line; } set { _line = value; Invalidate(); } }
    public Color FillColor { get { return _fill; } set { _fill = value; Invalidate(); } }

    public K3Spark()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.DoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
    }

    public void Push(float v)
    {
        _pts.Add(v);
        while (_pts.Count > _maxPts) _pts.RemoveAt(0);
        Invalidate();
    }

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
        using (SolidBrush fb = new SolidBrush(Color.FromArgb(35, _fill)))
            g.FillPolygon(fb, fillPts);
        using (Pen p = new Pen(_line, 1.6f))
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

function Test-HibernationEnabled {
    try {
        $out = powercfg /a 2>$null
        return ($out -notmatch 'Hibernation has not been enabled')
    } catch { return $false }
}

function Test-TelemetryEnabled {
    try {
        $s = Get-Service DiagTrack -ErrorAction SilentlyContinue
        if ($s) { return $s.Status -eq 'Running' }
    } catch { }
    return $false
}

function Test-GameModeEnabled {
    try {
        $v = Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -ErrorAction SilentlyContinue
        if ($v -and $v.AllowAutoGameMode -eq 1) { return $true }
    } catch { }
    return $false
}

function Test-GameBarDisabled {
    try {
        $v = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -ErrorAction SilentlyContinue
        if ($v -and $v.AppCaptureEnabled -eq 0) { return $true }
    } catch { }
    return $false
}

function Test-UltimateUnlocked {
    try {
        return (powercfg /list 2>$null | Select-String 'e9a42b02-d5df-448d-aa00-03f14749eb61') -ne $null
    } catch { return $false }
}

function Test-KenziePlanExists {
    try {
        return (powercfg /list 2>$null | Select-String 'b7701089-9d55-49a7-90ec-f6be3a3566a9') -ne $null
    } catch { return $false }
}

# ============================================================
#  FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Kenzie's Tweaks"
$form.Size = New-Object System.Drawing.Size(1120, 740)
$form.StartPosition = "CenterScreen"
$form.BackColor = $C.Bg
$form.ForeColor = $C.Text
$form.FormBorderStyle = "None"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
Enable-DoubleBuffer $form

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
$titleBar.Size = New-Object System.Drawing.Size($form.Width, 54)
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
$brandLogo.Text = "K"
$brandLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
$brandLogo.ForeColor = [System.Drawing.Color]::White
$brandLogo.AutoSize = $false
$brandLogo.Size = New-Object System.Drawing.Size(38, 38)
$brandLogo.Location = New-Object System.Drawing.Point(16, 8)
$brandLogo.TextAlign = "MiddleCenter"
$brandLogo.BackColor = $C.Accent
$titleBar.Controls.Add($brandLogo)

$brandTitle = New-Object System.Windows.Forms.Label
$brandTitle.Text = "Kenzie's Tweaks"
$brandTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
$brandTitle.ForeColor = $C.Text
$brandTitle.AutoSize = $true
$brandTitle.BackColor = [System.Drawing.Color]::Transparent
$brandTitle.Location = New-Object System.Drawing.Point(62, 10)
$titleBar.Controls.Add($brandTitle)

$brandSub = New-Object System.Windows.Forms.Label
$brandSub.Text = "Sleek Performance Dashboard"
$brandSub.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$brandSub.ForeColor = $C.TextDim
$brandSub.AutoSize = $true
$brandSub.BackColor = [System.Drawing.Color]::Transparent
$brandSub.Location = New-Object System.Drawing.Point(64, 31)
$titleBar.Controls.Add($brandSub)

function New-Tb {
    param([string]$Glyph, [int]$X, [System.Drawing.Color]$Hover)
    $b = New-Object System.Windows.Forms.Label
    $b.Text = $Glyph
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $b.ForeColor = $C.TextDim
    $b.BackColor = [System.Drawing.Color]::Transparent
    $b.Size = New-Object System.Drawing.Size(46, 54)
    $b.Location = New-Object System.Drawing.Point($X, 0)
    $b.TextAlign = "MiddleCenter"
    $b.Cursor = "Hand"
    $hc = $Hover
    $b.Add_MouseEnter({
        param($s, $e)
        $s.ForeColor = $hc
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
$lLogo.Text = "K"
$lLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 48, [System.Drawing.FontStyle]::Bold)
$lLogo.ForeColor = [System.Drawing.Color]::White
$lLogo.AutoSize = $false
$lLogo.Size = New-Object System.Drawing.Size(140, 140)
$lLogo.Location = New-Object System.Drawing.Point(490, 210)
$lLogo.TextAlign = "MiddleCenter"
$lLogo.BackColor = $C.Accent
$loading.Controls.Add($lLogo)

$lTitle = New-Object System.Windows.Forms.Label
$lTitle.Text = "Kenzie's Tweaks"
$lTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 26, [System.Drawing.FontStyle]::Bold)
$lTitle.ForeColor = $C.Text
$lTitle.AutoSize = $true
$lTitle.BackColor = [System.Drawing.Color]::Transparent
$lTitle.Location = New-Object System.Drawing.Point(400, 380)
$loading.Controls.Add($lTitle)

$lSub = New-Object System.Windows.Forms.Label
$lSub.Text = "Sleek Performance Dashboard"
$lSub.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lSub.ForeColor = $C.TextDim
$lSub.AutoSize = $true
$lSub.BackColor = [System.Drawing.Color]::Transparent
$lSub.Location = New-Object System.Drawing.Point(470, 425)
$loading.Controls.Add($lSub)

$lStatus = New-Object System.Windows.Forms.Label
$lStatus.Text = "Initializing..."
$lStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lStatus.ForeColor = $C.TextMid
$lStatus.AutoSize = $true
$lStatus.BackColor = [System.Drawing.Color]::Transparent
$lStatus.Location = New-Object System.Drawing.Point(500, 475)
$loading.Controls.Add($lStatus)

$lBarBg = New-Object System.Windows.Forms.Panel
$lBarBg.Size = New-Object System.Drawing.Size(380, 4)
$lBarBg.Location = New-Object System.Drawing.Point(370, 505)
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
        Start-Sleep -Milliseconds 180
        $loading.Visible = $false
        $loading.SendToBack()
        Refresh-AllStates
    }
})
$loadTimer.Start()

# ============================================================
#  LAYOUT
# ============================================================
$main = New-Object System.Windows.Forms.Panel
$main.Size = New-Object System.Drawing.Size($form.Width, ($form.Height - 54))
$main.Location = New-Object System.Drawing.Point(0, 54)
$main.BackColor = $C.Bg
$form.Controls.Add($main)

$sidebar = New-Object K3Card
$sidebar.Size = New-Object System.Drawing.Size(240, ($main.Height - 24))
$sidebar.Location = New-Object System.Drawing.Point(12, 12)
$sidebar.FillColor = $C.BgAlt
$sidebar.BorderColor = $C.Border
$sidebar.Radius = 16
$sidebar.HoverGlow = $false
$main.Controls.Add($sidebar)

$sideBadge = New-Object System.Windows.Forms.Label
$sideBadge.Text = "K"
$sideBadge.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 20, [System.Drawing.FontStyle]::Bold)
$sideBadge.ForeColor = [System.Drawing.Color]::White
$sideBadge.AutoSize = $false
$sideBadge.Size = New-Object System.Drawing.Size(56, 56)
$sideBadge.Location = New-Object System.Drawing.Point(24, 24)
$sideBadge.TextAlign = "MiddleCenter"
$sideBadge.BackColor = $C.Accent
$sidebar.Controls.Add($sideBadge)

$sideName = New-Object System.Windows.Forms.Label
$sideName.Text = "Kenzie's`nTweaks"
$sideName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13, [System.Drawing.FontStyle]::Bold)
$sideName.ForeColor = $C.Text
$sideName.AutoSize = $true
$sideName.BackColor = [System.Drawing.Color]::Transparent
$sideName.Location = New-Object System.Drawing.Point(92, 32)
$sidebar.Controls.Add($sideName)

$adminCard = New-Object K3Card
$adminCard.Size = New-Object System.Drawing.Size(192, 34)
$adminCard.Location = New-Object System.Drawing.Point(24, 106)
$adminCard.Radius = 9
$adminCard.HoverGlow = $false
$adminCard.FillColor = if ($isAdmin) { [System.Drawing.Color]::FromArgb(14, 40, 30) } else { [System.Drawing.Color]::FromArgb(40, 32, 12) }
$adminCard.BorderColor = if ($isAdmin) { $C.Success } else { $C.Warning }
$sidebar.Controls.Add($adminCard)

$adminTxt = New-Object System.Windows.Forms.Label
$adminTxt.Text = if ($isAdmin) { "ADMINISTRATOR" } else { "LIMITED MODE" }
$adminTxt.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$adminTxt.ForeColor = if ($isAdmin) { $C.Success } else { $C.Warning }
$adminTxt.AutoSize = $true
$adminTxt.BackColor = [System.Drawing.Color]::Transparent
$adminTxt.Location = New-Object System.Drawing.Point(20, 8)
$adminCard.Controls.Add($adminTxt)

$navLabel = New-Object System.Windows.Forms.Label
$navLabel.Text = "NAVIGATION"
$navLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 7.5, [System.Drawing.FontStyle]::Bold)
$navLabel.ForeColor = $C.Muted
$navLabel.AutoSize = $true
$navLabel.BackColor = [System.Drawing.Color]::Transparent
$navLabel.Location = New-Object System.Drawing.Point(28, 165)
$sidebar.Controls.Add($navLabel)

$script:navButtons = @{}
$navItems = @(
    @{ Key = "dashboard"; Label = "Dashboard" }
    @{ Key = "power";     Label = "Power Plans" }
    @{ Key = "tweaks";    Label = "Tweaks" }
    @{ Key = "system";    Label = "System Info" }
    @{ Key = "processes"; Label = "Processes" }
    @{ Key = "about";     Label = "About" }
)

$navY = 192
foreach ($nav in $navItems) {
    $nb = New-Object K3Button
    $nb.Text = $nav.Label
    $nb.Size = New-Object System.Drawing.Size(192, 42)
    $nb.Location = New-Object System.Drawing.Point(24, $navY)
    $nb.NormalColor = $C.BgAlt
    $nb.HoverColor = $C.SurfaceHi
    $nb.AccentColor = $C.Accent
    $nb.TextColor = $C.TextMid
    $nb.Radius = 10
    $nb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5, [System.Drawing.FontStyle]::Bold)
    $nb.Tag = $nav.Key
    $sidebar.Controls.Add($nb)
    $script:navButtons[$nav.Key] = $nb
    $navY += 48
}

$content = New-Object System.Windows.Forms.Panel
$content.Size = New-Object System.Drawing.Size(($main.Width - 276), ($main.Height - 24))
$content.Location = New-Object System.Drawing.Point(264, 12)
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

$h1 = New-Object System.Windows.Forms.Label
$h1.Text = "Dashboard"
$h1.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$h1.ForeColor = $C.Text
$h1.AutoSize = $true
$h1.BackColor = [System.Drawing.Color]::Transparent
$h1.Location = New-Object System.Drawing.Point(4, 2)
$pageDash.Controls.Add($h1)

$h2 = New-Object System.Windows.Forms.Label
$h2.Text = "Live system performance overview"
$h2.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$h2.ForeColor = $C.TextDim
$h2.AutoSize = $true
$h2.BackColor = [System.Drawing.Color]::Transparent
$h2.Location = New-Object System.Drawing.Point(6, 42)
$pageDash.Controls.Add($h2)

$cardW = [int](($content.Width - 24) / 2)

$cpuCard = New-Object K3Card
$cpuCard.Size = New-Object System.Drawing.Size($cardW, 156)
$cpuCard.Location = New-Object System.Drawing.Point(4, 78)
$cpuCard.FillColor = $C.Surface
$cpuCard.BorderColor = $C.Border
$pageDash.Controls.Add($cpuCard)

$cpuTitle = New-Object System.Windows.Forms.Label
$cpuTitle.Text = "CPU LOAD"
$cpuTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5, [System.Drawing.FontStyle]::Bold)
$cpuTitle.ForeColor = $C.TextDim
$cpuTitle.AutoSize = $true
$cpuTitle.BackColor = [System.Drawing.Color]::Transparent
$cpuTitle.Location = New-Object System.Drawing.Point(22, 16)
$cpuCard.Controls.Add($cpuTitle)

$cpuPct = New-Object System.Windows.Forms.Label
$cpuPct.Text = "0%"
$cpuPct.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 30, [System.Drawing.FontStyle]::Bold)
$cpuPct.ForeColor = $C.Text
$cpuPct.AutoSize = $true
$cpuPct.BackColor = [System.Drawing.Color]::Transparent
$cpuPct.Location = New-Object System.Drawing.Point(20, 38)
$cpuCard.Controls.Add($cpuPct)

$cpuBar = New-Object K3Bar
$cpuBar.Size = New-Object System.Drawing.Size(($cardW - 44), 8)
$cpuBar.Location = New-Object System.Drawing.Point(22, 96)
$cpuBar.ColorFrom = $C.Accent
$cpuBar.ColorTo = $C.Cyan
$cpuCard.Controls.Add($cpuBar)

$cpuSpark = New-Object K3Spark
$cpuSpark.Size = New-Object System.Drawing.Size(($cardW - 44), 30)
$cpuSpark.Location = New-Object System.Drawing.Point(22, 116)
$cpuSpark.LineColor = $C.Cyan
$cpuSpark.FillColor = $C.Accent
$cpuCard.Controls.Add($cpuSpark)

$ramCard = New-Object K3Card
$ramCard.Size = New-Object System.Drawing.Size($cardW, 156)
$ramCard.Location = New-Object System.Drawing.Point(($cardW + 20), 78)
$ramCard.FillColor = $C.Surface
$ramCard.BorderColor = $C.Border
$pageDash.Controls.Add($ramCard)

$ramTitle = New-Object System.Windows.Forms.Label
$ramTitle.Text = "MEMORY"
$ramTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5, [System.Drawing.FontStyle]::Bold)
$ramTitle.ForeColor = $C.TextDim
$ramTitle.AutoSize = $true
$ramTitle.BackColor = [System.Drawing.Color]::Transparent
$ramTitle.Location = New-Object System.Drawing.Point(22, 16)
$ramCard.Controls.Add($ramTitle)

$ramPct = New-Object System.Windows.Forms.Label
$ramPct.Text = "0%"
$ramPct.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 30, [System.Drawing.FontStyle]::Bold)
$ramPct.ForeColor = $C.Text
$ramPct.AutoSize = $true
$ramPct.BackColor = [System.Drawing.Color]::Transparent
$ramPct.Location = New-Object System.Drawing.Point(20, 38)
$ramCard.Controls.Add($ramPct)

$ramBar = New-Object K3Bar
$ramBar.Size = New-Object System.Drawing.Size(($cardW - 44), 8)
$ramBar.Location = New-Object System.Drawing.Point(22, 96)
$ramBar.ColorFrom = $C.Accent2
$ramBar.ColorTo = $C.Pink
$ramCard.Controls.Add($ramBar)

$ramSpark = New-Object K3Spark
$ramSpark.Size = New-Object System.Drawing.Size(($cardW - 44), 30)
$ramSpark.Location = New-Object System.Drawing.Point(22, 116)
$ramSpark.LineColor = $C.Pink
$ramSpark.FillColor = $C.Accent2
$ramCard.Controls.Add($ramSpark)

$procCard = New-Object K3Card
$procCard.Size = New-Object System.Drawing.Size(($content.Width - 8), 260)
$procCard.Location = New-Object System.Drawing.Point(4, 246)
$procCard.FillColor = $C.Surface
$procCard.BorderColor = $C.Border
$procCard.HoverGlow = $false
$pageDash.Controls.Add($procCard)

$procTitle = New-Object System.Windows.Forms.Label
$procTitle.Text = "TOP PROCESSES"
$procTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5, [System.Drawing.FontStyle]::Bold)
$procTitle.ForeColor = $C.TextDim
$procTitle.AutoSize = $true
$procTitle.BackColor = [System.Drawing.Color]::Transparent
$procTitle.Location = New-Object System.Drawing.Point(22, 16)
$procCard.Controls.Add($procTitle)

$procList = New-Object System.Windows.Forms.Label
$procList.Font = New-Object System.Drawing.Font("Consolas", 9)
$procList.ForeColor = $C.TextMid
$procList.BackColor = [System.Drawing.Color]::Transparent
$procList.AutoSize = $false
$procList.Size = New-Object System.Drawing.Size(($procCard.Width - 40), 210)
$procList.Location = New-Object System.Drawing.Point(22, 42)
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

$ph1 = New-Object System.Windows.Forms.Label
$ph1.Text = "Power Plans"
$ph1.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$ph1.ForeColor = $C.Text
$ph1.AutoSize = $true
$ph1.BackColor = [System.Drawing.Color]::Transparent
$ph1.Location = New-Object System.Drawing.Point(4, 2)
$pagePower.Controls.Add($ph1)

$ph2 = New-Object System.Windows.Forms.Label
$ph2.Text = "Switch between performance profiles instantly"
$ph2.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$ph2.ForeColor = $C.TextDim
$ph2.AutoSize = $true
$ph2.BackColor = [System.Drawing.Color]::Transparent
$ph2.Location = New-Object System.Drawing.Point(6, 42)
$pagePower.Controls.Add($ph2)

$activeCard = New-Object K3Card
$activeCard.Size = New-Object System.Drawing.Size(($content.Width - 20), 116)
$activeCard.Location = New-Object System.Drawing.Point(4, 78)
$activeCard.Radius = 16
$activeCard.FillColor = $C.Surface
$activeCard.BorderColor = $C.Accent
$activeCard.HoverGlow = $false
$pagePower.Controls.Add($activeCard)

$activeTagLbl = New-Object System.Windows.Forms.Label
$activeTagLbl.Text = "K"
$activeTagLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$activeTagLbl.ForeColor = [System.Drawing.Color]::White
$activeTagLbl.AutoSize = $false
$activeTagLbl.Size = New-Object System.Drawing.Size(72, 72)
$activeTagLbl.Location = New-Object System.Drawing.Point(22, 22)
$activeTagLbl.TextAlign = "MiddleCenter"
$activeTagLbl.BackColor = $C.Accent
$activeCard.Controls.Add($activeTagLbl)

$activeHeadLbl = New-Object System.Windows.Forms.Label
$activeHeadLbl.Text = "ACTIVE POWER PLAN"
$activeHeadLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$activeHeadLbl.ForeColor = $C.TextDim
$activeHeadLbl.AutoSize = $true
$activeHeadLbl.BackColor = [System.Drawing.Color]::Transparent
$activeHeadLbl.Location = New-Object System.Drawing.Point(115, 22)
$activeCard.Controls.Add($activeHeadLbl)

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
$btnW = [int](($content.Width - 30) / 3)
foreach ($plan in $PowerPlans) {
    $pb = New-Object K3Button
    $pb.Text = "[$($plan.Tag)]  $($plan.Name)"
    $pb.Size = New-Object System.Drawing.Size($btnW, 62)
    $pb.Location = New-Object System.Drawing.Point($planX, $planY)
    $pb.NormalColor = $C.Surface
    $pb.HoverColor = $C.SurfaceHi
    $pb.AccentColor = $C.Accent
    $pb.TextColor = $C.Text
    $pb.Radius = 12
    $pb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5, [System.Drawing.FontStyle]::Bold)
    $pb.Tag = $plan.Guid
    $pb.Add_Click({
        param($s, $e)
        Apply-PowerPlan -Guid $s.Tag -Button $s
    })
    $pagePower.Controls.Add($pb)
    $script:planButtons[$plan.Guid] = $pb
    $col++
    if ($col -ge 3) { $col = 0; $planX = 4; $planY += 74 }
    else { $planX += ($btnW + 6) }
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
#  PAGE: TWEAKS  (with toggles + status)
# ============================================================
$pageTweaks = New-Object System.Windows.Forms.Panel
$pageTweaks.Size = $content.Size
$pageTweaks.Location = New-Object System.Drawing.Point(0, 0)
$pageTweaks.BackColor = $C.Bg
$pageTweaks.Visible = $false
$content.Controls.Add($pageTweaks)

$th1 = New-Object System.Windows.Forms.Label
$th1.Text = "Tweaks"
$th1.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$th1.ForeColor = $C.Text
$th1.AutoSize = $true
$th1.BackColor = [System.Drawing.Color]::Transparent
$th1.Location = New-Object System.Drawing.Point(4, 2)
$pageTweaks.Controls.Add($th1)

$th2 = New-Object System.Windows.Forms.Label
$th2.Text = "Toggle system optimizations on or off"
$th2.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$th2.ForeColor = $C.TextDim
$th2.AutoSize = $true
$th2.BackColor = [System.Drawing.Color]::Transparent
$th2.Location = New-Object System.Drawing.Point(6, 42)
$pageTweaks.Controls.Add($th2)

# Tweak definitions
$script:Tweaks = @(
    @{
        Key = "ultimate"
        Name = "Ultimate Performance Plan"
        Desc = "Unlock hidden Ultimate Performance power scheme"
        Test = { Test-UltimateUnlocked }
        On   = { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null }
        Off  = { powercfg /delete e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null }
    }
    @{
        Key = "kenzieplan"
        Name = "Kenzie's Custom Plan"
        Desc = "Create custom plan b7701089-... from Ultimate"
        Test = { Test-KenziePlanExists }
        On   = {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 b7701089-9d55-49a7-90ec-f6be3a3566a9 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e b7701089-9d55-49a7-90ec-f6be3a3566a9 2>&1 | Out-Null
            }
        }
        Off  = { powercfg /delete b7701089-9d55-49a7-90ec-f6be3a3566a9 2>&1 | Out-Null }
    }
    @{
        Key = "hibernate"
        Name = "Hibernation"
        Desc = "Enable or disable hibernate (frees disk)"
        Test = { Test-HibernationEnabled }
        On   = { powercfg -h on 2>&1 | Out-Null }
        Off  = { powercfg -h off 2>&1 | Out-Null }
    }
    @{
        Key = "telemetry"
        Name = "DiagTrack Telemetry"
        Desc = "Windows telemetry tracking service"
        Test = { Test-TelemetryEnabled }
        On   = { Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service DiagTrack -ErrorAction SilentlyContinue }
        Off  = { Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue }
    }
    @{
        Key = "gamemode"
        Name = "Windows Game Mode"
        Desc = "Optimize system for gaming sessions"
        Test = { Test-GameModeEnabled }
        On   = {
            if (-not (Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }
            Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 -ErrorAction SilentlyContinue
        }
        Off  = {
            if (-not (Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }
            Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 0 -ErrorAction SilentlyContinue
        }
    }
    @{
        Key = "gamebar"
        Name = "Disable Xbox Game Bar"
        Desc = "Turn off the Game Bar overlay entirely"
        Test = { Test-GameBarDisabled }
        On   = {
            if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR')) {
                New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null
            }
            Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 -ErrorAction SilentlyContinue
        }
        Off  = {
            if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR')) {
                New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null
            }
            Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 1 -ErrorAction SilentlyContinue
        }
    }
)

$script:TweakControls = @{}
$ty = 80
foreach ($t in $Tweaks) {
    $row = New-Object K3Card
    $row.Size = New-Object System.Drawing.Size(($content.Width - 20), 72)
    $row.Location = New-Object System.Drawing.Point(4, $ty)
    $row.Radius = 12
    $row.FillColor = $C.Surface
    $row.BorderColor = $C.Border
    $pageTweaks.Controls.Add($row)

    $nameLbl = New-Object System.Windows.Forms.Label
    $nameLbl.Text = $t.Name
    $nameLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
    $nameLbl.ForeColor = $C.Text
    $nameLbl.AutoSize = $true
    $nameLbl.BackColor = [System.Drawing.Color]::Transparent
    $nameLbl.Location = New-Object System.Drawing.Point(22, 14)
    $row.Controls.Add($nameLbl)

    $descLbl = New-Object System.Windows.Forms.Label
    $descLbl.Text = $t.Desc
    $descLbl.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $descLbl.ForeColor = $C.TextDim
    $descLbl.AutoSize = $true
    $descLbl.BackColor = [System.Drawing.Color]::Transparent
    $descLbl.Location = New-Object System.Drawing.Point(22, 40)
    $row.Controls.Add($descLbl)

    # Status badge
    $statusBadge = New-Object K3Card
    $statusBadge.Size = New-Object System.Drawing.Size(100, 30)
    $statusBadge.Location = New-Object System.Drawing.Point(($row.Width - 240), 21)
    $statusBadge.Radius = 8
    $statusBadge.HoverGlow = $false
    $statusBadge.FillColor = $C.Off
    $statusBadge.BorderColor = $C.Muted
    $row.Controls.Add($statusBadge)

    $statusTxt = New-Object System.Windows.Forms.Label
    $statusTxt.Text = "OFF"
    $statusTxt.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5, [System.Drawing.FontStyle]::Bold)
    $statusTxt.ForeColor = $C.TextDim
    $statusTxt.AutoSize = $false
    $statusTxt.Size = New-Object System.Drawing.Size(100, 30)
    $statusTxt.Location = New-Object System.Drawing.Point(0, 0)
    $statusTxt.TextAlign = "MiddleCenter"
    $statusTxt.BackColor = [System.Drawing.Color]::Transparent
    $statusBadge.Controls.Add($statusTxt)

    # Toggle
    $toggle = New-Object K3Toggle
    $toggle.Size = New-Object System.Drawing.Size(52, 26)
    $toggle.Location = New-Object System.Drawing.Point(($row.Width - 130), 23)
    $toggle.OnColor = $C.Success
    $toggle.OffColor = $C.Off
    $row.Controls.Add($toggle)

    $script:TweakControls[$t.Key] = @{
        Toggle = $toggle
        Status = $statusTxt
        Badge  = $statusBadge
        Def    = $t
    }

    # Wire up the toggle
    $key = $t.Key
    $toggle.Add_Toggled({
        param($s, $e)
        $c = $script:TweakControls[$key]
        $c.Toggle.Busy = $true
        try {
            if ($c.Toggle.Checked) {
                & $c.Def.On
                Show-Status "$($c.Def.Name) enabled" "Success"
            } else {
                & $c.Def.Off
                Show-Status "$($c.Def.Name) disabled" "Success"
            }
            Start-Sleep -Milliseconds 200
            Update-TweakState -Key $key
        } catch {
            Show-Status "Error: $($_.Exception.Message)" "Error"
        } finally {
            $c.Toggle.Busy = $false
        }
    })

    $ty += 80
}

# ============================================================
#  PAGE: SYSTEM
# ============================================================
$pageSystem = New-Object System.Windows.Forms.Panel
$pageSystem.Size = $content.Size
$pageSystem.Location = New-Object System.Drawing.Point(0, 0)
$pageSystem.BackColor = $C.Bg
$pageSystem.Visible = $false
$content.Controls.Add($pageSystem)

$sh1 = New-Object System.Windows.Forms.Label
$sh1.Text = "System Information"
$sh1.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$sh1.ForeColor = $C.Text
$sh1.AutoSize = $true
$sh1.BackColor = [System.Drawing.Color]::Transparent
$sh1.Location = New-Object System.Drawing.Point(4, 2)
$pageSystem.Controls.Add($sh1)

$sh2 = New-Object System.Windows.Forms.Label
$sh2.Text = "Hardware and OS details"
$sh2.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$sh2.ForeColor = $C.TextDim
$sh2.AutoSize = $true
$sh2.BackColor = [System.Drawing.Color]::Transparent
$sh2.Location = New-Object System.Drawing.Point(6, 42)
$pageSystem.Controls.Add($sh2)

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

$sy = 78
foreach ($f in $sysData) {
    $card = New-Object K3Card
    $card.Size = New-Object System.Drawing.Size(($content.Width - 20), 60)
    $card.Location = New-Object System.Drawing.Point(4, $sy)
    $card.Radius = 11
    $card.FillColor = $C.Surface
    $card.BorderColor = $C.Border
    $pageSystem.Controls.Add($card)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $f.L.ToUpper()
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = $C.TextDim
    $lbl.AutoSize = $true
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Location = New-Object System.Drawing.Point(22, 12)
    $card.Controls.Add($lbl)

    $val = New-Object System.Windows.Forms.Label
    $val.Text = $f.V
    $val.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
    $val.ForeColor = $C.Text
    $val.AutoSize = $true
    $val.BackColor = [System.Drawing.Color]::Transparent
    $val.Location = New-Object System.Drawing.Point(22, 30)
    $card.Controls.Add($val)

    $sy += 68
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

$prh1 = New-Object System.Windows.Forms.Label
$prh1.Text = "Processes"
$prh1.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$prh1.ForeColor = $C.Text
$prh1.AutoSize = $true
$prh1.BackColor = [System.Drawing.Color]::Transparent
$prh1.Location = New-Object System.Drawing.Point(4, 2)
$pageProc.Controls.Add($prh1)

$prh2 = New-Object System.Windows.Forms.Label
$prh2.Text = "Top consumers - auto-refreshing"
$prh2.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$prh2.ForeColor = $C.TextDim
$prh2.AutoSize = $true
$prh2.BackColor = [System.Drawing.Color]::Transparent
$prh2.Location = New-Object System.Drawing.Point(6, 42)
$pageProc.Controls.Add($prh2)

$procBigCard = New-Object K3Card
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
#  PAGE: ABOUT
# ============================================================
$pageAbout = New-Object System.Windows.Forms.Panel
$pageAbout.Size = $content.Size
$pageAbout.Location = New-Object System.Drawing.Point(0, 0)
$pageAbout.BackColor = $C.Bg
$pageAbout.Visible = $false
$content.Controls.Add($pageAbout)

$ah1 = New-Object System.Windows.Forms.Label
$ah1.Text = "About"
$ah1.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
$ah1.ForeColor = $C.Text
$ah1.AutoSize = $true
$ah1.BackColor = [System.Drawing.Color]::Transparent
$ah1.Location = New-Object System.Drawing.Point(4, 2)
$pageAbout.Controls.Add($ah1)

$aboutCard = New-Object K3Card
$aboutCard.Size = New-Object System.Drawing.Size(($content.Width - 40), 400)
$aboutCard.Location = New-Object System.Drawing.Point(4, 60)
$aboutCard.Radius = 18
$aboutCard.FillColor = $C.Surface
$aboutCard.BorderColor = $C.Border
$aboutCard.HoverGlow = $false
$pageAbout.Controls.Add($aboutCard)

$aboutLogo = New-Object System.Windows.Forms.Label
$aboutLogo.Text = "K"
$aboutLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 36, [System.Drawing.FontStyle]::Bold)
$aboutLogo.ForeColor = [System.Drawing.Color]::White
$aboutLogo.AutoSize = $false
$aboutLogo.Size = New-Object System.Drawing.Size(110, 110)
$aboutLogo.Location = New-Object System.Drawing.Point(30, 30)
$aboutLogo.TextAlign = "MiddleCenter"
$aboutLogo.BackColor = $C.Accent
$aboutCard.Controls.Add($aboutLogo)

$aboutTitle = New-Object System.Windows.Forms.Label
$aboutTitle.Text = "Kenzie's Tweaks"
$aboutTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 24, [System.Drawing.FontStyle]::Bold)
$aboutTitle.ForeColor = $C.Text
$aboutTitle.AutoSize = $true
$aboutTitle.BackColor = [System.Drawing.Color]::Transparent
$aboutTitle.Location = New-Object System.Drawing.Point(170, 40)
$aboutCard.Controls.Add($aboutTitle)

$aboutVer = New-Object System.Windows.Forms.Label
$aboutVer.Text = "Version 3.0  -  Sleek Dark UI"
$aboutVer.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$aboutVer.ForeColor = $C.TextDim
$aboutVer.AutoSize = $true
$aboutVer.BackColor = [System.Drawing.Color]::Transparent
$aboutVer.Location = New-Object System.Drawing.Point(172, 85)
$aboutCard.Controls.Add($aboutVer)

$aboutDesc = New-Object System.Windows.Forms.Label
$aboutDesc.Text = "A sleek PowerShell dashboard for power plan`nmanagement, system tweaks, and live monitoring.`nBuilt with WinForms + custom C# controls.`n`nCustom plan GUID:`nb7701089-9d55-49a7-90ec-f6be3a3566a9"
$aboutDesc.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
$aboutDesc.ForeColor = $C.TextMid
$aboutDesc.AutoSize = $true
$aboutDesc.BackColor = [System.Drawing.Color]::Transparent
$aboutDesc.Location = New-Object System.Drawing.Point(172, 120)
$aboutCard.Controls.Add($aboutDesc)

$aboutFooter = New-Object System.Windows.Forms.Label
$aboutFooter.Text = "github.com/kenziestweaks"
$aboutFooter.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$aboutFooter.ForeColor = $C.TextDim
$aboutFooter.AutoSize = $true
$aboutFooter.BackColor = [System.Drawing.Color]::Transparent
$aboutFooter.Location = New-Object System.Drawing.Point(172, 350)
$aboutCard.Controls.Add($aboutFooter)

# ============================================================
#  NAVIGATION
# ============================================================
$script:pages = @{
    dashboard = $pageDash
    power     = $pagePower
    tweaks    = $pageTweaks
    system    = $pageSystem
    processes = $pageProc
    about     = $pageAbout
}

function Switch-Page {
    param([string]$Key)
    foreach ($k in $script:pages.Keys) {
        $script:pages[$k].Visible = ($k - $Key)
        $script:navButtons[$k].IsActive = ($k -eq $Key)
    }
    $script:pages[$Key].BringToFront
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
function Update-TweakState {
    param([string]$Key)
    $c = $script:TweakControls[$Key]
    if (-not $c) { return }
    try {
        $enabled = & $c.Def.Test
    } catch { $enabled = $false }

    $c.Toggle.Checked = [bool]$enabled
    if ($enabled) {
        $c.Status.Text = "ENABLED"
        $c.Status.ForeColor = $C.Success
        $c.Badge.FillColor = [System.Drawing.Color]::FromArgb(14, 44, 30)
        $c.Badge.BorderColor = $C.Success
    } else {
        $c.Status.Text = "DISABLED"
        $c.Status.ForeColor = $C.TextDim
        $c.Badge.FillColor = $C.Off
        $c.Badge.BorderColor = $C.Muted
    }
    $c.Badge.Invalidate()
}

function Refresh-AllStates {
    foreach ($k in $script:TweakControls.Keys) {
        Update-TweakState -Key $k
    }
    Update-ActivePlanDisplay
}

function Update-ActivePlanDisplay {
    $ag = Get-ActivePlanGuid
    if ($ag) {
        $plan = $PowerPlans | Where-Object { $_.Guid -eq $ag } | Select-Object -First 1
        if ($plan) {
            $activeNameLbl.Text = "[$($plan.Tag)]  $($plan.Name)"
            $activeGuidLbl.Text = "GUID: $($plan.Guid)"
            $activeTagLbl.Text = $plan.Tag
        } else {
            $activeNameLbl.Text = "Custom Plan"
            $activeGuidLbl.Text = "GUID: $ag"
            $activeTagLbl.Text = "?"
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
            Refresh-AllStates
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
#  LIVE MONITOR
# ============================================================
$monTimer = New-Object System.Windows.Forms.Timer
$monTimer.Interval = 1000
$monTimer.Add_Tick({
    try {
        $cpuVal = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue |
            Measure-Object -Property LoadPercentage -Average).Average
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