#!/bin/bash

# ===== Определение констант и переменных =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/configs"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
BACKUPS_DIR="$SCRIPT_DIR/backups"
LOGS_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOGS_DIR/setup_$(date +%Y%m%d_%H%M%S).log"

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===== Создание необходимых директорий =====
mkdir -p "$BACKUPS_DIR" "$LOGS_DIR"
chmod 775 $BACKUPS_DIR
chmod 775 $LOGS_DIR
chown $SUDO_USER:users -R $BACKUPS_DIR
chown $SUDO_USER:users -R $LOGS_DIR

# ===== Вспомогательные функции =====

# Функция логирования
log() {
    local message="$1"
    echo "[$(date +%H:%M:%S)] $message" >> "$LOG_FILE"
    chown 666 $LOG_FILE
    echo -e "$message"
}

# Функции для форматированного вывода
info() {
    log "${CYAN}[INFO]${NC} $1"
}

success() {
    log "${GREEN}[ OK ]${NC} $1"
}

error() {
    log "${RED}[ERROR]${NC} $1"
}

warning() {
    log "${YELLOW}[WARN]${NC} $1"
}

# Функция для выполнения команды с выводом прогресса
execute_with_progress() {
    local cmd="$1"
    local msg="$2"

    echo -ne "${CYAN}[INFO]${NC} $msg... "
    log "[EXEC] $cmd"

    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}Готово${NC}"
        return 0
    else
        echo -e "${RED}Ошибка${NC}"
        error "Команда завершилась с ошибкой. Подробности в логе: $LOG_FILE"
        return 1
    fi
}

# Функция для создания резервной копии файла
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup_path="$BACKUPS_DIR/$(basename "$file").bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup_path"
        success "Создана резервная копия: $backup_path"
    else
        warning "Файл $file не существует, резервная копия не создана"
    fi
}

# Функция проверки root-прав
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

# Функция для выполнения скрипта
run_script() {
    local script="$1"
    if [ -f "$script" ]; then
        echo ""
        info "===== Запуск скрипта: ${YELLOW}$(basename "$script")${NC} ====="
        if bash "$script"; then
            success "===== Скрипт ${GREEN}$(basename "$script")${NC} выполнен успешно ====="
            return 0
        else
            error "===== Ошибка при выполнении скрипта ${RED}$(basename "$script")${NC} ====="
            return 1
        fi
    else
        error "Скрипт $script не найден"
        return 1
    fi
}

# ===== Функция отображения меню =====
show_menu() {
    if ! command -v whiptail &> /dev/null; then
        info "Установка whiptail..."
        apt update && apt install -y whiptail
    fi

    local CHOICE=$(whiptail --title "Mint-X Setup" --menu "Выберите действие:" 20 78 12 \
        "0" "Выполнить все" \
        "1" "Настройка системных параметров" \
        "2" "Установка пользовательских программ" \
        "3" "Применение конфигураций" \
        "4" "Очистка системы" \
        "5" "Выход из программы" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        info "Отмена операции"
        return 1
    fi

    case "$CHOICE" in
        0)
            run_all
            exit 0
            ;;
        1)
            system_configure
            ;;
        2)
            install_software
            ;;
        3)
            apply_configs
            ;;
        4)
            system_cleanup
            ;;
        5)
            info "Выход из программы"
            exit 0
            ;;
        *)
            info "Отмена"
            exit 0
            ;;
    esac

    # Возврат в меню после выполнения действия
    show_menu
}

# ===== Основные функции =====

# Обновление системы и базовая настройка
system_base() {
    info "[Запуск обновления системы и базовой настройки]"
    run_script "$SCRIPTS_DIR/0_base.sh"
	echo ""
}

# Настройка системных параметров
system_configure() {
    info "[Запуск настройки системных параметров]"
    run_script "$SCRIPTS_DIR/1_system.sh"
	echo ""
}

# Установка пользовательских программ
install_software() {
    info "[Установка пользовательских программ]"
    run_script "$SCRIPTS_DIR/2_software.sh"
	echo ""
}

# Применение конфигураций
apply_configs() {
    info "[Применение конфигураций]"
    run_script "$SCRIPTS_DIR/3_configs.sh"
	echo ""
}

# Очистка системы
system_cleanup() {
    info "[Очистка системы]"
    run_script "$SCRIPTS_DIR/4_cleanup.sh"
	echo ""
}

# Выполнение всех шагов
run_all() {
    info "[Выполнение всех шагов установки]"
	echo ""
    system_configure
    install_software
    apply_configs
    system_cleanup
    success "Все шаги выполнены"
	echo ""
}

# ===== Основная логика =====
main() {
    info "Запуск ${GREEN}Mint-X${NC} Setup"
    info "Логи сохраняются в: $LOG_FILE"
	echo ""

    system_base

    # Проверка root-прав
    check_root

    # Отображение меню
    show_menu
}

# Запуск основной функции
main
