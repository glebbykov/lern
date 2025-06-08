/* simpled.c – минимальный демон
 *
 *  ▸ двойной fork() для отсоединения от терминала;
 *  ▸ umask(0)  – снимаем маску прав;
 *  ▸ stdin / stdout / stderr → /dev/null;
 *  ▸ каждые 10 с пишем текущее время (time_t) в /var/log/simpled.log.
 *
 *  Сборка:  gcc -O2 -Wall -Wextra -o simpled simpled.c
 */

#define _GNU_SOURCE
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

static const char *LOGFILE = "/var/log/simpled.log";

/* безопасная запись без буферизации */
static void log_time(void)
{
    int fd = open(LOGFILE, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd == -1) return;

    time_t now = time(NULL);
    dprintf(fd, "%ld\n", (long)now);
    close(fd);
}

int main(void)
{
    /* 1-й fork: родитель завершается, потомок → сессия */
    pid_t pid = fork();
    if (pid < 0)  exit(EXIT_FAILURE);
    if (pid > 0)  exit(EXIT_SUCCESS);        /* родитель */

    /* создать новую сессию */
    if (setsid() == -1) exit(EXIT_FAILURE);

    /* 2-й fork: гарантируем, что демон не получит TTY */
    pid = fork();
    if (pid < 0)  exit(EXIT_FAILURE);
    if (pid > 0)  exit(EXIT_SUCCESS);        /* первый потомок */

    /* базовая инициализация */
    umask(0);
    chdir("/");

    /* перенаправить стандартные дескрипторы в /dev/null */
    int nullfd = open("/dev/null", O_RDWR);
    if (nullfd != -1) {
        dup2(nullfd, STDIN_FILENO);
        dup2(nullfd, STDOUT_FILENO);
        dup2(nullfd, STDERR_FILENO);
        if (nullfd > 2) close(nullfd);
    }

    /* основной цикл */
    for (;;) {
        log_time();
        sleep(10);
    }
}
