FROM golang:1.20.5-alpine3.17

ADD . /app
WORKDIR /app

CMD ["sh"]
