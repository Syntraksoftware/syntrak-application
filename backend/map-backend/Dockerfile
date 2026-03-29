# syntax=docker/dockerfile:1.7
FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt ./requirements-shared.txt
COPY map-backend/requirements.txt ./requirements-service.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements-shared.txt && \
    pip install --no-cache-dir -r requirements-service.txt

# Copy application and shared code
COPY map-backend/ ./
COPY shared/ ./shared/

RUN useradd --create-home --shell /usr/sbin/nologin appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5200

# Run the application
CMD ["python", "run.py"]