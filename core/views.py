from django.shortcuts import render

def home(request):
    context = {
        "tayyib_tags": ["Django", "Flutter", "PostgreSQL", "Groq AI", "AWS EC2/RDS", "Terraform", "GitHub Actions"],
        "tayyib_app_tags": ["Flutter", "Dart", "Provider", "JWT", "Barcode Scanner", "Groq Vision", "REST API"],
        "varoq_tags": ["Django", "DRF", "PostgreSQL", "Docker", "Telegram Bot", "JWT", "AWS"],
        "skills": {
            "Cloud & DevOps": ["AWS", "Docker", "Kubernetes", "Jenkins", "GitHub Actions"],
            "Backend": ["Python", "Django", "DRF", "PostgreSQL", "REST APIs", "JWT"],
            "IaC & Automation": ["Terraform", "Kubespray", "RBAC", "Bash"],
            "OS & Tools": ["Linux (Ubuntu/RHEL)", "Git", "Flutter"],
        },
    }
    return render(request, "core/home.html", context)