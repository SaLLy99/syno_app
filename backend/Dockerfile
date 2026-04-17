FROM python:3.11-slim

WORKDIR /app

# Install PostgreSQL client dependencies and a C compiler
# These are required to build psycopg2-binary if a wheel isn't available
# or if pip attempts a source build.
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY ./app ./app

# Copy translation files into the backend assets folder
COPY ./flutter/assets/lang ./app/assets/lang

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
