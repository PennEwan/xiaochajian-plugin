@echo off
rem Codex starts this plugin's MCP server through cmd.exe so no file inside the plugin folder stays in use.
setlocal
set "ASSIST_PLUGIN_ROOT=%~dp0.."
set "SHADOW="
for /f "usebackq delims=" %%P in (` "%~dp0assist.exe" shadow `) do set "SHADOW=%%P"
if not defined SHADOW set "SHADOW=%~dp0assist.exe"
cd /d "%USERPROFILE%"
"%SHADOW%" %*
