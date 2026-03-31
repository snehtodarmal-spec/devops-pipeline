pipeline {
    agent any

    environment {
        IMAGE_NAME        = "devops-pipeline-app"
        IMAGE_TAG         = "${env.BUILD_NUMBER}"    
        EC2_HOST          = "3.236.211.72"
        EC2_USER          = "ec2-user"
        SONAR_HOST_URL    = "http://3.236.215.53:9000"
    }

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --oneline'
            }
        }

        stage('Install') {
            steps {
                dir('app') {
                    sh 'npm ci'
                }
            }
        }

        stage('Test') {
            steps {
                dir('app') {
                    sh 'npm test -- --coverage --forceExit'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                // withSonarQubeEnv refers to the name in your casc.yaml
                // withCredentials provides the token we know works
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_KEY')]) {
                        sh '''
                            sonar-scanner \
                                -Dsonar.projectKey=devops-pipeline-app \
                                -Dsonar.sources=app/src \
                                -Dsonar.tests=app/test \
                                -Dsonar.javascript.lcov.reportPaths=app/coverage/lcov.info \
                                -Dsonar.host.url=http://3.236.215.53:9000 \
                                -Dsonar.login=$SONAR_KEY
                        '''
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials', 
                    usernameVariable: 'D_USER', 
                    passwordVariable: 'D_PASS'
                )]) {
                    sh '''
                        # If D_USER is empty, manually set it to your known username
                        USERNAME=${D_USER:-navcomwest}
                        
                        echo "Logging into DockerHub as $USERNAME..."
                        printf '%s' "$D_PASS" | docker login -u "$USERNAME" --password-stdin

                        echo "Building Docker image..."
                        docker build \
                            -t "$USERNAME/$IMAGE_NAME:$IMAGE_TAG" \
                            -t "$USERNAME/$IMAGE_NAME:latest" \
                            .
                    '''
                }
            }
        }

        stage('Push to Registry') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials', 
                    usernameVariable: 'D_USER', 
                    passwordVariable: 'D_PASS'
                )]) {
                    sh '''
                        USERNAME=${D_USER:-navcomwest}
                        
                        echo "Pushing images to DockerHub..."
                        docker push "$USERNAME/$IMAGE_NAME:$IMAGE_TAG"
                        docker push "$USERNAME/$IMAGE_NAME:latest"
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                sh '''
                    echo "Preparing SSH key..."
                    # 1. Simple copy to a writable location to avoid Read-Only issues
                    cp /var/jenkins_home/ec2-key.pem /tmp/deploy_key.pem
                    chmod 600 /tmp/deploy_key.pem

                    echo "Diagnostic: Checking key fingerprint..."
                    ssh-keygen -l -f /tmp/deploy_key.pem || echo "Warning: Key format still looks invalid to local tools"

                    echo "Connecting to ${EC2_HOST}..."
                    # 2. Use -v to see the 'Handshake'. 
                    # If this fails, the log will tell us exactly why.
                    ssh -v -i /tmp/deploy_key.pem -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} "echo 'SSH Handshake Successful'"
                    
                    echo "Running Deployment Script..."
                    ssh -i /tmp/deploy_key.pem -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} "bash -s" < scripts/deploy-ec2.sh
                    
                    rm /tmp/deploy_key.pem
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed — check the console output."
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
