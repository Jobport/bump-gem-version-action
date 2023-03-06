FROM ruby:3.2.1-alpine3.17 as base
RUN gem update --system 3.4.7 && \
    apk --no-cache add git jq curl
RUN gem install gem-release
COPY labels /labels
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
