param (
    [switch]$gui,
    [switch]$sram
)

$env:PATH = "C:\altera_pro\25.1.1\questa_fse\win64;$env:PATH"
$root = Split-path $PSScriptRoot -Parent
Set-location "$root"

$do_script = if ($sram) { "./scripts/sram.do" } else { "./scripts/test.do" }

if ($gui) {
    vsim -do "set GUI_MODE 1; do $do_script"
} else {
    vsim -batch -do "set GUI_MODE 0; do $do_script"
}

exit $LASTEXITCODE