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
    sensor_offline_threshold_seconds: int = 25
    sensor_offline_check_interval_seconds: int = 5


settings = Settings()
