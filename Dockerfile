FROM ubuntu:rolling
WORKDIR /workspaces

ARG PLATFORM="x86_64-linux"
ARG TARGET_PLATFORM=""
ARG COMPILER_NIX_NAME="ghc961"
ARG MINIMAL="true"
ARG IOG="false"

RUN DEBIAN_FRONTEND=noninteractive \
 && apt-get update \
 && apt-get -y install curl gh git grep jq nix zstd \
 && curl -L https://raw.githubusercontent.com/input-output-hk/actions/latest/devx/support/fetch-docker.sh -o fetch-docker.sh \
 && chmod +x fetch-docker.sh \
 && SUFFIX='' \
 && if [ "$MINIMAL" = "true" ]; then SUFFIX="${SUFFIX}-minimal"; fi \
 && if [ "$IOG" = "true" ]; then SUFFIX="${SUFFIX}-iog"; fi \
 && ./fetch-docker.sh input-output-hk/devx $PLATFORM.$COMPILER_NIX_NAME$TARGET_PLATFORM${SUFFIX}-env | zstd -d | nix-store --import | tee store-paths.txt

RUN cat <<EOF >> $HOME/.bashrc
CACHE_DIR="\$HOME/.cache"
if [ ! -d "\$CACHE_DIR" ] && [ -n "\$GITHUB_TOKEN" ]; then
    echo "\$GITHUB_TOKEN" | gh auth login --with-token
    COMMIT_HASH=\$(git rev-parse HEAD)
    REPO_URL=\$(git config --get remote.origin.url)
    if [[ "\$REPO_URL" =~ git@github.com:(.+)/(.+)\.git ]]; then
        OWNER=\${BASH_REMATCH[1]}
        REPO=\${BASH_REMATCH[2]}
    elif [[ "\$REPO_URL" =~ https://github.com/(.+)/(.+).git ]]; then
        OWNER=\${BASH_REMATCH[1]}
        REPO=\${BASH_REMATCH[2]}
    fi
    if [ -n "\$COMMIT_HASH" ] && [ -n "\$OWNER" ] &&  [ -n "\$REPO" ]; then
        ARTIFACT_NAME="cache-\$COMMIT_HASH"
        ARTIFACT_URL=\$(gh api "repos/\$OWNER/\$REPO/actions/artifacts" --jq ".artifacts[] | select(.name==\"\$ARTIFACT_NAME\") | .archive_download_url" | head -n 1)
        if [ -n "\$ARTIFACT_URL" ]; then
            curl -L -o "artifact.zstd" -H "Authorization: token \$GITHUB_TOKEN" "\$ARTIFACT_URL"
            zstd -d "artifact.zstd" --output-dir-flat "\$CACHE_DIR"
            rm "artifact.zstd"
        fi
    fi
fi
source $(grep -m 1 -e '-env.sh$' store-paths.txt)
EOF