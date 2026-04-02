// docker-bake.hcl — параллельная сборка нескольких образов
//
// Использование:
//   docker buildx bake -f lab/bake/docker-bake.hcl
//   docker buildx bake -f lab/bake/docker-bake.hcl --print   # показать план без сборки
//   docker buildx bake -f lab/bake/docker-bake.hcl api        # собрать только api
//
// Bake собирает ВСЕ targets параллельно (в отличие от последовательного docker build)

variable "REGISTRY" {
  default = "localhost:5000"
}

variable "TAG" {
  default = "dev"
}

// Группа: собрать все сервисы одной командой
group "default" {
  targets = ["api", "worker", "migrator"]
}

// Target: API-сервер
target "api" {
  context    = "../src"
  dockerfile = "Dockerfile"
  target     = "prod"
  tags       = ["${REGISTRY}/myapp-api:${TAG}"]
  platforms  = ["linux/amd64"]
}

// Target: Worker (тот же Dockerfile, другой target)
target "worker" {
  context    = "../src"
  dockerfile = "Dockerfile"
  target     = "prod"
  tags       = ["${REGISTRY}/myapp-worker:${TAG}"]
  args = {
    CMD_OVERRIDE = "worker"
  }
}

// Target: Мигратор БД
target "migrator" {
  context    = "../src"
  dockerfile = "Dockerfile"
  target     = "builder"
  tags       = ["${REGISTRY}/myapp-migrator:${TAG}"]
}

// Target: Dev-образ с hot-reload
target "dev" {
  inherits   = ["api"]
  target     = "dev"
  tags       = ["${REGISTRY}/myapp-api:dev"]
  cache-from = ["type=registry,ref=${REGISTRY}/myapp-api:cache"]
  cache-to   = ["type=registry,ref=${REGISTRY}/myapp-api:cache,mode=max"]
}
