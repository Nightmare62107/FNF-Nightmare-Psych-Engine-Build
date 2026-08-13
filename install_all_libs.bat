@echo off
echo ====================================================
echo Starting Haxelib Installation Script
echo ====================================================
echo.

:: Standard Releases (Versions)
echo [1/4] Installing standard haxelib releases...
call haxelib install flixel-tools 1.5.1
call haxelib install flixel-addons 4.0.1
call haxelib install flixel 6.2.0
call haxelib install crypto 1.3.0
call haxelib install format 3.8.0
call haxelib install haxebanana 1.0.2
call haxelib install haxelib 4.2.0
call haxelib install hmm 3.1.0
call haxelib install hscript-iris 1.1.3
call haxelib install hx3compat 1.1.0
call haxelib install hx4compat 1.0.0
call haxelib install hxcpp 4.3.2
call haxelib install hxdiscord_rpc 1.3.0
call haxelib install hxp 1.3.1
call haxelib install hxvlc 2.3.0
call haxelib install lime 8.3.2
call haxelib install lime-samples 7.0.0
call haxelib install newgrounds 2.0.3
call haxelib install openfl 9.5.2
call haxelib install thx.core 0.44.0
call haxelib install tink_core 1.26.0
call haxelib install tjson 1.4.0
call haxelib install utest 1.13.2

:: Git Repositories
echo.
echo [2/4] Installing Git dependencies...
call haxelib git flxanimate https://github.com
call haxelib git funkin.vis https://github.com
call haxelib git grid.audio https://github.com
call haxelib git hx_libnx https://github.com
call haxelib git linc_luajit https://github.com

:: Version Locking / Enforcement
echo.
echo [3/4] Ensuring active versions are correctly selected...
call haxelib set flixel-tools 1.5.1
call haxelib set flixel-addons 4.0.1
call haxelib set flixel 6.2.0
call haxelib set crypto 1.3.0
call haxelib set format 3.8.0
call haxelib set haxebanana 1.0.2
call haxelib set haxelib 4.2.0
call haxelib set hmm 3.1.0
call haxelib set hscript-iris 1.1.3
call haxelib set hx3compat 1.1.0
call haxelib set hx4compat 1.0.0
call haxelib set hxcpp 4.3.2
call haxelib set hxdiscord_rpc 1.3.0
call haxelib set hxp 1.3.1
call haxelib set hxvlc 2.3.0
call haxelib set lime 8.3.2
call haxelib set lime-samples 7.0.0
call haxelib set newgrounds 2.0.3
call haxelib set openfl 9.5.2
call haxelib set thx.core 0.44.0
call haxelib set tink_core 1.26.0
call haxelib set tjson 1.4.0
call haxelib set utest 1.13.2

echo.
echo ====================================================
echo [4/4] Process completed! Review logs above for errors.
echo ====================================================
pause
