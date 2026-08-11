# ==========================================
# Stage 1: Build the React application
# ==========================================
FROM node:20-alpine AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy package files first (better caching)
COPY package.json package-lock.json ./

# Install dependencies (npm ci is preferred in CI/CD, but npm install is fine too)
RUN npm install

# Copy the rest of the application code
COPY . .

# Build the application (Vite outputs to the 'dist' folder)
RUN npm run build

# ==========================================
# Stage 2: Serve the application with Nginx
# ==========================================
FROM nginx:alpine

# Remove default Nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy the compiled React app from the builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy our custom Nginx configuration for React Router
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80 to the outside world
EXPOSE 80

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
