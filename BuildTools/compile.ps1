$version=$args[0]
if ($version -eq $null){
	echo "No Version supplied, not bulding"
	return
}


function addSpacing{
	param ($targetFile)
	
	for ($i = 0; $i -lt 2; $i++){
		Add-Content $targetFile ("---------------------------------------------------------------------------")
	}
}

$mypath = $MyInvocation.MyCommand.Path
$mypath = Split-Path $mypath -Parent #get location WO filename
$mypath = Split-Path $mypath -Parent #get main project loc

$file = $mypath + "/BetterCap/BetterCap_Compiled.lua"

echo ("----BUILDING IN: " + $file + " ----")
#clear file
Clear-Content $file

#build info
$ver = "Better CAP version: " +$version+ " | Build time: " +(Get-Date -date (Get-Date).ToUniversalTime()-uformat "%d.%m.%Y %H%MZ")
Add-Content $file ('---' + $ver + '---')
Add-Content $file ('env.info("' + $ver + '")')

#append code from every source file
$files = Get-ChildItem $mypath/BetterCap/Source/
for ($i=0; $i -lt $files.Count; $i++) {
	addSpacing($file)
	Add-Content $file ("--     Source file: " + $files[$i].Name)
	addSpacing($file)
	Add-Content $file ("")
	
	Add-Content $file (Get-Content $files[$i].FullName )	
	
	Add-Content $file ("")
}

echo "----BUILD DONE----"
echo ""

#launch tests
echo "----Launch Tests----"
$files = Get-ChildItem $mypath/BetterCap/SourceTest/
 for ($i=0; $i -lt $files.Count; $i++) {
	echo ""
	echo ("----EXECUTING TEST: " + $files[$i].Name + " ----")
	lua $files[$i].FullName
}
echo "----Testing Done----"