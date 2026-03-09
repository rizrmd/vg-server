# SpacetimeDB Deployment Guide

This repository is configured for deployment to [Coolify](https://coolify.io/) using the official SpacetimeDB Docker image.

## Coolify Deployment

This repository is configured for deployment to [Coolify](https://coolify.io/).

### Coolify Configuration

- **App UUID:** `nw8g4co0skk488ss000k44ok`
- **Project UUID:** `sws0ckk`
- **Branch:** `master`
- **Dockerfile:** Uses root `Dockerfile`

### Deploy via Coolify

1. Push changes to `master` branch
2. Coolify will automatically build and deploy

Or trigger a manual redeploy from the host:

```bash
docker exec coolify php artisan tinker --execute='$app = App\\Models\\Application::where("uuid", "nw8g4co0skk488ss000k44ok")->firstOrFail(); $uuid = (string) new Visus\\Cuid2\\Cuid2(); $result = queue_application_deployment($app, $uuid, 0, "HEAD", false, false, false, false, null, true); var_export($result);'
```

### Check Deployment Status

```bash
# Latest deployments
docker exec coolify-db psql -U coolify -d coolify -At -F $'\t' -c "SELECT id, deployment_uuid, status, created_at, finished_at FROM application_deployment_queues WHERE application_id='133' ORDER BY id DESC LIMIT 5;"

# Latest deployment logs
docker exec coolify-db psql -U coolify -d coolify -At -F $'\t' -c "SELECT id, deployment_uuid, status, logs FROM application_deployment_queues WHERE application_id='133' ORDER BY id DESC LIMIT 1;"

# Check if container is running
docker ps --filter 'label=coolify.applicationId=133' --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
```

### Verify Installation

On your local machine, add the Coolify-hosted server:

```bash
spacetime server add coolify --url https://your-coolify-domain.com
spacetime server list
```

## Useful Commands

```bash
# Check deployment status
docker exec coolify-db psql -U coolify -d coolify -At -F $'\t' -c "SELECT id, deployment_uuid, status, created_at, finished_at FROM application_deployment_queues WHERE application_id='133' ORDER BY id DESC LIMIT 5;"

# Check latest deployment logs
docker exec coolify-db psql -U coolify -d coolify -At -F $'\t' -c "SELECT id, deployment_uuid, status, logs FROM application_deployment_queues WHERE application_id='133' ORDER BY id DESC LIMIT 1;"

# Check if container is running
docker ps --filter 'label=coolify.applicationId=133' --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
```

## Troubleshooting

### View application logs via Coolify dashboard or:
```bash
docker logs <container-id>
```

### Access SpacetimeDB CLI inside container
```bash
docker exec -it vg-server-spacetimedb bash
spacetime --help
```
