pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    skipDefaultCheckout(true)
    buildDiscarder(logRotator(numToKeepStr: '15'))
  }

  environment {
    PROJ = '/workspace'
    BACK = '/workspace/backend'
    IMG  = "maint_backend:${BUILD_NUMBER}"

    MAIL_TO   = 'ikramsaidi47@gmail.com'
    MAIL_FROM = 'tonmail@gmail.com'
    MAIL_REPLY= 'tonmail@gmail.com'
  }

  stages {

    stage('Preflight (/workspace)') {
      steps {
        sh '''
          #!/bin/bash
          set -euo pipefail
          echo "== Vérification du montage /workspace =="
          if [ ! -d "$PROJ" ]; then
            echo "ERREUR: $PROJ n'existe pas dans le conteneur Jenkins."
            echo "Assure-toi d'avoir un volume Docker compose type: - .:/workspace"
            exit 2
          fi
          if [ ! -d "$BACK" ] || [ ! -f "$BACK/pom.xml" ]; then
            echo "ERREUR: $BACK/pom.xml introuvable. Structure attendue: /workspace/backend/pom.xml"
            exit 2
          fi
          echo "[OK] backend détecté."
        '''
      }
    }

    stage('Show workspace') {
      steps {
        sh '''
          #!/bin/bash
          echo "== Listing /workspace ==" && ls -la "$PROJ"
          echo "== Listing backend =="    && ls -la "$BACK"
        '''
      }
    }

    stage('Build & Unit / IT Tests (Maven)') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          cd "$BACK"

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
      post {
        always {
          sh '''
            #!/bin/bash
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
            #!/bin/bash
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
        jacoco execPattern:   'backend/target/*.exec',
               classPattern:  'backend/target/classes',
               sourcePattern: 'backend/src/main/java',
               changeBuildStatus: true,
               minimumInstructionCoverage: '0.75'
      }
    }

    stage('JaCoCo HTML report (archive)') {
      steps {
        sh '''
          #!/bin/bash
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
          #!/bin/bash
          set -eux
          if ! command -v docker >/dev/null 2>&1; then
            echo "Docker CLI indisponible dans l'agent — on saute la build d'image."
            exit 0
          fi
          cd "$PROJ"
          if [ ! -f backend/Dockerfile ]; then
            echo "Pas de Dockerfile dans backend/ — on saute la build d'image."
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
          #!/bin/bash
          set -eux
          if ! command -v docker >/dev/null 2>&1; then
            echo "Docker CLI indisponible — on saute le smoke test."
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
          sh '''
            #!/bin/bash
            docker rm -f ci-backend >/dev/null 2>&1 || true
          '''
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
        body: """<p>Build OK.</p>
                 <p><b>Image:</b> ${IMG}</p>
                 <p><a href='${env.BUILD_URL}'>Console</a></p>""",
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
        body: """<p>Pipeline échoué — voir la console :</p>
                 <p><a href='${env.BUILD_URL}'>${env.BUILD_URL}</a></p>""",
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
        body: """<p>Build UNSTABLE (couverture ou quality gate).</p>
                 <p><a href='${env.BUILD_URL}'>Console</a></p>""",
        attachLog: true,
        compressLog: true
      )
    }
    always {
      cleanWs()
    }
  }
}
