FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=8080 DATA_DIR=/app/storage
COPY . .
RUN mkdir -p /app/storage && chown -R node:node /app/storage
USER node
VOLUME ["/app/storage"]
EXPOSE 8080
CMD ["node", "server.js"]
