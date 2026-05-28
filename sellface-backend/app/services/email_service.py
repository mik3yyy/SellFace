"""
Simple email alert service using Gmail SMTP.

Required env vars (set in Render dashboard):
  SMTP_FROM_EMAIL  — the Gmail address you send from (e.g. yourname@gmail.com)
  SMTP_PASSWORD    — a Gmail App Password (not your login password)
                     Create one at: https://myaccount.google.com/apppasswords
                     (requires 2-Step Verification to be enabled on the account)
"""
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

logger = logging.getLogger(__name__)


def send_low_balance_alert(balance: float, threshold: float) -> None:
    from app.config import get_settings
    settings = get_settings()

    if not settings.smtp_configured:
        logger.warning("SMTP not configured — skipping low balance alert (set SMTP_FROM_EMAIL + SMTP_PASSWORD)")
        return

    subject = f"⚠️ SellFace — Astria AI credits low ({balance:.0f} remaining)"
    body = f"""\
Your Astria AI credit balance is running low.

Current balance : {balance:.0f} credits
Alert threshold : {threshold:.0f} credits

Generation jobs will start failing once credits reach zero.

Top up here: https://www.astria.ai/users/edit

— SellFace automated alert
"""
    _send(settings.alert_email, subject, body)


def send_job_failed_alert(job_id: str, persona_name: str, error: str) -> None:
    from app.config import get_settings
    settings = get_settings()

    if not settings.smtp_configured:
        return

    subject = f"❌ SellFace — Generation job failed ({persona_name})"
    body = f"""\
A generation job has failed and may need manual attention.

Job ID      : {job_id}
Person      : {persona_name}
Error       : {error}

Retry it in the admin dashboard:
https://sellface.onrender.com/admin#jobs

— SellFace automated alert
"""
    _send(settings.alert_email, subject, body)


def _send(to: str, subject: str, body: str) -> None:
    from app.config import get_settings
    settings = get_settings()

    try:
        msg = MIMEMultipart()
        msg["From"] = settings.smtp_from_email
        msg["To"] = to
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain"))

        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as server:
            server.ehlo()
            server.starttls()
            server.login(settings.smtp_from_email, settings.smtp_password)
            server.sendmail(settings.smtp_from_email, to, msg.as_string())

        logger.info("Alert email sent to %s: %s", to, subject)
    except Exception as e:
        logger.error("Failed to send alert email to %s: %s", to, e)
