Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Kenzie's Tweaks"
$form.Size = New-Object System.Drawing.Size(700,500)
$form.StartPosition = "CenterScreen"

$title = New-Object System.Windows.Forms.Label
$title.Text = "Kenzie's Tweaks"
$title.Font = New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(25,20)
$title.AutoSize = $true

$form.Controls.Add($title)

$button = New-Object System.Windows.Forms.Button
$button.Text = "Apply Tweak"
$button.Location = New-Object System.Drawing.Point(25,80)
$button.Size = New-Object System.Drawing.Size(180,45)

$button.Add_Click({
    # Put your tweak here
    [System.Windows.Forms.MessageBox]::Show(
        "Tweak applied!",
        "Kenzie's Tweaks"
    )
})

$form.Controls.Add($button)

$form.ShowDialog()