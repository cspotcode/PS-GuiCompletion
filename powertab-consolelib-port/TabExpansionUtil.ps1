## http://rubli.info/t-blog/2011/06/29/querying-key-states-in-powershell/
Function Get-KeyState {
    param(
        [UInt16]$KeyCode
    )

    $Signature = '[DllImport("user32.dll")]public static extern short GetKeyState(int nVirtKey);'
    $Type = Add-Type -MemberDefinition $Signature -Name User32PowerTab -Namespace GetKeyState -PassThru
    return [Bool]($Type::GetKeyState($KeyCode) -band 0x80)
}
