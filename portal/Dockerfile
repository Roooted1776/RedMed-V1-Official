# Minimal static file server for the account portal. Serves this directory
# only — a separate image/container from whatever builds redmed-portal
# (tapper/'s image), per the surface-separation rule in AGENTS.md.
FROM nginx:alpine
COPY . /usr/share/nginx/html
EXPOSE 80
