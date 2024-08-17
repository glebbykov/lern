#!/bin/bash

file_count=$(ls -1 "$1" | wc -l)

echo "Количество файлов в директории $1: $file_count"
