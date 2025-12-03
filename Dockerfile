FROM gradle:5.2.1-jdk8-alpine AS builder
WORKDIR /app

COPY . .
USER root
RUN apk add --no-cache dos2unix \
    && dos2unix ./gradlew \
    && chmod +x ./gradlew \
    && gradle clean build --no-daemon --warning-mode all

FROM eclipse-temurin:8-jre-focal AS final
WORKDIR /app
COPY fetch_nvd_data.sh /app/
RUN apt-get update && apt-get install -y --no-install-recommends curl dos2unix unzip \
    && rm -rf /var/lib/apt/lists/* \
    && chmod +x /app/fetch_nvd_data.sh \
    && dos2unix /app/fetch_nvd_data.sh \
    && /app/fetch_nvd_data.sh \
    && rm /app/fetch_nvd_data.sh
COPY --from=builder /app/build/libs/tam-server.jar tam-server.jar
EXPOSE 8080
ARG mongoConnection
ARG jwtSecret
ARG supportMail
ARG supportMailPW
ARG supportMailReceiver
ENV MONGODB_CONNECTION=$mongoConnection
ENV OVVL_JWT_SECRET=$jwtSecret
ENV SUPPORT_MAIL_SENDER=$supportMail
ENV SUPPORT_MAIL_SENDER_PW=$supportMailPW
ENV SUPPORT_MAIL_RECEIVER=$supportMailReceiver
ENTRYPOINT ["java", "-jar", "tam-server.jar"]
