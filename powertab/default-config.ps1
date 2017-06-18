$PowerTabConfig = @{
    Colors = @{
        # This is the "Original" theme
        TextColor = 'Yellow'
        BackColor = 'DarkGray'
        SelectedTextColor = 'Red'
        SelectedBackColor = 'DarkRed'

        BorderTextColor = 'Yellow'
        BorderBackColor = 'DarkBlue'
        BorderColor = 'Blue'
        FilterColor = 'Gray'
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