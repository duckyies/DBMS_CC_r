FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install dependencies first (layer caching)
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy source (app/ and db/schema.sql + db/seed.sql)
COPY . .

# Run as an unprivileged user
RUN useradd --system --no-create-home appuser
USER appuser

EXPOSE 3001

# The app creates any missing tables and loads the demo data itself on startup (see app/db.py)
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-3001}"]
