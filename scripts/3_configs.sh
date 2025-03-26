#!/bin/bash

# Определение цветов для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Получаем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="${SCRIPT_DIR}/../configs"
BACKUP_DIR="$(dirname "${SCRIPT_DIR}")/backups"

# Функции для вывода
function info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

function success() {
    echo -e "${GREEN}[ OK ]${NC} $1"
}

function error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Создаем директорию для резервных копий
mkdir -p "$BACKUP_DIR"

# Определяем домашнюю директорию пользователя
if [ "$SUDO_USER" ]; then
    USER_HOME="/home/$SUDO_USER"
else
    USER_HOME="$HOME"
fi

# Проверка наличия директории с конфигурациями
if [ ! -d "$CONFIGS_DIR" ]; then
    error "Директория с конфигурациями не найдена: $CONFIGS_DIR"
    exit 1
fi

# Создаем карту соответствия исходных директорий и целевых путей
declare -A CONFIG_MAPPING
CONFIG_MAPPING["$CONFIGS_DIR/.config"]="$USER_HOME/.config"
CONFIG_MAPPING["$CONFIGS_DIR/.local"]="$USER_HOME/.local"
CONFIG_MAPPING["$CONFIGS_DIR/home"]="$USER_HOME"
CONFIG_MAPPING["$CONFIGS_DIR/etc"]="/etc"

# Функция для рекурсивного копирования конфигурационных файлов
function copy_config_dir() {
    local src_dir="$1"
    local dest_dir="$2"

    # Проверяем существование исходной директории
    if [ ! -d "$src_dir" ]; then
        warning "Исходная директория $src_dir не найдена, пропускаем"
        return 0
    fi

    # Проверяем, есть ли файлы для копирования
    if [ -z "$(ls -A "$src_dir")" ]; then
        warning "Директория $src_dir пуста, пропускаем"
        return 0
    fi

    # Создаем директорию назначения, если она не существует
    mkdir -p "$dest_dir"

    # Копируем содержимое директории
    info "Копирование конфигураций из $src_dir в $dest_dir"

    # Проверяем наличие rsync
    if command -v rsync &> /dev/null; then
        # Используем rsync для копирования с сохранением структуры
        rsync -av --backup --backup-dir="$BACKUP_DIR" "$src_dir/" "$dest_dir/" > /dev/null 2>&1
    else
        # Если rsync не установлен, используем cp
        for file in "$src_dir"/*; do
            if [ -f "$file" ]; then
                # Если файл существует в целевой директории, создаем резервную копию
                if [ -f "$dest_dir/$(basename "$file")" ]; then
                    cp "$dest_dir/$(basename "$file")" "$BACKUP_DIR/$(basename "$file").bak.$(date +%Y%m%d%H%M%S)"
                fi
                cp "$file" "$dest_dir/"
            elif [ -d "$file" ]; then
                # Рекурсивно копируем поддиректории
                copy_config_dir "$file" "$dest_dir/$(basename "$file")"
            fi
        done
    fi

    # Устанавливаем правильные права
    if [ "$SUDO_USER" ] && [[ "$dest_dir" == "$USER_HOME"* ]]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$dest_dir"
    fi

    success "Конфигурации скопированы из $src_dir в $dest_dir"
    return 0
}

info "Начинаем копирование файлов конфигураций..."

# Копируем конфигурации согласно карте соответствия
for src_dir in "${!CONFIG_MAPPING[@]}"; do
    dest_dir="${CONFIG_MAPPING[$src_dir]}"

    if [ -d "$src_dir" ]; then
        copy_config_dir "$src_dir" "$dest_dir"
    else
        warning "Директория $src_dir не существует, пропускаем"
    fi
done

# Применение конфигураций
info "Применение конфигураций..."

# Перезагрузка i3 (если запущен)
if pgrep -x "i3" > /dev/null; then
    info "Перезагрузка i3..."
    if [ "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" i3-msg reload
    else
        i3-msg reload
    fi
fi

# Перезагрузка Xresources
if [ -f "$USER_HOME/.Xresources" ]; then
    info "Применение .Xresources..."
    if [ "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" xrdb -merge "$USER_HOME/.Xresources"
    else
        xrdb -merge "$USER_HOME/.Xresources"
    fi
fi

# Функция для установки шрифтов
function install_fonts() {
    local src_dir="$CONFIGS_DIR/fonts"
    local user_font_dir="$USER_HOME/.local/share/fonts"
    local system_font_dir="/usr/local/share/fonts"

    # Проверяем существование исходной директории
    if [ ! -d "$src_dir" ]; then
        warning "Директория с шрифтами не найдена: $src_dir, пропускаем"
        return 0
    fi

    # Проверяем, есть ли файлы для копирования
    if [ -z "$(ls -A "$src_dir" 2>/dev/null)" ]; then
        warning "Директория с шрифтами пуста: $src_dir, пропускаем"
        return 0
    fi

    info "Установка шрифтов из $src_dir"

    # Создаем директорию для пользовательских шрифтов
    mkdir -p "$user_font_dir"

    # Копируем шрифты в пользовательскую директорию
    copy_config_dir "$src_dir" "$user_font_dir"

    # Обновляем кэш шрифтов
    info "Обновление кэша шрифтов..."
    if [ "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" fc-cache -f
    else
        fc-cache -f
    fi

    success "Шрифты установлены и кэш обновлен"
}

# Добавляем вызов функции установки шрифтов после копирования конфигураций
info "Начинаем копирование файлов конфигураций..."

# Копируем конфигурации согласно карте соответствия
for src_dir in "${!CONFIG_MAPPING[@]}"; do
    dest_dir="${CONFIG_MAPPING[$src_dir]}"

    if [ -d "$src_dir" ]; then
        copy_config_dir "$src_dir" "$dest_dir"
    else
        warning "Директория $src_dir не существует, пропускаем"
    fi
done

# Функция для установки разрешений на запуск скриптов .sh в директориях пользователя
function set_executable_permissions() {
    info "Установка разрешений на запуск скриптов .sh в директориях пользователя"

    # Проходим по всем целевым директориям
    for dest_dir in "${CONFIG_MAPPING[@]}"; do
        if [ -d "$dest_dir" ]; then
            # Находим все файлы с расширением .sh и устанавливаем права на выполнение
            find "$dest_dir" -type f -name "*.sh" -exec chmod +x {} \;

            # Устанавливаем правильные права владельца для файлов
            if [ "$SUDO_USER" ] && [[ "$dest_dir" == "$USER_HOME"* ]]; then
                find "$dest_dir" -type f -name "*.sh" -exec chown "$SUDO_USER:$SUDO_USER" {} \;
            fi
        fi
    done

    success "Разрешения на запуск скриптов .sh установлены"
}

# Копирование обоев
info "Копирование обоев..."

# Определяем пути к папкам
PICTURES_RU="/home/$SUDO_USER/Изображения"
WALLPAPERS_RU="$PICTURES_RU/Обои"
PICTURES_EN="/home/$SUDO_USER/Pictures"
SOURCE_DIR="configs/wallpapers"

# Проверяем существование папок и создаем нужную структуру
if [ -d "$PICTURES_RU" ]; then
    # Если есть русская папка Изображения, используем ее
    mkdir -p "$WALLPAPERS_RU"
    DESTINATION_DIR="$WALLPAPERS_RU"
else
    # Иначе используем или создаем английскую папку Pictures
    mkdir -p "$PICTURES_EN"
    DESTINATION_DIR="$PICTURES_EN"
fi

# Проверяем наличие исходной папки с обоями
if [ -d "$SOURCE_DIR" ]; then
    # Копируем файлы из исходной папки в целевую
    cp -r "$SOURCE_DIR"/* "$DESTINATION_DIR"/

    # Устанавливаем права доступа
    chmod 755 "$DESTINATION_DIR"
    find "$DESTINATION_DIR" -type d -exec chmod 755 {} \;
    find "$DESTINATION_DIR" -type f -exec chmod 644 {} \;
    chown -R $SUDO_USER:$SUDO_USER "$DESTINATION_DIR"

    success "Обои успешно скопированы в $DESTINATION_DIR"
else
    error "Исходная папка $SOURCE_DIR не найдена"
fi

# Устанавливаем шрифты
install_fonts

set_executable_permissions

success "Копирование и применение конфигураций завершено!"
