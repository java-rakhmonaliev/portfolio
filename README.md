# Portfolio — Javokhirbek Rakhmonaliev

Personal portfolio and blog built with Django, deployed on AWS EC2 with PostgreSQL on RDS.

**Live:** [java-rakhmonaliev.uz](http://java-rakhmonaliev.uz)

## Stack

- **Backend:** Django, Gunicorn
- **Database:** PostgreSQL (AWS RDS)
- **Web server:** Nginx
- **Infrastructure:** AWS EC2 + RDS + Elastic IP (Terraform)
- **CI/CD:** GitHub Actions → SSH deploy

## Project Structure

```
portfolio/          # Django project config (settings, urls, wsgi)
core/               # Main portfolio app (home page)
blog/               # Blog app (list + detail views)
templates/          # HTML templates
static/             # Static files (CSS, resume)
infra/              # Terraform infrastructure
```

## Local Setup

```bash
git clone https://github.com/java-rakhmonaliev/portfolio.git
cd portfolio

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env  # fill in your values

python manage.py migrate
python manage.py runserver
```

## Environment Variables

```env
SECRET_KEY=
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

DB_NAME=portfolio
DB_USER=postgres
DB_PASSWORD=
DB_HOST=localhost
DB_PORT=5432
```

## Infrastructure

Provisioned with Terraform in `infra/`:

- EC2 `t3.micro` (Ubuntu 22.04)
- RDS PostgreSQL `db.t3.micro`
- Elastic IP
- Security group (ports 22, 80, 443, 5432)

```bash
cd infra
terraform init
terraform apply -var="db_password=..." -var="secret_key=..."
```

## Deployment

Push to `main` triggers GitHub Actions which SSHes into EC2 and runs:

```bash
cd /app
git pull origin main
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo systemctl restart portfolio
```

Required GitHub secrets: `EC2_HOST`, `EC2_SSH_KEY`.