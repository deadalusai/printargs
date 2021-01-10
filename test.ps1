function Test {
    param ([scriptblock] $Block)
    $Command = $Block.ToString().Trim()
    Write-Host -ForegroundColor 'Green' $Command
    & $Block
}

$a = 'hello "world" \" \\" goodbye "moon"' 
$b = 'path\without\whitespace\'
$c = 'path\with whitespace\'
$d = 'argument passed to flag'
$e = 'five trailing backslashes \\\\\'

function PrintArgs {
    $i = 1
    foreach ($Arg in $Args) {
        Write-Host "Pwsh [$i] -> [$Arg]"
        $i += 1
    }
}

function Invoke-Native {
    param($Executable, $Arguments)
    # Build an arguments string which follows the Windows command-line arguments string rules
    # See: https://docs.microsoft.com/en-us/previous-versions//17w5ykft(v=vs.85)?redirectedfrom=MSDN
    $ArgsString = @()
    foreach ($Arg in $Arguments) {
        $Arg = $Arg -replace '(\\+)"','$1$1"' # Double-up all backslashes immediately preceeding quote marks.
        $Arg = $Arg -replace '(\\+)$','$1$1'  # Double-up all backslashes immediately preceeding the end of the string.
        $Arg = $Arg -replace '"','\"'         # Escape internal quote marks.
        $ArgsString += "`"$Arg`""             # Quote the argument.
    }
    # Use the stop-parsing symbol (--%) to ensure the argument string is passed along unchanged 
    # See: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing?view=powershell-7.1
    Invoke-Expression "& `"$Executable`" --% $($ArgsString -Join ' ')"
}

Test { PrintArgs $a $b $c $e --arg=$d }
Test { Invoke-Native -Executable "$PSScriptRoot\target\debug\printargs" -Arguments @($a, $b, $c, $e, "--arg=$d") }
Test { & "$PSScriptRoot\target\debug\printargs" $a $b $c $e --arg=$d <# (this one doesn't work) #> }