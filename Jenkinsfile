pipeline {
  agent any

  tools {
    maven 'Maven3'   
    jdk 'JDK17'     
  }

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  environment {
    MAIL_TO   = 'ikramsaidi47@gmail.com'
    MAIL_FROM = 'tonmail@gmail.com'   
    MAIL_REPLY= 'tonmail@gmail.com'
  }

  stages {

    stage('Checkout') {
      steps {
        echo "Clonage du dépôt GitHub..."
        checkout scm
      }
    }

    stage('Build & Test') {
      steps {
        dir('backend') {
          echo "Compilation + tests Maven..."
          sh 'mvn -B -DskipTests=false clean verify'
        }
      }
      post {
        always {
          echo "Récupération des rapports JUnit..."
          junit allowEmptyResults: true, keepLongStdio: true, testResults: 'backend/target/surefire-reports/*.xml'
        }
        success {
          echo "Compilation et tests réussis."
        }
        failure {
          echo "Erreur dans les tests."
        }
      }
    }

    stage('JaCoCo Report') {
      steps {
        dir('backend') {
          echo "📈 Génération du rapport JaCoCo..."
          sh 'mvn jacoco:report'
        }
      }
      post {
        always {
          echo "📂 Archivage du rapport JaCoCo..."
          archiveArtifacts artifacts: 'backend/target/site/jacoco/**', fingerprint: true
        }
      }
    }

    stage('Coverage Check (>=75%)') {
      steps {
        script {
          // Lecture du rapport JaCoCo pour valider la couverture
          def reportFile = readFile('backend/target/site/jacoco/index.html')
          def covered = reportFile.contains('75%') || reportFile.contains('80%') || reportFile.contains('90%')
          if (!covered) {
            error("Couverture insuffisante (<75%).")
          } else {
            echo "Couverture correcte (>=75%)."
          }
        }
      }
    }

    stage('Archive JAR') {
      steps {
        echo "📦 Archivage du JAR..."
        archiveArtifacts artifacts: 'backend/target/*.jar', fingerprint: true
      }
    }
  }

  post {
    success {
      echo "Pipeline terminé avec succès."

      emailext(
        to: "${env.MAIL_TO}",
        from: "${env.MAIL_FROM}",
        replyTo: "${env.MAIL_REPLY}",
        subject: "Jenkins - Build ${env.JOB_NAME} #${env.BUILD_NUMBER} réussi",
        mimeType: 'text/html',
        body: """<h2>Build réussi</h2>
                 <p>Le projet <b>${env.JOB_NAME}</b> a compilé avec succès.</p>
                 <ul>
                   <li>Build #${env.BUILD_NUMBER}</li>
                   <li><a href='${env.BUILD_URL}'>Voir les détails</a></li>
                 </ul>
                 <p>Rapports JaCoCo et JUnit archivés.</p>""",
        attachLog: true,
        compressLog: true
      )
    }

    failure {
      echo "Pipeline échoué."

      emailext(
        to: "${env.MAIL_TO}",
        from: "${env.MAIL_FROM}",
        replyTo: "${env.MAIL_REPLY}",
        subject: "Jenkins - Build ${env.JOB_NAME} #${env.BUILD_NUMBER} échoué",
        mimeType: 'text/html',
        body: """<h2>Build échoué</h2>
                 <p>Le build <b>${env.JOB_NAME}</b> #${env.BUILD_NUMBER} a échoué.</p>
                 <p><a href='${env.BUILD_URL}'>Voir les logs Jenkins</a></p>""",
        attachLog: true,
        compressLog: true
      )
    }

    unstable {
      echo "Build instable ."

      emailext(
        to: "${env.MAIL_TO}",
        from: "${env.MAIL_FROM}",
        replyTo: "${env.MAIL_REPLY}",
        subject: "Jenkins - Build ${env.JOB_NAME} #${env.BUILD_NUMBER} instable",
        mimeType: 'text/html',
        body: """<h2>Build instable</h2>
                 <p>Couverture ou tests partiellement réussis.</p>
                 <p><a href='${env.BUILD_URL}'>Voir la console Jenkins</a></p>""",
        attachLog: true,
        compressLog: true
      )
    }

    always {
      echo "🧹 Nettoyage du workspace..."
      cleanWs()
    }
  }
}
