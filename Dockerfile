FROM ubuntu:rolling
WORKDIR /workspaces

ARG PLATFORM="x86_64-linux"
ARG TARGET_PLATFORM=""
ARG COMPILER_NIX_NAME="ghc961"
ARG MINIMAL="true"
ARG IOG="false"

RUN DEBIAN_FRONTEND=noninteractive \
 && apt-get update \
 && apt-get -y install curl git jq nix zstd \
 && curl -L https://raw.githubusercontent.com/input-output-hk/actions/latest/devx/support/fetch-docker.sh -o fetch-docker.sh \
 && chmod +x fetch-docker.sh \
 && SUFFIX='' \
 && if [ "$MINIMAL" = "true" ]; then SUFFIX="${SUFFIX}-minimal"; fi \
 && if [ "$IOG" = "true" ]; then SUFFIX="${SUFFIX}-iog"; fi \
 && ./fetch-docker.sh input-output-hk/devx $PLATFORM.$COMPILER_NIX_NAME$TARGET_PLATFORM${SUFFIX}-env | zstd -d | nix-store --import | tee store-paths.txt

RUN cat <<EOF >> $HOME/.bashrc
CACHE_DIR="$HOME/.cache"
if [ ! -d "\$CACHE_DIR" ]; then
    REPO_URL=\$(git config --get remote.origin.url)
    GITHUB_REPO=\$(basename -s .git "\$REPO_URL")
    COMMIT_HASH=\$(git rev-parse HEAD)
    ARTIFACT_NAME="cache-\$COMMIT_HASH"
    RUN_ID=\$(curl -s -H "Authorization: token \$GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/\$GITHUB_REPO/actions/runs?branch=master&status=success&event=push&per_page=1" | jq -r --arg COMMIT_HASH "\$COMMIT_HASH" '.workflow_runs[] | select(.head_sha==\$COMMIT_HASH).id')
    ARTIFACT_URL=\$(curl -s -H "Authorization: token \$GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/\$GITHUB_REPO/actions/runs/\$RUN_ID/artifacts" | jq -r --arg ARTIFACT_NAME "\$ARTIFACT_NAME" '.artifacts[] | select(.name==\$ARTIFACT_NAME).archive_download_url')
    if [ ! -z "\$ARTIFACT_URL" ]; then
        curl -L -o "artifact.zstd" -H "Authorization: token \$GITHUB_TOKEN" "\$ARTIFACT_URL"
        zstd -d "artifact.zstd" --output-dir-flat "\$CACHE_DIR"
        rm "artifact.zstd"
    fi
fi
# Handling the fragile way to get, e.g., `ghc8107-iog-env.sh` derivation path
echo "source $(tail -n 2 store-paths.txt | head -n 1)"
EOF
