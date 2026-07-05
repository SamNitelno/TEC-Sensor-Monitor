from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str
    jwt_secret: str
    jwt_expire_minutes: int = 1440
    admin_login: str
    admin_password: str
    api_public_base_url: str = "http://localhost:8000"
    # ESP/firmware ingest URL (HTTP, no TLS). Empty = derive from api_public_base_url (https→http).
    device_ingest_base_url: str = ""
    viewer_login: str = "viewer"
    viewer_password: str = "viewer"
    sensor_offline_threshold_seconds: int = 15
    sensor_offline_check_interval_seconds: int = 5
    downtime_worker_interval_seconds: int = 30
    downtime_smoothing_samples: int = 3
    default_idle_power_threshold_w: float = 50.0
    default_idle_current_threshold_a: float = 0.5
    default_idle_duration_seconds: int = 60
    verification_code_ttl_minutes: int = 10
    verification_smtp_host: str = "smtp.gmail.com"
    verification_smtp_port: int = 587
    verification_smtp_user: str = "semenigolnikov@gmail.com"
    verification_smtp_password: str = ""
    verification_sms_api_id: str = ""
    verification_sms_from: str = "79135466546"
    verification_delivery_mode: str = "log"

    # CORS (comma-separated origins; empty = allow all for dev)
    cors_origins: str = ""

    # Structured logging
    log_level: str = "INFO"
    json_logs: bool = True

    # Rate limiting
    ingest_rate_limit: str = "120/minute"

    # Ingest validation
    ingest_max_batch_size: int = 100
    ingest_max_current_a: float = 1000.0
    ingest_min_current_a: float = 0.0
    ingest_max_power_w: float = 1_000_000.0
    ingest_min_power_w: float = 0.0

    # MQTT (optional)
    mqtt_enabled: bool = False
    mqtt_host: str = "mosquitto"
    mqtt_port: int = 1883
    mqtt_username: str = ""
    mqtt_password: str = ""

    # TimescaleDB policies (applied via migration; documented here)
    timescale_retention_days: int = 365
    timescale_compress_after_days: int = 7

    @field_validator("cors_origins")
    @classmethod
    def _strip_cors(cls, value: str) -> str:
        return value.strip()

    @property
    def cors_origin_list(self) -> list[str]:
        if not self.cors_origins:
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def resolved_device_ingest_base_url(self) -> str:
        """Base URL for ESP HTTP ingest (plain HTTP, port 80 in prod)."""
        if self.device_ingest_base_url.strip():
            return self.device_ingest_base_url.rstrip("/")
        public = self.api_public_base_url.rstrip("/")
        if public.startswith("https://"):
            return "http://" + public[len("https://") :]
        if public.startswith("http://"):
            return public
        return f"http://{public}"


settings = Settings()
