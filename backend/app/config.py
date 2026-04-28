import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict
from dotenv import load_dotenv # Import load_dotenv


# Determine absolute path to .env (backend root)
ENV_FILE_PATH = Path(__file__).resolve().parent.parent / ".env"

# Explicitly load environment variables from the .env file into os.environ
load_dotenv(dotenv_path=ENV_FILE_PATH)

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    debug: bool = False
    
    smtp_server: str 
    smtp_port: int 
    smtp_user: str
    smtp_password: str

    # Twilio SMS Gateway Settings
    twilio_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone: str = ""

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE_PATH),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False
    )

try:
    settings = Settings()
except Exception as e:
    print(f"--- CRITICAL CONFIG ERROR ---")
    print(f"Failed to load settings. Error: {e}")
    print(f"Current OS Environment SMTP_USER: '{os.getenv('SMTP_USER', 'NOT IN OS ENV')}'")
    print(f"-----------------------------")
    # Re-raise to prevent the app from starting with invalid config
    raise e
