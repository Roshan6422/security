@echo off
echo Running flutter pub get... > build_log.txt
flutter pub get -v >> build_log.txt 2>&1
echo Done. >> build_log.txt
