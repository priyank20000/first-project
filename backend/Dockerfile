# ==========================================
# 1. DEVELOPMENT STAGE
# ==========================================

FROM node:20-alpine as dev

WORKDIR /app

COPY backend/package.json ./
RUN npm install

COPY backend/ .

ENV CHOKIDAR_USEPOLLING=true
ENV WATCHPACK_POLLING=true

CMD ["npm","run", "dev"]

# ==========================================
# 3. PRODUCTION STAGE 
# ==========================================

FROM node:20-alpine as prod

WORKDIR /app

COPY backend/package.json ./
RUN npm install

COPY backend/ .

CMD ["npm","start"]