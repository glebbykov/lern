# Broken: плохой Dockerfile — без .dockerignore, от root, неправильный порядок
FROM python:3.12

WORKDIR /app

# Плохо: копирует ВСЁ, включая .git, .env, __pycache__
COPY . .

# Плохо: ПОСЛЕ COPY . . — кеш инвалидируется при любом изменении
RUN pip install -r requirements.txt

# Плохо: нет USER — запуск от root
# Плохо: нет HEALTHCHECK

CMD ["python", "app.py"]
