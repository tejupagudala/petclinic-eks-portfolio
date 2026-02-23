

FROM eclipse-temurin:21-jdk AS builder

WORKDIR /usr/src/app/

COPY mvnw .
COPY .mvn .mvn
RUN chmod +x mvnw

# Copy parent/root pom + module pom first (caching dependencies)
COPY pom.xml .
COPY spring-petclinic-customers-service/pom.xml spring-petclinic-customers-service/pom.xml
COPY spring-petclinic-discovery-server/pom.xml spring-petclinic-discovery-server/pom.xml
COPY spring-petclinic-genai-service/pom.xml spring-petclinic-genai-service/pom.xml
COPY spring-petclinic-vets-service/pom.xml spring-petclinic-vets-service/pom.xml
COPY spring-petclinic-visits-service/pom.xml spring-petclinic-visits-service/pom.xml
COPY spring-petclinic-visits-service/pom.xml spring-petclinic-api-gateway/pom.xml

# (Optional but recommended) download dependencies for faster rebuilds
RUN ./mvnw -q -DskipTests -f spring-petclinic-api-gateway/pom.xml dependency:go-offline


# Now copy the rest of the source code (changes frequently)
COPY . .

# Build only the customers service module (CI-style)
RUN ./mvnw -q -DskipTests -f spring-petclinic-api-gateway/pom.xml package

#####################################################

FROM eclipse-temurin:21-jre

WORKDIR /usr/src/app/

# Copy only the built jar from the builder stage
# (This uses a wildcard so you don't hardcode version)
COPY --from=builder /usr/src/app/spring-petclinic-api-gateway/target/*.jar /app/app.jar

# Optional: document the port (check your config for actual port)
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]