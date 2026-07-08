from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
  model_config = SettingsConfigDict(
    env_file=Path(__file__).parent.parent / ".env.local",
    env_file_encoding="utf-8",
    dotenv_filtering="only_existing")

  postgres_app_url: str


settings = Settings()
