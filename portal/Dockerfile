FROM node:22-bookworm-slim
COPY server.mjs /server.mjs
COPY site /site
ENV PORT=8090
ENV STATIC_ROOT=/site
EXPOSE 8090
CMD ["node", "/server.mjs"]
