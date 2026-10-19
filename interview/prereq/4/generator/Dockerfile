FROM python:3.13-alpine
RUN pip install --no-cache-dir prometheus_client==0.21.1
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY generator.py .
USER app
EXPOSE 9090
ENTRYPOINT ["python3", "generator.py"]
