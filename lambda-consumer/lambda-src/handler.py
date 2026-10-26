import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone

import boto3
import pika
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SCOPES = ["https://www.googleapis.com/auth/calendar"]
DEFAULT_TIMEZONE = "America/Sao_Paulo"
EXCHANGE = "calendar.exchange"
ROUTING_KEYS = (
    "calendar.event.create",
    "calendar.event.update",
    "calendar.event.delete",
)
MAX_RUNTIME_SECONDS = 50
MAX_MESSAGES_PER_RUN = 50

_secrets_client = None
_calendar_service = None


def get_secrets_client():
    global _secrets_client
    if _secrets_client is None:
        _secrets_client = boto3.client("secretsmanager")
    return _secrets_client


def get_google_service():
    global _calendar_service
    if _calendar_service is not None:
        return _calendar_service

    secret_arn = os.environ.get("GOOGLE_SECRET_ARN")
    if not secret_arn:
        raise ValueError("GOOGLE_SECRET_ARN not configured")

    response = get_secrets_client().get_secret_value(SecretId=secret_arn)
    secret_str = response.get("SecretString")
    if not secret_str:
        raise ValueError("SecretString not found in secret")

    info = json.loads(secret_str)
    credentials = service_account.Credentials.from_service_account_info(info, scopes=SCOPES)
    _calendar_service = build("calendar", "v3", credentials=credentials, cache_discovery=False)
    return _calendar_service


def parse_datetime(value):
    if not value:
        return None
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000, tz=timezone.utc)
    text = str(value).replace("Z", "+00:00")
    return datetime.fromisoformat(text)


def build_event(command):
    pedido_id = command.get("pedidoId")
    produto = command.get("produto") or ""
    descricao = command.get("descricao") or ""

    summary = f"Pedido #{pedido_id} - {produto}" if pedido_id else produto or "Pedido"
    event = {"summary": summary, "description": descricao}

    start = parse_datetime(command.get("dataInicio"))
    end = parse_datetime(command.get("dataFim"))
    if start:
        event["start"] = {"dateTime": start.isoformat(), "timeZone": DEFAULT_TIMEZONE}
    if end:
        event["end"] = {"dateTime": end.isoformat(), "timeZone": DEFAULT_TIMEZONE}

    return event


def handle_command(command):
    tipo = str(command.get("tipo", "")).lower()
    calendar_id = os.environ.get("GOOGLE_CALENDAR_ID") or "primary"
    service = get_google_service()
    pedido_id = command.get("pedidoId")

    if tipo in ("create", "criacao"):
        created = service.events().insert(calendarId=calendar_id, body=build_event(command)).execute()
        logger.info("Event created id=%s pedido=%s", created.get("id"), pedido_id)
        return created.get("id")

    if tipo in ("update", "atualizacao"):
        event_id = command.get("eventoGoogleCalendarId")
        if not event_id:
            logger.warning("Missing eventoGoogleCalendarId for update pedido=%s; skipping", pedido_id)
            return None
        service.events().update(
            calendarId=calendar_id, eventId=event_id, body=build_event(command)
        ).execute()
        logger.info("Event updated id=%s pedido=%s", event_id, pedido_id)
        return event_id

    if tipo in ("delete", "exclusao"):
        event_id = command.get("eventoGoogleCalendarId")
        if not event_id:
            logger.warning("Missing eventoGoogleCalendarId for delete pedido=%s; skipping", pedido_id)
            return None
        service.events().delete(calendarId=calendar_id, eventId=event_id).execute()
        logger.info("Event deleted id=%s pedido=%s", event_id, pedido_id)
        return event_id

    logger.warning("Unknown tipo=%s pedido=%s; discarding", tipo, pedido_id)
    return None


def open_connection():
    credentials = pika.PlainCredentials(
        os.environ.get("RABBITMQ_USERNAME", "guest"),
        os.environ.get("RABBITMQ_PASSWORD", "guest"),
    )
    parameters = pika.ConnectionParameters(
        host=os.environ["RABBITMQ_HOST"],
        port=int(os.environ.get("RABBITMQ_PORT", "5672")),
        credentials=credentials,
        heartbeat=30,
        blocked_connection_timeout=10,
        socket_timeout=10,
        connection_attempts=3,
        retry_delay=2,
    )
    return pika.BlockingConnection(parameters)


def declare_topology(channel):
    queue = os.environ.get("RABBITMQ_QUEUE", "calendar.events.queue")
    channel.exchange_declare(exchange=EXCHANGE, exchange_type="topic", durable=True)
    channel.queue_declare(queue=queue, durable=True)
    for routing_key in ROUTING_KEYS:
        channel.queue_bind(queue=queue, exchange=EXCHANGE, routing_key=routing_key)
    return queue


def publish_command(channel, command, routing_key):
    channel.basic_publish(
        exchange=EXCHANGE,
        routing_key=routing_key,
        body=json.dumps(command).encode("utf-8"),
        properties=pika.BasicProperties(content_type="application/json", delivery_mode=2),
    )
    logger.info("Published tipo=%s pedido=%s", command.get("tipo"), command.get("pedidoId"))


def drain(channel, queue, deadline):
    results = []
    while len(results) < MAX_MESSAGES_PER_RUN and time.time() < deadline:
        method, _properties, body = channel.basic_get(queue=queue, auto_ack=False)
        if method is None:
            break
        entry = {"eventId": None, "error": None}
        try:
            command = json.loads(body.decode("utf-8"))
            logger.info("Received tipo=%s pedido=%s", command.get("tipo"), command.get("pedidoId"))
            entry["eventId"] = handle_command(command)
            channel.basic_ack(delivery_tag=method.delivery_tag)
        except HttpError as error:
            status = getattr(getattr(error, "resp", None), "status", None)
            transient = status in (429, 500, 502, 503, 504)
            logger.error(
                "Google API error status=%s transient=%s: %s", status, transient, error, exc_info=True
            )
            channel.basic_nack(delivery_tag=method.delivery_tag, requeue=transient)
            entry["error"] = str(error)
        except Exception as error:  # noqa: BLE001
            logger.error("Unexpected error processing message", exc_info=True)
            channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
            entry["error"] = str(error)
        results.append(entry)
    return results


def run_self_test():
    now = datetime.now(timezone.utc)
    start = (now + timedelta(hours=1)).replace(microsecond=0).isoformat()
    end = (now + timedelta(hours=2)).replace(microsecond=0).isoformat()
    base = {
        "pedidoId": 999999,
        "produto": "E2E self test",
        "descricao": "Mensagem gerada pelo smoke test da Lambda",
        "dataInicio": start,
        "dataFim": end,
        "eventoGoogleCalendarId": None,
    }

    connection = open_connection()
    summary = {"create": None, "update": None, "delete": None}
    try:
        channel = connection.channel()
        queue = declare_topology(channel)

        publish_command(channel, dict(base, tipo="create"), "calendar.event.create")
        created = drain(channel, queue, time.time() + 20)
        summary["create"] = created
        event_id = next((item["eventId"] for item in created if item["eventId"]), None)

        if event_id:
            publish_command(
                channel,
                dict(base, tipo="update", descricao="Atualizado pelo smoke test", eventoGoogleCalendarId=event_id),
                "calendar.event.update",
            )
            summary["update"] = drain(channel, queue, time.time() + 20)

            publish_command(
                channel,
                dict(base, tipo="delete", eventoGoogleCalendarId=event_id),
                "calendar.event.delete",
            )
            summary["delete"] = drain(channel, queue, time.time() + 20)
    finally:
        try:
            connection.close()
        except Exception:
            pass

    logger.info("Self test summary: %s", summary)
    return {"selfTest": summary, "calendarId": os.environ.get("GOOGLE_CALENDAR_ID") or "primary"}


def lambda_handler(event, context):
    if isinstance(event, dict) and event.get("action") == "self_test":
        return run_self_test()

    queue = os.environ.get("RABBITMQ_QUEUE", "calendar.events.queue")
    deadline = time.time() + MAX_RUNTIME_SECONDS

    connection = open_connection()
    try:
        channel = connection.channel()
        declare_topology(channel)
        results = drain(channel, queue, deadline)
    finally:
        try:
            connection.close()
        except Exception:
            pass

    processed = len([item for item in results if item["error"] is None])
    failed = len(results) - processed
    logger.info("Run finished processed=%s failed=%s", processed, failed)
    return {"processed": processed, "failed": failed}
