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
NC='\033[0m' # No Color

# ===== Создание необходимых директорий =====
mkdir -p "$BACKUPS_DIR" "$LOGS_DIR"

# ===== Вспомогательные функции =====

# Функция логирования
log() {
    local message="$1"
    echo "[$(date +%H:%M:%S)] $message" >> "$LOG_FILE"
    echo -e "$message"
}

# Функции для форматированного вывода
info() {
    log "${BLUE}[INFO]${NC} $1"
}

success() {
    log "${GREEN}[OK]${NC} $1"
}

error() {
    log "${RED}[ERROR]${NC} $1"
}

warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

# Функция для выполнения команды с выводом прогресса
execute_with_progress() {
    local cmd="$1"
    local msg="$2"
    
    echo -ne "${BLUE}[INFO]${NC} $msg... "
    log "[EXECUTING] $cmd"
    
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
        info "===== Запуск скрипта: ${RED}$(basename "$script")${NC} ====="
        if bash "$script"; then
            success "===== Скрипт ${GREEN}$(basename "$script")${NC} выполнен успешно ====="
            return 0
        else
            error "===== Ошибка при выполнении скрипта $(basename "$script") ====="
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
        "1" "Выполнить все" \
        "2" "Настройка системных параметров" \
        "3" "Установка пользовательских программ" \
        "4" "Установка рабочих программ" \
        "5" "Применение конфигураций" \
        "6" "Очистка системы" 3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        info "Отмена операции"
        return 1
    fi

    case "$CHOICE" in
        1)
            run_all
            ;;
        2)
            system_configure
            ;;
        3)
            install_user_software
            ;;
        4)
            install_work_software
            ;;
        5)
            apply_configs
            ;;
        6)
            system_cleanup
            ;;
        *)
            info "Выход из программы"
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
    run_script "$SCRIPTS_DIR/base.sh"
	echo ""
}

# Настройка системных параметров
system_configure() {
    info "[Запуск настройки системных параметров]"
    run_script "$SCRIPTS_DIR/services.sh"
	echo ""
}

# Установка пользовательских программ
install_user_software() {
    info "[Установка пользовательских программ]"
    run_script "$SCRIPTS_DIR/user_apps.sh"
	echo ""
}

# Установка рабочих программ
install_work_software() {
    info "[Установка рабочих программ]"
    run_script "$SCRIPTS_DIR/work_apps.sh"
	echo ""
}

# Применение конфигураций
apply_configs() {
    info "[Применение конфигураций]"
    run_script "$SCRIPTS_DIR/apply_configs.sh"
	echo ""
}

# Очистка системы
system_cleanup() {
    info "[Очистка системы]"
    run_script "$SCRIPTS_DIR/cleanup.sh"
	echo ""
}

# Выполнение всех шагов
run_all() {
    info "[Выполнение всех шагов установки]"
	echo ""
    system_configure
    install_user_software
    install_work_software
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
