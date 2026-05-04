"""
Push notification service.
Currently a structured placeholder. Replace with real APNs or Firebase integration.
"""
import logging

logger = logging.getLogger(__name__)


def send_images_ready(device_tokens: list[str], persona_name: str, job_id: str) -> None:
    """
    Notify user their generated images are ready.

    TODO: Implement with APNs (aioapns / httpx + JWT) or Firebase Admin SDK.

    APNs integration sketch:
        import httpx, jwt, time
        token = jwt.encode({"iss": team_id, "iat": time.time()}, private_key, algorithm="ES256", headers={"kid": key_id})
        for device_token in device_tokens:
            httpx.post(
                f"https://api.push.apple.com/3/device/{device_token}",
                headers={"Authorization": f"bearer {token}", "apns-topic": bundle_id},
                json={"aps": {"alert": {"title": "Your photos are ready!", "body": f"{persona_name}'s images are ready to view."}, "sound": "default"}},
                http2=True,
            )
    """
    for token in device_tokens:
        logger.info(
            "[NOTIFICATION] Would send to token=%s | title='Your photos are ready!' | "
            "body='%s images are ready.' | job_id=%s",
            token[:12] + "...",
            persona_name,
            job_id,
        )


def send_job_failed(device_tokens: list[str], persona_name: str) -> None:
    for token in device_tokens:
        logger.warning(
            "[NOTIFICATION] Job failed — would notify token=%s for persona=%s",
            token[:12] + "...",
            persona_name,
        )
