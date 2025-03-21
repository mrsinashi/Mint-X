#!/bin/bash

# Скрипт базовой настройки и обновления системы

# Определение цветов для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода информации
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Функция для вывода успешного выполнения
success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Функция для вывода ошибок
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция для вывода предупреждений
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Функция для выполнения команды с выводом прогресса
execute_with_progress() {
    local cmd="$1"
    local msg="$2"
    
    echo -ne "${BLUE}[INFO]${NC} $msg... "
    
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}Готово${NC}"
        return 0
    else
        echo -e "${RED}Ошибка${NC}"
        return 1
    fi
}

# Проверка наличия прав суперпользователя
if [ "$(id -u)" -ne 0 ]; then
    error "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# Обновление списка пакетов
info "Начинаем обновление системы..."
execute_with_progress "apt update" "Обновление списка пакетов"

# Обновление дистрибутива
execute_with_progress "apt full-upgrade -y" "Обновление дистрибутива"
echo

# Список ненужного ПО
UNWANTED_PACKAGES=(
    thunderbird*
    vlc*
    transmission*
)

# Удаление ненужных пакетов
info "Удаление ненужных пакетов..."
# Проверка и удаление пакетов
#for package in "${UNWANTED_PACKAGES[@]}"; do
#    if dpkg -l | grep -q "^ii  $package "; then
#        info "Удаление пакета $package..."
#        if apt-get remove -y "$package"; then
#            success "Пакет $package успешно удален"
#        else
#            error "Не удалось удалить пакет $package"
#        fi
#    else
#        info "Пакет $package не установлен"
#    fi
#done

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
    execute_with_progress "apt-get purge -y ${PACKAGES_TO_REMOVE[*]}" "Удаление нежелательных пакетов"
else
    info "Нежелательные пакеты не обнаружены"
fi

echo ""

# Установка базовых пакетов
info "Установка базовых пакетов..."
BASE_PACKAGES=(
    git
    curl
    wget
    htop
    unzip
    net-tools
    gnupg2
    tree
    lsof
    tmux
)

#for pkg in "${BASE_PACKAGES[@]}"; do
#    if dpkg -l | grep -q "^ii  $pkg "; then
#        info "Пакет $pkg уже установлен"
#    else
#        execute_with_progress "apt install -y $pkg" "Установка пакета $pkg"
#    fi
#done

info "Проверка наличия базовых пакетов..."

# Фильтрация пакетов для установки и вывод информации
PACKAGES_TO_INSTALL=()
ALREADY_INSTALLED=()

for package in "${BASE_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        ALREADY_INSTALLED+=("$package")
    else
        PACKAGES_TO_INSTALL+=("$package")
    fi
done

# Вывод информации о пакетах, которые уже установлены
if [ ${#ALREADY_INSTALLED[@]} -gt 0 ]; then
    info "Следующие пакеты уже установлены: ${ALREADY_INSTALLED[*]}"
fi

# Установка отфильтрованных пакетов
if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    info "Установка следующих пакетов: ${PACKAGES_TO_INSTALL[*]}"
    execute_with_progress "apt-get install -y ${PACKAGES_TO_INSTALL[*]}" "Установка базовых пакетов"
else
    info "Все базовые пакеты уже установлены"
fi

echo ""

#Очистка неиспользуемых пакетов
execute_with_progress "apt autoremove -y" "Очистка неиспользуемых пакетов"

# Очистка кэша apt
execute_with_progress "apt clean" "Очистка кэша apt"
execute_with_progress "apt autoclean" "Автоочистка apt"

# Удаление старых ядер (оставляем текущее и предыдущее)
info "Проверка наличия старых ядер..."
CURRENT_KERNEL=$(uname -r | cut -f1,2 -d"-")
OLD_KERNELS=$(dpkg -l 'linux-*' | awk '/^ii/{ print $2}' | grep -v -e "$CURRENT_KERNEL" | grep -e '[0-9]' | grep -v -e "libc")

if [ -n "$OLD_KERNELS" ]; then
    warning "Найдены старые ядра. Удаляем..."
    execute_with_progress "apt purge -y $OLD_KERNELS" "Удаление старых ядер"
else
    info "Старых ядер не обнаружено"
fi

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
success "Базовая настройка и обновление системы завершены успешно!"
