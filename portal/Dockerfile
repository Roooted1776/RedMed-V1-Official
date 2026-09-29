# Static notice only. No sign-in, no Supabase client. Separate image from
# the tapper shell, per the surface-separation rule in AGENTS.md.
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY . /usr/share/nginx/html
RUN rm -f /usr/share/nginx/html/nginx.conf /usr/share/nginx/html/Dockerfile /usr/share/nginx/html/README.md
EXPOSE 80
