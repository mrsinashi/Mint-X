#!/bin/bash

# Скрипт базовой настройки и обновления системы

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

# Обновление списка пакетов
execute_with_progress "apt update" "Обновление списка пакетов"

# Обновление дистрибутива
execute_with_progress "apt full-upgrade -y" "Обновление дистрибутива"

echo ""

# Установка базовых пакетов
info "Установка базовых пакетов..."
BASE_PACKAGES=(
    git
    cmake
    pkg-config
    build-essential
    curl
    wget
    htop
    unzip
    net-tools
    gnupg2
    tree
    lsof
    apt-transport-https
    chrony
    gparted
    lshw
    inxi
    numlockx
    openssh-server
    xclip
    dconf-editor
    gpg
    util-linux
    xutils
    pkg-config
    python3
    x11-utils
    gcc
    make
)

info "Проверка наличия базовых пакетов..."

# Фильтрация пакетов для установки и вывод информации
PACKAGES_TO_INSTALL=()
ALREADY_INSTALLED=()
NOT_AVAILABLE=()

for package in "${BASE_PACKAGES[@]}"; do
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
    execute_with_progress "apt install -y ${PACKAGES_TO_INSTALL[*]}" "Установка базовых пакетов"
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

# Проверка ядер системы
info "Проверка ядер системы..."

# Флаг для контроля выполнения удаления ядер
PROCEED_WITH_KERNEL_REMOVAL=true

# Получаем текущее используемое ядро
CURRENT_KERNEL=$(uname -r)
CURRENT_KERNEL_VERSION=$(echo "$CURRENT_KERNEL" | cut -f1,2 -d"-")

# Получаем список всех установленных ядер в одинаковом формате
INSTALLED_KERNELS=$(dpkg -l 'linux-image-*-generic' | grep '^ii' | awk '{print $2}' | sed 's/linux-image-//')

# Проверяем, есть ли более новые ядра, чем текущее
NEWEST_KERNEL=$(echo "$INSTALLED_KERNELS" | sort -V | tail -n1)
CURRENT_KERNEL_CLEAN=$(echo "$CURRENT_KERNEL" | sed 's/linux-image-//')

if [ "$NEWEST_KERNEL" != "$CURRENT_KERNEL_CLEAN" ]; then
    warning "Обнаружено новое ядро ($NEWEST_KERNEL), которое еще не используется."
    warning "Текущее используемое ядро: $CURRENT_KERNEL"
    warning "Необходимо перезагрузить системуи повторно запустить ${CYAN}Setup.sh${NC} перед удалением старых ядер."
    PROCEED_WITH_KERNEL_REMOVAL=false
fi

if $PROCEED_WITH_KERNEL_REMOVAL; then
    # Формируем список ядер для удаления (исключая текущее)
    # Фильтруем только пакеты ядра (image, headers, modules)
    OLD_KERNELS=$(dpkg -l 'linux-image-*-generic' 'linux-headers-*' 'linux-modules-*' | 
                  grep '^ii' | 
                  awk '{print $2}' | 
                  grep -v "$CURRENT_KERNEL_VERSION" | 
                  grep -E 'linux-(image|headers|modules)')

    if [ -n "$OLD_KERNELS" ]; then
        warning "Найдены старые ядра для удаления:"
        echo "$OLD_KERNELS" | sed 's/^/    /'

        execute_with_progress "apt purge -y $(echo ${OLD_KERNELS[*]})" "Удаление старых ядер"

        execute_with_progress "apt autoremove -y" "Удаление зависимостей ядра"
        success "Старые ядра удалены"
    else
        info "Старых ядер для удаления не обнаружено"
    fi
else
    info "Удаление старых ядер отложено до следующей перезагрузки"
fi

echo ""

# Очистка журналов
info "Очистка системных журналов..."
if command -v journalctl &> /dev/null; then
    execute_with_progress "journalctl --vacuum-time=7d" "Очистка journalctl (оставляем логи за 7 дней)"
fi

echo ""

# Проверка свободного места
info "Проверка свободного места на диске..."
info "$(df -h / | awk 'NR==2 {print "Свободно: " $4 " из " $2 " (" $5 " использовано)"}')"

echo ""

success "Базовая настройка и обновление системы завершены успешно!"
