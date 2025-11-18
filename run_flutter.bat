@echo off
set PUB_CACHE=C:\flutter_pub_cache
set FLUTTER_ROOT=%~dp0flutter_install\flutter
cd flutter-frontend
..\flutter_install\flutter\bin\flutter.bat run -d chrome
