$ErrorActionPreference = 'Stop'
$UI = $Host.UI.RawUI

. $PSScriptRoot\powertab\default-config.ps1
. $PSScriptRoot\powertab\ConsoleLib.ps1

Function Install-GuiCompletion($Key = 'Ctrl+Spacebar') {
    Set-PSReadLineKeyHandler -Key $Key -ScriptBlock {
        Invoke-GuiCompletion
    }
}

Function Invoke-GuiCompletion {
    while ($true) {
        # Get input buffer state from PSReadLine
        $buffer = ""
        $cursorPosition = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$buffer, [ref]$cursorPosition)
        if ($cursorPosition -eq 0) {
            return
        }
        # get list of completion items via the standard API
        $completion = TabExpansion2 $buffer $cursorPosition
        if ($completion.CompletionMatches.Count -eq 0) {
            return
        }
        # show the menu
        $Recurse = $false
        $replacement = Get-ConsoleList -Content $completion.CompletionMatches -Recurse ([ref]$Recurse)
        # Based on return value, apply the completion to the buffer state
        if ($replacement) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($completion.ReplacementIndex, $completion.ReplacementLength, $replacement)
        }
        if ($Recurse -eq $false) {
            break
        }
    }
}

Export-ModuleMember -Function Install-GuiCompletion, Invoke-GuiCompletion -Variable GuiCompletionConfig
