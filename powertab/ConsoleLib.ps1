Function Get-ConsoleList {
    param(
        [Parameter(Position = 0)]
        [ValidateNotNull()]
        [Object[]]
        $Content = @()
        ,
        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [String]
        $LastWord = ''
        ,
        [Parameter(Position = 2)]
        [ValidateNotNull()]
        [String]
        $ReturnWord = '' ## Text to return with filter if list closes without a selected item
        ,
        [Switch]
        $ForceList
        ,
        [ref]
        $Recurse # Will be set to true if completion menu should be re-opened after applying the completion
    )

    if (-not $PSBoundParameters.ContainsKey("ReturnWord")) {$ReturnWord = $LastWord}

    ## If contents contains less than minimum options, then forward contents without displaying console list
    if (($Content.Length -lt $PowerTabConfig.MinimumListItems) -and (-not $ForceList)) {
        $Content | Select-Object -ExpandProperty CompletionText
        return
    }

    ## Create console list
    $Filter = $OldFilter = ''
    $Colors = $PowerTabConfig.Colors
    $ListHandle = New-ConsoleList $Content $Colors.BorderColor $Colors.BorderBackColor $Colors.TextColor $Colors.BackColor

    ## Preview of current filter, shows up where cursor is at
    $PreviewBuffer = ConvertTo-BufferCellArray "$Filter " $Colors.FilterColor $UI.BackgroundColor
    $Preview = New-Buffer $UI.CursorPosition $PreviewBuffer

    Function Add-Status {
        ## Title buffer, shows the last word in header of console list
        $TitleBuffer = ConvertTo-BufferCellArray " $LastWord" $Colors.BorderTextColor $Colors.BorderBackColor
        $TitlePosition = $ListHandle.Position
        $TitlePosition.X += 2
        $TitleHandle = New-Buffer $TitlePosition $TitleBuffer

        ## Filter buffer, shows the current filter after the last word in header of console list
        $FilterBuffer = ConvertTo-BufferCellArray "$Filter " $Colors.FilterColor $Colors.BorderBackColor
        $FilterPosition = $ListHandle.Position
        $FilterPosition.X += (3 + $LastWord.Length)
        $FilterHandle = New-Buffer $FilterPosition $FilterBuffer

        ## Status buffer, shows at footer of console list. Displays selected item index, index range of currently visible items, and total item count.
        $StatusBuffer = ConvertTo-BufferCellArray "[$($ListHandle.SelectedItem + 1)] $($ListHandle.FirstItem + 1)-$($ListHandle.LastItem + 1) [$($Content.Length)]" $Colors.BorderTextColor $Colors.BorderBackColor
        $StatusPosition = $ListHandle.Position
        $StatusPosition.X += 2
        $StatusPosition.Y += ($listHandle.ListConfig.ListHeight - 1)
        $StatusHandle = New-Buffer $StatusPosition $StatusBuffer
    }
    . Add-Status

    ## Select the first item in the list
    $SelectedItem = 0
    Set-Selection 1 ($SelectedItem + 1) ($ListHandle.ListConfig.ListWidth - 3) $Colors.SelectedTextColor $Colors.SelectedBackColor

    ## Listen for first key press
    $Key = $UI.ReadKey('NoEcho,IncludeKeyDown')

    ## Process key presses
    $Items = @()
    $Continue = $true
    while ($Key.VirtualKeyCode -ne 27 -and $Continue -eq $true) {
        if ($OldFilter -ne $Filter) {
            $Preview.Clear()
            $PreviewBuffer = ConvertTo-BufferCellArray "$Filter " $Colors.FilterColor $UI.BackgroundColor
            $Preview = New-Buffer $Preview.Location $PreviewBuffer
            $OldFilter = $Filter
        }

        $ShiftPressed = 0x10 -band [int]$Key.ControlKeyState ## Check for ShiftPressed
        switch ($Key.VirtualKeyCode) {
            9 { ## Tab
                ## In Visual Studio, Tab acts like Enter
                if ($PowerTabConfig.VisualStudioTabBehavior) {
                    ## Expand with currently selected item
                    $ListHandle.Items[$ListHandle.SelectedItem].CompletionText
                    $Continue = $false
                    break
                } else {
                    if ($ShiftPressed) {
                        Move-Selection -1 ## Up
                    } else {
                        Move-Selection 1 ## Down
                    }
                    break
                }
            }
            38 { ## Up Arrow
                if ($ShiftPressed) {
                    ## Fast scroll selected
                    if ($PowerTabConfig.FastScrollItemCount -gt ($ListHandle.Items.Count - 1)) {
                        $Count = ($ListHandle.Items.Count - 1)
                    } else {
                        $Count = $PowerTabConfig.FastScrollItemCount
                    }
                    Move-Selection (- $Count)
                } else {
                    Move-Selection -1
                }
                break
            }
            40 { ## Down Arrow
                if ($ShiftPressed) {
                    ## Fast scroll selected
                    if ($PowerTabConfig.FastScrollItemCount -gt ($ListHandle.Items.Count - 1)) {
                        $Count = ($ListHandle.Items.Count - 1)
                    } else {
                        $Count = $PowerTabConfig.FastScrollItemCount
                    }
                    Move-Selection $Count
                } else {
                    Move-Selection 1
                }
                break
            }
            33 { ## Page Up
                $Count = $ListHandle.Items.Count
                if ($Count -gt $ListHandle.MaxItems) {
                    $Count = $ListHandle.MaxItems
                }
                Move-Selection (-($Count - 1))
                break
            }
            34 { ## Page Down
                $Count = $ListHandle.Items.Count
                if ($Count -gt $ListHandle.MaxItems) {
                    $Count = $ListHandle.MaxItems
                }
                Move-Selection ($Count - 1)
                break
            }
            39 { ## Right Arrow
                ## Add a new character (the one right after the current filter string) from currently selected item
                # skip wildcard filter
                if ($Filter.Contains('*')) {break}
                # skip end of text
                $Text = $ListHandle.Items[$ListHandle.SelectedItem].ListItemText
                $Index = $LastWord.Length + $Filter.Length
                if ($Index -ge $Text.Length) {break}
                # append next char
                $Char = $Text[$Index]
                $Filter += $Char

                $Old = $Items.Length
                $Items = @(Select-Item $Content $LastWord $Filter)
                $New = $Items.Length
                if ($New -lt 1) {
                    ## If new filter results in no items, sound error beep and remove character
                    [System.Console]::Beep()
                    $Filter = $Filter.SubString(0, $Filter.Length - 1)
                } else {
                    if ($Old -ne $New) {
                        ## Update console list contents
                        $ListHandle.Clear()
                        $ListHandle = New-ConsoleList $Items $Colors.BorderColor $Colors.BorderBackColor $Colors.TextColor $Colors.BackColor
                        ## Update status buffers
                        . Add-Status
                    }
                    ## Select first item of new list
                    $SelectedItem = 0
                    Set-Selection 1 ($SelectedItem + 1) ($ListHandle.ListConfig.ListWidth - 3) $Colors.SelectedTextColor $Colors.SelectedBackColor
                    $Host.UI.Write($Colors.FilterColor, $UI.BackgroundColor, $Char)
                }
                break
            }
            {(8,37 -contains $_)} { # Backspace or Left Arrow
                if ($Filter) {
                    ## Remove last character from filter
                    $Filter = $Filter.SubString(0, $Filter.Length - 1)
                    $Host.UI.Write([char]8)
                    Write-Line ($UI.CursorPosition.X) ($UI.CursorPosition.Y - $UI.WindowPosition.Y) " " $Colors.FilterColor $UI.BackgroundColor

                    $Old = $Items.Length
                    $Items = @(Select-Item $Content $LastWord $Filter)
                    $New = $Items.Length
                    if ($Old -ne $New) {
                        ## If the item list changed, update the contents of the console list
                        $ListHandle.Clear()
                        $ListHandle = New-ConsoleList $Items $Colors.BorderColor $Colors.BorderBackColor $Colors.TextColor $Colors.BackColor
                        ## Update status buffers
                        . Add-Status
                    }
                    ## Select first item of new list
                    $SelectedItem = 0
                    Set-Selection 1 ($SelectedItem + 1) ($ListHandle.ListConfig.ListWidth - 3) $Colors.SelectedTextColor $Colors.SelectedBackColor
                } else {
                    if ($PowerTabConfig.CloseListOnEmptyFilter) {
                        $Key.VirtualKeyCode = 27
                        $Continue = $false
                    } else {
                        [System.Console]::Beep()
                    }
                }
                break
            }
            190 { ## Period
                if ($PowerTabConfig.DotComplete -and -not $PowerTabFileSystemMode) {
                    if ($PowerTabConfig.AutoExpandOnDot) {
                        $Recurse.Value = $true
                    }
                    $ListHandle.Items[$ListHandle.SelectedItem].CompletionText + '.'
                    $Continue = $false
                    break
                }
            }
            {'\','/' -contains $Key.Character} { ## Path Separators
                if ($PowerTabConfig.BackSlashComplete) {
                    if ($PowerTabConfig.AutoExpandOnBackSlash) {
                        $Recurse.Value = $true
                    }
                    $ListHandle.Items[$ListHandle.SelectedItem].CompletionText + $Key.Character
                    $Continue = $false
                    break
                }
            }
            32 { ## Space
                ## True if "Space" and SpaceComplete is true, or "Ctrl+Space" and SpaceComplete is false
                if (($PowerTabConfig.SpaceComplete -and -not ($Key.ControlKeyState -match 'CtrlPressed')) -or (-not $PowerTabConfig.SpaceComplete -and ($Key.ControlKeyState -match 'CtrlPressed'))) {
                    ## Expand with currently selected item
                    $Item = $ListHandle.Items[$ListHandle.SelectedItem].CompletionText
                    if ((-not $Item.Contains(' ')) -and ($PowerTabFileSystemMode -ne $true)) {$Item += ' '}
                    $Item
                    $Continue = $false
                    break
                }
            }
            {($PowerTabConfig.CustomCompletionChars.ToCharArray() -contains $Key.Character) -and $PowerTabConfig.CustomComplete} { ## Extra completions
                $Item = $ListHandle.Items[$ListHandle.SelectedItem].CompletionText
                $Item = ($Item + $Key.Character) -replace "\$($Key.Character){2}$",$Key.Character
                $Item
                $Continue = $false
                break
            }
            13 { ## Enter
                ## Expand with currently selected item
                $ListHandle.Items[$ListHandle.SelectedItem].CompletionText
                $Continue = $false
                break
            }
            {$Key.Character} { ## Character
                ## Add character to filter
                $Filter += $Key.Character

                $Old = $Items.Length
                $Items = @(Select-Item $Content $LastWord $Filter)
                $New = $Items.Length
                if ($Items.Length -lt 1) {
                    ## New filter results in no items
                    if ($PowerTabConfig.CloseListOnEmptyFilter) {
                        ## Close console list and return the return word with current filter (includes new character)
                        $ListHandle.Clear()
                        return "$ReturnWord$Filter"
                    } else {
                        ## Sound error beep and remove character
                        [System.Console]::Beep()
                        $Filter = $Filter.SubString(0, $Filter.Length - 1)
                    }
                } else {
                    if ($Old -ne $New) {
                        ## If the item list changed, update the contents of the console list
                        $ListHandle.Clear()
                        $ListHandle = New-ConsoleList $Items $Colors.BorderColor $Colors.BorderBackColor $Colors.TextColor $Colors.BackColor
                        ## Update status buffer
                        . Add-Status
                        ## Select first item of new list
                        $SelectedItem = 0
                        Set-Selection 1 ($SelectedItem + 1) ($ListHandle.ListConfig.ListWidth - 3) $Colors.SelectedTextColor $Colors.SelectedBackColor
                    }

                    $Host.UI.Write($Colors.FilterColor, $UI.BackgroundColor, $Key.Character)
                }
                break
            }
        }

        ## Listen for next key press
        if ($Continue) {$Key = $UI.ReadKey('NoEcho,IncludeKeyDown')}
    }

    $ListHandle.Clear()

    if ($Key.VirtualKeyCode -eq 27) {
        ## No items left and request that console list close, so return the return word with current filter
        return "$ReturnWord$Filter"
    }
}

Function New-Box {
    param(
        [System.Drawing.Size]
        $Size
        ,
        [System.ConsoleColor]
        $ForegroundColor = $UI.ForegroundColor
        ,
        [System.ConsoleColor]
        $BackgroundColor = $UI.BackgroundColor
    )

    $HorizontalDouble = [string][char]9552
    $VerticalDouble = [string][char]9553
    $TopLeftDouble = [string][char]9556
    $TopRightDouble = [string][char]9559
    $BottomLeftDouble = [string][char]9562
    $BottomRightDouble = [string][char]9565
    $Horizontal = [string][char]9472
    $Vertical = [string][char]9474
    $TopLeft = [string][char]9484
    $TopRight = [string][char]9488
    $BottomLeft = [string][char]9492
    $BottomRight = [string][char]9496
    #$Cross = [string][char]9532
    #$HorizontalDoubleSingleUp = [string][char]9575
    #$HorizontalDoubleSingleDown = [string][char]9572
    #$VerticalDoubleLeftSingle = [string][char]9570
    #$VerticalDoubleRightSingle = [string][char]9567
    $TopLeftDoubleSingle = [string][char]9554
    $TopRightDoubleSingle = [string][char]9557
    $BottomLeftDoubleSingle = [string][char]9560
    $BottomRightDoubleSingle = [string][char]9563
    #$TopLeftSingleDouble = [string][char]9555
    #$TopRightSingleDouble = [string][char]9558
    #$BottomLeftSingleDouble = [string][char]9561
    #$BottomRightSingleDouble = [string][char]9564

    if ($PowerTabConfig.DoubleBorder) {
        ## Double line box
        $LineTop = $TopLeftDouble `
            + $HorizontalDouble * ($Size.width - 2) `
            + $TopRightDouble
        $LineField = $VerticalDouble `
            + ' ' * ($Size.width - 2) `
            + $VerticalDouble
        $LineBottom = $BottomLeftDouble `
            + $HorizontalDouble * ($Size.width - 2) `
            + $BottomRightDouble
    } elseif ($false) {
        ## Mixed line box, double horizontal, single vertical
        $LineTop = $TopLeftDoubleSingle `
            + $HorizontalDouble * ($Size.width - 2) `
            + $TopRightDoubleSingle
        $LineField = $Vertical `
            + ' ' * ($Size.width - 2) `
            + $Vertical
        $LineBottom = $BottomLeftDoubleSingle `
            + $HorizontalDouble * ($Size.width - 2) `
            + $BottomRightDoubleSingle
    } elseif ($false) {
        ## Mixed line box, single horizontal, double vertical
        $LineTop = $TopLeftDoubleSingle `
            + $HorizontalDouble * ($Size.width - 2) `
            + $TopRightDoubleSingle
        $LineField = $Vertical `
            + ' ' * ($Size.width - 2) `
            + $Vertical
        $LineBottom = $BottomLeftDoubleSingle `
            + $HorizontalDouble * ($Size.width - 2) `
            + $BottomRightDoubleSingle
    } else {
        ## Single line box
        $LineTop = $TopLeft `
            + $Horizontal * ($Size.width - 2) `
            + $TopRight
        $LineField = $Vertical `
            + ' ' * ($Size.width - 2) `
            + $Vertical
        $LineBottom = $BottomLeft `
            + $Horizontal * ($Size.width - 2) `
            + $BottomRight
    }
    $Box = $(
        $LineTop
        1..($Size.Height - 2) | .{process{$LineField}}
        $LineBottom
    )
    $BoxBuffer = $UI.NewBufferCellArray($Box, $ForegroundColor, $BackgroundColor)
    ,$BoxBuffer
}

Function Get-ContentSize {
    param(
        [Object[]]$Content
    )

    $MaxWidth = ($Content | .{process { $_.ListItemText.Length } end {$PowerTabConfig.MinimumTextWidth}} | Measure-Object -Maximum).Maximum
    New-Object System.Drawing.Size $MaxWidth, $Content.Length
}

Function New-Position {
    param(
        [Int]$X
        ,
        [Int]$Y
    )

    $Position = $UI.WindowPosition
    $Position.X += $X
    $Position.Y += $Y
    $Position
}

Function New-Buffer {
    param(
        [System.Management.Automation.Host.Coordinates]
        $Position
        ,
        [System.Management.Automation.Host.BufferCell[,]]
        $Buffer
    )

    $BufferBottom = $BufferTop = $Position
    $BufferBottom.X += ($Buffer.GetUpperBound(1))
    $BufferBottom.Y += ($Buffer.GetUpperBound(0))

    $OldTop = New-Object System.Management.Automation.Host.Coordinates 0, $BufferTop.Y
    $OldBottom = New-Object System.Management.Automation.Host.Coordinates ($UI.BufferSize.Width - 1), $BufferBottom.Y
    $OldBuffer = $UI.GetBufferContents((New-Object System.Management.Automation.Host.Rectangle $OldTop, $OldBottom))

    $UI.SetBufferContents($BufferTop, $Buffer)
    $Handle = New-Object System.Management.Automation.PSObject -Property @{
        Content = $Buffer
        OldContent = $OldBuffer
        Location = $BufferTop
        OldLocation = $OldTop
    }
    Add-Member -InputObject $Handle -MemberType ScriptMethod -Name Clear -Value {$UI.SetBufferContents($This.OldLocation, $This.OldContent)}
    Add-Member -InputObject $Handle -MemberType ScriptMethod -Name Show -Value {$UI.SetBufferContents($This.Location, $This.Content)}
    $Handle
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
    )

    ,$UI.NewBufferCellArray($Content, $ForegroundColor, $BackgroundColor)
}

Function Parse-List {
    param(
        [System.Drawing.Size]$Size
    )

    $WindowPosition = $UI.WindowPosition
    $WindowSize = $UI.WindowSize
    $Cursor = $UI.CursorPosition
    $Center = [int]($WindowSize.Height / 2)
    $CursorOffset = $Cursor.Y - $WindowPosition.Y
    $CursorOffsetBottom = $WindowSize.Height - $CursorOffset

    # Vertical Placement and size
    $ListHeight = $Size.Height + 2

    if (($CursorOffset -gt $Center) -and ($ListHeight -ge $CursorOffsetBottom)) {$Placement = 'Above'}
    else {$Placement = 'Below'}

    switch ($Placement) {
        'Above' {
            $MaxListHeight = $CursorOffset - 1
            if ($MaxListHeight -lt $ListHeight) {$ListHeight = $MaxListHeight}
            $Y = $CursorOffset - $ListHeight
        }
        'Below' {
            $MaxListHeight = $CursorOffsetBottom - 2
            if ($MaxListHeight -lt $ListHeight) {$ListHeight = $MaxListHeight}
            $Y = $CursorOffSet + 1
        }
    }
    $MaxItems = $MaxListHeight - 2
    $PageSize = $ListHeight - 2

    # Horizontal
    $ListWidth = $Size.Width + 4
    if ($ListWidth -gt $WindowSize.Width) {$ListWidth = $Windowsize.Width}
    $Max = $ListWidth
    if (($Cursor.X + $Max) -lt ($WindowSize.Width - 2)) {
        $X = $Cursor.X
    } else {
        if (($Cursor.X - $Max) -gt 0) {
            $X = $Cursor.X - $Max
        } else {
            $X = $windowSize.Width - $Max
        }
    }

    # Output
    New-Object System.Management.Automation.PSObject -Property @{
        Orientation = $Placement
        TopX = $X
        TopY = $Y
        ListHeight = $ListHeight
        ListWidth = $ListWidth
        MaxItems = $MaxItems
        PageSize = $PageSize
    }
}

Function New-ConsoleList {
    param(
        [Object[]]
        $Content
        ,
        [System.ConsoleColor]
        $BorderForegroundColor
        ,
        [System.ConsoleColor]
        $BorderBackgroundColor
        ,
        [System.ConsoleColor]
        $ContentForegroundColor
        ,
        [System.ConsoleColor]
        $ContentBackgroundColor
    )

    $Size = Get-ContentSize $Content
    $MinWidth = ([String]$Content.Count).Length * 4 + 7
    if ($Size.Width -lt $MinWidth) {$Size.Width = $MinWidth}
    $Lines = @(foreach ($Item in $Content) {"$($Item.CompletionText) ".PadRight($Size.Width + 2)})
    $ListConfig = Parse-List $Size
    $BoxSize = New-Object System.Drawing.Size $ListConfig.ListWidth, $ListConfig.ListHeight
    $Box = New-Box $BoxSize $BorderForegroundColor $BorderBackgroundColor

    $Position = New-Position $ListConfig.TopX $ListConfig.TopY
    $BoxHandle = New-Buffer $Position $Box

    # Place content
    $Position.X += 1
    $Position.Y += 1
    $ContentBuffer = ConvertTo-BufferCellArray ($Lines[0..($ListConfig.ListHeight - 3)]) $ContentForegroundColor $ContentBackgroundColor
    $ContentHandle = New-Buffer $Position $ContentBuffer
    $Handle = New-Object System.Management.Automation.PSObject -Property @{
        Position = New-Position $ListConfig.TopX $ListConfig.TopY
        ListConfig = $ListConfig
        ContentSize = $Size
        BoxSize = $BoxSize
        Box = $BoxHandle
        Content = $ContentHandle
        SelectedItem = 0
        SelectedLine = 1
        Items = $Content
        FirstItem = 0
        LastItem = $Listconfig.ListHeight - 3
        PageSize = $Listconfig.PageSize
        MaxItems = $Listconfig.MaxItems
    }
    Add-Member -InputObject $Handle -MemberType ScriptMethod -Name Clear -Value {$This.Box.Clear()}
    Add-Member -InputObject $Handle -MemberType ScriptMethod -Name Show -Value {$This.Box.Show(); $This.Content.Show()}
    $Handle
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

Function Move-List {
    param(
        [Int]$X
        ,
        [Int]$Y
        ,
        [Int]$Width
        ,
        [Int]$Height
        ,
        [Int]$Offset
    )

    $Position = $ListHandle.Position
    $Position.X += $X
    $Position.Y += $Y
    $Rectangle = New-Object System.Management.Automation.Host.Rectangle $Position.X, $Position.Y, ($Position.X + $Width), ($Position.Y + $Height - 1)
    $Position.Y += $OffSet
    $BufferCell = New-Object System.Management.Automation.Host.BufferCell
    $BufferCell.BackgroundColor = $PowerTabConfig.Colors.BackColor
    $UI.ScrollBufferContents($Rectangle, $Position, $Rectangle, $BufferCell)
}

Function Set-Selection {
    param(
        [Int]$X
        ,
        [Int]$Y
        ,
        [Int]$Width
        ,
        [System.ConsoleColor]
        $ForegroundColor
        ,
        [System.ConsoleColor]
        $BackgroundColor
    )

    $Position = $ListHandle.Position
    $Position.X += $X
    $Position.Y += $Y
    $Rectangle = New-Object System.Management.Automation.Host.Rectangle $Position.X, $Position.Y, ($Position.X + $Width), $Position.Y
    $LineBuffer = $UI.GetBufferContents($Rectangle)
    $LineBuffer = $UI.NewBufferCellArray(
        @([String]::Join("", ($LineBuffer | .{process{$_.Character}}))),
        $ForegroundColor,
        $BackgroundColor
    )
    $UI.SetBufferContents($Position, $LineBuffer)
}

Function Move-Selection {
    param(
        [Int]$Count
    )

    $SelectedItem = $ListHandle.SelectedItem
    $Line = $ListHandle.SelectedLine
    if ($Count -ge 0) { ## Down in list
        $One = 1
        if ($SelectedItem -eq $ListHandle.LastItem) {
            $Move = $true
            $Count = [Math]::min($Count, ($ListHandle.Items.Count - $SelectedItem - 1))
        } else {
            $Move = $false
            $Count = [Math]::min($Count, ($ListHandle.PageSize - $Line))
        }
    } else {
        $One = -1
        if ($SelectedItem -eq $ListHandle.FirstItem) {
            $Move = $true
            $Count = [Math]::max($Count, -$SelectedItem)
        } else {
            $Move = $false
            $Count = [Math]::max($Count, -$Line + 1)
        }
    }
    if ($Count -eq 0) {return}

    # Erase highlight of selected line
    Set-Selection 1 $Line ($ListHandle.ListConfig.ListWidth - 3) $PowerTabConfig.Colors.TextColor $PowerTabConfig.Colors.BackColor
    $SelectedItem += $Count
    if ($Move) {
        # Scroll rows that are already visible to avoid re-rendering them
        Move-List 1 1 ($ListHandle.ListConfig.ListWidth - 3) ($ListHandle.ListConfig.ListHeight - 2) (-$Count)
        $ListHandle.FirstItem += $Count
        $ListHandle.LastItem += $Count

        # Draw rows that were not previously visible
        $LinePosition = $ListHandle.Position
        $LinePosition.X += 1
        if ($One -eq 1) {
            $LinePosition.Y += $Line - ($Count - $One)
            $LineBuffer = ConvertTo-BufferCellArray ($ListHandle.Items[($SelectedItem - ($Count - $One)) .. $SelectedItem] | Select-Object -ExpandProperty ListItemText) $PowerTabConfig.Colors.TextColor $PowerTabConfig.Colors.BackColor
        } else {
            $LinePosition.Y += 1
            $LineBuffer = ConvertTo-BufferCellArray ($ListHandle.Items[($SelectedItem..($SelectedItem - ($Count - $One)))] | Select-Object -ExpandProperty ListItemText) $PowerTabConfig.Colors.TextColor $PowerTabConfig.Colors.BackColor
        }
        New-Buffer $LinePosition $LineBuffer
    } else {
        $Line += $Count
    }
    # Draw highlight of selected line
    Set-Selection 1 $Line ($ListHandle.ListConfig.ListWidth - 3) $PowerTabConfig.Colors.SelectedTextColor $PowerTabConfig.Colors.SelectedBackColor
    $ListHandle.SelectedItem = $SelectedItem
    $ListHandle.SelectedLine = $Line

    ## New status buffer
    $StatusHandle.Clear()
    $StatusBuffer = ConvertTo-BufferCellArray "[$($ListHandle.SelectedItem + 1)] $($ListHandle.FirstItem + 1)-$($ListHandle.LastItem + 1) [$($Content.Length)]" `
        $PowerTabConfig.Colors.BorderTextColor $PowerTabConfig.Colors.BorderBackColor
    $StatusHandle = New-Buffer $StatusHandle.Location $StatusBuffer
}

function Get-FilterPattern($Filter) {
    $Filter = [Regex]::Escape($Filter)
    for ($i = 0; $i -lt $Filter.Length - 1; ++$i) {
        if ($Filter[$i] -eq '\') {
            if ($Filter[$i + 1] -eq '*') {
                $Filter = $Filter.Substring(0, $i) + '.*' + $Filter.Substring($i + 2)
            }
            elseif ($Filter[$i + 1] -eq '?') {
                $Filter = $Filter.Substring(0, $i) + '.?' + $Filter.Substring($i + 2)
            }
            else {
                ++$i
            }
        }
    }
    $Filter
}

function Select-Item($Content, $Prefix, $Filter) {
    $pattern = '^' + [Regex]::Escape($Prefix) + (Get-FilterPattern $Filter)
    foreach ($_ in $Content) {
        if ($_.ListItemText -match $pattern) {
            $_
        }
    }
}
