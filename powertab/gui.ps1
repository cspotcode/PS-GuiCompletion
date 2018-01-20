Function ScrollConsoleRegion {
    param(
        [Int]$X
        ,
        [Int]$Y
        ,
        [Int]$Width
        ,
        [Int]$Height
        ,
        [Int]$XOffset = 0
        ,
        [Int]$YOffset = 0
        ,
        [Switch]$RelativeToWindow
    )

    if($RelativeToWindow) {
        $Position = if($RelativeToWindow) { $UI.WindowPosition } else { Coordinates 0, 0 }
    }
    $Position.X += $X
    $Position.Y += $Y
    $Rectangle = Rectangle $Position.X, $Position.Y, ($Position.X + $Width), ($Position.Y + $Height - 1)
    $Position.X += $XOffSet
    $Position.Y += $YOffSet
    $BufferCell = BufferCell
    $BufferCell.BackgroundColor = $PowerTabConfig.Colors.BackColor
    $UI.ScrollBufferContents($Rectangle, $Position, $Rectangle, $BufferCell)
}

Function Write-Line {
    param(
        [Int]$X
        ,
        [Int]$Y
        ,
        [String]$Text
        ,
        [System.ConsoleColor]
        $ForegroundColor
        ,
        [System.ConsoleColor]
        $BackgroundColor
    )

    $Position = $UI.WindowPosition
    $Position.X += $X
    $Position.Y += $Y
    if ($Text -eq '') {$Text = '-'}
    $Buffer = $UI.NewBufferCellArray([String[]]$Text, $ForegroundColor, $BackgroundColor)
    $UI.SetBufferContents($Position, $Buffer)
}
