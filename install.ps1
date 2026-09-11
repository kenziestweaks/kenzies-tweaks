#Requires -Version 5.1
<#
    Kenzie's Tweaks v5.0 - Rebuilt
    Root-cause fixes for WinForms architecture.
#>

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$script:IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $script:IsAdmin) {
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
#  1. DESIGN SYSTEM (define before any control uses it)
# ============================================================
$script:D = @{
    Bg0   = [System.Drawing.Color]::FromArgb(8, 9, 12)
    Bg1   = [System.Drawing.Color]::FromArgb(13, 15, 20)
    Card  = [System.Drawing.Color]::FromArgb(23, 27, 36)
    CardHi= [System.Drawing.Color]::FromArgb(30, 36, 48)
    Border= [System.Drawing.Color]::FromArgb(38, 44, 58)
    BorderHi = [System.Drawing.Color]::FromArgb(58, 68, 88)
    TextHi= [System.Drawing.Color]::FromArgb(245, 248, 252)
    Text  = [System.Drawing.Color]::FromArgb(220, 228, 240)
    TextMid = [System.Drawing.Color]::FromArgb(160, 175, 195)
    TextDim = [System.Drawing.Color]::FromArgb(120, 135, 158)
    TextFaint = [System.Drawing.Color]::FromArgb(85, 96, 116)
    Accent= [System.Drawing.Color]::FromArgb(88, 148, 255)
    AccentHi = [System.Drawing.Color]::FromArgb(120, 175, 255)
    AccentSoft = [System.Drawing.Color]::FromArgb(30, 45, 80)
    Violet= [System.Drawing.Color]::FromArgb(150, 108, 255)
    Cyan  = [System.Drawing.Color]::FromArgb(100, 220, 255)
    Green = [System.Drawing.Color]::FromArgb(70, 220, 150)
    GreenSoft = [System.Drawing.Color]::FromArgb(20, 55, 40)
    Amber = [System.Drawing.Color]::FromArgb(255, 190, 90)
    AmberSoft = [System.Drawing.Color]::FromArgb(55, 42, 18)
    Red   = [System.Drawing.Color]::FromArgb(255, 105, 120)
    RedSoft = [System.Drawing.Color]::FromArgb(60, 24, 32)
    White = [System.Drawing.Color]::White
    Transparent = [System.Drawing.Color]::Transparent
}

$script:PowerPlans = @(
    @{ Name = "Kenzie's Custom";      Guid = "b7701089-9d55-49a7-90ec-f6be3a3566a9"; Tag = "KC" }
    @{ Name = "Ultimate Performance"; Guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"; Tag = "UP" }
    @{ Name = "High Performance";     Guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; Tag = "HP" }
    @{ Name = "Balanced";             Guid = "381b4222-f694-41f0-9685-ff5bb260df2e"; Tag = "BL" }
    @{ Name = "Power Saver";          Guid = "a1841308-3541-4fab-bc81-f71556f20b4a"; Tag = "PS" }
)

# ============================================================
#  2. CUSTOM CONTROLS (C# 5 safe)
#     All SetStyle calls happen BEFORE any property assignment
#     that requires the style flag to be enabled.
# ============================================================
if (-not ("KT5" -as [type])) {
    $cs = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace KT5
{
    public static class Util
    {
        public static GraphicsPath Round(Rectangle r, int radius)
        {
            GraphicsPath p = new GraphicsPath();
            if (r.Width < 2 || r.Height < 2)
            {
                p.AddRectangle(new Rectangle(r.X, r.Y, Math.Max(r.Width, 1), Math.Max(r.Height, 1)));
                return p;
            }
            int d = radius * 2;
            if (d > r.Width) d = r.Width;
            if (d > r.Height) d = r.Height;
            if (d < 2) d = 2;
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
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

    public enum KTVariant { Primary, Secondary, Ghost, Outline, Danger, Success, Icon }

    public class KTButton : Button
    {
        private KTVariant _variant = KTVariant.Secondary;
        private int _radius = 10;
        private bool _hovering, _pressing, _loading, _focused;
        private float _glow;
        private Timer _t;
        private Color _customBg, _customFg, _customBorder;
        private bool _custom = false;

        public KTVariant Variant { get { return _variant; } set { _variant = value; Invalidate(); } }
        public int Radius { get { return _radius; } set { _radius = value; Invalidate(); } }
        public bool IsLoading { get { return _loading; } set { _loading = value; Enabled = !value; Invalidate(); } }
        public Color CustomBg { get { return _customBg; } set { _customBg = value; _custom = true; Invalidate(); } }
        public Color CustomFg { get { return _customFg; } set { _customFg = value; _custom = true; Invalidate(); } }
        public Color CustomBorder { get { return _customBorder; } set { _customBorder = value; _custom = true; Invalidate(); } }

        public KTButton()
        {
            // Set styles FIRST so BackColor = Transparent is legal
            SetStyle(ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer |
                     ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor |
                     ControlStyles.Selectable, true);
            BackColor = Color.Transparent;
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            Font = new Font("Segoe UI Semibold", 9.5f, FontStyle.Bold);
            Cursor = Cursors.Hand;
            TabStop = true;
            _t = new Timer();
            _t.Interval = 16;
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
        protected override void OnMouseLeave(EventArgs e) { _hovering = false; _pressing = false; base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { _pressing = true; Invalidate(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { _pressing = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnGotFocus(EventArgs e) { _focused = true; Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { _focused = false; Invalidate(); base.OnLostFocus(e); }
        protected override bool IsInputKey(Keys k) { return true; }

        private void GetColors(out Color bg, out Color fg, out Color border)
        {
            bg = Color.FromArgb(24, 30, 42); fg = Color.FromArgb(220, 228, 240); border = Color.FromArgb(38, 44, 58);
            if (_custom) { bg = _customBg; fg = _customFg; border = _customBorder; return; }
            switch (_variant)
            {
                case KTVariant.Primary:   bg = Color.FromArgb(88, 148, 255); fg = Color.White; border = Color.FromArgb(120, 175, 255); break;
                case KTVariant.Secondary: bg = Color.FromArgb(28, 34, 46);   fg = Color.FromArgb(220, 228, 240); border = Color.FromArgb(48, 56, 72); break;
                case KTVariant.Ghost:     bg = Color.FromArgb(0, 0, 0, 0);   fg = Color.FromArgb(180, 195, 215); border = Color.FromArgb(0, 0, 0, 0); break;
                case KTVariant.Outline:   bg = Color.FromArgb(0, 0, 0, 0);   fg = Color.FromArgb(220, 228, 240); border = Color.FromArgb(80, 95, 120); break;
                case KTVariant.Danger:    bg = Color.FromArgb(255, 105, 120); fg = Color.White; border = Color.FromArgb(255, 130, 140); break;
                case KTVariant.Success:   bg = Color.FromArgb(70, 220, 150);  fg = Color.FromArgb(5, 20, 12); border = Color.FromArgb(100, 235, 175); break;
                case KTVariant.Icon:      bg = Color.FromArgb(0, 0, 0, 0);   fg = Color.FromArgb(200, 215, 235); border = Color.FromArgb(0, 0, 0, 0); break;
            }
        }

        protected override void OnPaint(PaintEventArgs pevent)
        {
            Graphics g = pevent.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = Width, h = Height;
            if (w < 2 || h < 2) return;

            Rectangle r = new Rectangle(0, 0, w - 1, h - 1);
            if (_pressing) r = new Rectangle(0, 1, w - 1, h - 1);

            Color bg, fg, border;
            GetColors(out bg, out fg, out border);

            if (_hovering && _variant != KTVariant.Ghost && _variant != KTVariant.Icon)
                bg = Util.Blend(bg, Color.White, 0.10f);
            if (_variant == KTVariant.Ghost || _variant == KTVariant.Icon)
                bg = Color.FromArgb((int)(_glow * 40), 255, 255, 255);

            using (GraphicsPath path = Util.Round(r, _radius))
            {
                if (bg.A > 0)
                    using (SolidBrush b = new SolidBrush(bg))
                        g.FillPath(b, path);
                if (_focused || (_hovering && border.A > 0))
                {
                    Color bc = _focused ? Color.FromArgb(160, 200, 255) : border;
                    using (Pen p = new Pen(bc, _focused ? 1.6f : 1f))
                        g.DrawPath(p, path);
                }
            }

            if (_loading)
            {
                int cx = w / 2, cy = h / 2, rad = 8;
                float ang = (float)(Environment.TickCount % 1000) / 1000f * 360f;
                using (Pen p = new Pen(fg, 2f))
                {
                    p.StartCap = LineCap.Round; p.EndCap = LineCap.Round;
                    g.DrawArc(p, cx - rad, cy - rad, rad * 2, rad * 2, ang, 260);
                }
            }
            else
            {
                Color tcol = Enabled ? fg : Color.FromArgb(90, 100, 118);
                TextRenderer.DrawText(g, Text, Font, r, tcol,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
            }
        }
    }

    public class KTToggle : Control
    {
        private bool _checked;
        private float _anim;
        private Timer _t;
        private bool _hovering, _busy, _focused;

        public bool Checked { get { return _checked; } set { _checked = value; Invalidate(); } }
        public bool Busy { get { return _busy; } set { _busy = value; Cursor = value ? Cursors.WaitCursor : Cursors.Hand; Invalidate(); } }
        public event EventHandler Toggled;

        public KTToggle()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor | ControlStyles.Selectable, true);
            BackColor = Color.Transparent;
            Size = new Size(46, 24);
            Cursor = Cursors.Hand;
            TabStop = true;
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

        protected override void OnMouseEnter(EventArgs e) { _hovering = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { _hovering = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnGotFocus(EventArgs e) { _focused = true; Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { _focused = false; Invalidate(); base.OnLostFocus(e); }
        protected override bool IsInputKey(Keys k) { return true; }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter) { OnClick(EventArgs.Empty); e.Handled = true; }
            base.OnKeyDown(e);
        }

        protected override void OnClick(EventArgs e)
        {
            if (!_busy) { _checked = !_checked; if (Toggled != null) Toggled(this, EventArgs.Empty); }
            base.OnClick(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = Width, h = Height;
            if (w < 4 || h < 4) return;

            Color off = Color.FromArgb(50, 58, 76);
            Color on = Color.FromArgb(70, 220, 150);
            Color bg = Util.Blend(off, on, _anim);
            if (_hovering) bg = Util.Blend(bg, Color.White, 0.08f);
            if (_busy) bg = Color.FromArgb(40, 48, 64);

            Rectangle r = new Rectangle(0, 0, w - 1, h - 1);
            GraphicsPath path = new GraphicsPath();
            int d = h - 2;
            path.AddArc(r.X, r.Y, d, d, 90, 180);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 180);
            path.CloseFigure();

            using (SolidBrush b = new SolidBrush(bg))
                g.FillPath(b, path);
            if (_anim > 0.1f)
                using (Pen gp = new Pen(Color.FromArgb((int)(_anim * 80), on), 3f))
                    g.DrawPath(gp, path);
            if (_focused)
                using (Pen fp = new Pen(Color.FromArgb(160, 200, 255), 2f))
                    g.DrawPath(fp, path);
            path.Dispose();

            int knobSize = h - 6;
            if (knobSize < 2) knobSize = 2;
            int knobX = (int)(3 + _anim * (w - knobSize - 6));
            using (SolidBrush kb = new SolidBrush(_busy ? Color.FromArgb(180, 190, 210) : Color.White))
                g.FillEllipse(kb, knobX, 3, knobSize, knobSize);

            if (_busy)
            {
                float ang = (float)(Environment.TickCount % 900) / 900f * 360f;
                using (Pen p = new Pen(Color.FromArgb(200, 230, 255), 1.6f))
                {
                    p.StartCap = LineCap.Round; p.EndCap = LineCap.Round;
                    g.DrawArc(p, knobX + 5, 8, knobSize - 10, knobSize - 10, ang, 250);
                }
            }
        }
    }

    public class KTBar : Control
    {
        private float _value, _anim;
        private Color _c1 = Color.FromArgb(88, 148, 255);
        private Color _c2 = Color.FromArgb(150, 108, 255);
        private Timer _t;

        public float Value { get { return _value; } set { _value = value; } }
        public Color ColorFrom { get { return _c1; } set { _c1 = value; Invalidate(); } }
        public Color ColorTo { get { return _c2; } set { _c2 = value; Invalidate(); } }

        public KTBar()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            _t = new Timer();
            _t.Interval = 16;
            _t.Tick += new EventHandler(Tick);
            _t.Start();
        }

        private void Tick(object s, EventArgs e)
        {
            float tgt = Math.Max(0f, Math.Min(_value, 100f)) / 100f;
            _anim += (tgt - _anim) * 0.15f;
            if (Math.Abs(_anim - tgt) < 0.001f) _anim = tgt;
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = Width, h = Height;
            if (w < 4 || h < 2) return;

            int rad = h / 2;
            Rectangle full = new Rectangle(0, 0, w - 1, h - 1);
            using (GraphicsPath fp = Util.Round(full, rad))
            using (SolidBrush bg = new SolidBrush(Color.FromArgb(28, 34, 46)))
                g.FillPath(bg, fp);

            int fillW = (int)(w * _anim);
            if (fillW > 3)
            {
                Rectangle fr = new Rectangle(0, 0, fillW, h - 1);
                using (GraphicsPath fillPath = Util.Round(fr, rad))
                using (LinearGradientBrush lb = new LinearGradientBrush(
                    new Rectangle(0, 0, Math.Max(fillW, 2), h),
                    _c1, _c2, LinearGradientMode.Horizontal))
                    g.FillPath(lb, fillPath);
            }
        }
    }

    public class KTSpark : Control
    {
        private System.Collections.Generic.List<float> _pts = new System.Collections.Generic.List<float>();
        private int _maxPts = 60;
        private Color _line = Color.FromArgb(100, 220, 255);
        private Color _fill = Color.FromArgb(88, 148, 255);

        public Color LineColor { get { return _line; } set { _line = value; Invalidate(); } }
        public Color FillColor { get { return _fill; } set { _fill = value; Invalidate(); } }

        public KTSpark()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        public void Push(float v) { _pts.Add(v); while (_pts.Count > _maxPts) _pts.RemoveAt(0); Invalidate(); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = Width, h = Height;
            if (w < 4 || h < 4 || _pts.Count < 2) return;

            float step = (float)w / (_maxPts - 1);
            PointF[] pts = new PointF[_pts.Count];
            int off = _maxPts - _pts.Count;
            for (int i = 0; i < _pts.Count; i++)
            {
                float x = (off + i) * step;
                float y = h - (_pts[i] / 100f) * h;
                if (y < 0) y = 0; if (y > h) y = h;
                pts[i] = new PointF(x, y);
            }
            PointF[] fillPts = new PointF[pts.Length + 2];
            Array.Copy(pts, fillPts, pts.Length);
            fillPts[pts.Length] = new PointF(pts[pts.Length - 1].X, h);
            fillPts[pts.Length + 1] = new PointF(pts[0].X, h);
            using (SolidBrush fb = new SolidBrush(Color.FromArgb(30, _fill)))
                g.FillPolygon(fb, fillPts);
            using (Pen p = new Pen(_line, 1.6f))
                g.DrawLines(p, pts);
        }
    }

    public class KTChip : Control
    {
        private string _chipText = "";
        private Color _bg = Color.FromArgb(20, 55, 40);
        private Color _fg = Color.FromArgb(70, 220, 150);
        private Color _border = Color.FromArgb(70, 220, 150);
        private int _radius = 7;

        // Use a separate property name to avoid clashing with Control.Text
        public string ChipText { get { return _chipText; } set { _chipText = value; Invalidate(); } }
        public Color BgColor { get { return _bg; } set { _bg = value; Invalidate(); } }
        public Color FgColor { get { return _fg; } set { _fg = value; Invalidate(); } }
        public Color BorderColor { get { return _border; } set { _border = value; Invalidate(); } }
        public int Radius { get { return _radius; } set { _radius = value; Invalidate(); } }

        public KTChip()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                     ControlStyles.DoubleBuffer | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Size = new Size(90, 24);
            Font = new Font("Segoe UI Semibold", 8f, FontStyle.Bold);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int w = Width, h = Height;
            if (w < 2 || h < 2) return;

            Rectangle r = new Rectangle(0, 0, w - 1, h - 1);
            using (GraphicsPath path = Util.Round(r, _radius))
            {
                using (SolidBrush b = new SolidBrush(_bg))
                    g.FillPath(b, path);
                using (Pen p = new Pen(Color.FromArgb(120, _border), 1f))
                    g.DrawPath(p, path);
            }
            TextRenderer.DrawText(g, _chipText, Font, r, _fg,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }
}
"@
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $cs -Language CSharp
}

# ============================================================
#  3. HELPERS
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
function Test-UltimateUnlocked {
    try { return (powercfg /list 2>$null | Select-String 'e9a42b02-d5df-448d-aa00-03f14749eb61') -ne $null }
    catch { return $false }
}
function Test-KenziePlanExists {
    try { return (powercfg /list 2>$null | Select-String 'b7701089-9d55-49a7-90ec-f6be3a3566a9') -ne $null }
    catch { return $false }
}
function Test-HibernationEnabled {
    try { $out = powercfg /a 2>$null; return ($out -notmatch 'Hibernation has not been enabled') } catch { return $false }
}
function Test-TelemetryEnabled {
    try { $s = Get-Service DiagTrack -ErrorAction SilentlyContinue; if ($s) { return $s.Status -eq 'Running' } } catch { }
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

# ============================================================
#  4. MAIN FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Kenzie's Tweaks"
$form.Size = New-Object System.Drawing.Size(1200, 780)
$form.MinimumSize = New-Object System.Drawing.Size(900, 600)
$form.StartPosition = "CenterScreen"
$form.BackColor = $D.Bg0
$form.ForeColor = $D.Text
$form.FormBorderStyle = "None"
$form.KeyPreview = $true
Enable-DoubleBuffer $form

$form.Add_Resize({
    if ($form.Width -lt 4 -or $form.Height -lt 4) { return }
    $r = 18
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc(0, 0, $r * 2, $r * 2, 180, 90)
    $p.AddArc($form.Width - $r * 2, 0, $r * 2, $r * 2, 270, 90)
    $p.AddArc($form.Width - $r * 2, $form.Height - $r * 2, $r * 2, $r * 2, 0, 90)
    $p.AddArc(0, $form.Height - $r * 2, $r * 2, $r * 2, 90, 90)
    $p.CloseAllFigures()
    $form.Region = New-Object System.Drawing.Region($p)
})

# ============================================================
#  5. TITLE BAR
# ============================================================
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Height = 48
$titleBar.Dock = "Top"
$titleBar.BackColor = $D.Bg1
$form.Controls.Add($titleBar)

$titleBar.Add_Paint({
    param($s, $e)
    if ($titleBar.Width -lt 2) { return }
    $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
    $e.Graphics.DrawLine($pen, 0, $titleBar.Height - 1, $titleBar.Width, $titleBar.Height - 1)
    $pen.Dispose()
})

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

$brandMark = New-Object System.Windows.Forms.Label
$brandMark.Text = "K"
$brandMark.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
$brandMark.ForeColor = $D.White
$brandMark.AutoSize = $false
$brandMark.Size = New-Object System.Drawing.Size(30, 30)
$brandMark.Location = New-Object System.Drawing.Point(14, 9)
$brandMark.TextAlign = "MiddleCenter"
$brandMark.BackColor = $D.Accent
$titleBar.Controls.Add($brandMark)

$brandTitle = New-Object System.Windows.Forms.Label
$brandTitle.Text = "Kenzie's Tweaks"
$brandTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
$brandTitle.ForeColor = $D.TextHi
$brandTitle.AutoSize = $true
$brandTitle.BackColor = $D.Transparent
$brandTitle.Location = New-Object System.Drawing.Point(54, 14)
$titleBar.Controls.Add($brandTitle)

# Title buttons - explicit types, no bare type literals
function New-TbBtn {
    param(
        [Parameter(Mandatory=$true)][string]$Glyph,
        [Parameter(Mandatory=$true)][int]$PosX,
        [Parameter(Mandatory=$true)][System.Drawing.Color]$HoverColor,
        [Parameter(Mandatory=$true)][System.Drawing.Color]$HoverBg
    )
    $b = New-Object System.Windows.Forms.Label
    $b.Text = $Glyph
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $b.ForeColor = $D.TextMid
    $b.BackColor = $D.Transparent
    $b.Size = New-Object System.Drawing.Size(46, 48)
    $b.Location = New-Object System.Drawing.Point($PosX, 0)
    $b.TextAlign = "MiddleCenter"
    $b.Cursor = "Hand"
    $hc = $HoverColor
    $hb = $HoverBg
    $b.Add_MouseEnter({
        param($s, $e)
        $s.ForeColor = $hc
        $s.BackColor = $hb
    })
    $b.Add_MouseLeave({
        param($s, $e)
        $s.ForeColor = $D.TextMid
        $s.BackColor = $D.Transparent
    })
    return $b
}

$btnMin = New-TbBtn -Glyph "_" -PosX ($form.Width - 92) -HoverColor $D.TextHi -HoverBg $D.Card
$btnMin.Add_Click({ $form.WindowState = "Minimized" })
$titleBar.Controls.Add($btnMin)

$btnClose = New-TbBtn -Glyph "X" -PosX ($form.Width - 46) -HoverColor $D.White -HoverBg $D.Red
$btnClose.Add_Click({ $form.Close() })
$titleBar.Controls.Add($btnClose)

# ============================================================
#  6. LOADING OVERLAY
# ============================================================
$loadingPanel = New-Object System.Windows.Forms.Panel
$loadingPanel.Dock = "Fill"
$loadingPanel.BackColor = $D.Bg0
$form.Controls.Add($loadingPanel)
$loadingPanel.BringToFront()

$loadLogo = New-Object System.Windows.Forms.Label
$loadLogo.Text = "K"
$loadLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 44, [System.Drawing.FontStyle]::Bold)
$loadLogo.ForeColor = $D.White
$loadLogo.AutoSize = $false
$loadLogo.Size = New-Object System.Drawing.Size(120, 120)
$loadLogo.TextAlign = "MiddleCenter"
$loadLogo.BackColor = $D.Accent
$loadingPanel.Controls.Add($loadLogo)

$loadTitle = New-Object System.Windows.Forms.Label
$loadTitle.Text = "Kenzie's Tweaks"
$loadTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 24, [System.Drawing.FontStyle]::Bold)
$loadTitle.ForeColor = $D.TextHi
$loadTitle.AutoSize = $true
$loadTitle.BackColor = $D.Transparent
$loadingPanel.Controls.Add($loadTitle)

$loadSub = New-Object System.Windows.Forms.Label
$loadSub.Text = "Preparing your workspace"
$loadSub.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$loadSub.ForeColor = $D.TextDim
$loadSub.AutoSize = $true
$loadSub.BackColor = $D.Transparent
$loadingPanel.Controls.Add($loadSub)

$loadBarBg = New-Object System.Windows.Forms.Panel
$loadBarBg.Size = New-Object System.Drawing.Size(360, 3)
$loadBarBg.BackColor = $D.Card
$loadingPanel.Controls.Add($loadBarBg)

$loadBar = New-Object System.Windows.Forms.Panel
$loadBar.Size = New-Object System.Drawing.Size(0, 3)
$loadBar.Location = New-Object System.Drawing.Point(0, 0)
$loadBar.BackColor = $D.Accent
$loadBarBg.Controls.Add($loadBar)

$script:LoadSteps = @("Initializing engine","Verifying privileges","Reading power schemes","Detecting hardware","Rendering interface","Ready")
$script:LoadPct = 0

$loadTimer = New-Object System.Windows.Forms.Timer
$loadTimer.Interval = 20
$loadTimer.Add_Tick({
    $script:LoadPct += 2.5
    if ($script:LoadPct -gt 100) { $script:LoadPct = 100 }
    $loadBar.Width = [int](360 * ($script:LoadPct / 100))
    $idx = [Math]::Min([int]($script:LoadPct / 17), $script:LoadSteps.Count - 1)
    $loadSub.Text = $script:LoadSteps[$idx]
    if ($script:LoadPct -ge 100) {
        $loadTimer.Stop()
        Start-Sleep -Milliseconds 150
        $loadingPanel.Visible = $false
        if (Get-Command Refresh-AllStates -ErrorAction SilentlyContinue) { Refresh-AllStates }
    }
})
$loadTimer.Start()

$loadingPanel.Add_Resize({
    if ($loadingPanel.Width -lt 200) { return }
    $cx = [int](($loadingPanel.Width - 120) / 2)
    $loadLogo.Location = New-Object System.Drawing.Point($cx, 220)
    $loadTitle.Location = New-Object System.Drawing.Point(($cx - 60), 360)
    $loadSub.Location = New-Object System.Drawing.Point(($cx - 20), 405)
    $loadBarBg.Location = New-Object System.Drawing.Point($cx, 450)
})

# ============================================================
#  7. SIDEBAR
# ============================================================
$root = New-Object System.Windows.Forms.Panel
$root.Dock = "Fill"
$root.BackColor = $D.Bg0
$form.Controls.Add($root)
$root.BringToFront()

$script:SidebarExpanded = $true
$script:SIDEBAR_W_EXP = 240
$script:SIDEBAR_W_COL = 68

$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Width = $script:SIDEBAR_W_EXP
$sidebar.Dock = "Left"
$sidebar.BackColor = $D.Bg1
$root.Controls.Add($sidebar)

$sidebar.Add_Paint({
    param($s, $e)
    if ($sidebar.Width -lt 2) { return }
    $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
    $e.Graphics.DrawLine($pen, $sidebar.Width - 1, 0, $sidebar.Width - 1, $sidebar.Height)
    $pen.Dispose()
})

$sideInner = New-Object System.Windows.Forms.Panel
$sideInner.Dock = "Fill"
$sideInner.BackColor = $D.Transparent
$sideInner.AutoScroll = $true
$sidebar.Controls.Add($sideInner)

$sideHeader = New-Object System.Windows.Forms.Panel
$sideHeader.Height = 60
$sideHeader.Dock = "Top"
$sideHeader.BackColor = $D.Transparent
$sideInner.Controls.Add($sideHeader)

$sideLogo = New-Object System.Windows.Forms.Label
$sideLogo.Text = "K"
$sideLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold)
$sideLogo.ForeColor = $D.White
$sideLogo.AutoSize = $false
$sideLogo.Size = New-Object System.Drawing.Size(36, 36)
$sideLogo.Location = New-Object System.Drawing.Point(16, 12)
$sideLogo.TextAlign = "MiddleCenter"
$sideLogo.BackColor = $D.Accent
$sideHeader.Controls.Add($sideLogo)

$sideName = New-Object System.Windows.Forms.Label
$sideName.Text = "Kenzie's"
$sideName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
$sideName.ForeColor = $D.TextHi
$sideName.AutoSize = $true
$sideName.BackColor = $D.Transparent
$sideName.Location = New-Object System.Drawing.Point(60, 20)
$sideHeader.Controls.Add($sideName)

$sideToggle = New-Object KT5.KTButton
$sideToggle.Variant = [KT5.KTVariant]::Icon
$sideToggle.Text = "<<"
$sideToggle.Size = New-Object System.Drawing.Size(32, 32)
$sideToggle.Location = New-Object System.Drawing.Point(($script:SIDEBAR_W_EXP - 42), 14)
$sideToggle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
$sideHeader.Controls.Add($sideToggle)

$script:NavButtons = @{}
$script:NavLabels = @{}
$script:NavItems = @(
    @{ Key = "dashboard";  Label = "Dashboard";   Short = "D" }
    @{ Key = "power";      Label = "Power Plans"; Short = "P" }
    @{ Key = "tweaks";     Label = "Tweaks";      Short = "T" }
    @{ Key = "system";     Label = "System";      Short = "S" }
    @{ Key = "processes";  Label = "Processes";   Short = "R" }
    @{ Key = "about";      Label = "About";       Short = "i" }
)

$navGroupLbl = New-Object System.Windows.Forms.Label
$navGroupLbl.Text = "NAVIGATION"
$navGroupLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 7.5, [System.Drawing.FontStyle]::Bold)
$navGroupLbl.ForeColor = $D.TextFaint
$navGroupLbl.AutoSize = $true
$navGroupLbl.BackColor = $D.Transparent
$navGroupLbl.Location = New-Object System.Drawing.Point(20, 80)
$sideInner.Controls.Add($navGroupLbl)

$navY = 100
foreach ($nav in $script:NavItems) {
    $nb = New-Object KT5.KTButton
    $nb.Variant = [KT5.KTVariant]::Ghost
    $nb.Text = $nav.Label
    $nb.TextAlign = "MiddleLeft"
    $nb.Size = New-Object System.Drawing.Size(($script:SIDEBAR_W_EXP - 24), 40)
    $nb.Location = New-Object System.Drawing.Point(12, $navY)
    $nb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $nb.Padding = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
    $nb.Tag = $nav.Key
    $nb.CustomFg = $D.TextMid
    $sideInner.Controls.Add($nb)
    $script:NavButtons[$nav.Key] = $nb

    $dot = New-Object System.Windows.Forms.Label
    $dot.Text = $nav.Short
    $dot.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
    $dot.ForeColor = $D.TextDim
    $dot.AutoSize = $false
    $dot.Size = New-Object System.Drawing.Size(28, 28)
    $dot.Location = New-Object System.Drawing.Point(20, ($navY + 6))
    $dot.TextAlign = "MiddleCenter"
    $dot.BackColor = $D.Card
    $sideInner.Controls.Add($dot)
    $dot.BringToFront()
    $script:NavLabels[$nav.Key] = $dot

    $navY += 46
}

$content = New-Object System.Windows.Forms.Panel
$content.Dock = "Fill"
$content.BackColor = $D.Bg0
$content.Padding = New-Object System.Windows.Forms.Padding(24, 20, 24, 20)
$root.Controls.Add($content)
$content.BringToFront()

# ============================================================
#  8. TOASTS
# ============================================================
$script:Toasts = New-Object System.Collections.ArrayList

function Show-Toast {
    param([string]$Message, [string]$Type = "info", [int]$DurationMs = 3500)
    $colors = @{
        info    = @{ Bg = $D.AccentSoft; Br = $D.Accent; Fg = $D.AccentHi; Icon = "i" }
        success = @{ Bg = $D.GreenSoft;  Br = $D.Green;  Fg = $D.Green;   Icon = "+" }
        error   = @{ Bg = $D.RedSoft;    Br = $D.Red;    Fg = $D.Red;     Icon = "!" }
        warning = @{ Bg = $D.AmberSoft;  Br = $D.Amber;  Fg = $D.Amber;   Icon = "!" }
        loading = @{ Bg = $D.CardHi;     Br = $D.BorderHi; Fg = $D.TextMid; Icon = "~" }
    }
    $c = $colors[$Type]; if (-not $c) { $c = $colors.info }
    $cap = $c

    $toast = New-Object System.Windows.Forms.Panel
    $toast.Size = New-Object System.Drawing.Size(340, 56)
    $toast.BackColor = $cap.Bg

    $toast.Add_Paint({
        param($s, $e)
        if ($toast.Width -lt 4) { return }
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $rect = New-Object System.Drawing.Rectangle(0, 0, $toast.Width - 1, $toast.Height - 1)
        $path = [KT5.Util]::Round($rect, 10)
        $pen = [System.Drawing.Pen]::new($cap.Br, [float]1.0)
        $g.DrawPath($pen, $path)
        $pen.Dispose()
        $path.Dispose()
    })

    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = $cap.Icon
    $icon.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
    $icon.ForeColor = $cap.Fg
    $icon.AutoSize = $false
    $icon.Size = New-Object System.Drawing.Size(36, 36)
    $icon.Location = New-Object System.Drawing.Point(10, 10)
    $icon.TextAlign = "MiddleCenter"
    $icon.BackColor = $D.Transparent
    $toast.Controls.Add($icon)

    $msg = New-Object System.Windows.Forms.Label
    $msg.Text = $Message
    $msg.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5, [System.Drawing.FontStyle]::Bold)
    $msg.ForeColor = $cap.Fg
    $msg.AutoSize = $false
    $msg.Size = New-Object System.Drawing.Size(280, 56)
    $msg.Location = New-Object System.Drawing.Point(50, 0)
    $msg.TextAlign = "MiddleLeft"
    $msg.BackColor = $D.Transparent
    $toast.Controls.Add($msg)

    $toast.Location = New-Object System.Drawing.Point(($form.Width - $toast.Width - 24), ($form.Height - 80))
    $form.Controls.Add($toast)
    $toast.BringToFront()
    [void]$script:Toasts.Add($toast)

    if ($Type -ne "loading") {
        $tm = New-Object System.Windows.Forms.Timer
        $tm.Interval = $DurationMs
        $tm.Add_Tick({ $tm.Stop(); $tm.Dispose(); try { $toast.Dispose() } catch { } })
        $tm.Start()
    }
    return $toast
}

function Update-Toasts {
    $y = $form.Height - 80
    for ($i = $script:Toasts.Count - 1; $i -ge 0; $i--) {
        $t = $script:Toasts[$i]
        if ($t.IsDisposed) { $script:Toasts.RemoveAt($i); continue }
        $t.Location = New-Object System.Drawing.Point(($form.Width - $t.Width - 24), $y)
        $y -= ($t.Height + 10)
    }
}

# ============================================================
#  9. SIDEBAR STATE
# ============================================================
function Set-SidebarState {
    param([bool]$Expanded)
    $script:SidebarExpanded = $Expanded
    if ($Expanded) {
        $sidebar.Width = $script:SIDEBAR_W_EXP
        $sideToggle.Text = "<<"
        $sideToggle.Location = New-Object System.Drawing.Point(($script:SIDEBAR_W_EXP - 42), 14)
        $sideName.Visible = $true
        $navGroupLbl.Visible = $true
    } else {
        $sidebar.Width = $script:SIDEBAR_W_COL
        $sideToggle.Text = ">>"
        $sideToggle.Location = New-Object System.Drawing.Point(($script:SIDEBAR_W_COL - 42), 14)
        $sideName.Visible = $false
        $navGroupLbl.Visible = $false
    }
    foreach ($k in $script:NavButtons.Keys) {
        $nb = $script:NavButtons[$k]
        if ($Expanded) {
            $nb.Width = ($script:SIDEBAR_W_EXP - 24)
            $nb.Text = ($script:NavItems | Where-Object { $_.Key -eq $k }).Label
        } else {
            $nb.Width = ($script:SIDEBAR_W_COL - 24)
            $nb.Text = ""
        }
        $nb.Invalidate()
        $script:NavLabels[$k].Location = New-Object System.Drawing.Point(20, ($nb.Top + 6))
    }
}

$sideToggle.Add_Click({ Set-SidebarState -Expanded (-not $script:SidebarExpanded) })

# ============================================================
#  10. PAGES
# ============================================================
$script:Pages = @{}

function New-Page {
    param([string]$Key)
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = "Fill"
    $p.BackColor = $D.Bg0
    $p.Visible = $false
    $content.Controls.Add($p)
    $script:Pages[$Key] = $p
    return $p
}
function New-H1 {
    param($parent, $text)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 22, [System.Drawing.FontStyle]::Bold)
    $l.ForeColor = $D.TextHi
    $l.AutoSize = $true
    $l.BackColor = $D.Transparent
    $l.Location = New-Object System.Drawing.Point(0, 0)
    $parent.Controls.Add($l)
    return $l
}
function New-H2 {
    param($parent, $text)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $l.ForeColor = $D.TextDim
    $l.AutoSize = $true
    $l.BackColor = $D.Transparent
    $l.Location = New-Object System.Drawing.Point(2, 34)
    $parent.Controls.Add($l)
    return $l
}

# ---------- Dashboard ----------
$pageDash = New-Page "dashboard"
New-H1 $pageDash "Dashboard" | Out-Null
New-H2 $pageDash "Live system performance overview" | Out-Null

$cpuCard = New-Object System.Windows.Forms.Panel
$cpuCard.Size = New-Object System.Drawing.Size(380, 156)
$cpuCard.Location = New-Object System.Drawing.Point(0, 78)
$cpuCard.BackColor = $D.Card
$cpuCard.Add_Paint({
    param($s, $e)
    if ($cpuCard.Width -lt 4 -or $cpuCard.Height -lt 4) { return }
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, ($cpuCard.Width - 1), ($cpuCard.Height - 1))
    $path = [KT5.Util]::Round($rect, 14)
    $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
    $g.DrawPath($pen, $path)
    $pen.Dispose()
    $path.Dispose()
})
$pageDash.Controls.Add($cpuCard)

$cpuTitle = New-Object System.Windows.Forms.Label
$cpuTitle.Text = "CPU LOAD"
$cpuTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5, [System.Drawing.FontStyle]::Bold)
$cpuTitle.ForeColor = $D.TextDim
$cpuTitle.AutoSize = $true
$cpuTitle.BackColor = $D.Transparent
$cpuTitle.Location = New-Object System.Drawing.Point(22, 16)
$cpuCard.Controls.Add($cpuTitle)

$cpuPct = New-Object System.Windows.Forms.Label
$cpuPct.Text = "0%"
$cpuPct.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 30, [System.Drawing.FontStyle]::Bold)
$cpuPct.ForeColor = $D.TextHi
$cpuPct.AutoSize = $true
$cpuPct.BackColor = $D.Transparent
$cpuPct.Location = New-Object System.Drawing.Point(20, 38)
$cpuCard.Controls.Add($cpuPct)

$cpuBar = New-Object KT5.KTBar
$cpuBar.Size = New-Object System.Drawing.Size(336, 8)
$cpuBar.Location = New-Object System.Drawing.Point(22, 96)
$cpuBar.ColorFrom = $D.Accent
$cpuBar.ColorTo = $D.Cyan
$cpuCard.Controls.Add($cpuBar)

$cpuSpark = New-Object KT5.KTSpark
$cpuSpark.Size = New-Object System.Drawing.Size(336, 30)
$cpuSpark.Location = New-Object System.Drawing.Point(22, 116)
$cpuSpark.LineColor = $D.Cyan
$cpuSpark.FillColor = $D.Accent
$cpuCard.Controls.Add($cpuSpark)

$ramCard = New-Object System.Windows.Forms.Panel
$ramCard.Size = New-Object System.Drawing.Size(380, 156)
$ramCard.Location = New-Object System.Drawing.Point(400, 78)
$ramCard.BackColor = $D.Card
$ramCard.Add_Paint({
    param($s, $e)
    if ($ramCard.Width -lt 4 -or $ramCard.Height -lt 4) { return }
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, ($ramCard.Width - 1), ($ramCard.Height - 1))
    $path = [KT5.Util]::Round($rect, 14)
    $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
    $g.DrawPath($pen, $path)
    $pen.Dispose()
    $path.Dispose()
})
$pageDash.Controls.Add($ramCard)

$ramTitle = New-Object System.Windows.Forms.Label
$ramTitle.Text = "MEMORY"
$ramTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5, [System.Drawing.FontStyle]::Bold)
$ramTitle.ForeColor = $D.TextDim
$ramTitle.AutoSize = $true
$ramTitle.BackColor = $D.Transparent
$ramTitle.Location = New-Object System.Drawing.Point(22, 16)
$ramCard.Controls.Add($ramTitle)

$ramPct = New-Object System.Windows.Forms.Label
$ramPct.Text = "0%"
$ramPct.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 30, [System.Drawing.FontStyle]::Bold)
$ramPct.ForeColor = $D.TextHi
$ramPct.AutoSize = $true
$ramPct.BackColor = $D.Transparent
$ramPct.Location = New-Object System.Drawing.Point(20, 38)
$ramCard.Controls.Add($ramPct)

$ramBar = New-Object KT5.KTBar
$ramBar.Size = New-Object System.Drawing.Size(336, 8)
$ramBar.Location = New-Object System.Drawing.Point(22, 96)
$ramBar.ColorFrom = $D.Violet
$ramBar.ColorTo = $D.Accent
$ramCard.Controls.Add($ramBar)

$ramSpark = New-Object KT5.KTSpark
$ramSpark.Size = New-Object System.Drawing.Size(336, 30)
$ramSpark.Location = New-Object System.Drawing.Point(22, 116)
$ramSpark.LineColor = $D.Violet
$ramSpark.FillColor = $D.Violet
$ramCard.Controls.Add($ramSpark)

$procCard = New-Object System.Windows.Forms.Panel
$procCard.Size = New-Object System.Drawing.Size(780, 300)
$procCard.Location = New-Object System.Drawing.Point(0, 248)
$procCard.BackColor = $D.Card
$procCard.Add_Paint({
    param($s, $e)
    if ($procCard.Width -lt 4 -or $procCard.Height -lt 4) { return }
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, ($procCard.Width - 1), ($procCard.Height - 1))
    $path = [KT5.Util]::Round($rect, 14)
    $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
    $g.DrawPath($pen, $path)
    $pen.Dispose()
    $path.Dispose()
})
$pageDash.Controls.Add($procCard)

$procTitle = New-Object System.Windows.Forms.Label
$procTitle.Text = "TOP PROCESSES"
$procTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5, [System.Drawing.FontStyle]::Bold)
$procTitle.ForeColor = $D.TextDim
$procTitle.AutoSize = $true
$procTitle.BackColor = $D.Transparent
$procTitle.Location = New-Object System.Drawing.Point(22, 16)
$procCard.Controls.Add($procTitle)

$procList = New-Object System.Windows.Forms.Label
$procList.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$procList.ForeColor = $D.TextMid
$procList.BackColor = $D.Transparent
$procList.AutoSize = $false
$procList.Size = New-Object System.Drawing.Size(740, 240)
$procList.Location = New-Object System.Drawing.Point(22, 46)
$procCard.Controls.Add($procList)

# ---------- Power ----------
$pagePower = New-Page "power"
New-H1 $pagePower "Power Plans" | Out-Null
New-H2 $pagePower "Switch between performance profiles instantly" | Out-Null

$activeCard = New-Object System.Windows.Forms.Panel
$activeCard.Size = New-Object System.Drawing.Size(760, 116)
$activeCard.Location = New-Object System.Drawing.Point(0, 78)
$activeCard.BackColor = $D.Card
$activeCard.Add_Paint({
    param($s, $e)
    if ($activeCard.Width -lt 4 -or $activeCard.Height -lt 4) { return }
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, ($activeCard.Width - 1), ($activeCard.Height - 1))
    $path = [KT5.Util]::Round($rect, 14)
    $pen = [System.Drawing.Pen]::new($D.Accent, [float]1.4)
    $g.DrawPath($pen, $path)
    $pen.Dispose()
    $path.Dispose()
})
$pagePower.Controls.Add($activeCard)

$activeTag = New-Object System.Windows.Forms.Label
$activeTag.Text = "K"
$activeTag.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 20, [System.Drawing.FontStyle]::Bold)
$activeTag.ForeColor = $D.White
$activeTag.AutoSize = $false
$activeTag.Size = New-Object System.Drawing.Size(72, 72)
$activeTag.Location = New-Object System.Drawing.Point(22, 22)
$activeTag.TextAlign = "MiddleCenter"
$activeTag.BackColor = $D.Accent
$activeCard.Controls.Add($activeTag)

$activeHead = New-Object System.Windows.Forms.Label
$activeHead.Text = "ACTIVE POWER PLAN"
$activeHead.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
$activeHead.ForeColor = $D.TextDim
$activeHead.AutoSize = $true
$activeHead.BackColor = $D.Transparent
$activeHead.Location = New-Object System.Drawing.Point(115, 24)
$activeCard.Controls.Add($activeHead)

$activeNameLbl = New-Object System.Windows.Forms.Label
$activeNameLbl.Text = "Detecting..."
$activeNameLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 15, [System.Drawing.FontStyle]::Bold)
$activeNameLbl.ForeColor = $D.TextHi
$activeNameLbl.AutoSize = $true
$activeNameLbl.BackColor = $D.Transparent
$activeNameLbl.Location = New-Object System.Drawing.Point(115, 46)
$activeCard.Controls.Add($activeNameLbl)

$activeGuidLbl = New-Object System.Windows.Forms.Label
$activeGuidLbl.Text = ""
$activeGuidLbl.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$activeGuidLbl.ForeColor = $D.TextFaint
$activeGuidLbl.AutoSize = $true
$activeGuidLbl.BackColor = $D.Transparent
$activeGuidLbl.Location = New-Object System.Drawing.Point(117, 82)
$activeCard.Controls.Add($activeGuidLbl)

$script:PlanButtons = @{}
$planY = 214
$planX = 0
$col = 0
$planW = 246
foreach ($plan in $script:PowerPlans) {
    $pb = New-Object KT5.KTButton
    $pb.Variant = [KT5.KTVariant]::Secondary
    $pb.Text = "$($plan.Tag)    $($plan.Name)"
    $pb.TextAlign = "MiddleLeft"
    $pb.Padding = New-Object System.Windows.Forms.Padding(16, 0, 0, 0)
    $pb.Size = New-Object System.Drawing.Size($planW, 62)
    $pb.Location = New-Object System.Drawing.Point($planX, $planY)
    $pb.Radius = 12
    $pb.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5, [System.Drawing.FontStyle]::Bold)
    $pb.Tag = $plan.Guid
    $pb.Add_Click({ param($s, $e) Apply-PowerPlan -Guid $s.Tag -Button $s })
    $pagePower.Controls.Add($pb)
    $script:PlanButtons[$plan.Guid] = $pb
    $col++
    if ($col -ge 3) { $col = 0; $planX = 0; $planY += 74 } else { $planX += ($planW + 8) }
}

# ---------- Tweaks ----------
$pageTweaks = New-Page "tweaks"
New-H1 $pageTweaks "Tweaks" | Out-Null
New-H2 $pageTweaks "Toggle system optimizations - state is live and accurate" | Out-Null

$script:Tweaks = @(
    @{ Key = "ultimate"; Name = "Ultimate Performance Plan"; Desc = "Unlock hidden Ultimate Performance power scheme"; Test = { Test-UltimateUnlocked }
       On = { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null }
       Off = { powercfg /delete e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null } }
    @{ Key = "kenzieplan"; Name = "Kenzie's Custom Plan"; Desc = "Create custom plan b7701089-... from Ultimate"; Test = { Test-KenziePlanExists }
       On = { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 b7701089-9d55-49a7-90ec-f6be3a3566a9 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e b7701089-9d55-49a7-90ec-f6be3a3566a9 2>&1 | Out-Null } }
       Off = { powercfg /delete b7701089-9d55-49a7-90ec-f6be3a3566a9 2>&1 | Out-Null } }
    @{ Key = "hibernate"; Name = "Hibernation"; Desc = "Enable or disable hibernate (frees disk)"; Test = { Test-HibernationEnabled }
       On = { powercfg -h on 2>&1 | Out-Null }
       Off = { powercfg -h off 2>&1 | Out-Null } }
    @{ Key = "telemetry"; Name = "DiagTrack Telemetry"; Desc = "Windows telemetry tracking service"; Test = { Test-TelemetryEnabled }
       On = { Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service DiagTrack -ErrorAction SilentlyContinue }
       Off = { Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue } }
    @{ Key = "gamemode"; Name = "Windows Game Mode"; Desc = "Optimize system for gaming sessions"; Test = { Test-GameModeEnabled }
       On = { if (-not (Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }; Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 -ErrorAction SilentlyContinue }
       Off = { if (-not (Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }; Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 0 -ErrorAction SilentlyContinue } }
    @{ Key = "gamebar"; Name = "Disable Xbox Game Bar"; Desc = "Turn off the Game Bar overlay entirely"; Test = { Test-GameBarDisabled }
       On = { if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR')) { New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null }; Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 -ErrorAction SilentlyContinue }
       Off = { if (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR')) { New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Force | Out-Null }; Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 1 -ErrorAction SilentlyContinue } }
)

$script:TweakControls = @{}
$ty = 78
foreach ($t in $script:Tweaks) {
    $row = New-Object System.Windows.Forms.Panel
    $row.Size = New-Object System.Drawing.Size(760, 76)
    $row.Location = New-Object System.Drawing.Point(0, $ty)
    $row.BackColor = $D.Card
    $row.Tag = $t.Key
    $row.Add_Paint({
        param($s, $e)
        if ($row.Width -lt 4 -or $row.Height -lt 4) { return }
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $rect = New-Object System.Drawing.Rectangle(0, 0, ($row.Width - 1), ($row.Height - 1))
        $path = [KT5.Util]::Round($rect, 12)
        $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
        $g.DrawPath($pen, $path)
        $pen.Dispose()
        $path.Dispose()
    })
    $pageTweaks.Controls.Add($row)

    $nameLbl = New-Object System.Windows.Forms.Label
    $nameLbl.Text = $t.Name
    $nameLbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
    $nameLbl.ForeColor = $D.TextHi
    $nameLbl.AutoSize = $true
    $nameLbl.BackColor = $D.Transparent
    $nameLbl.Location = New-Object System.Drawing.Point(24, 15)
    $row.Controls.Add($nameLbl)

    $descLbl = New-Object System.Windows.Forms.Label
    $descLbl.Text = $t.Desc
    $descLbl.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $descLbl.ForeColor = $D.TextDim
    $descLbl.AutoSize = $true
    $descLbl.BackColor = $D.Transparent
    $descLbl.Location = New-Object System.Drawing.Point(24, 42)
    $row.Controls.Add($descLbl)

    $chip = New-Object KT5.KTChip
    $chip.ChipText = "DISABLED"
    $chip.Size = New-Object System.Drawing.Size(100, 26)
    $chip.Location = New-Object System.Drawing.Point(($row.Width - 230), 25)
    $chip.BgColor = $D.CardHi
    $chip.FgColor = $D.TextDim
    $chip.BorderColor = $D.BorderHi
    $row.Controls.Add($chip)

    $tg = New-Object KT5.KTToggle
    $tg.Size = New-Object System.Drawing.Size(48, 26)
    $tg.Location = New-Object System.Drawing.Point(($row.Width - 100), 25)
    $row.Controls.Add($tg)

    $script:TweakControls[$t.Key] = @{ Toggle = $tg; Chip = $chip; Def = $t; Row = $row }

    $key = $t.Key
    $tg.Add_Toggled({
        param($s, $e)
        $c = $script:TweakControls[$key]
        $c.Toggle.Busy = $true
        $c.Chip.ChipText = "WORKING"
        $c.Chip.BgColor = $D.AmberSoft
        $c.Chip.FgColor = $D.Amber
        $c.Chip.BorderColor = $D.Amber
        [System.Windows.Forms.Application]::DoEvents()
        try {
            if ($c.Toggle.Checked) { & $c.Def.On; Show-Toast "$($c.Def.Name) enabled" "success" | Out-Null }
            else { & $c.Def.Off; Show-Toast "$($c.Def.Name) disabled" "info" | Out-Null }
            Start-Sleep -Milliseconds 200
            Update-TweakState -Key $key
        } catch {
            Show-Toast "Error: $($_.Exception.Message)" "error" | Out-Null
        } finally {
            $c.Toggle.Busy = $false
        }
    })
    $ty += 84
}

# ---------- System ----------
$pageSystem = New-Page "system"
New-H1 $pageSystem "System Information" | Out-Null
New-H2 $pageSystem "Hardware and OS details" | Out-Null

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
    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(760, 60)
    $card.Location = New-Object System.Drawing.Point(0, $sy)
    $card.BackColor = $D.Card
    $card.Add_Paint({
        param($s, $e)
        if ($card.Width -lt 4 -or $card.Height -lt 4) { return }
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $rect = New-Object System.Drawing.Rectangle(0, 0, ($card.Width - 1), ($card.Height - 1))
        $path = [KT5.Util]::Round($rect, 11)
        $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
        $g.DrawPath($pen, $path)
        $pen.Dispose()
        $path.Dispose()
    })
    $pageSystem.Controls.Add($card)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $f.L.ToUpper()
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = $D.TextFaint
    $lbl.AutoSize = $true
    $lbl.BackColor = $D.Transparent
    $lbl.Location = New-Object System.Drawing.Point(22, 12)
    $card.Controls.Add($lbl)

    $val = New-Object System.Windows.Forms.Label
    $val.Text = $f.V
    $val.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
    $val.ForeColor = $D.Text
    $val.AutoSize = $true
    $val.BackColor = $D.Transparent
    $val.Location = New-Object System.Drawing.Point(22, 30)
    $card.Controls.Add($val)

    $sy += 68
}

# ---------- Processes ----------
$pageProc = New-Page "processes"
New-H1 $pageProc "Processes" | Out-Null
New-H2 $pageProc "Top consumers - auto-refreshing" | Out-Null

$procBigCard = New-Object System.Windows.Forms.Panel
$procBigCard.Size = New-Object System.Drawing.Size(760, 460)
$procBigCard.Location = New-Object System.Drawing.Point(0, 76)
$procBigCard.BackColor = $D.Card
$procBigCard.Anchor = "Top,Left,Right,Bottom"
$procBigCard.Add_Paint({
    param($s, $e)
    if ($procBigCard.Width -lt 4 -or $procBigCard.Height -lt 4) { return }
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, ($procBigCard.Width - 1), ($procBigCard.Height - 1))
    $path = [KT5.Util]::Round($rect, 14)
    $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
    $g.DrawPath($pen, $path)
    $pen.Dispose()
    $path.Dispose()
})
$pageProc.Controls.Add($procBigCard)

$procGrid = New-Object System.Windows.Forms.Label
$procGrid.Font = New-Object System.Drawing.Font("Consolas", 10)
$procGrid.ForeColor = $D.TextMid
$procGrid.BackColor = $D.Transparent
$procGrid.AutoSize = $false
$procGrid.Size = New-Object System.Drawing.Size(720, 420)
$procGrid.Location = New-Object System.Drawing.Point(24, 24)
$procBigCard.Controls.Add($procGrid)

# ---------- About ----------
$pageAbout = New-Page "about"
New-H1 $pageAbout "About" | Out-Null

$aboutCard = New-Object System.Windows.Forms.Panel
$aboutCard.Size = New-Object System.Drawing.Size(760, 400)
$aboutCard.Location = New-Object System.Drawing.Point(0, 60)
$aboutCard.BackColor = $D.Card
$aboutCard.Add_Paint({
    param($s, $e)
    if ($aboutCard.Width -lt 4 -or $aboutCard.Height -lt 4) { return }
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, ($aboutCard.Width - 1), ($aboutCard.Height - 1))
    $path = [KT5.Util]::Round($rect, 16)
    $pen = [System.Drawing.Pen]::new($D.Border, [float]1.0)
    $g.DrawPath($pen, $path)
    $pen.Dispose()
    $path.Dispose()
})
$pageAbout.Controls.Add($aboutCard)

$aboutLogo = New-Object System.Windows.Forms.Label
$aboutLogo.Text = "K"
$aboutLogo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 36, [System.Drawing.FontStyle]::Bold)
$aboutLogo.ForeColor = $D.White
$aboutLogo.AutoSize = $false
$aboutLogo.Size = New-Object System.Drawing.Size(100, 100)
$aboutLogo.Location = New-Object System.Drawing.Point(30, 30)
$aboutLogo.TextAlign = "MiddleCenter"
$aboutLogo.BackColor = $D.Accent
$aboutCard.Controls.Add($aboutLogo)

$aboutTitle = New-Object System.Windows.Forms.Label
$aboutTitle.Text = "Kenzie's Tweaks"
$aboutTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 24, [System.Drawing.FontStyle]::Bold)
$aboutTitle.ForeColor = $D.TextHi
$aboutTitle.AutoSize = $true
$aboutTitle.BackColor = $D.Transparent
$aboutTitle.Location = New-Object System.Drawing.Point(160, 40)
$aboutCard.Controls.Add($aboutTitle)

$aboutVer = New-Object System.Windows.Forms.Label
$aboutVer.Text = "Version 5.0  -  Rebuilt"
$aboutVer.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$aboutVer.ForeColor = $D.TextDim
$aboutVer.AutoSize = $true
$aboutVer.BackColor = $D.Transparent
$aboutVer.Location = New-Object System.Drawing.Point(162, 85)
$aboutCard.Controls.Add($aboutVer)

$aboutDesc = New-Object System.Windows.Forms.Label
$aboutDesc.Text = "A premium PowerShell dashboard for power plan`nmanagement, system tweaks, and live monitoring.`n`nCustom plan GUID:`nb7701089-9d55-49a7-90ec-f6be3a3566a9"
$aboutDesc.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
$aboutDesc.ForeColor = $D.TextMid
$aboutDesc.AutoSize = $true
$aboutDesc.BackColor = $D.Transparent
$aboutDesc.Location = New-Object System.Drawing.Point(162, 120)
$aboutCard.Controls.Add($aboutDesc)

# ============================================================
#  11. NAVIGATION + STATE FUNCTIONS
# ============================================================
function Switch-Page {
    param([string]$Key)
    foreach ($k in $script:Pages.Keys) {
        $script:Pages[$k].Visible = ($k -eq $Key)
        if ($k -eq $Key) {
            $script:NavButtons[$k].CustomBg = $D.Accent
            $script:NavButtons[$k].CustomFg = $D.White
        } else {
            $script:NavButtons[$k].CustomFg = $D.TextMid
        }
        $script:NavButtons[$k].Invalidate()
    }
    $script:Pages[$Key].BringToFront()
}

foreach ($k in $script:NavButtons.Keys) {
    $key = $k
    $script:NavButtons[$k].Add_Click({ Switch-Page -Key $key })
}

function Update-TweakState {
    param([string]$Key)
    $c = $script:TweakControls[$Key]
    if (-not $c) { return }
    try { $enabled = [bool](& $c.Def.Test) } catch { $enabled = $false }
    $c.Toggle.Checked = $enabled
    if ($enabled) {
        $c.Chip.ChipText = "ENABLED"
        $c.Chip.BgColor = $D.GreenSoft
        $c.Chip.FgColor = $D.Green
        $c.Chip.BorderColor = $D.Green
    } else {
        $c.Chip.ChipText = "DISABLED"
        $c.Chip.BgColor = $D.CardHi
        $c.Chip.FgColor = $D.TextDim
        $c.Chip.BorderColor = $D.BorderHi
    }
}

function Refresh-AllStates {
    foreach ($k in $script:TweakControls.Keys) { Update-TweakState -Key $k }
    Update-ActivePlanDisplay
}

function Update-ActivePlanDisplay {
    $ag = Get-ActivePlanGuid
    if ($ag) {
        $plan = $script:PowerPlans | Where-Object { $_.Guid -eq $ag } | Select-Object -First 1
        if ($plan) {
            $activeNameLbl.Text = $plan.Name
            $activeGuidLbl.Text = "GUID: $($plan.Guid)"
            $activeTag.Text = $plan.Tag
        } else {
            $activeNameLbl.Text = "Custom Plan"
            $activeGuidLbl.Text = "GUID: $ag"
            $activeTag.Text = "?"
        }
        foreach ($key in $script:PlanButtons.Keys) {
            if ($key -eq $ag) { $script:PlanButtons[$key].Variant = [KT5.KTVariant]::Primary }
            else { $script:PlanButtons[$key].Variant = [KT5.KTVariant]::Secondary }
            $script:PlanButtons[$key].Invalidate()
        }
    }
}

function Apply-PowerPlan {
    param([string]$Guid, [object]$Button)
    if (-not $script:IsAdmin) { Show-Toast "Administrator privileges required" "warning" | Out-Null; return }
    $Button.IsLoading = $true
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $check = powercfg /list 2>$null | Select-String $Guid
        if (-not $check) {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $Guid 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e $Guid 2>&1 | Out-Null }
            Start-Sleep -Milliseconds 250
        }
        powercfg /setactive $Guid 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Show-Toast "Power plan applied" "success" | Out-Null
            Start-Sleep -Milliseconds 120
            Update-ActivePlanDisplay
            Refresh-AllStates
        } else {
            Show-Toast "Failed to apply power plan" "error" | Out-Null
        }
    } catch {
        Show-Toast "Error: $($_.Exception.Message)" "error" | Out-Null
    } finally {
        $Button.IsLoading = $false
    }
}

# ============================================================
#  12. LIVE MONITOR
# ============================================================
$monTimer = New-Object System.Windows.Forms.Timer
$monTimer.Interval = 1500
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
    try {
        $procs = Get-Process -ErrorAction SilentlyContinue | Sort-Object -Property CPU -Descending | Select-Object -First 12
        $sb = New-Object System.Text.StringBuilder
        $i = 1
        foreach ($p in $procs) {
            $cpuMs = if ($p.CPU) { [int]$p.CPU } else { 0 }
            $memMB = [int]($p.WorkingSet64 / 1MB)
            [void]$sb.AppendLine(("{0,2}.  {1,-30}  CPU:{2,7} ms   RAM:{3,6} MB" -f $i, $p.ProcessName, $cpuMs, $memMB))
            $i++
        }
        $procList.Text = $sb.ToString()
        $procGrid.Text = $sb.ToString()
    } catch { }
    Update-Toasts
})
$monTimer.Start()

# ============================================================
#  13. FORM EVENTS
# ============================================================
$form.Add_Shown({
    Switch-Page -Key "dashboard"
    Set-SidebarState -Expanded $true
    $form.Activate()
})

$form.Add_FormClosing({
    try { $loadTimer.Stop(); $loadTimer.Dispose() } catch { }
    try { $monTimer.Stop(); $monTimer.Dispose() } catch { }
})

$form.Add_Resize({ Update-Toasts })

[void]$form.ShowDialog()