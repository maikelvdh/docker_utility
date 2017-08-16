FROM alpine:3.6

RUN apk add --no-cache \
    bash \
    curl \
    jq

COPY docker_image_commands.sh /usr/local/bin/docker_image_commands.sh

ENTRYPOINT ["/usr/local/bin/docker_image_commands.sh"]

