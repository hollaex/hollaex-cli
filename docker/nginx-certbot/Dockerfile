FROM nginx:1.15.8-alpine
RUN apk add certbot py-pip build-base libffi-dev openssl-dev python-dev && \
    pip install certbot-nginx && \
    apk del build-base libffi-dev openssl-dev python-dev py-pip
EXPOSE 80
EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]