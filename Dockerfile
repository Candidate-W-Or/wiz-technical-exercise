FROM nginx:alpine
RUN echo "<h1>Wiz Technical Exercise - Live Demo</h1>" > /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
