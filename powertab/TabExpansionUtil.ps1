## http://rubli.info/t-blog/2011/06/29/querying-key-states-in-powershell/
Function Get-KeyState {
    param(
        [UInt16]$KeyCode
    )

    # This only works on Windows, so for now, we are never using it.

    $Signature = '[DllImport("user32.dll")]public static extern short GetKeyState(int nVirtKey);'
    $Type = Add-Type -MemberDefinition $Signature -Name User32PowerTab -Namespace GetKeyState -PassThru
    return [Bool]($Type::GetKeyState($KeyCode) -band 0x80)
}

Function New-TabItem {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Value
        ,
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Text = $Value
        ,
        [ValidateNotNullOrEmpty()]
        [String]
        $Type = "Unknown"
    )

    process {
        New-Object PSObject -Property @{Text=$Text; DisplayText=""; Value=$Value; Type=$Type}
    }
}