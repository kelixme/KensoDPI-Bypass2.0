@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: Установка кодировки UTF-8
for /f "tokens=2 delims=:" %%a in ('chcp') do set "original_codepage=%%a"
set "original_codepage=%original_codepage: =%"
reg add "HKCU\Console" /v CodePage /t REG_DWORD /d 65001 /f >nul 2>&1

:: Переменные
set SRVCNAME=AdGuardHome
set SRVCDIR="%~dp0lib\AdGuardHome.exe"
set SRVCDESC="AdGuardHome-DNS-Filter"
set ICON_PATH=%~dp0lib\favicon.ico
title %SRVCDESC%

:menu
mode con cols=85 lines=30
cls

:: Чтение порта из YAML
set CURRENT_PORT=8080
set YAML_PATH=lib\AdGuardHome.yaml
if exist "!YAML_PATH!" (
    for /f "tokens=*" %%a in ('findstr /c:"address:" "!YAML_PATH!"') do (
        set "line=%%a"
        set "line=!line:*address:=!"
        set "line=!line: =!"
        for /f "tokens=2 delims=:" %%b in ("!line!") do set CURRENT_PORT=%%b
    )
) else (
    if exist "AdGuardHome.yaml" (
        for /f "tokens=*" %%a in ('findstr /c:"address:" "AdGuardHome.yaml"') do (
            set "line=%%a"
            set "line=!line:*address:=!"
            set "line=!line: =!"
            for /f "tokens=2 delims=:" %%b in ("!line!") do set CURRENT_PORT=%%b
        )
    )
)

if "!CURRENT_PORT!"=="" set CURRENT_PORT=8080
set CURRENT_PORT=!CURRENT_PORT: =!

:: Проверка прав администратора
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [90m =============================================[0m
    echo [93m     Статус: [92mАдминистратор[0m
    sc query %SRVCNAME% >nul 2>&1
    if !errorlevel! equ 0 (
        echo [96m     Служба: [92mУстановлена[0m
    ) else (
        echo [96m     Служба: [91mНе установлена[0m
    )
    echo [90m =============================================[0m
) else (
    echo [90m =============================================[0m
    echo [93m     Статус: [91mНе Администратор[0m
    sc query %SRVCNAME% >nul 2>&1
    if !errorlevel! equ 0 (
        echo  [96m     Служба: [92mУстановлена[0m
    ) else (
        echo  [96m     Служба: [91mНе установлена[0m
    )
    echo [90m =============================================[0m
    echo [93m  Запуск с правами администратора...[0m
    powershell -Command "Start-Process -Verb RunAs -FilePath '%0' -ArgumentList 'am_admin'" > nul
    exit
)

echo.
echo [90m =========== Управление службой [92m%SRVCNAME%[90m ===========[0m
echo   [93m1[0m - [92mУстановить службу[0m
echo   [93m2[0m - [91mУдалить службу[0m
echo   [93m3[0m - Изменить порт веб-интерфейса [90m[[91m!CURRENT_PORT![90m][0m
echo   [93m4[0m - [96mНастройка DNS (Обязателно выбирете любой после установки)[0m
echo   [93m5[0m - [90mВыход[0m
echo.
set /p choice=[96m  Выбор: [93m

if "%choice%"=="1" goto install
if "%choice%"=="2" goto uninstall_menu
if "%choice%"=="3" goto change_port
if "%choice%"=="4" goto dns_menu
if "%choice%"=="5" exit /b
goto menu

:dns_menu
mode con cols=85 lines=25
cls
echo [90m =============================================[0m
echo [93m              Настройка DNS[0m
echo [90m =============================================[0m
echo.
echo Выберите тип DNS:
echo.
echo   [93m1[0m - AdGuard Home + Google DNS
echo       IPv4 : 127.0.0.1 / 8.8.8.8
echo       IPv6 : ::1 / 2001:4860:4860::8888
echo.
echo   [93m2[0m - AdGuard Home + CloudFlare DNS [РЕКОМЕНДУЕТСЯ]
echo       IPv4 : 127.0.0.1 / 1.1.1.1
echo       IPv6 : ::1 / 2606:4700:4700::1111
echo.
echo   [93m3[0m - AdGuard Home + Yandex DNS
echo       IPv4 : 127.0.0.1 / 77.88.8.8
echo       IPv6 : ::1 / 2a02:6b8::feed:0ff
echo.
echo   [93m4[0m - AdGuard Home + AdGuard DNS
echo       IPv4 : 127.0.0.1 / 94.140.14.14
echo       IPv6 : ::1 / 2a10:50c0::ad1:ff
echo.
echo   [93m5[0m - Удалить DNS (автоматический режим DHCP) [ОСТОРОЖНО, ОТКЛЮЧИТ ADGHOME]
echo   [93m0[0m - Вернуться в меню
echo.
set /p dns_choice=[96m  Выбор: [93m

if "%dns_choice%"=="0" goto menu
if "%dns_choice%"=="1" set DNS4_1=127.0.0.1 & set DNS4_2=8.8.8.8 & set DNS6_1=::1 & set DNS6_2=2001:4860:4860::8888 & goto apply_dns_only
if "%dns_choice%"=="2" set DNS4_1=127.0.0.1 & set DNS4_2=1.1.1.1 & set DNS6_1=::1 & set DNS6_2=2606:4700:4700::1111 & goto apply_dns_only
if "%dns_choice%"=="3" set DNS4_1=127.0.0.1 & set DNS4_2=77.88.8.8 & set DNS6_1=::1 & set DNS6_2=2a02:6b8::feed:0ff & goto apply_dns_only
if "%dns_choice%"=="4" set DNS4_1=127.0.0.1 & set DNS4_2=94.140.14.14 & set DNS6_1=::1 & set DNS6_2=2a10:50c0::ad1:ff & goto apply_dns_only
if "%dns_choice%"=="5" goto remove_dns_only

echo   [91mНеверный выбор![0m
pause
goto dns_menu

:apply_dns_only
cls
echo [90m =============================================[0m
echo [93m           Применение DNS настроек[0m
echo [90m =============================================[0m
echo.
echo   [93mУстанавливаются DNS сервера:[0m
echo     IPv4: %DNS4_1% / %DNS4_2%
echo     IPv6: %DNS6_1% / %DNS6_2%
echo.

call :apply_dns "%DNS4_1%" "%DNS4_2%" "%DNS6_1%" "%DNS6_2%"

echo.
echo [90m =============================================[0m
echo [92mНастройка DNS выполнена![0m
echo [90m =============================================[0m
echo.
echo  [90m========================== [93mНажмите [94mENTER[0m
pause > nul
goto menu

:remove_dns_only
cls
echo [90m =============================================[0m
echo [93m           Сброс DNS настроек[0m
echo [90m =============================================[0m
echo.
echo   [93mСброс DNS на автоматический режим (DHCP)...[0m
call :remove_dns
echo.
echo [90m =============================================[0m
echo [92mСброс DNS выполнен![0m
echo [90m =============================================[0m
echo.
echo  [90m========================== [93mНажмите [94mENTER[0m
pause > nul
goto menu

:stop_and_delete_service
:: Остановка и удаление службы
echo   [93mОстановка и удаление службы...[0m
taskkill /f /im AdGuardHome.exe >nul 2>&1
net stop %SRVCNAME% > nul 2>&1
sc delete %SRVCNAME% > nul 2>&1
timeout /t 2 /nobreak >nul
exit /b

:create_service
:: Создание и запуск службы
echo   [93mСоздание службы...[0m
sc create "%SRVCNAME%" binPath= "cmd.exe /k start \"\" \"%SRVCDIR%\"" DisplayName= "%SRVCNAME%" start= auto type= own >nul 2>&1
if %errorlevel% neq 0 (
    echo   [91mОшибка при создании службы![0m
    exit /b 1
)

sc description %SRVCNAME% "%SRVCDESC%" >nul 2>&1
sc failure "%SRVCNAME%" reset= 30 actions= restart/1000/restart/1000/restart/1000 >nul 2>&1
echo   [92mСлужба создана[0m

echo   [93mЗапуск службы...[0m
start /B sc start %SRVCNAME% >nul 2>&1

sc query %SRVCNAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo   [92mСлужба запущена[0m
) else (
    echo   [91mОшибка при запуске службы![0m
    echo   [93mЗапускаем AdGuardHome вручную...[0m
    start "" %SRVCDIR%
)
exit /b 0

:install
mode con cols=85 lines=30
cls
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process -Verb RunAs -FilePath '%0' -ArgumentList 'am_admin'" > nul
    exit
)

echo [90m =============================================[0m
echo [93m           Установка службы %SRVCNAME%[0m
echo [90m =============================================[0m
echo.

:: Копирование YAML файла в папку lib
if not exist "lib\AdGuardHome.yaml" (
    if exist "AdGuardHome.yaml" (
        copy "AdGuardHome.yaml" "lib\AdGuardHome.yaml" >nul
        echo   [94mСкопирован существующий файл в lib\[0m
    )
)

:: Если служба уже установлена - удаляем её
sc query %SRVCNAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo   [93mСлужба уже установлена. Переустановка...[0m
    call :stop_and_delete_service
    echo   [92mСлужба удалена[0m
    echo.
)

:: Создание и запуск службы
call :create_service
if %errorlevel% neq 0 (
    pause
    exit /b 1
)
echo.

:: Создание ярлыков
echo   [93mСоздание ярлыков...[0m
call :create_shortcuts
echo   [92mЯрлыки созданы[0m
echo.

:install_complete
echo.
echo [90m =============================================[0m
echo [92mУстановка успешно завершена![0m
echo [90m =============================================[0m
echo.

:: Открытие веб-интерфейса
echo   [93mОткрытие веб-интерфейса...[0m
timeout /t 2 /nobreak >nul
start http://localhost:!CURRENT_PORT!
echo   [92mВеб-интерфейс доступен: http://localhost:!CURRENT_PORT![0m
echo.
echo  [90m========================== [93mНажмите [94mENTER[0m
pause > nul
goto menu

:apply_dns
:: Применение настроек DNS (скопировано из dns.bat)
set DNS4_1=%~1
set DNS4_2=%~2
set DNS6_1=%~3
set DNS6_2=%~4

echo   [93mПоиск активных адаптеров...[0m
echo.

set adapter_count=0

:: Используем PowerShell для получения списка адаптеров (как в dns.bat)
for /f "usebackq tokens=*" %%a in (`powershell -Command "& {Get-NetAdapter -Physical | Where-Object {$_.Status -eq 'Up'} | Select-Object -ExpandProperty Name}"`) do (
    set /a adapter_count+=1
    echo   [96m[!adapter_count!] Настройка адаптера: %%a[0m
    
    :: Очищаем существующие DNS серверы
    netsh interface ipv4 delete dns name="%%a" all >nul 2>&1
    netsh interface ipv6 delete dns name="%%a" all >nul 2>&1
    
    :: Устанавливаем IPv4 DNS
    netsh interface ipv4 set dns name="%%a" source=static addr=%DNS4_1% register=primary validate=no >nul
    if not "%DNS4_2%"=="" netsh interface ipv4 add dns name="%%a" addr=%DNS4_2% index=2 validate=no >nul
    
    :: Устанавливаем IPv6 DNS
    netsh interface ipv6 set dns name="%%a" source=static addr=%DNS6_1% register=primary validate=no >nul
    if not "%DNS6_2%"=="" netsh interface ipv6 add dns name="%%a" addr=%DNS6_2% index=2 validate=no >nul
    
    echo     [92m[ГОТОВО][0m
    echo.
)

if %adapter_count%==0 (
    echo   [91mВНИМАНИЕ: Не найдено ни одного активного адаптера![0m
    echo   [93mПроверьте подключение или запустите от имени администратора.[0m
) else (
    echo   [92mНастройка завершена. Обработано адаптеров: %adapter_count%[0m
    echo.
    echo   [96mТекущие настройки DNS по всем адаптерам:[0m
    echo.
    powershell -Command "& {Get-DnsClientServerAddress | Where-Object {$_.AddressFamily -in ('IPv4','IPv6') -and $_.ServerAddresses -ne $null} | Format-Table -Property InterfaceAlias, AddressFamily, ServerAddresses -AutoSize}"
)
exit /b

:create_shortcuts
:: Создание ярлыков через PowerShell
set WEB_URL=http://localhost:!CURRENT_PORT!
set SHORTCUT_NAME=AdGuardHome
set "ICON_ABS=%~dp0lib\favicon.ico"

:: Экранирование для PowerShell
set "ICON_ABS_PS=%ICON_ABS:\=\\%"

:: Проверка наличия иконки
if exist "%ICON_ABS%" (
    set HAS_ICON=1
    echo   [92m[+] Иконка найдена: %ICON_ABS%[0m
) else (
    set HAS_ICON=0
    echo   [93m[!] Внимание: файл иконки не найден: %ICON_ABS%[0m
    echo   [93m[!] Будут созданы ярлыки без иконки.[0m
)

:: Ярлык на рабочем столе
powershell -Command ^
    "$WshShell = New-Object -ComObject WScript.Shell; " ^
    "$Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\%SHORTCUT_NAME%.lnk'); " ^
    "$Shortcut.TargetPath = '%WEB_URL%'; " ^
    "$Shortcut.Save(); " ^
    "if (%HAS_ICON%) { " ^
    "    $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\%SHORTCUT_NAME%.lnk'); " ^
    "    $Shortcut.IconLocation = '%ICON_ABS_PS%'; " ^
    "    $Shortcut.Save(); " ^
    "}"

:: Ярлык в папке со скриптом
powershell -Command ^
    "$WshShell = New-Object -ComObject WScript.Shell; " ^
    "$Shortcut = $WshShell.CreateShortcut('%~dp0%SHORTCUT_NAME%.lnk'); " ^
    "$Shortcut.TargetPath = '%WEB_URL%'; " ^
    "$Shortcut.Save(); " ^
    "if (%HAS_ICON%) { " ^
    "    $Shortcut = $WshShell.CreateShortcut('%~dp0%SHORTCUT_NAME%.lnk'); " ^
    "    $Shortcut.IconLocation = '%ICON_ABS_PS%'; " ^
    "    $Shortcut.Save(); " ^
    "}"

:: Ярлык в меню Пуск
powershell -Command ^
    "$WshShell = New-Object -ComObject WScript.Shell; " ^
    "$Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\%SHORTCUT_NAME%.lnk'); " ^
    "$Shortcut.TargetPath = '%WEB_URL%'; " ^
    "$Shortcut.Save(); " ^
    "if (%HAS_ICON%) { " ^
    "    $Shortcut = $WshShell.CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\%SHORTCUT_NAME%.lnk'); " ^
    "    $Shortcut.IconLocation = '%ICON_ABS_PS%'; " ^
    "    $Shortcut.Save(); " ^
    "}"

exit /b

:delete_shortcuts
:: Удаление ярлыков
set SHORTCUT_NAME=AdGuardHome

del /f /q "%USERPROFILE%\Desktop\%SHORTCUT_NAME%.lnk" 2>nul
del /f /q "%USERPROFILE%\Desktop\%SHORTCUT_NAME%.url" 2>nul
del /f /q "%~dp0%SHORTCUT_NAME%.lnk" 2>nul
del /f /q "%~dp0%SHORTCUT_NAME%.url" 2>nul
del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\%SHORTCUT_NAME%.lnk" 2>nul
del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\%SHORTCUT_NAME%.url" 2>nul

exit /b

:uninstall_menu
mode con cols=85 lines=20
cls
echo [90m =============================================[0m
echo [93m           Удаление службы %SRVCNAME%[0m
echo [90m =============================================[0m
echo.
echo   Что делать с настройками DNS?
echo.
echo   [93m1[0m - [91mУдалить DNS настройки[0m (автоматический DHCP)
echo   [93m2[0m - [92mСохранить текущие DNS настройки[0m
echo   [93m0[0m - Отмена
echo.
set /p dns_choice=[96m  Выбор: [93m

if "%dns_choice%"=="0" goto menu
if "%dns_choice%"=="1" set REMOVE_DNS=1
if "%dns_choice%"=="2" set REMOVE_DNS=0
if not defined REMOVE_DNS goto uninstall_menu

goto uninstall

:uninstall
mode con cols=85 lines=20
cls
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process -Verb RunAs -FilePath '%0' -ArgumentList 'am_admin'" > nul
    exit
)

echo [90m =============================================[0m
echo [93m           Удаление службы %SRVCNAME%[0m
echo [90m =============================================[0m
echo.

:: Удаление ярлыков
echo   [93mУдаление ярлыков...[0m
call :delete_shortcuts
echo   [92mЯрлыки удалены[0m
echo.

:: Удаление службы
sc query %SRVCNAME% >nul 2>&1
if %errorlevel% equ 0 (
    call :stop_and_delete_service
    echo   [92mСлужба удалена[0m
) else (
    echo   [91mСлужба не найдена[0m
)

:: Сброс DNS если нужно
if "%REMOVE_DNS%"=="1" (
    echo.
    echo   [93mСброс DNS настроек...[0m
    call :remove_dns
) else (
    echo.
    echo   [92mDNS настройки сохранены[0m
)

echo.
echo [90m =============================================[0m
echo [92mУдаление успешно завершено![0m
echo [90m =============================================[0m
echo.
echo  [90m========================== [93mНажмите [94mENTER[0m
pause > nul
goto menu

:remove_dns
:: Сброс DNS на автоматический режим (DHCP)
set adapter_count=0

for /f "usebackq tokens=*" %%a in (`powershell -Command "Get-NetAdapter -Physical | Where-Object {$_.Status -eq 'Up'} | Select-Object -ExpandProperty Name"`) do (
    set /a adapter_count+=1
    echo     [96mСброс DNS на адаптере: %%a[0m
    netsh interface ipv4 set dns name="%%a" source=dhcp >nul 2>&1
    netsh interface ipv6 set dns name="%%a" source=dhcp >nul 2>&1
)

if %adapter_count%==0 (
    echo   [91mАктивных сетевых интерфейсов не найдено![0m
) else (
    echo   [92mDNS сброшен на %adapter_count% адаптерах (автоматический DHCP)[0m
)
exit /b

:change_port
mode con cols=85 lines=25
cls
echo [90m =============================================[0m
echo [93m           Изменение HTTP порта[0m
echo [90m =============================================[0m
echo.

set YAML_FILE=lib\AdGuardHome.yaml
if not exist "lib\AdGuardHome.yaml" (
    if exist "AdGuardHome.yaml" (
        set YAML_FILE=AdGuardHome.yaml
    ) else (
        echo   [91mОшибка: конфигурационный файл не найден![0m
        echo.
        echo  [90m========================== [93mНажмите [94mENTER[0m
        pause > nul
        goto menu
    )
)

echo   Текущий порт: [91m!CURRENT_PORT![0m
echo.
set /p NEW_PORT=[96m  Введите новый порт (Enter - отмена): [93m

if "%NEW_PORT%"=="" (
    echo   [93mИзменение отменено[0m
    echo.
    echo  [90m========================== [93mНажмите [94mENTER[0m
    pause > nul
    goto menu
)

:: Проверка на число
set "check="
for /f "delims=0123456789" %%i in ("%NEW_PORT%") do set check=%%i
if defined check (
    echo   [91mОшибка: порт должен содержать только цифры![0m
    echo.
    echo  [90m========================== [93mНажмите [94mENTER[0m
    pause > nul
    goto change_port
)

:: Проверка, установлена ли служба
set SERVICE_WAS_INSTALLED=0
sc query %SRVCNAME% >nul 2>&1
if %errorlevel% equ 0 set SERVICE_WAS_INSTALLED=1

:: Если служба установлена - удаляем её
if !SERVICE_WAS_INSTALLED! equ 1 (
    echo   [93mСлужба установлена. Остановка и удаление службы...[0m
    call :stop_and_delete_service
    echo   [92mСлужба удалена[0m
    echo.
)

:: Обновление порта в YAML
set TEMP_FILE=%YAML_FILE%.tmp
(
    for /f "usebackq delims=" %%a in ("%YAML_FILE%") do (
        set "line=%%a"
        echo !line! | findstr /b /c:"  address:" >nul
        if !errorlevel! equ 0 (
            echo   address: 0.0.0.0:%NEW_PORT%
        ) else (
            echo !line!
        )
    )
) > "%TEMP_FILE%"
move /y "%TEMP_FILE%" "%YAML_FILE%" >nul

if "%YAML_FILE%"=="AdGuardHome.yaml" (
    if exist "lib" (
        copy "%YAML_FILE%" "lib\AdGuardHome.yaml" >nul
    )
)

echo   [92mПорт изменен с !CURRENT_PORT! на %NEW_PORT%[0m
echo.
set CURRENT_PORT=%NEW_PORT%

:: Обновление ярлыков под новый порт
echo   [93mОбновление ярлыков...[0m
call :delete_shortcuts
call :create_shortcuts
echo   [92mЯрлыки обновлены с новым портом[0m
echo.

:: Если служба была установлена - переустанавливаем её
if !SERVICE_WAS_INSTALLED! equ 1 (
    echo   [93mЖдем 3 секунды перед переустановкой службы...[0m
    timeout /t 3 /nobreak >nul
    echo   [93mПереустановка службы...[0m
    call :create_service
    echo   [92mСлужба переустановлена[0m
) else (
    echo   [93mСлужба не была установлена, переустановка не требуется[0m
)

echo.
echo  [90m========================== [93mНажмите [94mENTER[0m
pause > nul
goto menu