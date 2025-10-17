pipeline {
    agent {
        docker {
            image 'maven:3.9.9-eclipse-temurin-17'
            args '-v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/workspace --entrypoint=""'
        }
    }

    environment {
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        PATH      = "${JAVA_HOME}/bin:${PATH}"
        PROJ      = '/workspace'
        BACK      = "${PROJ}/backend"
        IMG       = "maint_backend:${BUILD_NUMBER}"

        MAIL_TO   = 'ikramsaidi47@gmail.com'
        MAIL_FROM = 'tonmail@gmail.com'
        MAIL_REPLY= 'tonmail@gmail.com'

        ARTIFACTS_DIR = "${WORKSPACE}/artifacts"
        REPORTS_DIR   = "${WORKSPACE}/reports"
        JACOCO_DIR    = "${WORKSPACE}/jacoco"
    }

    stages {
        stage('Preflight (/workspace)') {
            steps {
                sh 'bash -c "set -euo pipefail; echo \\"== Vérification du montage /workspace ==\\"; [ -d \\"$PROJ\\"] || { echo \\"ERREUR: $PROJ n\'existe pas.\\"; exit 2; }; [ -f \\"$BACK/pom.xml\\"] || { echo \\"ERREUR: $BACK/pom.xml introuvable.\\"; exit 2; }; echo \\"[OK] backend détecté.\\" "'

            }
        }

        stage('Show workspace') {
            steps {
                sh '''
#!/bin/bash
echo "== Listing /workspace ==" && ls -la "$PROJ"
echo "== Listing backend ==" && ls -la "$BACK"
                '''
            }
        }

        stage('Build & Tests Maven') {
            steps {
                dir("${BACK}") {
                    sh '''
#!/bin/bash
set -euxo pipefail
[ -f mvnw ] || { echo "ERREUR: mvnw introuvable"; exit 1; }
sed -i 's/\r$//' mvnw || true
chmod +x mvnw
./mvnw -B -U clean verify
                    '''
                }
            }
            post {
                always {
                    sh '''
#!/bin/bash
mkdir -p "${REPORTS_DIR}/surefire" "${REPORTS_DIR}/failsafe"
cp -f "${BACK}/target/surefire-reports/"*.xml "${REPORTS_DIR}/surefire/" || true
cp -f "${BACK}/target/failsafe-reports/"*.xml "${REPORTS_DIR}/failsafe/" || true
                    '''
                    junit allowEmptyResults: true, keepLongStdio: true, testResults: 'reports/surefire/*.xml'
                    junit allowEmptyResults: true, keepLongStdio: true, testResults: 'reports/failsafe/*.xml'
                }
                success {
                    sh '''
#!/bin/bash
mkdir -p "${ARTIFACTS_DIR}"
cp -f "${BACK}/target/"*.jar "${ARTIFACTS_DIR}/" || true
                    '''
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/*.jar', fingerprint: true
                }
            }
        }

        stage('Quality Gate (JaCoCo >= 75%)') {
            steps {
                jacoco execPattern: 'backend/target/jacoco.exec',
                       classPattern: 'backend/target/classes',
                       sourcePattern: 'backend/src/main/java',
                       changeBuildStatus: true,
                       minimumInstructionCoverage: '0.75'
            }
        }

        stage('JaCoCo HTML Report') {
            steps {
                sh '''
#!/bin/bash
set -eux
cd "$BACK"
./mvnw -B -U jacoco:report || true
mkdir -p "${JACOCO_DIR}"
cp -r target/site/jacoco/* "${JACOCO_DIR}/" || true
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
#!/bin/bash
set -eux
command -v docker >/dev/null 2>&1 || { echo "Docker CLI indisponible, skip."; exit 0; }
[ -f backend/Dockerfile ] || { echo "Pas de Dockerfile, skip."; exit 0; }
docker build -t "$IMG" backend
docker image ls "$IMG"
                '''
            }
        }

        stage('Smoke Test Image') {
            when { expression { return fileExists('backend/Dockerfile') } }
            steps {
                sh '''
#!/bin/bash
set -eux
command -v docker >/dev/null 2>&1 || { echo "Docker CLI indisponible, skip."; exit 0; }

docker rm -f ci-backend >/dev/null 2>&1 || true
docker run -d --name ci-backend -p 18585:8585 "$IMG"

for i in $(seq 1 30); do
    curl -sf http://localhost:18585/actuator/health >/dev/null 2>&1 && break
    curl -sf http://localhost:18585/series >/dev/null 2>&1 && break
    sleep 2
done

STATUS=$(docker inspect -f '{{.State.Running}}' ci-backend)
if [ "$STATUS" != "true" ]; then
    echo "Service did not start"
    docker logs ci-backend || true
    exit 1
fi
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
                body: """<p>Build réussi.</p><p><b>Image:</b> ${IMG}</p><p><a href='${env.BUILD_URL}'>Console Jenkins</a></p>""",
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
                body: """<p>Le pipeline a échoué.</p><p><a href='${env.BUILD_URL}'>Voir les logs Jenkins</a></p>""",
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
                body: """<p>Build instable (quality gate ou couverture).</p><p><a href='${env.BUILD_URL}'>Console Jenkins</a></p>""",
                attachLog: true,
                compressLog: true
            )
        }
    }
}
