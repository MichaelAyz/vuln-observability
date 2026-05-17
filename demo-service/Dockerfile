FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (cached layer — only invalidated when requirements change)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Runtime environment
ENV PYTHONUNBUFFERED=1
ENV FLASK_ENV=production

EXPOSE 8080

CMD ["python", "app.py"]
