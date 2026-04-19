# airgenome buildx bake — htz (builder SSOT) 5분 timer 자동 빌드
# 사용: docker buildx bake -f docker/buildx.bake.hcl --push
#      docker buildx bake -f docker/buildx.bake.hcl dev       # L3 만
#      docker buildx bake -f docker/buildx.bake.hcl base      # L1 만

variable "REGISTRY" {
  default = "ghcr.io/need-singularity/airgenome"
}

variable "GITSHA" {
  default = "local"
}

variable "CLAUDE_VERSION" {
  default = "latest"
}

# builder platforms — linux/amd64 우선 (ubu1/ubu2/htz 전부 amd64)
variable "PLATFORMS" {
  default = ["linux/amd64"]
}

group "default" {
  targets = ["base", "claude", "dev"]
}

target "base" {
  context    = "."
  dockerfile = "docker/Dockerfile"
  target     = "base"
  platforms  = PLATFORMS
  tags = [
    "${REGISTRY}:base",
    "${REGISTRY}:base-${GITSHA}",
  ]
  cache-from = ["type=registry,ref=${REGISTRY}:cache-base"]
  cache-to   = ["type=registry,ref=${REGISTRY}:cache-base,mode=max"]
}

target "claude" {
  context    = "."
  dockerfile = "docker/Dockerfile"
  target     = "claude"
  platforms  = PLATFORMS
  args = {
    CLAUDE_VERSION = CLAUDE_VERSION
  }
  tags = [
    "${REGISTRY}:claude",
    "${REGISTRY}:claude-${GITSHA}",
  ]
  cache-from = [
    "type=registry,ref=${REGISTRY}:cache-base",
    "type=registry,ref=${REGISTRY}:cache-claude",
  ]
  cache-to = ["type=registry,ref=${REGISTRY}:cache-claude,mode=max"]
  contexts = {
    base = "target:base"
  }
}

target "dev" {
  context    = "."
  dockerfile = "docker/Dockerfile"
  target     = "dev"
  platforms  = PLATFORMS
  tags = [
    "${REGISTRY}:dev",
    "${REGISTRY}:${GITSHA}",   # 이동 tag + 불변 gitsha tag
  ]
  cache-from = [
    "type=registry,ref=${REGISTRY}:cache-claude",
    "type=registry,ref=${REGISTRY}:cache-dev",
  ]
  cache-to = ["type=registry,ref=${REGISTRY}:cache-dev,mode=max"]
  contexts = {
    claude = "target:claude"
  }
}
