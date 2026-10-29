# Imagen chica, sin dependencias de desarrollo y corriendo sin root
FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production

# Primero las dependencias (se cachean mientras package.json no cambie)
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

COPY server.js ./

USER node
EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health >/dev/null || exit 1

CMD ["node", "server.js"]
