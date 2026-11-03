@echo off
rem Starts a separate n8n for this project only (option B, without Docker).
rem Its own data, login, credentials and workflows live in the n8n-data folder next to this file,
rem and it may read and write files only in the output folder. Any other n8n on this computer is not affected.
set "N8N_USER_FOLDER=%~dp0n8n-data"
set "N8N_RESTRICT_FILE_ACCESS_TO=%~dp0output"
set N8N_PORT=5680
set GENERIC_TIMEZONE=Europe/Copenhagen
set N8N_DIAGNOSTICS_ENABLED=false
set N8N_PERSONALIZATION_ENABLED=false
set N8N_BLOCK_ENV_ACCESS_IN_NODE=true
if not exist "%~dp0output" mkdir "%~dp0output"
echo Tender radar n8n: open http://localhost:5680 in your browser. Close this window to stop it.
n8n start
