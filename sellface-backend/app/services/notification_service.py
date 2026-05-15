"""
Push notification service — APNs HTTP/2 + JWT.

Requires APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY in .env.
If any of these are unset the service logs a warning and skips sending.

The p8 private key should be stored in .env with literal \\n between lines:
  APNS_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\\nMIGH...\\n-----END PRIVATE KEY-----
"""
import logging
import time

import httpx
import jwt

from app.config import get_settings

logger = logging.getLogger(__name__)

APNS_HOST_PROD = "https://api.push.apple.com"
APNS_HOST_SANDBOX = "https://api.sandbox.push.apple.com"

# Cache the JWT so we don't re-sign every notification (APNs tokens are valid for 1 hour)
_jwt_cache: tuple[str, float] | None = None


def _apns_jwt(settings) -> str:
    global _jwt_cache
    now = time.time()
    if _jwt_cache and now - _jwt_cache[1] < 3000:  # refresh every ~50 min
        return _jwt_cache[0]

    token = jwt.encode(
        {"iss": settings.apns_team_id, "iat": int(now)},
        settings.apns_private_key_pem,
        algorithm="ES256",
        headers={"kid": settings.apns_key_id},
    )
    _jwt_cache = (token, now)
    return token


def _send(device_tokens: list[str], payload: dict, settings) -> None:
    if not device_tokens:
        return

    if not settings.apns_configured:
        logger.warning(
            "[NOTIFICATION] APNs not configured (APNS_KEY_ID/APNS_TEAM_ID/APNS_PRIVATE_KEY missing) — skipping"
        )
        return

    host = APNS_HOST_SANDBOX if settings.apns_use_sandbox else APNS_HOST_PROD
    token = _apns_jwt(settings)

    with httpx.Client(http2=True, timeout=15) as client:
        for device_token in device_tokens:
            try:
                resp = client.post(
                    f"{host}/3/device/{device_token}",
                    headers={
                        "authorization": f"bearer {token}",
                        "apns-topic": settings.apns_bundle_id,
                        "apns-push-type": "alert",
                        "apns-priority": "10",
                    },
                    json=payload,
                )
                if resp.status_code == 200:
                    logger.info("APNs push sent → token=%s...", device_token[:8])
                else:
                    logger.warning(
                        "APNs push rejected: status=%d body=%s token=%s...",
                        resp.status_code, resp.text, device_token[:8],
                    )
            except Exception:
                logger.exception("APNs push error for token=%s...", device_token[:8])


def send_images_ready(device_tokens: list[str], persona_name: str, job_id: str) -> None:
    settings = get_settings()
    payload = {
        "aps": {
            "alert": {
                "title": "Your photos are ready!",
                "body": f"{persona_name}'s generated images are ready to view.",
            },
            "sound": "default",
            "badge": 1,
        },
        "job_id": job_id,
    }
    _send(device_tokens, payload, settings)


def send_job_failed(device_tokens: list[str], persona_name: str) -> None:
    settings = get_settings()
    payload = {
        "aps": {
            "alert": {
                "title": "Generation failed",
                "body": f"We couldn't generate {persona_name}'s images. Please try again.",
            },
            "sound": "default",
        }
    }
    _send(device_tokens, payload, settings)
