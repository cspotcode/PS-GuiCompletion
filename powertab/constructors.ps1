# Constructors, factories, and converters

# These are faster and less verbose than New-Object with lengthy namespaces

Function Rectangle($arglist) {
    [Activator]::CreateInstance([System.Management.Automation.Host.Rectangle], $arglist)
}

Function BufferCell($arglist) {
    [Activator]::CreateInstance([System.Management.Automation.Host.BufferCell], $arglist)
}

Function Coordinates($arglist) {
    [Activator]::CreateInstance([System.Management.Automation.Host.Coordinates], $arglist)
}

Function Size($arglist) {
    [Activator]::CreateInstance([System.Drawing.Size], $arglist)
}

# Create a window-relative `Coordinates` instances
Function New-Position {
    param(
        [Int]$X,
        [Int]$Y
    )

    $Position = $UI.WindowPosition
    $Position.X += $X
    $Position.Y += $Y
    $Position
}

Function ConvertTo-BufferCellArray {
    param(
        [String[]]
        $Content
        ,
        [System.ConsoleColor]
        $ForegroundColor = $UI.ForegroundColor
        ,
        [System.ConsoleColor]
        $BackgroundColor = $UI.BackgroundColor
        ,
        [int]
        $Width = 0
    )

    # If width is unspecified, auto-detect max string length
    if($Width -eq 0) {
        ForEach($Row in $Content) {
            $l = $Row.Length
            if($l -gt $Width) {
                $Width = $l
            }
        }
    }
    $Height = $Content.Count
    $arr = [System.Management.Automation.Host.BufferCell[,]]::new($height, $width)
    $cell = $arr[0,0]
    # All cells have the same colors
    $cell.ForegroundColor = $ForegroundColor
    $cell.BackgroundColor = $BackgroundColor
    for($y = 0; $y -lt $height; $y++) {
        $row = $Content[$y]
        $rowLength = $row.Length
        # Fill row with available characters
        for($x = 0; $x -lt $rowLength; $x++) {
            $cell.Character = $row[$x]
            $arr[$y, $x] = $cell
        }
        # If row is too short, fill remaining cells with spaces
        $cell.Character = ' '
        for(; $x -lt $Width; $x++) {
            $arr[$y, $x] = $cell
        }
    }
    # Prevent pipe from iterating array
    ,$arr
}
