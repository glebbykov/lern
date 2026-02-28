# Common Issues

## Docker daemon is not running
- Symptom: `Cannot connect to the Docker daemon`.
- Fix: start Docker service / Docker Desktop.

## Permission denied on Linux
- Symptom: `permission denied while trying to connect to the Docker daemon socket`.
- Fix: add user to `docker` group and relogin.

## Pull rate limits
- Symptom: failed pulls from public registry.
- Fix: login into registry or mirror/cache images.
