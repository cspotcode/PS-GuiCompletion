$ErrorActionPreference = 'Stop'
. $PSScriptRoot\powertab\default-config.ps1
. $PSScriptRoot\powertab\ConsoleLib.ps1
. $PSScriptRoot\powertab\TabExpansionUtil.ps1

Function Install-GuiCompletion($Key = 'Ctrl+Spacebar') {
    Set-PSReadLineKeyHandler -Key $Key -ScriptBlock {
        Invoke-GuiCompletion
    }
}

Function Invoke-GuiCompletion {
    while($true) {
        # Get input buffer state from PSReadLine
        $buffer = ""
        $cursorPosition = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$buffer, [ref]$cursorPosition)
        if($cursorPosition -eq 0) {
            return
        }
        # get list of completion items via the standard API
        $completion = TabExpansion2 $buffer $cursorPosition
        if($completion.CompletionMatches.Count -eq 0) {
            return
        }
        $lastWord = $buffer.Substring($completion.ReplacementIndex, $completion.ReplacementLength)
        # show the menu
        $menuItems = $completion.CompletionMatches | ForEach-Object {
            New-TabItem -Text $_.CompletionText -Value $_.CompletionText
        }
        $Recurse = $false
        $replacement = $menuItems | Out-ConsoleList -LastWord $lastWord -Recurse ([ref]$Recurse)
        # Based on return value, apply the completion to the buffer state
        if($replacement -cne $lastWord) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($completion.ReplacementIndex, $completion.ReplacementLength, $replacement)
        }
        if($Recurse -eq $false) {
            break
        }
    }
}

# The list of export functions and variables is further restricted in .psd1
Export-ModuleMember -Function *
Export-ModuleMember -Variable GuiCompletionConfig