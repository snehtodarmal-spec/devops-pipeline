pipeline {
    agent any

    environment {
        IMAGE_NAME        = "devops-pipeline-app"
        IMAGE_TAG         = "${env.BUILD_NUMBER}"    
        EC2_HOST          = "52.207.217.65"
        EC2_USER          = "ec2-user"
        SONAR_HOST_URL    = "http://52.90.102.64:9000"
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
                                -Dsonar.host.url=http://52.90.102.64:9000 \
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
                    echo "Sanitizing SSH key..."
                    
                    # 1. Strip hidden Windows characters (\\r) and save to a writable location
                    # 2. Force a newline at the end (libcrypto requires this)
                    tr -d '\\r' < /var/jenkins_home/ec2-key.pem > /tmp/deploy_key.pem
                    echo "" >> /tmp/deploy_key.pem
                    
                    # 3. Set strict permissions on the NEW file
                    chmod 600 /tmp/deploy_key.pem

                    echo "Deploying to EC2 @ ${EC2_HOST}..."
                    
                    # 4. Use the cleaned key from /tmp
                    ssh -i /tmp/deploy_key.pem -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} \
                        "bash -s" < scripts/deploy-ec2.sh
                    
                    # 5. Clean up the temp file
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
