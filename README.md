# Linux Server Administration Lab

Небольшая лабораторная работа по администрированию Debian в VMware. Я настроил виртуальную машину как простой сервер: пользователи, SSH, firewall, Nginx, мониторинг и резервные копии.

## Что есть на сервере

```text
ПК → SSH по ключу → Debian VM
                     ├─ Nginx: статический сайт
                     ├─ UFW: SSH, HTTP, HTTPS, WireGuard
                     ├─ systemd: проверка состояния сервера
                     └─ cron: ежедневный backup
```

## Что находится в репозитории

| Папка / файл | Что это |
| --- | --- |
| `scripts/` | скрипты для пользователей, мониторинга, backup и сбора логов |
| `ssh/` | настройки безопасного SSH |
| `nginx/` | конфиг сайта Nginx |
| `systemd/` | service и timer мониторинга |
| `cron/` | расписание backup |
| `website/` | простая HTML-страница |
| `docs/logs/` | вывод команд с сервера |
| `docs/screenshots/` | скриншоты проверок |

## Пользователи

| Пользователь | Группа | Права |
| --- | --- | --- |
| `admin` | `admins` | может использовать `sudo` |
| `operator` | `operators` | может смотреть и перезапускать Nginx, смотреть логи |
| `developer` | `developers` | не имеет `sudo` |

Для каждого пользователя создан отдельный каталог:

```text
/srv/admin
/srv/operator
/srv/developer
```

Права на эти каталоги — `770`: посторонние пользователи их не читают.

## SSH

SSH работает на порту `2222`.

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers admin operator developer
```

Подключение администратора:

```bash
ssh -i ~/.ssh/linux-server-lab-admin -p 2222 admin@SERVER_IP
```

Перед изменением SSH нужно оставить открытой консоль VMware. Сначала проверить командой `sudo sshd -t`, затем открыть второе SSH-подключение по ключу. Только после успешной проверки отключать пароль.

## Firewall

Включён UFW. Входящие подключения разрешены только для:

```text
2222/tcp  SSH
80/tcp    HTTP
443/tcp   HTTPS
51820/udp WireGuard
```

Проверка:

```bash
sudo ufw status numbered
sudo ss -tulpn
```

Настройка UFW:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 51820/udp
sudo ufw enable
```

## Nginx и сайт

Nginx отдаёт статический сайт из папки `/var/www/site`.

```bash
sudo nginx -t
curl --noproxy '*' http://127.0.0.1/
```

## Мониторинг

Скрипт `server-monitor.sh` проверяет CPU, RAM, диск, Nginx, SSH и Docker.

Пример результата:

```yaml
CPU: OK
RAM: OK
DISK: OK
NGINX: OK
SSH: OK
DOCKER: OK
```

Мониторинг запускается через `server-monitor.timer` каждые 5 минут. Лог: `/var/log/linux-server-lab/monitor.log`.

## Backup и cron

Скрипт `backup.sh` сохраняет `/etc/nginx` и `/var/www/site` в архив `.tar.gz`.

- имя архива содержит дату;
- проверяется, что архив не повреждён;
- по умолчанию хранится 7 последних копий;
- лог пишется в `/var/log/linux-server-lab/backup.log`;
- если произошла ошибка, скрипт завершается с кодом ошибки.

Запуск вручную:

```bash
sudo /usr/local/sbin/backup.sh
```

Cron запускает backup каждый день в 02:30.

## Как установить заново

Команды выполняются в Debian под пользователем с `sudo`.

```bash
sudo apt update
sudo apt install -y nginx ufw docker.io tar cron procps curl

sudo install -m 0755 scripts/provision-users.sh /usr/local/sbin/provision-users.sh
sudo install -m 0755 scripts/backup.sh /usr/local/sbin/backup.sh
sudo install -m 0755 scripts/server-monitor.sh /usr/local/bin/server-monitor.sh
sudo /usr/local/sbin/provision-users.sh

sudo install -d -m 0755 /var/www/site
sudo install -m 0644 website/index.html /var/www/site/index.html
sudo install -m 0644 nginx/site.conf /etc/nginx/sites-available/linux-server-lab
sudo ln -sfn /etc/nginx/sites-available/linux-server-lab /etc/nginx/sites-enabled/linux-server-lab
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable --now nginx

sudo install -m 0644 systemd/server-monitor.service /etc/systemd/system/
sudo install -m 0644 systemd/server-monitor.timer /etc/systemd/system/
sudo install -d -m 0750 /var/log/linux-server-lab /var/backups/linux-server-lab
sudo systemctl daemon-reload
sudo systemctl enable --now server-monitor.timer
sudo systemctl start server-monitor.service

sudo crontab cron/backup.cron
sudo systemctl enable --now cron
```

SSH-настройку из `ssh/99-linux-server-lab.conf` нужно устанавливать отдельно и только после добавления публичного ключа для `admin`.

## Проверки и скриншоты

В папке `docs/logs` лежит реальный вывод команд с настроенной VM. В `docs/screenshots` — скриншоты этого вывода.

| Что проверялось | Лог | Скриншот |
| --- | --- | --- |
| Пользователи и права | [лог](docs/logs/01-users-and-access.log) | [скриншот](docs/screenshots/01-users-access.png) |
| Настройки SSH | [лог](docs/logs/02-ssh-policy.log) | [скриншот](docs/screenshots/02-ssh-hardening.png) |
| Вход `admin` по ключу | [лог](docs/logs/02-ssh-key-login.log) | [скриншот](docs/screenshots/02-ssh-key-login.png) |
| Firewall и открытые порты | [лог](docs/logs/03-firewall-and-ports.log) | [скриншот](docs/screenshots/03-firewall-ports.png) |
| Nginx и сайт | [лог](docs/logs/04-nginx.log) | [скриншот](docs/screenshots/04-nginx-http.png) |
| Мониторинг | [лог](docs/logs/05-monitoring.log) | [скриншот](docs/screenshots/05-monitoring.png) |
| Backup и cron | [лог](docs/logs/06-backup-and-cron.log) | [скриншот](docs/screenshots/06-backup-cron.png) |

## Если что-то не работает

| Проблема | Что проверить |
| --- | --- |
| Не подключается SSH | `sudo systemctl status ssh`, `sudo ufw status numbered`, порт `2222` |
| Nginx не открывается | `sudo nginx -t`, `sudo systemctl status nginx` |
| Не работает мониторинг | `sudo systemctl status server-monitor.service`, `sudo tail /var/log/linux-server-lab/monitor.log` |
| Не создаётся backup | `sudo tail /var/log/linux-server-lab/backup.log`, свободное место через `df -h` |
| Не запускается cron | `sudo systemctl status cron`, `sudo crontab -l` |

## Важно

В GitHub не нужно добавлять приватные ключи, пароли, токены и файлы с секретами. Файл `admin-access.key` уже исключён через `.gitignore`.
