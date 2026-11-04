FROM eclipse-temurin:17-jdk AS builder

WORKDIR /workspace

COPY . .

RUN chmod +x mvnw

RUN ./mvnw \
    -pl spring-petclinic-observability-demo-service \
    -am \
    package \
    -DskipTests


FROM eclipse-temurin:17-jre

WORKDIR /app

COPY --from=builder \
    /workspace/spring-petclinic-observability-demo-service/target/*.jar \
    /app/app.jar

EXPOSE 8084

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
