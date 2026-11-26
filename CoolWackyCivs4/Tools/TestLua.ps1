param(
    [Parameter(Mandatory = $true)]
    [string] $Civ5Path
)

$ErrorActionPreference = 'Stop'
if ([Environment]::Is64BitProcess) {
    $luaHost = Join-Path $env:WINDIR 'SysWOW64/WindowsPowerShell/v1.0/powershell.exe'
    & $luaHost -NoProfile -File $PSCommandPath -Civ5Path $Civ5Path
    exit $LASTEXITCODE
}
$resolvedGame = (Resolve-Path -LiteralPath $Civ5Path).Path
$env:Path = "$resolvedGame;$env:Path"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ArachnidLua51 {
    const string Dll = "lua51_Win32.dll";
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    public static extern IntPtr luaL_newstate();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    public static extern void luaL_openlibs(IntPtr state);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    public static extern int luaL_loadfile(IntPtr state, string file);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    public static extern int lua_pcall(IntPtr state, int args, int results, int errorFunc);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    public static extern IntPtr lua_tolstring(IntPtr state, int index, IntPtr size);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    public static extern void lua_settop(IntPtr state, int index);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    public static extern void lua_close(IntPtr state);
}
'@

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$state = [ArachnidLua51]::luaL_newstate()
if ($state -eq [IntPtr]::Zero) { throw 'Could not initialize Lua 5.1.' }
function Invoke-LuaFile([string] $File, [switch] $CompileOnly) {
    $code = [ArachnidLua51]::luaL_loadfile($state, $File)
    if ($code -eq 0 -and !$CompileOnly) {
        $code = [ArachnidLua51]::lua_pcall($state, 0, 0, 0)
    }
    if ($code -ne 0) {
        $message = [ArachnidLua51]::lua_tolstring($state, -1, [IntPtr]::Zero)
        throw [Runtime.InteropServices.Marshal]::PtrToStringAnsi($message)
    }
    [ArachnidLua51]::lua_settop($state, 0)
}
$previousDirectory = [Environment]::CurrentDirectory
[Environment]::CurrentDirectory = $root
try {
    [ArachnidLua51]::luaL_openlibs($state)
    $files = Get-ChildItem -LiteralPath (Join-Path $root 'Civilizations') -Filter '*.lua' -Recurse
    foreach ($file in $files) { Invoke-LuaFile $file.FullName -CompileOnly }
    Write-Output "Lua 5.1 syntax passed for $($files.Count) gameplay and UI files."
    Invoke-LuaFile (Join-Path $PSScriptRoot 'TestRules.lua')
    Write-Output 'Arachnid gameplay simulations passed.'
    Invoke-LuaFile (Join-Path $PSScriptRoot 'TestScorpion.lua')
    Write-Output 'Scorpion Dominion gameplay simulations passed.'
} finally {
    [Environment]::CurrentDirectory = $previousDirectory
    [ArachnidLua51]::lua_close($state)
}
