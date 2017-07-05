$PowerTabConfig = @{
    Colors = @{
        # This the default cmd menus theme
        TextColor = 'DarkMagenta'
        BackColor = 'White'
        SelectedTextColor = 'White'
        SelectedBackColor = 'DarkMagenta'

        BorderTextColor = 'DarkMagenta'
        BorderBackColor = 'White'
        BorderColor = 'DarkMagenta'
        FilterColor = 'DarkGray'
    }
    MinimumListItems = 2
    FastScrollItemCount = 10
    CloseListOnEmptyFilter = $true
    DotComplete = $true
    AutoExpandOnDot = $true
    BackSlashComplete = $true
    AutoExpandOnBackSlash = $true
    SpaceComplete = $true
    CustomCompletionChars = ']:)'
    CustomComplete = $true

    DoubleBorder = $true
}

# Expose globally to allow customization
$GuiCompletionConfig = $PowerTabConfig
