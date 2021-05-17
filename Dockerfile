FROM nginx:1.20-alpine

RUN apk add bash docker jq

ADD entrypoint.sh /docker-service-index-entrypoint.sh

CMD ["/docker-service-index-entrypoint.sh"]
