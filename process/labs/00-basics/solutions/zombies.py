"""
Решение задания 6: плодит 3 зомби-процесса.

Родитель делает fork() 3 раза, каждый ребёнок сразу exit().
Родитель НЕ вызывает wait() — поэтому ядро держит записи зомби,
пока родитель жив.

Наблюдение: ps aux покажет дочерние процессы в состоянии Z (zombie).
После kill PARENT → зомби усыновляет init → init вызывает wait() → они исчезают.
"""
import os
import time

for i in range(3):
    pid = os.fork()
    if pid == 0:
        os._exit(i)

print(f"Parent PID: {os.getpid()}")
print("Sleeping 60s, children are zombies now")
time.sleep(60)
