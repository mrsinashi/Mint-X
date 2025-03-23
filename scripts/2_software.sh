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
    transmission*
    rhythmbox*
    webapp-manager
    thingy
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
    polybar
    alacritty
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
