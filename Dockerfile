FROM python:3.13-slim

WORKDIR /app

# Install uv
RUN pip install uv

# Copy dependency file
COPY pyproject.toml ./

# Install dependencies (generate lock file if not exists)
RUN uv sync

# Copy application code
COPY app/ ./app/
COPY run.py ./
COPY init_db.py ./

# Set environment variables
ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONPATH=/app
ENV FLASK_APP=run.py

# Expose port
EXPOSE 5000

# Run with gunicorn
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "--access-logfile", "-", "--error-logfile", "-", "run:app"]
