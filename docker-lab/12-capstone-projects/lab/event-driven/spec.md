# Capstone: Event-driven

## ТЗ
Соберите producer/consumer pipeline с брокером сообщений.

## Acceptance criteria
- Producer публикует сообщения.
- Consumer обрабатывает и логирует результат.
- Есть retry и dead-letter стратегия.
- Есть метрики и диагностика отказов.

## Типовые баги для тренировки
- Дубли из-за at-least-once.
- Потеря сообщений при рестарте.
- Рост очереди без алертов.
