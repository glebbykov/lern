#!/bin/bash

# Проверяем, существует ли файл с директориями
if [ ! -f "line_count.list" ]; then
    echo "Файл line_count.list не найден."
    exit 1
fi

# Читаем файл line_count.list построчно и обрабатываем каждую директорию
while IFS= read -r dir; do
    # Удаляем лишние пробелы и невидимые символы в начале и в конце строки
    dir=$(echo "$dir" | tr -d '\r' | xargs)

    # Проверяем, существует ли директория
    if [ ! -d "$dir" ]; then
        echo "Директория $dir не существует."
        continue
    fi

    # Подсчитываем количество строк во всех файлах, включая скрытые, содержащих указанную часть имени
    line_count=$(cat "$dir"/.*"$1"* "$dir"/*"$1"* 2>/dev/null | wc -l)

    # Выводим результат
    echo "Общее количество строк во всех файлах в директории $dir, содержащих '$1' в имени (включая скрытые файлы): $line_count"

done < "line_count.list"
