
function New-Instance($sb) {
    $this = New-Object System.Management.Automation.PSObject
    function val($name, $val) {
        $this | Add-Member NoteProperty $name $val
    }
    function vals($dict) {
        $this | Add-Member -NotePropertyMembers $dict
    }
    function prop($name, $get, $set) {
        $this | Add-Member ScriptProperty $name $get $set
    }
    function method($name, $sb) {
        $this | Add-Member ScriptMethod $name $sb
    }
    & $sb
    return $this
}