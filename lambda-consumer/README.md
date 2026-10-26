# Lambda Consumer - Calendar Events

Lambda function invoked by an EventBridge schedule. Each invocation drains messages from the RabbitMQ queue `calendar.events.queue` (hosted on the backend EC2 instance) and creates, updates, or deletes Google Calendar events.

## Build

The Terraform module expects `lambda.zip` next to `main.tf`. Build it before `terraform apply`:

```powershell
.\build.ps1
```

```bash
./build.sh
```

## How it runs

- EventBridge rule `${project_name}-calendar-consumer-schedule` triggers the function every minute (configurable via `poll_schedule_expression`).
- The handler opens an AMQP connection, calls `basic_get` up to 50 times or 50 seconds, processes each `CalendarCommand`, acknowledges successful messages, requeues transient Google API failures, and discards messages that fail for other reasons.
- Google service account JSON is read from the Secrets Manager secret created by this module.

## After apply

1. Preferred: set `google_calendar_credentials_file` to a JSON path outside the
   repository. Terraform stores the file contents in the secret during `apply`.
   The value is persisted in `terraform.tfstate`, so protect the state. If the
   variable is omitted, seed the secret manually:
   ```bash
   aws secretsmanager put-secret-value --secret-id "$(terraform output -raw google_calendar_secret_arn)" --secret-string file://service-account.json
   ```
2. Set `google_calendar_id` to the target calendar (defaults to `primary` when empty).
3. Ensure the backend publishes to the same queue and that the Lambda SG can reach the backend on port 5672.

## Environment variables

- `RABBITMQ_HOST`, `RABBITMQ_PORT`, `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`, `RABBITMQ_QUEUE`
- `GOOGLE_SECRET_ARN`, `GOOGLE_CALENDAR_ID`
