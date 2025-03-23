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

# Функция для вывода предупреждений
warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Функция для создания резервных копий
function backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # Определяем директорию для резервных копий
        local backup_dir
        if [ -d "/distr/backups" ]; then
            backup_dir="/distr/backups"
        else
            backup_dir="$(dirname "${SCRIPT_DIR}")/backups"
            # Создаем директорию, если она не существует
            mkdir -p "$backup_dir"
        fi

        local backup_path="${backup_dir}/$(basename "$file").bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup_path"
        chmod 775 $backup_path
        chown $SUDO_USER:users $backup_path
        success "Создана резервная копия: $backup_path"
        return 0
    else
        warning "Файл $file не существует, резервная копия не создана"
        return 1
    fi
}

# Проверка прав суперпользователя
if [ "$(id -u)" -ne 0 ]; then
    error "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# 1. Отключение служб ufw и cups-browsed
info "Отключение служб..."
systemctl stop ufw
systemctl disable ufw
systemctl stop cups-browsed
systemctl disable cups-browsed
success "Службы ufw и cups-browsed отключены"

echo ""

# Настройка алиасов
info "Настройка алиасов..."
BASH_ALIASES_FILE="/home/$SUDO_USER/.bash_aliases"
backup_file "$BASH_ALIASES_FILE"

# Функция для проверки наличия алиаса в файле
check_alias_exists() {
    local alias_name="$1"
    if grep -q "^alias $alias_name=" "$BASH_ALIASES_FILE" 2>/dev/null; then
        return 0  # Алиас существует
    else
        return 1  # Алиас не существует
    fi
}

# Добавление алиасов с проверкой
add_alias_if_not_exists() {
    local alias_name="$1"
    local alias_value="$2"

    if ! check_alias_exists "$alias_name"; then
        echo "alias $alias_name='$alias_value'" >> "$BASH_ALIASES_FILE"
        info "Добавлен алиас: $alias_name"
    else
        info "Алиас $alias_name уже существует"
    fi
}

# Добавление алиасов
add_alias_if_not_exists "hgrep" "history | grep"
add_alias_if_not_exists "hl" "history | less"
add_alias_if_not_exists "clip" "xclip -sel clip"

chmod 775 $BASH_ALIASES_FILE
chown $SUDO_USER:users $BASH_ALIASES_FILE

success "Алиасы настроены в $BASH_ALIASES_FILE"

# Снятие комментариев со всех алиасов в .bashrc
info "Снятие комментариев с алиасов в .bashrc..."
BASHRC_FILE="/home/$SUDO_USER/.bashrc"
backup_file "$BASHRC_FILE"

if [ -f "$BASHRC_FILE" ]; then
    # Разкомментируем строки с алиасами, сохраняя пробелы в начале строки
    sed -i 's/^\([[:space:]]*\)#[[:space:]]*alias/\1alias/' "$BASHRC_FILE"
    success "Комментарии с алиасов в .bashrc удалены"
else
    error "Файл $BASHRC_FILE не найден"
fi

# 4. Изменение значений HISTSIZE и HISTFILESIZE в .bashrc
info "Настройка истории команд..."
if [ -f "$BASHRC_FILE" ]; then
    # Проверяем, существуют ли параметры
    if grep -q "^HISTSIZE=" "$BASHRC_FILE"; then
        # Заменяем существующее значение
        sed -i 's/^HISTSIZE=.*/HISTSIZE=10000/' "$BASHRC_FILE"
    else
        # Добавляем новый параметр
        echo "HISTSIZE=10000" >> "$BASHRC_FILE"
    fi

    if grep -q "^HISTFILESIZE=" "$BASHRC_FILE"; then
        # Заменяем существующее значение
        sed -i 's/^HISTFILESIZE=.*/HISTFILESIZE=20000/' "$BASHRC_FILE"
    else
        # Добавляем новый параметр
        echo "HISTFILESIZE=20000" >> "$BASHRC_FILE"
    fi

    success "Значения HISTSIZE и HISTFILESIZE обновлены"
else
    error "Файл $BASHRC_FILE не найден"
fi

# 5. Добавление строк в .bashrc с проверкой каждой строки
info "Добавление настроек истории в .bashrc..."
if [ -f "$BASHRC_FILE" ]; then
    # Проверяем и обновляем HISTTIMEFORMAT
    if grep -q "^export HISTTIMEFORMAT=" "$BASHRC_FILE"; then
        sed -i 's/^export HISTTIMEFORMAT=.*/export HISTTIMEFORMAT='\''|%m.%d.%Y %H:%M:%S| '\''/' "$BASHRC_FILE"
    else
        echo "export HISTTIMEFORMAT='|%m.%d.%Y %H:%M:%S| '" >> "$BASHRC_FILE"
    fi

    # Проверяем и обновляем PROMPT_COMMAND
    if grep -q "^export PROMPT_COMMAND=" "$BASHRC_FILE"; then
        sed -i 's/^export PROMPT_COMMAND=.*/export PROMPT_COMMAND='\''history -a'\''/' "$BASHRC_FILE"
    else
        echo "export PROMPT_COMMAND='history -a'" >> "$BASHRC_FILE"
    fi

    # Проверяем и обновляем HISTIGNORE
    if grep -q "^export HISTIGNORE=" "$BASHRC_FILE"; then
        sed -i 's/^export HISTIGNORE=.*/export HISTIGNORE='\''history | hgrep | hl'\''/' "$BASHRC_FILE"
    else
        echo "export HISTIGNORE='history | hgrep | hl'" >> "$BASHRC_FILE"
    fi

    success "Настройки истории обновлены в .bashrc"
else
    error "Файл $BASHRC_FILE не найден"
fi

echo ""

# 6. Создание структуры каталогов
info "Создание структуры каталогов..."
mkdir -p /distr/progs
mkdir -p /distr/drivers
mkdir -p /distr/config
mkdir -p /distr/temp
mkdir -p /distr/backups
chmod 775 -R /distr
chown $SUDO_USER:users -R /distr
success "Структура каталогов создана и настроена"

echo ""

# 7. Настройка /etc/chrony/chrony.conf
info "Настройка NTP-сервера..."
CHRONY_CONF="/etc/chrony/chrony.conf"

if [ -f "$CHRONY_CONF" ]; then
    # Создаем резервную копию
    backup_file "$CHRONY_CONF"

    # Запрашиваем адрес NTP-сервера
    read -p "Введите адрес NTP сервера [ntp1.vniiftri.ru]: " NTP_SERVER
    NTP_SERVER=${NTP_SERVER:-ntp1.vniiftri.ru}

    # Проверяем наличие строк server или pool
    if grep -q "^server\|^pool" "$CHRONY_CONF"; then
        # Сохраняем номер первой строки с server или pool
        FIRST_LINE=$(grep -n "^server\|^pool" "$CHRONY_CONF" | head -1 | cut -d: -f1)

        # Удаляем все строки server и pool
        sed -i '/^server\|^pool/d' "$CHRONY_CONF"

        # Вставляем новую строку на место первой удаленной
        sed -i "${FIRST_LINE}i server $NTP_SERVER iburst minpoll 8 maxpoll 12" "$CHRONY_CONF"
    else
        # Если нет строк server или pool, просто добавляем новую
        echo "server $NTP_SERVER iburst minpoll 8 maxpoll 12" >> "$CHRONY_CONF"
    fi

    # Перезапускаем службу chrony
    systemctl restart chronyd
    success "NTP-сервер настроен: $NTP_SERVER"
else
    error "Файл $CHRONY_CONF не найден"
fi

echo ""

success "Все настройки успешно применены!"
