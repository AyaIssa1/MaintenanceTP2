pipeline {
    agent {
        docker {
            image 'maven:3.9.9-eclipse-temurin-17'
            args '-v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/workspace'
        }
    }

    tools {
        jdk 'jdk17'
        maven 'Maven3'
    }

    environment {
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        PATH = "${JAVA_HOME}/bin:${PATH}"
        PROJ = '/workspace'
        BACK = "${PROJ}/backend"
        IMG  = "maint_backend:${BUILD_NUMBER}"

        MAIL_TO   = 'ikramsaidi47@gmail.com'
        MAIL_FROM = 'tonmail@gmail.com'
        MAIL_REPLY= 'tonmail@gmail.com'
    }

    stages {

        stage('Preflight (/workspace)') {
            steps {
                sh '''
                    set -euo pipefail
                    echo "== Vérification du montage /workspace =="
                    if [ ! -d "$PROJ" ]; then
                        echo "ERREUR: $PROJ n'existe pas dans le conteneur Jenkins."
                        exit 2
                    fi
                    if [ ! -d "$BACK" ] || [ ! -f "$BACK/pom.xml" ]; then
                        echo "ERREUR: $BACK/pom.xml introuvable."
                        exit 2
                    fi
                    echo "[OK] backend détecté."
                '''
            }
        }

        stage('Show workspace') {
            steps {
                sh '''
                    echo "== Listing /workspace ==" && ls -la "$PROJ"
                    echo "== Listing backend =="    && ls -la "$BACK"
                '''
            }
        }

        stage('Build & Unit / IT Tests (Maven)') {
            steps {
                dir("${BACK}") {
                    echo "Compilation + tests Maven..."
                    sh '''
                        set -euxo pipefail
                        if [ ! -f mvnw ]; then
                            echo "ERROR: mvnw not found in $BACK"
                            ls -la
                            exit 1
                        fi
                        sed -i 's/\r$//' mvnw || true
                        chmod +x mvnw

                        ./mvnw -B -U -DskipTests=false clean verify
                    '''
                }
            }
            post {
                always {
                    sh '''
                        set -eux
                        mkdir -p "${WORKSPACE}/reports/surefire" "${WORKSPACE}/reports/failsafe"
                        cp -f "${BACK}/target/surefire-reports/"*.xml "${WORKSPACE}/reports/surefire/"  || true
                        cp -f "${BACK}/target/failsafe-reports/"*.xml "${WORKSPACE}/reports/failsafe/" || true
                    '''
                    junit allowEmptyResults: true, keepLongStdio: true, testResults: 'reports/surefire/*.xml'
                    junit allowEmptyResults: true, keepLongStdio: true, testResults: 'reports/failsafe/*.xml'
                }
                success {
                    sh '''
                        set -eux
                        mkdir -p "${WORKSPACE}/artifacts"
                        cp -f "${BACK}/target/"*.jar "${WORKSPACE}/artifacts/" || true
                    '''
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/*.jar', fingerprint: true
                }
            }
        }

        stage('Quality Gate (JaCoCo >= 75%)') {
            steps {
                jacoco execPattern:   'backend/target/jacoco.exec',
                       classPattern:  'backend/target/classes',
                       sourcePattern: 'backend/src/main/java',
                       changeBuildStatus: true,
                       minimumInstructionCoverage: '0.75'
            }
        }

        stage('JaCoCo HTML report (archive)') {
            steps {
                sh '''
                    set -eux
                    cd "$BACK"
                    ./mvnw -B -U jacoco:report || true
                    mkdir -p "${WORKSPACE}/jacoco"
                    cp -r target/site/jacoco/* "${WORKSPACE}/jacoco/" || true
                '''
            }
            post {
                always {
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'jacoco/**'
                }
            }
        }

        stage('Docker Build (backend)') {
            steps {
                sh '''
                    set -eux
                    if ! command -v docker >/dev/null 2>&1; then
                        echo "Docker CLI indisponible, on saute la build d'image."
                        exit 0
                    fi
                    cd "$PROJ"
                    if [ ! -f backend/Dockerfile ]; then
                        echo "Pas de Dockerfile dans backend/, on saute la build d'image."
                        exit 0
                    fi
                    docker build -t "$IMG" backend
                    docker image ls "$IMG"
                '''
            }
        }

        stage('Smoke Test image') {
            when { expression { return fileExists('backend/Dockerfile') } }
            steps {
                sh '''
                    set -eux
                    if ! command -v docker >/dev/null 2>&1; then
                        echo "Docker CLI indisponible, on saute le smoke test."
                        exit 0
                    fi

                    docker rm -f ci-backend >/dev/null 2>&1 || true
                    docker run -d --name ci-backend -p 18585:8585 "$IMG"

                    for i in $(seq 1 30); do
                        if curl -sf http://localhost:18585/actuator/health >/dev/null 2>&1 \
                        || curl -sf http://localhost:18585/series >/dev/null 2>&1; then
                            echo "App is up"
                            exit 0
                        fi
                        sleep 2
                    done

                    echo "Service did not become healthy"
                    docker logs ci-backend || true
                    exit 1
                '''
            }
            post {
                always {
                    sh 'docker rm -f ci-backend >/dev/null 2>&1 || true'
                }
            }
        }
    }

    post {
        success {
            emailext(
                to: "${env.MAIL_TO}",
                from: "${env.MAIL_FROM}",
                replyTo: "${env.MAIL_REPLY}",
                subject: "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} SUCCESS",
                mimeType: 'text/html',
                body: """<p>✅ Build réussi.</p><p><b>Image:</b> ${IMG}</p><p><a href='${env.BUILD_URL}'>Console Jenkins</a></p>""",
                attachLog: true,
                compressLog: true
            )
        }
        failure {
            emailext(
                to: "${env.MAIL_TO}",
                from: "${env.MAIL_FROM}",
                replyTo: "${env.MAIL_REPLY}",
                subject: "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED",
                mimeType: 'text/html',
                body: """<p>❌ Le pipeline a échoué.</p><p><a href='${env.BUILD_URL}'>Voir les logs Jenkins</a></p>""",
                attachLog: true,
                compressLog: true
            )
        }
        unstable {
            emailext(
                to: "${env.MAIL_TO}",
                from: "${env.MAIL_FROM}",
                replyTo: "${env.MAIL_REPLY}",
                subject: "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} UNSTABLE",
                mimeType: 'text/html',
                body: """<p>⚠️ Build instable (couverture ou quality gate).</p><p><a href='${env.BUILD_URL}'>Console Jenkins</a></p>""",
                attachLog: true,
                compressLog: true
            )
        }
        always {
            cleanWs()
        }
pipeline {
    agent {
        docker {
            image 'maven:3.9.9-eclipse-temurin-17'
            args '-v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/workspace'
        }
    }

    tools {
        jdk 'jdk17'
        maven 'Maven3'
    }

    environment {
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        PATH = "${JAVA_HOME}/bin:${PATH}"
        PROJ = '/workspace'
        BACK = "${PROJ}/backend"
        IMG  = "maint_backend:${BUILD_NUMBER}"

        MAIL_TO   = 'ikramsaidi47@gmail.com'
        MAIL_FROM = 'tonmail@gmail.com'
        MAIL_REPLY= 'tonmail@gmail.com'
    }

    stages {

        stage('Preflight (/workspace)') {
            steps {
                sh '''
                    set -euo pipefail
                    echo "== Vérification du montage /workspace =="
                    if [ ! -d "$PROJ" ]; then
                        echo "ERREUR: $PROJ n'existe pas dans le conteneur Jenkins."
                        exit 2
                    fi
                    if [ ! -d "$BACK" ] || [ ! -f "$BACK/pom.xml" ]; then
                        echo "ERREUR: $BACK/pom.xml introuvable."
                        exit 2
                    fi
                    echo "[OK] backend détecté."
                '''
            }
        }

        stage('Show workspace') {
            steps {
                sh '''
                    echo "== Listing /workspace ==" && ls -la "$PROJ"
                    echo "== Listing backend =="    && ls -la "$BACK"
                '''
            }
        }

        stage('Build & Unit / IT Tests (Maven)') {
            steps {
                dir("${BACK}") {
                    echo "Compilation + tests Maven..."
                    sh '''
                        set -euxo pipefail
                        if [ ! -f mvnw ]; then
                            echo "ERROR: mvnw not found in $BACK"
                            ls -la
                            exit 1
                        fi
                        sed -i 's/\r$//' mvnw || true
                        chmod +x mvnw

                        ./mvnw -B -U -DskipTests=false clean verify
                    '''
                }
            }
            post {
                always {
                    sh '''
                        set -eux
                        mkdir -p "${WORKSPACE}/reports/surefire" "${WORKSPACE}/reports/failsafe"
                        cp -f "${BACK}/target/surefire-reports/"*.xml "${WORKSPACE}/reports/surefire/"  || true
                        cp -f "${BACK}/target/failsafe-reports/"*.xml "${WORKSPACE}/reports/failsafe/" || true
                    '''
                    junit allowEmptyResults: true, keepLongStdio: true, testResults: 'reports/surefire/*.xml'
                    junit allowEmptyResults: true, keepLongStdio: true, testResults: 'reports/failsafe/*.xml'
                }
                success {
                    sh '''
                        set -eux
                        mkdir -p "${WORKSPACE}/artifacts"
                        cp -f "${BACK}/target/"*.jar "${WORKSPACE}/artifacts/" || true
                    '''
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/*.jar', fingerprint: true
                }
            }
        }

        stage('Quality Gate (JaCoCo >= 75%)') {
            steps {
                jacoco execPattern:   'backend/target/jacoco.exec',
                       classPattern:  'backend/target/classes',
                       sourcePattern: 'backend/src/main/java',
                       changeBuildStatus: true,
                       minimumInstructionCoverage: '0.75'
            }
        }

        stage('JaCoCo HTML report (archive)') {
            steps {
                sh '''
                    set -eux
                    cd "$BACK"
                    ./mvnw -B -U jacoco:report || true
                    mkdir -p "${WORKSPACE}/jacoco"
                    cp -r target/site/jacoco/* "${WORKSPACE}/jacoco/" || true
                '''
            }
            post {
                always {
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'jacoco/**'
                }
            }
        }

        stage('Docker Build (backend)') {
            steps {
                sh '''
                    set -eux
                    if ! command -v docker >/dev/null 2>&1; then
                        echo "Docker CLI indisponible, on saute la build d'image."
                        exit 0
                    fi
                    cd "$PROJ"
                    if [ ! -f backend/Dockerfile ]; then
                        echo "Pas de Dockerfile dans backend/, on saute la build d'image."
                        exit 0
                    fi
                    docker build -t "$IMG" backend
                    docker image ls "$IMG"
                '''
            }
        }

        stage('Smoke Test image') {
            when { expression { return fileExists('backend/Dockerfile') } }
            steps {
                sh '''
                    set -eux
                    if ! command -v docker >/dev/null 2>&1; then
                        echo "Docker CLI indisponible, on saute le smoke test."
                        exit 0
                    fi

                    docker rm -f ci-backend >/dev/null 2>&1 || true
                    docker run -d --name ci-backend -p 18585:8585 "$IMG"

                    for i in $(seq 1 30); do
                        if curl -sf http://localhost:18585/actuator/health >/dev/null 2>&1 \
                        || curl -sf http://localhost:18585/series >/dev/null 2>&1; then
                            echo "App is up"
                            exit 0
                        fi
                        sleep 2
                    done

                    echo "Service did not become healthy"
                    docker logs ci-backend || true
                    exit 1
                '''
            }
            post {
                always {
                    sh 'docker rm -f ci-backend >/dev/null 2>&1 || true'
                }
            }
        }
    }

    post {
        success {
            emailext(
                to: "${env.MAIL_TO}",
                from: "${env.MAIL_FROM}",
                replyTo: "${env.MAIL_REPLY}",
                subject: "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} SUCCESS",
                mimeType: 'text/html',
                body: """<p>✅ Build réussi.</p><p><b>Image:</b> ${IMG}</p><p><a href='${env.BUILD_URL}'>Console Jenkins</a></p>""",
                attachLog: true,
                compressLog: true
            )
        }
        failure {
            emailext(
                to: "${env.MAIL_TO}",
                from: "${env.MAIL_FROM}",
                replyTo: "${env.MAIL_REPLY}",
                subject: "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED",
                mimeType: 'text/html',
                body: """<p>❌ Le pipeline a échoué.</p><p><a href='${env.BUILD_URL}'>Voir les logs Jenkins</a></p>""",
                attachLog: true,
                compressLog: true
            )
        }
        unstable {
            emailext(
                to: "${env.MAIL_TO}",
                from: "${env.MAIL_FROM}",
                replyTo: "${env.MAIL_REPLY}",
                subject: "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} UNSTABLE",
                mimeType: 'text/html',
                body: """<p>⚠️ Build instable (couverture ou quality gate).</p><p><a href='${env.BUILD_URL}'>Console Jenkins</a></p>""",
                attachLog: true,
                compressLog: true
            )
        }
        always {
            cleanWs()
        }
    }
}
