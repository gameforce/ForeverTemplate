# Landing page

Static site in `html/`, served by nginx-alpine via `docker-compose.yml` (bind-mounts `nginx.conf` and `html/` read-only, no build). `docker compose up -d` serves it on port 8085.

Local preview: `python3 -m http.server 8099 --directory html`.
