﻿# Inspired by Mark Embling
# http://www.markembling.info/view/my-ideal-powershell-prompt-with-git-integration

enum BranchBehindAndAheadDisplayOptions { Full; Compact; Minimal }

class PoshGitCellColor {
    [psobject]$BackgroundColor
    [psobject]$ForegroundColor

    PoshGitCellColor() {
        $this.ForegroundColor = $null
        $this.BackgroundColor = $null
    }

    PoshGitCellColor([psobject]$ForegroundColor) {
        $this.ForegroundColor = $ForegroundColor
        $this.BackgroundColor = $null
    }

    PoshGitCellColor([psobject]$ForegroundColor, [psobject]$BackgroundColor) {
        $this.ForegroundColor = $ForegroundColor
        $this.BackgroundColor = $BackgroundColor
    }

    hidden [string] ToString($color) {
        $ansiTerm = "$([char]0x1b)[0m"
        $colorSwatch = "  "

        if (!$color) {
            $str = "<default>"
        }
        elseif (Test-VirtualTerminalSequece $color) {
            $txt = EscapseAnsiString $color
            $str = "${color}${colorSwatch}${ansiTerm} $txt"
        }
        else {
            $str = ""

            if ($global:GitPromptSettings.AnsiConsole) {
                $bg = Get-BackgroundVirtualTerminalSequence $color
                $str += "${bg}${colorSwatch}${ansiTerm} "
            }

            $str += $color.ToString()
        }

        return $str
    }

    [string] ToString() {
        $str = "ForegroundColor: "
        $str += $this.ToString($this.ForegroundColor) + ", "
        $str += "BackgroundColor: "
        $str += $this.ToString($this.BackgroundColor)
        return $str
    }
}

class PoshGitTextSpan {
    [string]$Text
    [psobject]$BackgroundColor
    [psobject]$ForegroundColor
    [string]$CustomAnsi

    PoshGitTextSpan() {
        $this.Text = ""
        $this.ForegroundColor = $null
        $this.BackgroundColor = $null
        $this.CustomAnsi = $null
    }

    PoshGitTextSpan([string]$Text) {
        $this.Text = $Text
        $this.ForegroundColor = $null
        $this.BackgroundColor = $null
        $this.CustomAnsi = $null
    }

    PoshGitTextSpan([string]$Text, [psobject]$ForegroundColor) {
        $this.Text = $Text
        $this.ForegroundColor = $ForegroundColor
        $this.BackgroundColor = $null
        $this.CustomAnsi = $null
    }

    PoshGitTextSpan([string]$Text, [psobject]$ForegroundColor, [psobject]$BackgroundColor) {
        $this.Text = $Text
        $this.ForegroundColor = $ForegroundColor
        $this.BackgroundColor = $BackgroundColor
        $this.CustomAnsi = $null
    }

    PoshGitTextSpan([PoshGitTextSpan]$PoshGitTextSpan) {
        $this.Text = $PoshGitTextSpan.Text
        $this.ForegroundColor = $PoshGitTextSpan.ForegroundColor
        $this.BackgroundColor = $PoshGitTextSpan.BackgroundColor
        $this.CustomAnsi = $PoshGitTextSpan.CustomAnsi
    }

    PoshGitTextSpan([PoshGitCellColor]$PoshGitCellColor) {
        $this.Text = ''
        $this.ForegroundColor = $PoshGitCellColor.ForegroundColor
        $this.BackgroundColor = $PoshGitCellColor.BackgroundColor
        $this.CustomAnsi = $null
    }

    [string] ToString() {
        if ($global:GitPromptSettings.AnsiConsole) {
            if ($this.CustomAnsi) {
                $e = [char]27 + "["
                $ansi = $this.CustomAnsi
                $escAnsi = EscapseAnsiString $this.CustomAnsi
                $txt = $this.RenderAnsi()
                $str = "Text: '$txt',`t CustomAnsi: '${ansi}${escAnsi}${e}0m'"
            }
            else {
                $color = [PoshGitCellColor]::new($this.ForegroundColor, $this.BackgroundColor)
                $txt = $this.RenderAnsi()
                $str = "Text: '$txt',`t $($color.ToString())"
            }
        }
        else {
            $color = [PoshGitCellColor]::new($this.ForegroundColor, $this.BackgroundColor)
            $txt = $this.Text
            $str = "Text: '$txt',`t $($color.ToString())"
        }

        return $str
    }

    [string] RenderAnsi() {
        $e = [char]27 + "["
        $txt = $this.Text

        if ($this.CustomAnsi) {
            $ansi = $this.CustomAnsi
            $str = "${ansi}${txt}${e}0m"
        }
        else {
            $bg = $this.BackgroundColor
            if ($bg -and !(Test-VirtualTerminalSequece $bg)) {
                $bg = Get-BackgroundVirtualTerminalSequence $bg
            }

            $fg = $this.ForegroundColor
            if ($fg -and !(Test-VirtualTerminalSequece $fg)) {
                $fg = Get-ForegroundVirtualTerminalSequence $fg
            }

            $str = "${fg}${bg}${txt}${e}0m"
        }

        return $str
    }
}

class GitPromptSettings {
    [bool]$AnsiConsole = $Host.UI.SupportsVirtualTerminal -or ($Env:ConEmuANSI -eq "ON")

    [PoshGitCellColor]$DefaultColor   = [PoshGitCellColor]::new()
    [PoshGitCellColor]$BranchColor    = [PoshGitCellColor]::new([ConsoleColor]::Cyan)

    [PoshGitCellColor]$IndexColor     = [PoshGitCellColor]::new([ConsoleColor]::DarkGreen)
    [PoshGitCellColor]$WorkingColor   = [PoshGitCellColor]::new([ConsoleColor]::DarkRed)
    [PoshGitCellColor]$StashColor     = [PoshGitCellColor]::new([ConsoleColor]::Red)
    [PoshGitCellColor]$ErrorColor     = [PoshGitCellColor]::new([ConsoleColor]::Red)

    [PoshGitTextSpan]$BeforeText      = [PoshGitTextSpan]::new(' [', [ConsoleColor]::Yellow)
    [PoshGitTextSpan]$DelimText       = [PoshGitTextSpan]::new(' |', [ConsoleColor]::Yellow)
    [PoshGitTextSpan]$AfterText       = [PoshGitTextSpan]::new(']',  [ConsoleColor]::Yellow)

    [PoshGitTextSpan]$BeforeIndexText = [PoshGitTextSpan]::new('',  [ConsoleColor]::DarkGreen)
    [PoshGitTextSpan]$BeforeStashText = [PoshGitTextSpan]::new(' (', [ConsoleColor]::Red)
    [PoshGitTextSpan]$AfterStashText  = [PoshGitTextSpan]::new(')',  [ConsoleColor]::Red)

    [PoshGitTextSpan]$LocalDefaultStatusSymbol         = [PoshGitTextSpan]::new('',  [ConsoleColor]::DarkGreen)
    [PoshGitTextSpan]$LocalWorkingStatusSymbol         = [PoshGitTextSpan]::new('!', [ConsoleColor]::DarkRed)
    [PoshGitTextSpan]$LocalStagedStatusSymbol          = [PoshGitTextSpan]::new('~', [ConsoleColor]::DarkCyan)

    [PoshGitTextSpan]$BranchGoneStatusSymbol           = [PoshGitTextSpan]::new([char]0x00D7, [ConsoleColor]::DarkCyan) # × Multiplication sign
    [PoshGitTextSpan]$BranchIdenticalStatusSymbol      = [PoshGitTextSpan]::new([char]0x2261, [ConsoleColor]::Cyan)     # ≡ Three horizontal lines
    [PoshGitTextSpan]$BranchAheadStatusSymbol          = [PoshGitTextSpan]::new([char]0x2191, [ConsoleColor]::Green)    # ↑ Up arrow
    [PoshGitTextSpan]$BranchBehindStatusSymbol         = [PoshGitTextSpan]::new([char]0x2193, [ConsoleColor]::Red)      # ↓ Down arrow
    [PoshGitTextSpan]$BranchBehindAndAheadStatusSymbol = [PoshGitTextSpan]::new([char]0x2195, [ConsoleColor]::Yellow)   # ↕ Up & Down arrow

    [BranchBehindAndAheadDisplayOptions]$BranchBehindAndAheadDisplay = [BranchBehindAndAheadDisplayOptions]::Full

    [string]$FileAddedText       = '+'
    [string]$FileModifiedText    = '~'
    [string]$FileRemovedText     = '-'
    [string]$FileConflictedText  = '!'
    [string]$BranchUntrackedText = ''

    [bool]$EnableStashStatus  = $false
    [bool]$ShowStatusWhenZero = $true
    [bool]$AutoRefreshIndex   = $true

    [bool]$EnablePromptStatus                         = !$global:GitMissing
    [bool]$EnableFileStatus                           = $true
    [Nullable[bool]]$EnableFileStatusFromCache        = $null
    [string[]]$RepositoriesInWhichToDisableFileStatus = @()

    [string]$DescribeStyle     = ''
    [psobject]$EnableWindowTitle = 'posh~git ~ '

    [string]$DefaultPromptPrefix                = ''
    [string]$DefaultPromptSuffix                = '$(''>'' * ($nestedPromptLevel + 1)) '
    [string]$DefaultPromptDebugSuffix           = ' [DBG]$(''>'' * ($nestedPromptLevel + 1)) '
    [bool]$DefaultPromptEnableTiming            = $false
    [bool]$DefaultPromptAbbreviateHomeDirectory = $false

    [int]$BranchNameLimit          = 0
    [string]$TruncatedBranchSuffix = '...'

    [bool]$Debug = $false
}

$global:GitPromptSettings = [GitPromptSettings]::new()

# Override some of the normal colors if the background color is set to the default DarkMagenta.
$s = $global:GitPromptSettings
if ($Host.UI.RawUI.BackgroundColor -eq [ConsoleColor]::DarkMagenta) {
    $s.LocalDefaultStatusSymbol.ForegroundColor = 'Green'
    $s.LocalWorkingStatusSymbol.ForegroundColor = 'Red'
    $s.BeforeIndexText.ForegroundColor          = 'Green'
    $s.IndexColor.ForegroundColor               = 'Green'
    $s.WorkingColor.ForegroundColor             = 'Red'
}

$isAdminProcess = Test-Administrator
$adminHeader = if ($isAdminProcess) { 'Administrator: ' } else { '' }

$WindowTitleSupported = $true
# TODO: Hmm, this is a curious way to detemine window title supported
# Could do $host.Name -eq "Package Manager Host" but that is kinda specific
# Could attempt to change it and catch any exception and then set this to $false
if (Get-Module NuGet) {
    $WindowTitleSupported = $false
}

function Write-Prompt {
    param(
        [Parameter(Mandatory)]
        $Object,

        [Parameter()]
        $ForegroundColor = $null,

        [Parameter()]
        $BackgroundColor = $null,

        [Parameter(ValueFromPipeline = $true)]
        [System.Text.StringBuilder]
        $Builder
    )

    $s = $global:GitPromptSettings
    if ($s) {
        if ($null -eq $ForegroundColor) {
            $ForegroundColor = $s.DefaultColor.ForegroundColor
        }

        if ($null -eq $BackgroundColor) {
            $BackgroundColor = $s.DefaultColor.BackgroundColor
        }

        if ($s.AnsiConsole) {
            if ($Object -is [PoshGitTextSpan]) {
                $str = $Object.RenderAnsi()
            }
            else {
                $e = [char]27 + "["
                $f = Get-ForegroundVirtualTerminalSequence $ForegroundColor
                $b = Get-BackgroundVirtualTerminalSequence $BackgroundColor
                $str = "${f}${b}${Object}${e}0m"
            }

            if ($Builder) {
                return $Builder.Append($str)
            }

            return $str
        }
    }

    if ($Object -is [PoshGitTextSpan]) {
        $BackgroundColor = $Object.BackgroundColor
        $ForegroundColor = $Object.ForegroundColor
        $Object = $Object.Text
    }

    $writeHostParams = @{
        Object = $Object;
        NoNewLine = $true;
    }

    if ($BackgroundColor -and ($BackgroundColor -ge 0) -and ($BackgroundColor -le 15)) {
        $writeHostParams.BackgroundColor = $BackgroundColor
    }

    if ($ForegroundColor -and ($ForegroundColor -ge 0) -and ($ForegroundColor -le 15)) {
        $writeHostParams.ForegroundColor = $ForegroundColor
    }

    Write-Host @writeHostParams
    if ($Builder) {
        return $Builder
    }

    return ""
}

<#
.SYNOPSIS
    Writes the Git status for repo.  Typically, you use Write-VcsStatus
    function instead of this one.
.DESCRIPTION
    Writes the Git status for repo. This includes the branch name, branch
    status with respect to its remote (if exists), index status, working
    dir status, working dir local status and stash count (optional).
    Various settings from GitPromptSettngs are used to format and color
    the Git status.

    On systems that support ANSI terminal sequences, this method will
    return a string containing ANSI sequences to color various parts of
    the Git status string.  This string can be written to the host and
    the ANSI sequences will be interpreted and converted to the specified
    behaviors which is typically setting the foreground and/or background
    color of text.
.EXAMPLE
    PS C:\> Write-GitStatus (Get-GitStatus)

    Writes the Git status for the current repo.
.INPUTS
    System.Management.Automation.PSCustomObject
        This is PSCustomObject returned by Get-GitStatus
.OUTPUTS
    System.String
        This command returns a System.String object.
#>
function Write-GitStatus {
    param(
        # The Git status, retrieved from Get-GitStatus, from which to write the stash count.
        # If no other parameters are specified, the stash count is written to the host.
        [Parameter(Position = 0)]
        $Status
    )

    $s = $global:GitPromptSettings
    if (!$Status -or !$s) {
        if ($global:PreviousWindowTitle) {
            $Host.UI.RawUI.WindowTitle = $global:PreviousWindowTitle
        }

        return ""
    }

    $sb = [System.Text.StringBuilder]::new(150)

    $sb | Write-Prompt $s.BeforeText > $null
    $sb | Write-GitBranchName $Status -NoLeadingSpace > $null
    $sb | Write-GitBranchStatus $Status > $null

    if ($s.EnableFileStatus -and $Status.HasIndex) {
        $sb | Write-Prompt $s.BeforeIndexText > $null

        $sb | Write-GitIndexStatus $Status > $null

        if ($Status.HasWorking) {
            $sb | Write-Prompt $s.DelimText > $null
        }
    }

    if ($s.EnableFileStatus -and $Status.HasWorking) {
        $sb | Write-GitWorkingDirStatus $Status > $null
    }

    $sb | Write-GitWorkingDirStatusSummary $Status > $null

    if ($s.EnableStashStatus -and ($Status.StashCount -gt 0)) {
        $sb | Write-GitStashCount $Status > $null
    }

    $sb | Write-Prompt $s.AfterText > $null

    if ($WindowTitleSupported -and $s.EnableWindowTitle) {
        if (!$global:PreviousWindowTitle) {
            $global:PreviousWindowTitle = $Host.UI.RawUI.WindowTitle
        }

        $repoName = Split-Path -Leaf (Split-Path $status.GitDir)
        $prefix = if ($s.EnableWindowTitle -is [string]) { $s.EnableWindowTitle } else { '' }
        $Host.UI.RawUI.WindowTitle = "${script:adminHeader}${prefix}${repoName} [$($Status.Branch)]"
    }

    return $sb.ToString()
}

<#
.SYNOPSIS
    Formats the branch name text according to $GitPromptSettings.
.DESCRIPTION
    Formats the branch name text according the $GitPromptSettings:
    BranchNameLimit and TruncatedBranchSuffix.
.EXAMPLE
    PS C:\> $branchName = Format-GitBranchName (Get-GitStatus).Branch

    Gets the branch name formatted as specified by the user's $GitPromptSettings.
.INPUTS
    System.String
        This is the branch name as a string.
.OUTPUTS
    System.String
        This command returns a System.String object.
#>
function Format-GitBranchName {
    param(
        # The branch name to format according to the GitPromptSettings:
        # BranchNameLimit and TruncatedBranchSuffix.
        [Parameter(Position=0)]
        [string]
        $BranchName
    )

    $s = $global:GitPromptSettings
    if (!$s -or !$BranchName) {
        return "$BranchName"
    }

    $res = $BranchName
    if (($s.BranchNameLimit -gt 0) -and ($BranchName.Length -gt $s.BranchNameLimit))
    {
        $res = "{0}{1}" -f $BranchName.Substring(0, $s.BranchNameLimit), $s.TruncatedBranchSuffix
    }

    $res
}

<#
.SYNOPSIS
    Gets the colors to use for the branch status.
.DESCRIPTION
    Gets the colors to use for the branch status. This color is typically
    used for the branch name as well.  The default color is specified by
    $GitPromptSettins.BranchColor.  But depending on the Git status object
    passed in, the colors could be changed to match that of one these
    other $GitPromptSettings: BranchBehindAndAheadStatusSymbol,
    BranchBehindStatusSymbol or BranchAheadStatusSymbol.
.EXAMPLE
    PS C:\> $branchStatusColor = Get-GitBranchStatusColor (Get-GitStatus)

    Returns a PoshGitTextSpan with the foreground and background colors
    for the branch status.
.INPUTS
    System.Management.Automation.PSCustomObject
        This is PSCustomObject returned by Get-GitStatus
.OUTPUTS
    PoshGitTextSpan
        A PoshGitTextSpan with colors reflecting those to be used by
        branch status symbols.
#>
function Get-GitBranchStatusColor {
    param(
        # The Git status, retrieved from Get-GitStatus.
        [Parameter(Position = 0)]
        $Status
    )

    $s = $global:GitPromptSettings
    if (!$s) {
        return [PoshGitTextSpan]::new()
    }

    $branchStatusTextSpan = [PoshGitTextSpan]::new($s.BranchColor)

    if (($Status.BehindBy -ge 1) -and ($Status.AheadBy -ge 1)) {
        # We are both behind and ahead of remote
        $branchStatusTextSpan = [PoshGitTextSpan]::new($s.BranchBehindAndAheadStatusSymbol)
    }
    elseif ($Status.BehindBy -ge 1) {
        # We are behind remote
        $branchStatusTextSpan = [PoshGitTextSpan]::new($s.BranchBehindStatusSymbol)
    }
    elseif ($Status.AheadBy -ge 1) {
        # We are ahead of remote
        $branchStatusTextSpan = [PoshGitTextSpan]::new($s.BranchAheadStatusSymbol)
    }

    $branchStatusTextSpan.Text = ''
    $branchStatusTextSpan
}

<#
.SYNOPSIS
    Writes the branch name given the current Git status.
.DESCRIPTION
    Writes the branch name given the current Git status which can retrieved
    via the Get-GitStatus command. Branch name can be affected by the
    $GitPromptSettings: BranchColor, BranchNameLimit, TruncatedBranchSuffix
    and Branch*StatusSymbol colors.
.EXAMPLE
    PS C:\> Write-GitBranchName (Get-GitStatus)

    Writes the name of the current branch.
.INPUTS
    System.Management.Automation.PSCustomObject
        This is PSCustomObject returned by Get-GitStatus
.OUTPUTS
    System.String, System.Text.StringBuilder
        This command returns a System.String object unless the -StringBuilder parameter
        is supplied. In this case, it returns a System.Text.StringBuilder.
#>
function Write-GitBranchName {
    param(
        # The Git status, retrieved from Get-GitStatus, from which to write the branch status.
        # If no other parameters are specified, that branch status is written to the host.
        [Parameter(Position = 0)]
        $Status,

        # If specified the branch name is written into the provided StringBuilder object.
        [Parameter(ValueFromPipeline = $true)]
        [System.Text.StringBuilder]
        $StringBuilder,

        # If specified, suppresses the output of the leading space character.
        [Parameter()]
        [switch]
        $NoLeadingSpace
    )

    $s = $global:GitPromptSettings
    if (!$Status -or !$s) {
        return $(if ($StringBuilder) { $StringBuilder } else { "" })
    }

    $str = ""

    # Use the branch status colors (or CustomAnsi) to display the branch name
    $branchNameTextSpan = Get-GitBranchStatusColor $Status
    $branchNameTextSpan.Text = Format-GitBranchName $Status.Branch

    $textSpan = [PoshGitTextSpan]::new($branchNameTextSpan)
    if (!$NoLeadingSpace) {
        $textSpan.Text = " " + $branchNameTextSpan.Text
    }

    if ($StringBuilder) {
        $StringBuilder | Write-Prompt $textSpan > $null
    }
    else {
        $str = Write-Prompt $textSpan
    }

    return $(if ($StringBuilder) { $StringBuilder } else { $str })
}

<#
.SYNOPSIS
    Writes the branch status text given the current Git status.
.DESCRIPTION
    Writes the branch status text given the current Git status which can retrieved
    via the Get-GitStatus command. Branch status includes information about the
    upstream branch, how far behind and/or ahead the local branch is from the remote.
.EXAMPLE
    PS C:\> Write-GitBranchStatus (Get-GitStatus)

    Writes the status of the current branch to the host.
.INPUTS
    System.Management.Automation.PSCustomObject
        This is PSCustomObject returned by Get-GitStatus
.OUTPUTS
    System.String, System.Text.StringBuilder
        This command returns a System.String object unless the -StringBuilder parameter
        is supplied. In this case, it returns a System.Text.StringBuilder.
#>
function Write-GitBranchStatus {
    param(
        # The Git status, retrieved from Get-GitStatus, from which to write the branch status.
        # If no other parameters are specified, that branch status is written to the host.
        [Parameter(Position = 0)]
        $Status,

        # If specified the branch status is written into the provided StringBuilder object.
        [Parameter(ValueFromPipeline = $true)]
        [System.Text.StringBuilder]
        $StringBuilder,

        # If specified, suppresses the output of the leading space character.
        [Parameter()]
        [switch]
        $NoLeadingSpace
    )

    $s = $global:GitPromptSettings
    if (!$Status -or !$s) {
        return $(if ($StringBuilder) { $StringBuilder } else { "" })
    }

    $branchStatusTextSpan = Get-GitBranchStatusColor $Status

    if (!$Status.Upstream) {
        $branchStatusTextSpan.Text = $s.BranchUntrackedText
    }
    elseif ($Status.UpstreamGone -eq $true) {
        # Upstream branch is gone
        $branchStatusTextSpan.Text = $s.BranchGoneStatusSymbol.Text
    }
    elseif (($Status.BehindBy -eq 0) -and ($Status.AheadBy -eq 0)) {
        # We are aligned with remote
        $branchStatusTextSpan.Text = $s.BranchIdenticalStatusSymbol.Text
    }
    elseif (($Status.BehindBy -ge 1) -and ($Status.AheadBy -ge 1)) {
        # We are both behind and ahead of remote
        if ($s.BranchBehindAndAheadDisplay -eq "Full") {
            $branchStatusTextSpan.Text = ("{0}{1} {2}{3}" -f $s.BranchBehindStatusSymbol.Text, $Status.BehindBy, $s.BranchAheadStatusSymbol.Text, $status.AheadBy)
        }
        elseif ($s.BranchBehindAndAheadDisplay -eq "Compact") {
            $branchStatusTextSpan.Text = ("{0}{1}{2}" -f $Status.BehindBy, $s.BranchBehindAndAheadStatusSymbol.Text, $Status.AheadBy)
        }
    }
    elseif ($Status.BehindBy -ge 1) {
        # We are behind remote
        if (($s.BranchBehindAndAheadDisplay -eq "Full") -Or ($s.BranchBehindAndAheadDisplay -eq "Compact")) {
            $branchStatusTextSpan.Text = ("{0}{1}" -f $s.BranchBehindStatusSymbol.Text, $Status.BehindBy)
        }
    }
    elseif ($Status.AheadBy -ge 1) {
        # We are ahead of remote
        if (($s.BranchBehindAndAheadDisplay -eq "Full") -or ($s.BranchBehindAndAheadDisplay -eq "Compact")) {
            $branchStatusTextSpan.Text = ("{0}{1}" -f $s.BranchAheadStatusSymbol.Text, $Status.AheadBy)
        }
    }
    else {
        # This condition should not be possible but defaulting the variables to be safe
        $branchStatusTextSpan.Text = "?"
    }

    $str = ""
    if ($branchStatusTextSpan.Text) {
        $textSpan = [PoshGitTextSpan]::new($branchStatusTextSpan)
        if (!$NoLeadingSpace) {
            $textSpan.Text = " " + $branchStatusTextSpan.Text
        }

        if ($StringBuilder) {
            $StringBuilder | Write-Prompt $textSpan > $null
        }
        else {
            $str = Write-Prompt $textSpan
        }
    }

    return $(if ($StringBuilder) { $StringBuilder } else { $str })
}

<#
.SYNOPSIS
    Writes the index status text given the current Git status.
.DESCRIPTION
    Writes the index status text given the current Git status.
.EXAMPLE
    PS C:\> Write-GitIndexStatus (Get-GitStatus)

    Writes the Git index status to the host.
.INPUTS
    System.Management.Automation.PSCustomObject
        This is PSCustomObject returned by Get-GitStatus
.OUTPUTS
    System.String, System.Text.StringBuilder
        This command returns a System.String object unless the -StringBuilder parameter
        is supplied. In this case, it returns a System.Text.StringBuilder.
#>
function Write-GitIndexStatus {
    param(
        # The Git status, retrieved from Get-GitStatus, from which to write the index status.
        # If no other parameters are specified, that index status is written to the host.
        [Parameter(Position = 0)]
        $Status,

        # If specified the index status is written into the provided StringBuilder object.
        [Parameter(ValueFromPipeline = $true)]
        [System.Text.StringBuilder]
        $StringBuilder,

        # If specified, suppresses the output of the leading space character.
        [Parameter()]
        [switch]
        $NoLeadingSpace
    )

    $s = $global:GitPromptSettings
    if (!$Status -or !$s) {
        return $(if ($StringBuilder) { $StringBuilder } else { "" })
    }

    $str = ""

    if ($Status.HasIndex) {
        $indexStatusTextSpan = [PoshGitTextSpan]::new($s.IndexColor)

        if ($s.ShowStatusWhenZero -or $Status.Index.Added) {
            if ($NoLeadingSpace) {
                $indexStatusTextSpan.Text = ""
                $NoLeadingSpace = $false
            }
            else {
                $indexStatusTextSpan.Text = " "
            }

            $indexStatusTextSpan.Text += "$($s.FileAddedText)$($Status.Index.Added.Count)"

            if ($StringBuilder) {
                $StringBuilder | Write-Prompt $indexStatusTextSpan > $null
            }
            else {
                $str += Write-Prompt $indexStatusTextSpan
            }
        }

        if ($s.ShowStatusWhenZero -or $status.Index.Modified) {
            if ($NoLeadingSpace) {
                $indexStatusTextSpan.Text = ""
                $NoLeadingSpace = $false
            }
            else {
                $indexStatusTextSpan.Text = " "
            }

            $indexStatusTextSpan.Text += "$($s.FileModifiedText)$($status.Index.Modified.Count)"

            if ($StringBuilder) {
                $StringBuilder | Write-Prompt $indexStatusTextSpan > $null
            }
            else {
                $str += Write-Prompt $indexStatusTextSpan
            }
        }

        if ($s.ShowStatusWhenZero -or $Status.Index.Deleted) {
            if ($NoLeadingSpace) {
                $indexStatusTextSpan.Text = ""
                $NoLeadingSpace = $false
            }
            else {
                $indexStatusTextSpan.Text = " "
            }

            $indexStatusTextSpan.Text += "$($s.FileRemovedText)$($Status.Index.Deleted.Count)"

            if ($StringBuilder) {
                $StringBuilder | Write-Prompt $indexStatusTextSpan > $null
            }
            else {
                $str += Write-Prompt $indexStatusTextSpan
            }
        }

        if ($Status.Index.Unmerged) {
            if ($NoLeadingSpace) {
                $indexStatusTextSpan.Text = ""
                $NoLeadingSpace = $false
            }
            else {
                $indexStatusTextSpan.Text = " "
            }

            $indexStatusTextSpan.Text += "$($s.FileConflictedText)$($Status.Index.Unmerged.Count)"

            if ($StringBuilder) {
                $StringBuilder | Write-Prompt $indexStatusTextSpan > $null
            }
            else {
                $str += Write-Prompt $indexStatusTextSpan
            }
        }
    }

    return $(if ($StringBuilder) { $StringBuilder } else { $str })
}

<#
.SYNOPSIS
    Writes the working directory status text given the current Git status.
.DESCRIPTION
    Writes the working directory status text given the current Git status.
.EXAMPLE
    PS C:\> Write-GitWorkingDirStatus (Get-GitStatus)

    Writes the Git working directory status to the host.
.INPUTS
    System.Management.Automation.PSCustomObject
        This is PSCustomObject returned by Get-GitStatus
.OUTPUTS
    System.String, System.Text.StringBuilder
        This command returns a System.String object unless the -StringBuilder parameter
        is supplied. In this case, it returns a System.Text.StringBuilder.
#>
function Write-GitWorkingDirStatus {
    param(
        # The Git status, retrieved from Get-GitStatus, from which to write the working dir status.
        # If no other parameters are specified, that working dir status is written to the host.
        [Parameter(Position = 0)]
        $Status,

        # If specified the working dir status is written into the provided StringBuilder object.
        [Parameter(ValueFromPipeline = $true)]
        [System.Text.StringBuilder]
        $StringBuilder,

        # If specified, suppresses the output of the leading space character.
        [Parameter()]
        [switch]
        $NoLeadingSpace
    )

    $s = $global:GitPromptSettings
    if (!$Status -or !$s) {
        return $(if ($StringBuilder) { $StringBuilder } else { "" })
    }

    $str = ""

    if ($Status.HasWorking) {
        $workingTextSpan = [PoshGitTextSpan]::new($s.WorkingColor)

        if ($s.ShowStatusWhenZero -or $Status.Working.Added) {
            if ($NoLeadingSpace) {
                $workingTextSpan.Text = ""
                $NoLeadingSpace = $false
            }
            else {
                $workingTextSpan.Text = " "
            }

            $workingTextSpan.Text += "$($s.FileAddedText)$($Status.Working.Added.Count)"

            if ($StringBuilder) {
                $StringBuilder | Write-Prompt $workingTextSpan > $null
            }
            else {
                $str += Write-Prompt $workingTextSpan
            }
        }

        if ($s.ShowStatusWhenZero -or $Status.Working.Modified) {
            if ($NoLeadingSpace) {
                $workingTextSpan.Text = ""
                $NoLeadingSpace = $false
            }
            else {
                $workingTextSpan.Text = " "
            }

            $workingTextSpan.Text += "$($s.FileModifiedText)$($Status.Working.Modified.Count)"

            if ($StringBuilder) {
                $StringBuilder | Write-Prompt $workingTextSpan > $null
            }
            else {
                $str += Write-Prompt $workingTextSpan
            }
        }

        if ($s.ShowStatusWhenZero -or $Status.Working.Deleted) {
            if ($NoLeadingSpace) {
                $workingTextSpan.Text = ""
                $NoLeadingSpace = $false
            }
            else {
                $workingTextSpan.Text = " "
            }

            $workingTextSpan.Text += "$($s.FileRemovedText)$($Status.Working.Deleted.Count)"

            if ($StringBuilder) {
                $StringBuilder | Write-Prompt $workingTextSpan > $null
            }
            else {
                $str += Write-Prompt $workingTextSpan
            }
        }

        if ($Status.Working.Unmerged) {
            if ($NoLeadingSpace) {
                $workingTextSpan.Text = ""
                $NoLeadingSpace = $false
            }
            else {
                $workingTextSpan.Text = " "
            }

            $workingTextSpan.Text += "$($s.FileConflictedText)$($Status.Working.Unmerged.Count)"

            if ($StringBuilder) {
                $StringBuilder | Write-Prompt $workingTextSpan > $null
            }
            else {
                $str += Write-Prompt $workingTextSpan
            }
        }
    }

    return $(if ($StringBuilder) { $StringBuilder } else { $str })
}

<#
.SYNOPSIS
    Writes the working directory status summary text given the current Git status.
.DESCRIPTION
    Writes the working directory status summary text given the current Git status.
    If there are any unstaged commits, the $GitPromptSettings.LocalWorkingStatusSymbol
    will be output.  If not, then if are any staged but uncommmited changes, the
    $GitPromptSettings.LocalStagedStatusSymbol will be output.  If not, then
    $GitPromptSettings.LocalDefaultStatusSymbol will be output.
.EXAMPLE
    PS C:\> Write-GitWorkingDirStatusSummary (Get-GitStatus)

    Outputs the Git working directory status summary text.
.INPUTS
    System.Management.Automation.PSCustomObject
        This is PSCustomObject returned by Get-GitStatus
.OUTPUTS
    System.String, System.Text.StringBuilder
        This command returns a System.String object unless the -StringBuilder parameter
        is supplied. In this case, it returns a System.Text.StringBuilder.
#>
function Write-GitWorkingDirStatusSummary {
    param(
        # The Git status, retrieved from Get-GitStatus, from which to write the working dir local status.
        # If no other parameters are specified, that working dir local status is written to the host.
        [Parameter(Position = 0)]
        $Status,

        # If specified the working dir local status is written into the provided StringBuilder object.
        [Parameter(ValueFromPipeline = $true)]
        [System.Text.StringBuilder]
        $StringBuilder,

        # If specified, suppresses the output of the leading space character.
        [Parameter()]
        [switch]
        $NoLeadingSpace
    )

    $s = $global:GitPromptSettings
    if (!$Status -or !$s) {
        return $(if ($StringBuilder) { $StringBuilder } else { "" })
    }

    $str = ""

    # No uncommited changes
    $localStatusSymbol = $s.LocalDefaultStatusSymbol

    if ($Status.HasWorking) {
        # We have un-staged files in the working tree
        $localStatusSymbol = $s.LocalWorkingStatusSymbol
    }
    elseif ($Status.HasIndex) {
        # We have staged but uncommited files
        $localStatusSymbol = $s.LocalStagedStatusSymbol
    }

    if ($localStatusSymbol.Text) {
        $textSpan = [PoshGitTextSpan]::new($localStatusSymbol)
        if (!$NoLeadingSpace) {
            $textSpan.Text = " " + $localStatusSymbol.Text
        }

        if ($StringBuilder) {
            $StringBuilder | Write-Prompt $textSpan > $null
        }
        else {
            $str += Write-Prompt $textSpan
        }
    }

    return $(if ($StringBuilder) { $StringBuilder } else { $str })
}

<#
.SYNOPSIS
    Writes the stash count given the current Git status.
.DESCRIPTION
    Writes the stash count given the current Git status.
.EXAMPLE
    PS C:\> Write-GitStashCount (Get-GitStatus)

    Writes the Git stash count to the host.
.INPUTS
    System.Management.Automation.PSCustomObject
        This is PSCustomObject returned by Get-GitStatus
.OUTPUTS
    System.String, System.Text.StringBuilder
        This command returns a System.String object unless the -StringBuilder parameter
        is supplied. In this case, it returns a System.Text.StringBuilder.
#>
function Write-GitStashCount {
    param(
        # The Git status, retrieved from Get-GitStatus, from which to write the stash count.
        # If no other parameters are specified, the stash count is written to the host.
        [Parameter(Position = 0)]
        $Status,

        # If specified the working dir local status is written into the provided StringBuilder object.
        [Parameter(ValueFromPipeline = $true)]
        [System.Text.StringBuilder]
        $StringBuilder
    )

    $s = $global:GitPromptSettings
    if (!$Status -or !$s) {
        return $(if ($StringBuilder) { $StringBuilder } else { "" })
    }

    $str = ""

    if ($Status.StashCount -gt 0) {
        $stashTextSpan = [PoshGitTextSpan]::new($s.StashColor)
        $stashTextSpan.Text = "$($Status.StashCount)"

        if ($StringBuilder) {
            $StringBuilder | Write-Prompt $s.BeforeStashText > $null
            $StringBuilder | Write-Prompt $stashTextSpan > $null
            $StringBuilder | Write-Prompt $s.AfterStashText > $null
        }
        else {
            $str += Write-Prompt $s.BeforeStashText > $null
            $str += Write-Prompt $stashTextSpan > $null
            $str += Write-Prompt $s.AfterStashText > $null
        }
    }

    return $(if ($StringBuilder) { $StringBuilder } else { $str })
}

if (!(Test-Path Variable:Global:VcsPromptStatuses)) {
    $global:VcsPromptStatuses = @()
}

<#
.SYNOPSIS
    Writes all version control prompt statuses configured in $global:VscPromptStatuses.
.DESCRIPTION
    Writes all version control prompt statuses configured in $global:VscPromptStatuses.
    By default, this includes the PoshGit prompt status.
.EXAMPLE
    PS C:\> Write-VcsStatus

    Writes all version control prompt statuses that have been configured
    with the global variable $VscPromptStatuses
#>
function Global:Write-VcsStatus {
    Set-ConsoleMode -ANSI
    $OFS = ""
    $sb = [System.Text.StringBuilder]::new(200)

    $global:VcsPromptStatuses | ForEach-Object {
        $str = & $_
        if ($str) {
            # $str is quoted in case we get back an array of strings, quoting it will flatten the array
            # into a single string and $OFS="" will ensure no spaces between each array item.
            $sb.Append("$str") > $null
        }
    }

    $sb.ToString()
}

# Add scriptblock that will execute for Write-VcsStatus
$PoshGitVcsPrompt = {
    try {
        $global:GitStatus = Get-GitStatus
        Write-GitStatus $GitStatus
    }
    catch {
        $s = $global:GitPromptSettings
        if ($s) {
            $errorTextSpan = [PoshGitTextSpan]::new($s.ErrorColor)
            $errorTextSpan.Text = "PoshGitVcsPrompt error: $_"

            $sb = [System.Text.StringBuilder]::new()

            $sb | Write-Prompt $s.BeforeText > $null
            $sb | Write-Prompt $errorTextSpan > $null
            $sb | Write-Prompt $s.AfterText > $null

            $sb.ToString()
        }
    }
}

$global:VcsPromptStatuses += $PoshGitVcsPrompt
