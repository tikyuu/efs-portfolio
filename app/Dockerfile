FROM node:24-slim AS frontend-build

WORKDIR /frontend

COPY frontend/package.json frontend/package-lock.json ./

RUN npm ci --ignore-scripts

COPY frontend/ ./

RUN npm run build

FROM python:3.14-slim

WORKDIR /app

COPY app/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app/main.py .

COPY --from=frontend-build /frontend/dist/ /app/static/

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
