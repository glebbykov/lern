#!/usr/bin/env python3
import os
import threading
import time

def consume_memory(mb, duration):
    """Занять заданное количество мегабайт памяти на заданное время"""
    a = []
    for i in range(mb):
        a.append(bytearray(1024 * 1024))  # Занимаем 1 MB в каждой итерации
    time.sleep(duration)  # Держим память занятой указанное время
    # Дополнительные операции для создания активности в swap
    for i in range(mb):
        a[i] = None  # Освобождаем память поочередно
        time.sleep(0.01)  # Небольшая пауза между освобождением

def create_threads(num_threads, mem_per_thread, duration):
    threads = []
    for i in range(num_threads):
        t = threading.Thread(target=consume_memory, args=(mem_per_thread, duration))
        t.start()
        threads.append(t)
    
    for t in threads:
        t.join()

if __name__ == "__main__":
    num_threads = 10  # Количество потоков
    mem_per_thread = 5000  # Количество мегабайт на поток (например, 5 GB)
    duration = 600  # Время в секундах, на которое будет занята память (например, 10 минут)
    
    print(f"Starting {num_threads} threads, each consuming {mem_per_thread} MB of memory for {duration} seconds")
    create_threads(num_threads, mem_per_thread, duration)
    print("Memory load complete. Press Enter to exit.")
    input()
