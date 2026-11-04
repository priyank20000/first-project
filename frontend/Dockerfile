# ==========================================
# 1. DEVELOPMENT STAGE
# ==========================================
FROM node:20-alpine AS dev

WORKDIR /app

COPY frontend/package.json ./
RUN npm install

COPY frontend/ .

ENV CHOKIDAR_USEPOLLING=true
ENV WATCHPACK_POLLING=true
ENV FAST_REFRESH=true

CMD ["npm", "run", "dev", "--", "--host"]


# ==========================================
# 2. BUILD STAGE (For Production)
# ==========================================
FROM node:20-alpine AS build

WORKDIR /app

COPY frontend/package.json ./
RUN npm install

COPY frontend/ .

RUN npm run build


# ==========================================
# 3. PRODUCTION STAGE (Using Nginx)
# ==========================================
FROM nginx:alpine AS prod

COPY --from=build /app/dist /usr/share/nginx/html

CMD ["nginx", "-g", "daemon off;"]
