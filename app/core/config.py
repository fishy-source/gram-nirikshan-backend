"""
Application configuration using Pydantic BaseSettings.
All settings can be overridden via environment variables or .env file.
"""
from pydantic_settings import BaseSettings
from typing import List, Optional
from urllib.parse import quote_plus
import secrets


class Settings(BaseSettings):
    # App Settings
    APP_NAME: str = "Gram Nirikshan API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    SECRET_KEY: str = secrets.token_urlsafe(32)
    API_PREFIX: str = "/api/v1"

    # CORS
    ALLOWED_ORIGINS: List[str] = ["*"]

    # Database
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_NAME: str = "gram_nirikshan"
    DB_USER: str = "root"
    DB_PASSWORD: str = "password"

    @property
    def DATABASE_URL(self) -> str:
        import os
        host = os.getenv("DB_HOST") or os.getenv("MYSQLHOST") or self.DB_HOST
        try:
            port = int(os.getenv("DB_PORT") or os.getenv("MYSQLPORT") or self.DB_PORT)
        except ValueError:
            port = 3306
        name = os.getenv("DB_NAME") or os.getenv("MYSQLDATABASE") or self.DB_NAME
        user = os.getenv("DB_USER") or os.getenv("MYSQLUSER") or self.DB_USER
        password = os.getenv("DB_PASSWORD") or os.getenv("MYSQLPASSWORD") or self.DB_PASSWORD

        encoded_password = quote_plus(password)
        return f"mysql+aiomysql://{user}:{encoded_password}@{host}:{port}/{name}"

    # JWT
    JWT_SECRET_KEY: str = secrets.token_urlsafe(32)
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # OTP Settings
    OTP_EXPIRE_MINUTES: int = 10
    OTP_LENGTH: int = 6
    SMS_API_KEY: str = ""          # MSG91 API Key
    SMS_SENDER_ID: str = "GRNKSH"  # MSG91 Sender ID

    # File Upload
    UPLOAD_DIR: str = "uploads"
    MAX_FILE_SIZE_MB: int = 10
    ALLOWED_IMAGE_TYPES: List[str] = ["image/jpeg", "image/png", "image/webp"]
    ALLOWED_DOC_TYPES: List[str] = ["application/pdf", "application/vnd.ms-excel",
                                     "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]

    # Google Maps
    GOOGLE_MAPS_API_KEY: str = ""

    # Gemini AI
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash"

    # Firebase (Push Notifications)
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None

    # Email Settings
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = "noreply@gramnirikshan.in"
    SMTP_FROM_NAME: str = "Gram Nirikshan App"

    # Report Settings
    REPORT_LOGO_PATH: str = "assets/logo.png"
    DEPARTMENT_NAME: str = "ग्राम पंचायत विभाग"
    DEPARTMENT_NAME_EN: str = "Gram Panchayat Department"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


settings = Settings()
