# Interviewer-owned baseline image for apps/api, used by scenarios 2+ as
# the "already deployed, Argo-managed" starting point. NOT given to the
# candidate during scenario 1 - that's what they build themselves.
FROM node:22-alpine AS build
WORKDIR /app
COPY apps/api/package.json apps/api/package-lock.json ./
RUN npm ci --omit=dev
COPY apps/api/src ./src
COPY apps/api/migrations ./migrations

FROM node:22-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /app /app
USER app
ENV NODE_ENV=production
EXPOSE 3000
ENTRYPOINT ["node", "src/index.js"]
