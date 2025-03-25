#!/bin/bash

export DISPLAY=:0

# Завершаем текущие экземпляры polybar
killall -q polybar

# Ждем, пока процессы будут убиты
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Запускаем Polybar, используя конфигурацию по умолчанию
polybar main 2>&1 | tee -a /tmp/polybar.log & disown
#polybar timebar 2>&1 | tee -a /tmp/polybar.log & disown
#polybar datebar 2>&1 | tee -a /tmp/polybar.log & disown

echo "Polybar запущен..."
