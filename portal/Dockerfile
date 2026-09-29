# Minimal static file server for the account portal. Serves this directory
# only — a separate image/container from whatever builds redmed-portal
# (tapper/'s image), per the surface-separation rule in AGENTS.md.
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY . /usr/share/nginx/html
RUN rm -f /usr/share/nginx/html/nginx.conf /usr/share/nginx/html/Dockerfile /usr/share/nginx/html/README.md
EXPOSE 80
