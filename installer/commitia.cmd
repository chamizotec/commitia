@echo off
rem Atalho do CommitIA para PowerShell e CMD.
rem Localiza o Git Bash e repassa os argumentos para o script bash instalado ao lado.
rem Não usa bash do PATH: no Windows, bash.exe em System32 é o WSL.
setlocal

set "CI_BASH="
if defined COMMITIA_GIT_BASH if exist "%COMMITIA_GIT_BASH%" set "CI_BASH=%COMMITIA_GIT_BASH%"
if not defined CI_BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "CI_BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined CI_BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "CI_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"

if not defined CI_BASH (
  echo Git Bash nao encontrado. Instale o Git para Windows: https://git-scm.com/download/win 1>&2
  exit /b 1
)

set "MSYS_NO_PATHCONV=1"
"%CI_BASH%" "%~dp0commitia" %*
exit /b %ERRORLEVEL%
