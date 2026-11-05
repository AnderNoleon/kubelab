FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=3000
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY src ./src
# La versión (hash corto del commit) la pasa el pipeline de CI/CD.
ARG VERSION=dev
ENV APP_VERSION=$VERSION
USER 1000
EXPOSE 3000
CMD ["node", "src/server.js"]
