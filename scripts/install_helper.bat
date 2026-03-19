@echo off
set PATH=%~dp0..\node;%PATH%
cd /d %~dp0..\app
:: Falls noch keine .db da ist, wird sie hier final erstellt
call npx prisma db push