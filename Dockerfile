# ==============================================================================
# Viewfinder Lite - Container Image
# ==============================================================================
# A streamlined Digital Sovereignty Readiness Assessment tool
# Based on the official PHP 8.3 + Apache Docker Hub image
#
# Features:
# - 21 questions across 7 critical domains
# - 4-level maturity assessment (Foundation, Developing, Strategic, Advanced)
# - PDF report generation
# - Progress auto-save
#
# Build: docker build -t viewfinder-lite:latest .
# Run:   docker run -d -p 8080:80 --name viewfinder-lite viewfinder-lite:latest
# Open:  http://localhost:8080
# ==============================================================================

FROM php:8.3-apache

# ------------------------------------------------------------------------------
# Metadata
# ------------------------------------------------------------------------------
LABEL maintainer="Chris Jenkins <chrisj@redhat.com>" \
      name="viewfinder-lite" \
      version="1.0.0" \
      description="Viewfinder Lite - Digital Sovereignty Readiness Assessment" \
      summary="Lightweight assessment tool for evaluating digital sovereignty posture across 7 domains"

# ------------------------------------------------------------------------------
# PHP Extensions & System Dependencies
# ------------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libzip-dev \
        libonig-dev \
        unzip \
        curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd mbstring \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# Apache Configuration
# ------------------------------------------------------------------------------
# Enable required modules: mod_headers (security headers) + mod_rewrite (.htaccess)
RUN a2enmod headers rewrite

# Security headers and token suppression
RUN echo 'ServerTokens Prod' >> /etc/apache2/apache2.conf \
    && echo 'ServerSignature Off' >> /etc/apache2/apache2.conf \
    && printf '<IfModule mod_headers.c>\n  Header always set X-Content-Type-Options "nosniff"\n  Header always set X-Frame-Options "SAMEORIGIN"\n  Header always set X-XSS-Protection "1; mode=block"\n  Header always set Referrer-Policy "strict-origin-when-cross-origin"\n</IfModule>\n' \
       >> /etc/apache2/apache2.conf

# ------------------------------------------------------------------------------
# Composer Installation
# ------------------------------------------------------------------------------
RUN curl -sS https://getcomposer.org/installer | php -- \
        --install-dir=/usr/local/bin --filename=composer \
    && chmod +x /usr/local/bin/composer

# ------------------------------------------------------------------------------
# PHP Dependencies
# ------------------------------------------------------------------------------
WORKDIR /var/www/html

# Copy composer files first for better Docker layer caching
COPY composer.json composer.lock* ./

RUN composer install \
        --no-dev \
        --no-interaction \
        --prefer-dist \
        --optimize-autoloader \
        --no-scripts \
        --no-progress \
    && composer clear-cache

# ------------------------------------------------------------------------------
# Application Files
# ------------------------------------------------------------------------------
COPY index.php ./
COPY includes/ ./includes/
COPY ds-qualifier/ ./ds-qualifier/
COPY error-pages/ ./error-pages/
COPY css/ ./css/
COPY images/ ./images/
COPY README.md ./

# ------------------------------------------------------------------------------
# Directory Structure & Permissions
# ------------------------------------------------------------------------------
RUN mkdir -p /var/www/html/logs && chmod 775 /var/www/html/logs

# ------------------------------------------------------------------------------
# Runtime Configuration
# ------------------------------------------------------------------------------
EXPOSE 80

# Health check - verify application is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# CMD inherited from php:8.3-apache: apache2-foreground
