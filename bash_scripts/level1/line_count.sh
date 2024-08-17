#!/bin/bash

line_count=$(cat *.sh 2>/dev/null | wc -l)

echo "Общее количество строк во всех .sh файлах в текущей директории: $line_count"
