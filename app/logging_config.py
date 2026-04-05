#!/usr/bin/env python3
"""
Structured JSON Logging Configuration
Incident Response Quest - Bronze: The Watchtower
Uses standard library only (no external deps)
"""

import json
import logging
import sys
from datetime import datetime, timezone


class JsonFormatter(logging.Formatter):
    """Simple JSON formatter using standard library"""
    
    def format(self, record):
        log_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "component": record.name,
            "msg": record.getMessage(),
        }
        
        # Add extra fields if available
        if hasattr(record, 'funcName'):
            log_data['function'] = record.funcName
        
        # Add any extra attributes (avoid reserved keys)
        reserved = {'name', 'msg', 'args', 'levelname', 'levelno', 
                   'pathname', 'filename', 'module', 'exc_info', 
                   'exc_text', 'stack_info', 'lineno', 'funcName', 
                   'created', 'msecs', 'relativeCreated', 'thread', 
                   'threadName', 'processName', 'process', 'message'}
        for key, value in record.__dict__.items():
            if key not in reserved:
                log_data[key] = value
        
        return json.dumps(log_data)


def setup_logging(log_level=logging.INFO):
    """Setup structured JSON logging for the application"""
    
    # Create formatter
    formatter = JsonFormatter()
    
    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    root_logger.handlers = []  # Clear existing handlers
    root_logger.addHandler(console_handler)
    
    # Set specific levels for noisy libraries
    logging.getLogger('werkzeug').setLevel(logging.WARNING)
    logging.getLogger('peewee').setLevel(logging.WARNING)
    
    return root_logger


def get_logger(name):
    """Get a structured logger instance"""
    return logging.getLogger(name)
