#!/bin/bash
echo "Скрипт для оптимизации TCP (+BBR) и UDP на Linux сервере от IT Freedom Project (https://www.youtube.com/@it-freedom-project), (https://github.com/IT-Freedom-Project/Youtube)"
echo "Версия: Расширенная с systemd лимитами и CPU governor"

# Функция для удаления всех существующих строк с параметрами в файле /etc/security/limits.conf
remove_existing_settings() {
    local file="$1"
    shift
    for setting in "$@"; do
        sudo sed -i "/^$setting/d" "$file"
    done
}

# Функция для безопасного добавления настроек в файл /etc/sysctl.conf, если они еще не существуют
add_or_update_setting() {
    local file="$1"
    local setting="$2"
    local key=$(echo "$setting" | cut -d '=' -f 1) # Извлекаем ключ из настройки
    local value=$(echo "$setting" | cut -d '=' -f 2-)

    # Проверяем, существует ли ключ в файле
    if grep -qE "^$key\s*=" "$file"; then
        # Обновляем значение, если ключ найден
        sudo sed -i "s/^$key\s*=.*/$setting/" "$file"
        echo "Обновлено: $key"
    else
        # Добавляем настройку, если ключ не существует
        echo "$setting" | sudo tee -a "$file"
        echo "Добавлено: $setting"
    fi
}

echo "========================================="
echo "1. Обновление /etc/security/limits.conf..."
echo "========================================="

# Удаляем все существующие строки с параметрами
remove_existing_settings /etc/security/limits.conf "* soft nofile" "* hard nofile" "root soft nofile" "root hard nofile" \
    "* soft nproc" "* hard nproc" "* soft stack" "* hard stack" "* soft memlock" "* hard memlock" \
    "* soft msgqueue" "* hard msgqueue" "* soft sigpending" "* hard sigpending" "* soft cpu" "* hard cpu" \
    "* soft core" "* hard core" "* soft data" "* hard data" "* soft fsize" "* hard fsize"

# Устанавливаем глобальные лимиты для всех пользователей
add_or_update_setting /etc/security/limits.conf "* soft nofile 1048576"
add_or_update_setting /etc/security/limits.conf "* hard nofile 1048576"
add_or_update_setting /etc/security/limits.conf "root soft nofile 1048576"
add_or_update_setting /etc/security/limits.conf "root hard nofile 1048576"
add_or_update_setting /etc/security/limits.conf "* soft nproc unlimited"
add_or_update_setting /etc/security/limits.conf "* hard nproc unlimited"
add_or_update_setting /etc/security/limits.conf "* soft stack unlimited"
add_or_update_setting /etc/security/limits.conf "* hard stack unlimited"
add_or_update_setting /etc/security/limits.conf "* soft memlock unlimited"
add_or_update_setting /etc/security/limits.conf "* hard memlock unlimited"
add_or_update_setting /etc/security/limits.conf "* soft msgqueue unlimited"
add_or_update_setting /etc/security/limits.conf "* hard msgqueue unlimited"
add_or_update_setting /etc/security/limits.conf "* soft sigpending unlimited"
add_or_update_setting /etc/security/limits.conf "* hard sigpending unlimited"
add_or_update_setting /etc/security/limits.conf "* soft cpu unlimited"
add_or_update_setting /etc/security/limits.conf "* hard cpu unlimited"
add_or_update_setting /etc/security/limits.conf "* soft core unlimited"
add_or_update_setting /etc/security/limits.conf "* hard core unlimited"
add_or_update_setting /etc/security/limits.conf "* soft data unlimited"
add_or_update_setting /etc/security/limits.conf "* hard data unlimited"
add_or_update_setting /etc/security/limits.conf "* soft fsize unlimited"
add_or_update_setting /etc/security/limits.conf "* hard fsize unlimited"

echo "========================================="
echo "2. Настройка systemd лимитов..."
echo "========================================="

# Создаем директорию для systemd конфигурации если её нет
sudo mkdir -p /etc/systemd/system.conf.d/
sudo mkdir -p /etc/systemd/user.conf.d/

# Создаем файл с глобальными лимитами для systemd
cat << EOF | sudo tee /etc/systemd/system.conf.d/10-limits.conf
[Manager]
DefaultLimitNOFILE=1048576:1048576
DefaultLimitNPROC=infinity
DefaultLimitSTACK=infinity
DefaultLimitMEMLOCK=infinity
DefaultLimitSIGPENDING=infinity
DefaultLimitMSGQUEUE=infinity
DefaultLimitCPU=infinity
DefaultLimitCORE=infinity
DefaultLimitDATA=infinity
DefaultLimitFSIZE=infinity
DefaultLimitAS=infinity
DefaultTasksMax=infinity
EOF

# Копируем те же настройки для user сессий
sudo cp /etc/systemd/system.conf.d/10-limits.conf /etc/systemd/user.conf.d/10-limits.conf

echo "Перезагрузка systemd конфигурации..."
sudo systemctl daemon-reload

echo "========================================="
echo "3. Применение ulimit лимитов для текущей сессии..."
echo "========================================="

ulimit -u unlimited    # Максимальное количество процессов
ulimit -n 1048576      # Максимальное количество открытых файлов
ulimit -s unlimited    # Размер стека
ulimit -l unlimited    # Максимальный размер заблокированной памяти
ulimit -i unlimited    # Максимальное количество ожидающих сигналов
ulimit -q unlimited    # Максимальный размер очереди сообщений POSIX
ulimit -v unlimited    # Максимальный размер виртуальной памяти
ulimit -m unlimited    # Максимальный размер резидентной памяти
ulimit -x unlimited    # Максимальное количество блокировок файлов
ulimit -c unlimited    # Максимальный размер файла core dump
ulimit -d unlimited    # Максимальный размер сегмента данных процесса
ulimit -f unlimited    # Максимальный размер файлов, создаваемых процессом

echo "Текущие лимиты ulimit:"
ulimit -a

echo "========================================="
echo "4. Добавление настроек TCP и UDP в /etc/sysctl.conf..."
echo "========================================="

settings=(
    "fs.file-max = 50000000"                    # Увеличен максимум открытых файлов для всей системы (10M)
    "fs.nr_open = 4194304"                      # Увеличен максимум открытых файлов
    "net.core.rmem_max = 134217728"             # Увеличен буфер приема до 128MB
    "net.core.wmem_max = 134217728"             # Увеличен буфер отправки до 128MB
    "net.core.netdev_max_backlog = 500000"       # Увеличена очередь интерфейса
    "net.core.somaxconn = 1048576"                # Максимальный лимит очереди запросов
    "net.core.default_qdisc = fq"               # Планировщик очереди по умолчанию
    "net.ipv4.tcp_syncookies = 1"               # Защита от SYN flood атак
    "net.ipv4.tcp_tw_reuse = 1"                 # Повторное использование TIME-WAIT сокетов
    "net.ipv4.tcp_fin_timeout = 15"             # Уменьшен таймаут для закрытия соединения
    "net.ipv4.tcp_keepalive_time = 600"         # Время до начала отправки keepalive пакетов
    "net.ipv4.tcp_keepalive_probes = 3"         # Количество keepalive проб
    "net.ipv4.tcp_keepalive_intvl = 15"         # Интервал между keepalive пробами
    "net.ipv4.tcp_max_syn_backlog = 1048576"      # Увеличена очередь на установление соединений
    "net.ipv4.ip_local_port_range = 1024 65535" # Максимальный диапазон портов
    "net.ipv4.tcp_slow_start_after_idle = 0"    # Отключен slow start после idle
    "net.ipv4.tcp_max_tw_buckets = 2000000"     # Увеличено количество TIME-WAIT сокетов (2M)
    "net.ipv4.tcp_fastopen = 3"                 # TCP Fast Open для клиента и сервера
    "net.ipv4.udp_mem = 102400 204800 409600"   # Увеличены параметры памяти UDP
    "net.ipv4.tcp_mem = 102400 204800 409600"   # Увеличены параметры памяти TCP
    "net.ipv4.tcp_rmem = 4096 131072 134217728" # Буфер приема TCP: мин., дефолт, макс (128MB)
    "net.ipv4.tcp_wmem = 4096 131072 134217728" # Буфер отправки TCP: мин., дефолт, макс (128MB)
    "net.ipv4.tcp_mtu_probing = 1"              # Пробирование MTU
    "net.ipv4.tcp_congestion_control = bbr"     # BBR алгоритм контроля конгестии
    "net.ipv4.tcp_notsent_lowat = 16384"        # Порог для неотправленных байтов
    "net.ipv4.tcp_retries2 = 8"                 # Количество попыток ретрансляции
    "net.ipv6.conf.all.disable_ipv6 = 0"        # IPv6 включен
    "net.ipv6.conf.default.disable_ipv6 = 0"    # IPv6 включен по умолчанию
    "net.netfilter.nf_conntrack_max = 1048576"  # Лимит подключений
)

for setting in "${settings[@]}"; do
    add_or_update_setting /etc/sysctl.conf "$setting"
done

echo "Применение sysctl изменений..."
sudo sysctl -p

echo "========================================="
echo "5. Настройка CPU Governor на производительность..."
echo "========================================="

# Проверяем доступность cpufreq
if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
    # Устанавливаем governor в performance для всех CPU
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$cpu" ]; then
            echo "performance" | sudo tee $cpu > /dev/null
            echo "CPU $(basename $(dirname $cpu)) установлен в режим performance"
        fi
    done
    
    # Делаем настройку постоянной через cpufrequtils (если установлен)
    if command -v cpufreq-set &> /dev/null; then
        for i in $(seq 0 $(($(nproc)-1))); do
            sudo cpufreq-set -c $i -g performance
        done
    fi
    
    # Альтернативный метод через tuned (если установлен)
    if command -v tuned-adm &> /dev/null; then
        sudo tuned-adm profile latency-performance
        echo "Tuned профиль установлен в latency-performance"
    fi
else
    echo "CPU frequency scaling не доступен на этой системе"
fi

echo "========================================="
echo "6. Настройка профиля /etc/profile для постоянных ulimit..."
echo "========================================="

# Создаем файл с ulimit настройками для всех пользователей
cat << 'EOF' | sudo tee /etc/profile.d/ulimits.sh
#!/bin/bash
# Глобальные ulimit настройки

ulimit -u unlimited 2>/dev/null || true
ulimit -n 1048576 2>/dev/null || true
ulimit -s unlimited 2>/dev/null || true
ulimit -l unlimited 2>/dev/null || true
ulimit -i unlimited 2>/dev/null || true
ulimit -q unlimited 2>/dev/null || true
ulimit -v unlimited 2>/dev/null || true
ulimit -m unlimited 2>/dev/null || true
ulimit -x unlimited 2>/dev/null || true
ulimit -c unlimited 2>/dev/null || true
ulimit -d unlimited 2>/dev/null || true
ulimit -f unlimited 2>/dev/null || true
EOF

sudo chmod +x /etc/profile.d/ulimits.sh

echo "========================================="
echo "7. Проверка модуля tcp_bbr..."
echo "========================================="

# Проверка и загрузка модуля tcp_bbr
if ! lsmod | grep -q tcp_bbr; then
    sudo modprobe tcp_bbr
    echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/bbr.conf
    echo "Модуль tcp_bbr загружен и добавлен в автозагрузку"
else
    echo "Модуль tcp_bbr уже загружен"
fi

echo "========================================="
echo "Оптимизация завершена!"
echo "========================================="
echo ""
echo "Применены следующие изменения:"
echo "✓ Установлены расширенные лимиты в /etc/security/limits.conf"
echo "✓ Настроены глобальные systemd лимиты (DefaultLimitNOFILE=1048576)"
echo "✓ Применены ulimit настройки для текущей сессии"
echo "✓ Оптимизированы TCP/UDP параметры в sysctl"
echo "✓ CPU Governor установлен в режим performance"
echo "✓ Создан профиль для постоянных ulimit настроек"
echo "✓ Проверен и загружен модуль tcp_bbr"
echo ""
echo "Сервер будет перезагружен через 10 секунд для применения всех изменений..."
echo "Нажмите Ctrl+C для отмены перезагрузки"
sleep 10
sudo reboot
