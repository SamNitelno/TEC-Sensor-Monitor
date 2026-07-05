from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "development"
    database_url: str
    jwt_secret: str
    jwt_expire_minutes: int = 720
    admin_login: str
    admin_password: str
    api_public_base_url: str = "http://localhost:8000"
    device_ingest_base_url: str = ""
    viewer_login: str = "viewer"
    viewer_password: str
    allow_public_registration: bool = True
    sensor_offline_threshold_seconds: int = 15
    sensor_offline_check_interval_seconds: int = 5
    downtime_worker_interval_seconds: int = 30
    downtime_smoothing_samples: int = 3
    default_idle_power_threshold_w: float = 50.0
    default_idle_current_threshold_a: float = 0.5
    default_idle_duration_seconds: int = 60
    verification_code_ttl_minutes: int = 10
    verification_max_attempts: int = 5
    verification_smtp_host: str = "smtp.gmail.com"
    verification_smtp_port: int = 587
    verification_smtp_user: str = ""
    verification_smtp_password: str = ""
    verification_sms_api_id: str = ""
    verification_sms_from: str = ""
    verification_delivery_mode: str = "log"
    cors_origins: str = ""
    log_level: str = "INFO"
    json_logs: bool = True
    ingest_rate_limit: str = "120/minute"
    auth_login_rate_limit: str = "10/minute"
    auth_register_rate_limit: str = "5/minute"
    auth_verify_rate_limit: str = "10/minute"
    ingest_max_batch_size: int = 100
    ingest_max_current_a: float = 1000.0
    ingest_min_current_a: float = 0.0
    ingest_max_power_w: float = 1_000_000.0
    ingest_min_power_w: float = 0.0
    mqtt_enabled: bool = False
    mqtt_host: str = "mosquitto"
    mqtt_port: int = 1883
    mqtt_username: str = ""
    mqtt_password: str = ""
    timescale_retention_days: int = 365
    timescale_compress_after_days: int = 7

    # Derived from DATABASE_URL for prod guard
    postgres_password: str = ""

    @model_validator(mode="after")
    def _derive_postgres_password(self) -> "Settings":
        if not self.postgres_password and self.database_url:
            try:
                # postgresql+asyncpg://user:pass@host:port/db
                userinfo = self.database_url.split("@", 1)[0]
                if "://" in userinfo:
                    userinfo = userinfo.split("://", 1)[1]
                if ":" in userinfo:
                    self.postgres_password = userinfo.split(":", 1)[1]
            except (IndexError, ValueError):
                pass
        return self

    @field_validator("cors_origins")
    @classmethod
    def _strip_cors(cls, value: str) -> str:
        return value.strip()

    @property
    def is_production(self) -> bool:
        return self.app_env.strip().lower() == "production"

    @property
    def cors_origin_list(self) -> list[str]:
        if self.is_production:
            if not self.cors_origins:
                return []
            return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]
        if not self.cors_origins:
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def resolved_device_ingest_base_url(self) -> str:
        if self.device_ingest_base_url.strip():
            return self.device_ingest_base_url.rstrip("/")
        public = self.api_public_base_url.rstrip("/")
        if public.startswith("https://"):
            return "http://" + public[len("https://") :]
        if public.startswith("http://"):
            return public
        return f"http://{public}"


settings = Settings()
