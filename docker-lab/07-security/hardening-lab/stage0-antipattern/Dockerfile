# Этап 0 — как делать НЕ надо.
#   * ubuntu:latest — «живой» тег, раздутый базовый образ.
#   * root на рантайме — никакого USER.
#   * Секрет прокинут через ENV, попадает в слой образа.
#   * apt-кеш оставлен, pip ставит «глобально».
FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    SECRET=supersecret_do_not_leak \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv curl

WORKDIR /app

COPY requirements.txt ./
RUN pip3 install --break-system-packages -r requirements.txt

COPY app.py ./

EXPOSE 8083
CMD ["python3", "app.py"]
