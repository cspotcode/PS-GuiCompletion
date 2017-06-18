These files are lifted as verbatim as possible from the powertab source code.

default.config.ps1 is new and creates the configuration object that PowerTab's code expects.

TabExpansionUtil.ps1 is stripped way down to only the functions that are used.

ConsoleLib.ps1 contains the UI rendering code.  In particular, `Out-ConsoleList` renders a completion list.