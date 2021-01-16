function Test {
    param ([scriptblock] $Block)
    $Command = $Block.ToString().Trim()
    Write-Host -ForegroundColor 'Green' "Test: $Command"
    & $Block
}

function Benchmark {
    param ([scriptblock] $Block, [int] $Iterations = 1000)
    $Command = $Block.ToString().Trim()
    Write-Host -ForegroundColor 'Green' "Benchmark: $Command"
    Measure-Command {
        1..$Iterations | ForEach-Object {
            [void] (& $Block)
        }
    }
}

$a = 'hello "world" \" \\" goodbye "moon"' 
$b = 'path\without\whitespace\'
$c = 'path\with whitespace\'
$d = 'argument passed to flag'
$e = 'five trailing backslashes \\\\\'
$f = '\\\\\five leading backslashes'
$g = '\\?\C:\Windows\Extended Path Syntax\'

function PrintArgs {
    $i = 1
    foreach ($Arg in $Args) {
        Write-Host "Pwsh [$i] -> [$Arg]"
        $i += 1
    }
}

function Invoke-Native {
    param($Executable, $Arguments)
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($Executable);
    # Use UTF-8
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8;
    # Required for UTF-8
    $startInfo.RedirectStandardOutput = $true;
    $startInfo.CreateNoWindow = $true;
    $startInfo.UseShellExecute = $false;
    if ($startInfo.ArgumentList) {
        # PowerShell 6+ uses .NET 5+ and supports the ArgumentList property
        # which bypasses the need for manually escaping the argument list into
        # a command string.
        foreach ($arg in $Arguments) {
            $startInfo.ArgumentList.Add($arg)
        }
    }
    else {
        # Build an arguments string which follows the C++ command-line argument quoting rules
        # See: https://docs.microsoft.com/en-us/previous-versions//17w5ykft(v=vs.85)?redirectedfrom=MSDN
        $escaped = $Arguments | ForEach-Object {
            $_ = $_ -Replace '(\\+)"','$1$1"' # Escape backslash chains immediately preceeding quote marks.
            $_ = $_ -Replace '(\\+)$','$1$1'  # Escape backslash chains immediately preceeding the end of the string.
            $_ = $_ -Replace '"','\"'         # Escape quote marks.
            "`"$_`""                          # Quote the argument.
        }
        $startInfo.Arguments = $escaped -Join ' ';
    }
    [System.Diagnostics.Process]::Start($startInfo).StandardOutput.ReadToEnd()
}

Test { PrintArgs $a $b $c $e --arg=$d $f $g }
Test { Invoke-Native -Executable "$PSScriptRoot\target\debug\printargs" -Arguments @($a, $b, $c, $e, "--arg=$d", $f, $g) }
Test { & "$PSScriptRoot\target\debug\printargs" $a $b $c $e --arg=$d $f $g <# (this one doesn't work) #> }

function Escape-Argument {
    param([string] $Argument)
    $BACKSLASH = [char]'\'
    $QUOTE = [char]'"'
    # Build an quoted  argument string which follows the C++ command-line argument quoting rules
    # See: https://docs.microsoft.com/en-us/previous-versions//17w5ykft(v=vs.85)?redirectedfrom=MSDN
    $buf = [System.Text.StringBuilder]::new('"')
    $backslashes = 0
    foreach ($c in $Argument.GetEnumerator()) {
        if ($c -eq $BACKSLASH) {
            $backslashes += 1
            continue;
        }
        if ($c -eq $QUOTE) {
            # emit escaped backslashes, then escaped quote
            [void] $buf.Append('\' * $backslashes * 2)
            [void] $buf.Append('\"')
            $backslashes = 0;
            continue;
        }
        if ($backslashes -gt 0) {
            # emit unescaped backslashes
            [void] $buf.Append('\' * $backslashes)
            $backslashes = 0;
        }
        # emit the character
        [void] $buf.Append($c)
    }
    if ($backslashes -gt 0) {
        # emit escaped backslashes at the end of the string
        [void] $buf.Append('\' * $backslashes * 2)
    }
    [void] $buf.Append('"')
    $buf.ToString()
}

function Escape-ArgumentRegex {
    param([string] $s)
    $s = $s -Replace '(\\+)"','$1$1"' # Escape backslash chains immediately preceeding quote marks.
    $s = $s -Replace '(\\+)$','$1$1'  # Escape backslash chains immediately preceeding the end of the string.
    $s = $s -Replace '"','\"'         # Escape internal quote marks.
    "`"$s`""                          # Quote the argument.
}

# Benchmark { @($a, $b, $c, $d, $e, $f, $g) | Foreach-Object { Escape-Argument $_ } }
# Benchmark { @($a, $b, $c, $d, $e, $f, $g) | Foreach-Object { Escape-ArgumentRegex $_ } }