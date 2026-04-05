#!/usr/bin/env python3
"""
Structured JSON Logging Configuration
Incident Response Quest - Bronze: The Watchtower
"""

import json
import logging
import sys
from datetime import datetime, timezone
from pythonjsonlogger import jsonlogger


class CustomJsonFormatter(jsonlogger.JsonFormatter):
    """Custom JSON formatter for structured logging"""
    
    def add_fields(self, log_record, record, message_dict):
        super(CustomJsonFormatter, self).add_fields(log_record, record, message_dict)
        
        # Add timestamp in ISO 8601 format
        log_record['timestamp'] = datetime.now(timezone.utc).isoformat()
        
        # Add log level
        log_record['level'] = record.levelname
        
        # Add component/module
        log_record['component'] = record.name
        
        # Add function name
        if hasattr(record, 'funcName'):
            log_record['function'] = record.funcName
        
        # Add correlation ID if available (for tracing requests)
        log_record['correlation_id'] = getattr(record, 'correlation_id', 'N/A')


def setup_logging(log_level=logging.INFO):
    """Setup structured JSON logging for the application"""
    
    # Create formatter
    formatter = CustomJsonFormatter(
        '%(timestamp)s %(level)s %(component)s %(message)s'
    )
    
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
