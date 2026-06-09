#!/bin/bash
apt-get update -y
apt-get install -y python3-pip python3-venv nginx git postgresql-client

git clone https://github.com/java-rakhmonaliev/portfolio.git /app
cd /app

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cat > /app/.env << 'EOF'
SECRET_KEY=${secret_key}
DEBUG=False
ALLOWED_HOSTS=java-rakhmonaliev.uz,www.java-rakhmonaliev.uz
DB_NAME=portfolio
DB_USER=postgres
DB_PASSWORD=${db_password}
DB_HOST=${db_host}
DB_PORT=5432
EOF

source .venv/bin/activate
python manage.py migrate
python manage.py collectstatic --noinput

tee /etc/systemd/system/portfolio.service << 'EOF'
[Unit]
Description=Portfolio Django App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/app
EnvironmentFile=/app/.env
ExecStart=/app/.venv/bin/gunicorn portfolio.wsgi:application --bind 127.0.0.1:8000 --workers 2
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable portfolio
systemctl start portfolio

tee /etc/nginx/sites-available/portfolio << 'EOF'
server {
    listen 80;
    server_name java-rakhmonaliev.uz www.java-rakhmonaliev.uz;

    location /static/ {
        alias /app/staticfiles/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

ln -s /etc/nginx/sites-available/portfolio /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
