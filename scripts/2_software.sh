#!/bin/bash

# Скрипт удаления и установки пакетов

# Определение цветов для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция для вывода информации
info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Функция для вывода успешного выполнения
success() {
    echo -e "${GREEN}[ OK ]${NC} $1"
}

# Функция для вывода ошибок
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция для вывода предупреждений
warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Функция для выполнения команды с выводом прогресса
execute_with_progress() {
    local cmd="$1"
    local msg="$2"

    echo -ne "${CYAN}[INFO]${NC} $msg... "

    # Временно сохраняем вывод в файл для диагностики
    local temp_output=$(mktemp)

    # Выполняем команду без eval
    bash -c "$cmd" > "$temp_output" 2>&1
    local status=$?

    if [ $status -eq 0 ]; then
        echo -e "${GREEN}Готово${NC}"
        rm "$temp_output"
        return 0
    else
        echo -e "${RED}Ошибка${NC}"
        # Выводим содержимое для диагностики
        cat "$temp_output"
        rm "$temp_output"
        return 1
    fi
}


# Проверка наличия прав суперпользователя
if [ "$(id -u)" -ne 0 ]; then
    error "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# Список ненужного ПО
UNWANTED_PACKAGES=(
    hypnotix
    celluloid
    drawing
    brasero-common
    gnome-calculator
    file-roller
    firefox*
    pix xviewer*
    aptdaemon*
    aptitude*
    avahi-*
    gufw
    brltty
    fprintd
    ideviceinstaller
    ifuse
    thunderbird*
    vlc*
    transmission*
    warpinator*
    xreader*
    xed*
    rhythmbox*
    webapp-manager
    thingy
    mintreport
    mintupdate
)

info "Проверка наличия нежелательных пакетов..."

# Фильтрация пакетов для удаления и вывод информации
PACKAGES_TO_REMOVE=()
NOT_INSTALLED=()

for package in "${UNWANTED_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        PACKAGES_TO_REMOVE+=("$package")
    else
        NOT_INSTALLED+=("$package")
    fi
done

# Вывод информации о пакетах, которых нет в системе
if [ ${#NOT_INSTALLED[@]} -gt 0 ]; then
    info "Следующие пакеты не установлены (пропускаем): ${NOT_INSTALLED[*]}"
fi

# Удаление отфильтрованных нежелательных пакетов
if [ ${#PACKAGES_TO_REMOVE[@]} -gt 0 ]; then
    info "Удаление следующих пакетов: ${PACKAGES_TO_REMOVE[*]}"
    execute_with_progress "apt purge -y ${PACKAGES_TO_REMOVE[*]}" "Удаление нежелательных пакетов"
else
    info "Нежелательные пакеты не обнаружены"
fi

echo ""

# Установка дополнительных пакетов
info "Установка дополнительных пакетов..."
ADD_PACKAGES=(
    i3
    polybar
    kitty
    rofi
    flameshot
    picom
    remmina
    remmina-plugin-rdp
    remmina-plugin-vnc
    feh
    dunst
    redshift
    redshift-gtk
    xdotool
    jq
    gxkb
    openvpn
    xarchiver
)

info "Проверка наличия дополнительных пакетов..."

# Фильтрация пакетов для установки и вывод информации
PACKAGES_TO_INSTALL=()
ALREADY_INSTALLED=()
NOT_AVAILABLE=()

for package in "${ADD_PACKAGES[@]}"; do
    # Проверка, установлен ли пакет
    if dpkg -l | grep -q "^ii  $package "; then
        ALREADY_INSTALLED+=("$package")
    else
        # Проверка, доступен ли пакет в репозиториях
        if apt-cache show "$package" &>/dev/null; then
            PACKAGES_TO_INSTALL+=("$package")
        else
            NOT_AVAILABLE+=("$package")
        fi
    fi
done

# Вывод информации о пакетах, которые уже установлены
if [ ${#ALREADY_INSTALLED[@]} -gt 0 ]; then
    info "Следующие пакеты уже установлены: ${ALREADY_INSTALLED[*]}"
fi

# Вывод информации о пакетах, которых нет в репозиториях
if [ ${#NOT_AVAILABLE[@]} -gt 0 ]; then
    warning "Следующие пакеты недоступны в репозиториях: ${NOT_AVAILABLE[*]}"
fi

# Установка отфильтрованных пакетов
if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    info "Установка следующих пакетов: ${PACKAGES_TO_INSTALL[*]}"
    execute_with_progress "apt install -y ${PACKAGES_TO_INSTALL[*]}" "Установка дополнительных пакетов"
else
    if [ ${#NOT_AVAILABLE[@]} -eq 0 ]; then
        info "Все базовые пакеты уже установлены"
    else
        info "Нет доступных пакетов для установки"
    fi
fi

# Установка ksuperkey для привязки клавиши Win к меню приложений
info "Установка ksuperkey..."
# Проверяем, установлен ли уже ksuperkey
if ! command -v ksuperkey &> /dev/null; then
    # Устанавливаем зависимости
    apt install -y libx11-dev libxtst-dev

    # Создаем временную директорию для сборки
    mkdir -p /distr/temp/ksuperkey
    cd /distr/temp/ksuperkey

    # Клонируем репозиторий и собираем ksuperkey
    git clone https://github.com/hanschen/ksuperkey.git .
    make
    make install
    success "ksuperkey успешно установлен"
else
    info "ksuperkey уже установлен"
fi

# Установка Google Chrome
info "Установка Google Chrome..."

# Создание директории для ключей, если она не существует
mkdir -p /etc/apt/trusted.gpg.d

# Проверка наличия ключа Google
if [ -f "/etc/apt/trusted.gpg.d/google.gpg" ]; then
    info "GPG ключ Google уже установлен, пропускаем импорт"
else
    # Скачивание и импорт ключа Google
    execute_with_progress "curl -fSsL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/trusted.gpg.d/google.gpg" "Импорт ключа Google"
    success "GPG ключ Google успешно импортирован"
fi

# Добавление репозитория Google Chrome
execute_with_progress "echo 'deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main' | tee /etc/apt/sources.list.d/google-chrome.list" "Добавление репозитория Google Chrome"

# Обновление списка пакетов
execute_with_progress "apt update" "Обновление списка пакетов"

# Установка Google Chrome
execute_with_progress "apt install -y google-chrome-stable" "Установка Google Chrome"

# Установка Visual Studio Code
info "Установка Visual Studio Code..."

# Создание директории для ключей, если она не существует
mkdir -p /etc/apt/trusted.gpg.d

# Проверка наличия ключа Microsoft
if [ -f "/etc/apt/trusted.gpg.d/microsoft.gpg" ]; then
    info "GPG ключ Microsoft уже установлен, пропускаем импорт"
else
    # Скачивание и импорт ключа Microsoft
    execute_with_progress "curl -fSsL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg" "Импорт ключа Microsoft"
    success "GPG ключ Microsoft успешно импортирован"
fi

execute_with_progress "echo 'deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main' | tee /etc/apt/sources.list.d/microsoft-vscode.list" "Добавление репозитория VS Code"

# Обновление списка пакетов
execute_with_progress "apt update" "Обновление списка пакетов"

# Проверка, установлен ли уже VS Code
if dpkg -l | grep -q "code"; then
    info "Visual Studio Code уже установлен, пропускаем установку"
else
    # Установка VS Code
    execute_with_progress "apt install -y code" "Установка Visual Studio Code"
    success "Visual Studio Code успешно установлен"
fi

# Установка Telegram с официального сайта
info "Установка Telegram..."

# Проверяем, установлен ли уже Telegram
if [ -d "/opt/telegram" ] || [ -f "/usr/bin/telegram" ]; then
    info "Telegram уже установлен"
else
    # Создаем временную директорию для загрузки
    mkdir -p /distr/temp/telegram
    cd /distr/temp/telegram

        execute_with_progress "wget -O telegram.tar.xz https://telegram.org/dl/desktop/linux" "Загрузка Telegram (64-bit)"

    # Распаковываем архив
    execute_with_progress "tar -xJf telegram.tar.xz -C /opt/" "Распаковка Telegram"

    # Переименовываем директорию для удобства
    execute_with_progress "mv /opt/Telegram* /opt/telegram" "Настройка директории Telegram"

    # Создаем символическую ссылку
    execute_with_progress "ln -sf /opt/telegram/Telegram /usr/bin/telegram" "Создание символической ссылки"

    # Создаем .desktop файл для отображения в меню приложений
    cat > /usr/share/applications/telegram.desktop << EOL
[Desktop Entry]
Name=Telegram
Comment=Official desktop version of Telegram messaging app
Exec=/usr/bin/telegram
Icon=/opt/telegram/telegram.svg
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
EOL

    success "Telegram успешно установлен"
fi

# Установка We10X-icon-theme
info "Установка We10X-icon-theme..."
# Проверяем, установлена ли уже тема
if [ -d "/usr/share/icons/We10X" ] || [ -d "/home/$SUDO_USER/.local/share/icons/We10X" ] || [ -d "/home/$SUDO_USER/.icons/We10X" ]; then
    info "We10X-icon-theme уже установлена"
else
    # Создаем временную директорию для сборки
    mkdir -p /distr/temp/we10x
    cd /distr/temp/we10x

    # Клонируем репозиторий
    git clone https://github.com/yeyushengfan258/We10X-icon-theme.git .

    # Устанавливаем тему
    chmod +x install.sh
    ./install.sh

    success "We10X-icon-theme успешно установлена"
fi

echo ""

#Очистка неиспользуемых пакетов
execute_with_progress "apt autoremove -y" "Очистка неиспользуемых пакетов"

# Очистка кэша apt
execute_with_progress "apt clean" "Очистка кэша apt"
execute_with_progress "apt autoclean" "Автоочистка apt"

# Очистка журналов
info "Очистка системных журналов..."
if command -v journalctl &> /dev/null; then
    execute_with_progress "journalctl --vacuum-time=7d" "Очистка journalctl (оставляем логи за 7 дней)"
fi

# Проверка свободного места
echo ""
info "Проверка свободного места на диске..."
info "$(df -h / | awk 'NR==2 {print "Свободно: " $4 " из " $2 " (" $5 " использовано)"}')"

echo ""
success "Удаление ненужных и установка дополнительных пакетов завершены успешно!"
