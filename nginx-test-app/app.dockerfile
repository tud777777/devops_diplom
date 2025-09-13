FROM nginx:alpine
COPY ./nginx-test-app/index.html /usr/share/nginx/html
EXPOSE 80
