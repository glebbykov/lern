#!/bin/bash

# Проверяем, существует ли файл с директориями
if [ ! -f "line_count.list" ]; then
    echo "Файл line_count.list не найден."
    exit 1
fi

# Читаем файл line_count.list построчно и обрабатываем каждую директорию
while IFS= read -r dir; do
    # Проверяем, существует ли директория
    if [ ! -d "$dir" ]; then
        echo "Директория $dir не существует."
        continue
    fi

    # Подсчитываем количество строк во всех файлах, включая скрытые, содержащих указанную часть имени
    line_count=$(cat "$dir"/.*"$1"* "$dir"/*"$1"* 2>/dev/null | wc -l)
    
    # Если нужно подсчитывать файлы только на одном уровне директории
    # line_count=$(find "$dir" -maxdepth 1 -type f \( -name ".*$1*" -o -name "*$1*" \) -exec cat {} + 2>/dev/null | wc -l)

    echo "Общее количество строк во всех файлах в директории $dir, содержащих '$1' в имени (включая скрытые файлы): $line_count"

done < "line_count.list"
