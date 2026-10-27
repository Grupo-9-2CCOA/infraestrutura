import json
import os
import logging
from datetime import datetime, timedelta, timezone
import uuid

import boto3
from google.oauth2 import service_account
from googleapiclient.discovery import build
import pika

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SCOPES = ['https://www.googleapis.com/auth/calendar']
TIMEZONE = 'America/Sao_Paulo'
EXCHANGE = 'calendar.exchange'
ROUTING_KEYS = (
    'calendar.event.create',
    'calendar.event.update',
    'calendar.event.delete',
)

_s3_client = boto3.client('s3')
_secrets_client = boto3.client('secretsmanager')


def get_google_credentials():
    secret_arn = os.environ['GOOGLE_SECRET_ARN']
    response = _secrets_client.get_secret_value(SecretId=secret_arn)
    secret_string = response['SecretString']
    info = json.loads(secret_string)
    credentials = service_account.Credentials.from_service_account_info(info, scopes=SCOPES)
    return credentials


def get_calendar_service():
    credentials = get_google_credentials()
    service = build('calendar', 'v3', credentials=credentials, cache_discovery=False)
    return service


def build_event(command):
    data_inicio = parse_datetime(command.get('dataInicio'))
    data_fim = parse_datetime(command.get('dataFim'))
    if not data_inicio or not data_fim:
        raise ValueError('dataInicio and dataFim are required')
    if data_fim <= data_inicio:
        data_fim = data_inicio + timedelta(hours=1)
    pedido_id = command.get('pedidoId')
    produto = command.get('produto') or ''
    descricao = command.get('descricao') or ''
    summary = f'Pedido #{pedido_id} - {produto}' if pedido_id else produto or 'Pedido'
    return {
        'summary': summary,
        'description': descricao,
        'start': {
            'dateTime': data_inicio.strftime('%Y-%m-%dT%H:%M:%S'),
            'timeZone': TIMEZONE,
        },
        'end': {
            'dateTime': data_fim.strftime('%Y-%m-%dT%H:%M:%S'),
            'timeZone': TIMEZONE,
        },
    }


def parse_datetime(value):
    if not value:
        return None
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value, tz=timezone.utc).astimezone(timezone(timedelta(hours=-3)))
    if isinstance(value, str):
        try:
            if 'T' in value:
                if value.endswith('Z'):
                    value = value[:-1] + '+00:00'
                dt = datetime.fromisoformat(value)
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone(timedelta(hours=-3)))
                return dt.astimezone(timezone(timedelta(hours=-3)))
            return datetime.strptime(value, '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone(timedelta(hours=-3)))
        except Exception as exc:
            logger.warning('Failed to parse datetime %s: %s', value, exc)
            raise
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone(timedelta(hours=-3)))
        return value.astimezone(timezone(timedelta(hours=-3)))
    raise ValueError(f'Unsupported datetime type: {type(value)}')


def open_connection():
    host = os.environ['RABBITMQ_HOST']
    port = int(os.environ.get('RABBITMQ_PORT', '5672'))
    username = os.environ['RABBITMQ_USERNAME']
    password = os.environ['RABBITMQ_PASSWORD']
    credentials = pika.PlainCredentials(username, password)
    parameters = pika.ConnectionParameters(
        host=host,
        port=port,
        credentials=credentials,
        heartbeat=30,
        blocked_connection_timeout=300,
    )
    return pika.BlockingConnection(parameters)


def declare_topology(channel):
    channel.exchange_declare(exchange=EXCHANGE, exchange_type='topic', durable=True)
    channel.queue_declare(queue=os.environ['RABBITMQ_QUEUE'], durable=True)
    for key in ROUTING_KEYS:
        channel.queue_bind(exchange=EXCHANGE, queue=os.environ['RABBITMQ_QUEUE'], routing_key=key)


def persist_to_raw(command, tipo, outcome, pedido_id=None, body_sent=None, google_event=None, error=None):
    bucket = os.environ.get('RAW_BUCKET_NAME') or ''
    if not bucket or not pedido_id:
        return
    try:
        now = datetime.now(timezone.utc)
        key = f"raw/google-calendar/{now:%Y}/{now:%m}/{now:%d}/{pedido_id}-{uuid.uuid4()}.json"
        payload = {
            'pedidoId': int(pedido_id) if isinstance(pedido_id, str) and pedido_id.isdigit() else pedido_id,
            'tipo': tipo,
            'outcome': outcome,
            'bodySent': body_sent,
            'googleEvent': google_event,
            'error': error,
            'timestamp': now.isoformat().replace('+00:00', 'Z')
        }
        _s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
            ContentType='application/json'
        )
        logger.info('Persisted raw Google Calendar event to s3://%s/%s', bucket, key)
    except Exception as exc:
        logger.exception('Failed to persist to raw S3: %s', exc)


def notify_backend(pedido_id, event_id):
    if not pedido_id or not event_id:
        return
    backend_host = os.environ.get('BACKEND_HOST') or ''
    backend_port = os.environ.get('BACKEND_PORT') or '8080'
    if not backend_host:
        return
    try:
        import requests
        url = f"http://{backend_host}:{backend_port}/internal/pedidos/{pedido_id}/calendar-event"
        payload = {"eventoGoogleCalendarId": event_id}
        resp = requests.patch(url, json=payload, timeout=5)
        logger.info('Notified backend to link calendar event: status=%s', resp.status_code)
    except Exception as exc:
        logger.exception('Failed to notify backend to link calendar event: %s', exc)


def handle_command(service, calendar_id, command):
    tipo = (command.get('tipo') or '').lower()
    pedido_id = command.get('pedidoId')
    evento_google_id = command.get('eventoGoogleCalendarId')

    try:
        if tipo == 'create':
            body = build_event(command)
            try:
                event = service.events().insert(calendarId=calendar_id, body=body).execute()
                logger.info('Created Google Calendar event for pedido %s: %s', pedido_id, event.get('id'))
                persist_to_raw(command, tipo, 'success', pedido_id=pedido_id, body_sent=body, google_event=event)
                notify_backend(pedido_id, event.get('id'))
                return {'status': 'created', 'eventId': event.get('id')}
            except Exception as exc:
                error_msg = str(exc)
                logger.exception('Failed to create Google Calendar event for pedido %s', pedido_id)
                persist_to_raw(command, tipo, 'failure', pedido_id=pedido_id, body_sent=None, google_event=None, error=error_msg)
                raise

        if tipo == 'update':
            if not evento_google_id:
                logger.warning('Missing eventoGoogleCalendarId for update of pedido %s', pedido_id)
                persist_to_raw(command, tipo, 'failure', pedido_id=pedido_id, body_sent=None, google_event=None, error='missing eventoGoogleCalendarId')
                return {'status': 'skipped', 'reason': 'missing_event_id'}
            body = build_event(command)
            try:
                event = service.events().update(calendarId=calendar_id, eventId=evento_google_id, body=body).execute()
                logger.info('Updated Google Calendar event for pedido %s: %s', pedido_id, event.get('id'))
                persist_to_raw(command, tipo, 'success', pedido_id=pedido_id, body_sent=body, google_event=event)
                return {'status': 'updated', 'eventId': event.get('id')}
            except Exception as exc:
                error_msg = str(exc)
                logger.exception('Failed to update Google Calendar event for pedido %s', pedido_id)
                persist_to_raw(command, tipo, 'failure', pedido_id=pedido_id, body_sent=None, google_event=None, error=error_msg)
                raise

        if tipo == 'delete':
            if not evento_google_id:
     
            try:
                service.events().delete(calendarId=calendar_id, eventId=evento_google_id).execute()
                logger.info('Deleted Google Calendar event for pedido %s: %s', pedido_id, evento_google_id)
                persist_to_raw(command, tipo, 'success', pedido_id=pedido_id, body_sent=None, google_event={'id': evento_google_id})
                return {'status': 'deleted', 'eventId': evento_google_id}
            except Exception as exc:
                error_msg = str(exc)
                logger.exception('Failed to delete Google Calendar event for pedido %s', pedido_id)
                persist_to_raw(command, tipo, 'failure', pedido_id=pedido_id, body_sent=None, google_event=None, error=error_msg)
                raise

        logger.warning('Unknown command type: %s', tipo)
        persist_to_raw(command, tipo, 'failure', pedido_id=pedido_id, body_sent=None, google_event=None, error=f'unknown_tipo:{tipo}')
        return {'status': 'unknown'}
    except Exception:
        raise


def is_transient_google_error(exc):
    message = str(exc).lower()
    transient_codes = ['429', '500', '502', '503', '504', 'rate', 'quota']
    return any(code in message for code in transient_codes)


def drain(service, calendar_id, max_messages=50, max_seconds=50):
    connection = open_connection()
    channel = connection.channel()
    declare_topology(channel)
    queue = os.environ['RABBITMQ_QUEUE']
    processed = 0
    failed = 0
    started = datetime.now(timezone.utc)
    try:
        while processed + failed < max_messages:
            if (datetime.now(timezone.utc) - started).total_seconds() > max_seconds:
                break
            method, properties, body = channel.basic_get(queue=queue, auto_ack=False)
            if not method:
                break
            try:
                payload = json.loads(body.decode('utf-8'))
                result = handle_command(service, calendar_id, payload)
                channel.basic_ack(delivery_tag=method.delivery_tag)
                processed += 1
                logger.info('Processed calendar command: %s', result)
            except Exception as exc:
                failed += 1
                if is_transient_google_error(exc):
                    channel.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
                else:
                    channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
                logger.exception('Failed to process calendar command')
    finally:
        try:
            connection.close()
        except Exception:
            pass
    return {'processed': processed, 'failed': failed}


def lambda_handler(event, context):
    service = get_calendar_service()
    calendar_id = os.environ.get('GOOGLE_CALENDAR_ID') or 'primary'
    result = drain(service, calendar_id)
    logger.info('Calendar consumer finished: %s', result)
    return result
