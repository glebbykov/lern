1. Выводит количество файлов в текущей дирректории
```bash
ls -1 | wc -l
```
2. Выводит количество строк во всех .sh файлах
```bash
cat *.sh 2>/dev/null | wc -l
```
3. Выводит количество файлов с расширением .sh
```bash
ls -1 *.sh 2>/dev/null | wc -l
```
Аргумент -1 в команде ls выводит каждый элемент на отдельной строке

4. Выводит общий размер всех файлов в текущей директории
```
du -ch . | grep "total" | awk '{print $1}'
```