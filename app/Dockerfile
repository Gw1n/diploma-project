FROM python:3.9-alpine

ENV PYTHONUNBUFFERED 1

# Установка системных зависимостей
RUN apk add --update --no-cache postgresql-client jpeg-dev
RUN apk add --update --no-cache --virtual .tmp-build-deps \
    gcc libc-dev linux-headers postgresql-dev musl-dev zlib zlib-dev

WORKDIR /app

# 1. Сначала копируем только requirements
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN apk del .tmp-build-deps

# 2. Копируем entrypoint
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# 3. Копируем содержимое ВНУТРЕННЕЙ папки app в текущую папку (/app)
COPY app/ .

# Создаем пользователя
RUN adduser -D user
RUN chown -R user:user /app
USER user

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]