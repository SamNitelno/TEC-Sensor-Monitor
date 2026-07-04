from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str
    jwt_secret: str
    jwt_expire_minutes: int = 1440
    admin_login: str
    admin_password: str
    api_public_base_url: str = "http://localhost:8000"
    viewer_login: str = "viewer"
    viewer_password: str = "viewer"
    sensor_offline_threshold_seconds: int = 15
    downtime_worker_interval_seconds: int = 30
    default_idle_power_threshold_w: float = 50.0
    default_idle_current_threshold_a: float = 0.5
    default_idle_duration_seconds: int = 60
    downtime_smoothing_samples: int = 5


settings = Settings()
