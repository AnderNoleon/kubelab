# nginx sin privilegios de root, escucha en el puerto 8080
FROM nginxinc/nginx-unprivileged:1.29-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
# Escribe el hash del commit en la página para ver qué versión está desplegada
ARG VERSION=dev
USER root
RUN sed -i "s/__VERSION__/${VERSION}/g" /usr/share/nginx/html/index.html
USER 101
EXPOSE 8080
