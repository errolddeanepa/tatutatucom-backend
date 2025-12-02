ARG NODE_VERSION=22.14
FROM node:${NODE_VERSION}-bookworm-slim AS base

FROM base AS deps
WORKDIR /opt/medusa/deps
ARG NODE_ENV=development
ENV NODE_ENV=$NODE_ENV

# Install dependencies
# Only copy dependency manifests for better caching
COPY package.json yarn.lock .yarnrc.yml ./
# Install dependencies (no node_modules hoisting to final image yet)
RUN npm install

FROM base AS builder
WORKDIR /opt/medusa/build
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

# Build the application
COPY --from=deps /opt/medusa/deps .
COPY . .
RUN npm run build

FROM base AS runner
RUN apt-get update \
  && apt-get install --no-install-recommends -y tini=0.19.0-1+b3 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER node
WORKDIR /opt/medusa
COPY --from=builder --chown=node:node /opt/medusa/build .
ARG PORT=9000
ARG NODE_ENV=production
ENV PORT=$PORT
ENV NODE_ENV=$NODE_ENV

EXPOSE $PORT

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["./start.sh"]
